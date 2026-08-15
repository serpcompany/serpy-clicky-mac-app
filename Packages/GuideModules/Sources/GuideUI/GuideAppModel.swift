import AppKit
import Carbon
import GuideCore
import GuideMac
import Observation

@MainActor
@Observable
public final class GuideAppModel {
    public static let shared = GuideAppModel()

    public private(set) var phase: DictationPhase = .idle
    public private(set) var partialTranscript = ""
    public private(set) var statusMessage = "Starting…"
    public private(set) var recoveryMessage = ""
    public private(set) var permissions: PermissionSnapshot
    public private(set) var lastInsertionMethod: TextInsertionMethod?
    public private(set) var guidancePhase: GuidancePhase = .idle
    public private(set) var guidanceAnswer = ""
    public var guidanceQuestion = "What should I do next?"
    public var companionEnabled: Bool {
        didSet {
            guard oldValue != companionEnabled else { return }
            defaults.set(companionEnabled, forKey: Keys.companionEnabled)
            companionMachine.setEnabled(companionEnabled)
            applyCompanionVisibility()
        }
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let permissionService: PermissionService
    @ObservationIgnored private let transcriber: AppleSpeechTranscriber
    @ObservationIgnored private let insertionService: TextInsertionService
    @ObservationIgnored private let screenContextService: ScreenContextService
    @ObservationIgnored private let localGuidanceService: LocalGuidanceService
    @ObservationIgnored private let presentation: CompanionPresentation
    @ObservationIgnored private let companionController: CompanionPanelController
    @ObservationIgnored private var hotKeyService: GlobalHotKeyService?
    @ObservationIgnored private var guidanceHotKeyService: GlobalHotKeyService?
    @ObservationIgnored private var dictationMachine = DictationStateMachine()
    @ObservationIgnored private var companionMachine: CompanionStateMachine
    @ObservationIgnored private var focusedTarget: FocusedTextTarget?
    @ObservationIgnored private var started = false

    private enum Keys {
        static let companionEnabled = "GuideCompanion.companionEnabled"
    }

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        permissionService = PermissionService()
        transcriber = AppleSpeechTranscriber()
        insertionService = TextInsertionService()
        screenContextService = ScreenContextService()
        localGuidanceService = LocalGuidanceService()
        let presentation = CompanionPresentation()
        self.presentation = presentation
        companionController = CompanionPanelController(presentation: presentation)
        let enabled = defaults.object(forKey: Keys.companionEnabled) as? Bool ?? true
        companionEnabled = enabled
        companionMachine = CompanionStateMachine(isEnabled: enabled)
        permissions = PermissionSnapshot(
            microphone: .unknown,
            speechRecognition: .unknown,
            accessibility: .unknown,
            screenRecording: .unknown
        )
    }

    public var menuBarSymbol: String {
        switch phase {
        case .recording: "waveform.circle.fill"
        case .preparing, .transcribing, .inserting: "ellipsis.circle.fill"
        case .failed: "exclamationmark.circle.fill"
        default: "location.north.circle.fill"
        }
    }

    public var shortStatus: String {
        switch phase {
        case .idle: permissions.dictationReady ? "ready" : "setup needed"
        case .preparing: "preparing"
        case .recording: "recording"
        case .transcribing: "transcribing"
        case .inserting: "inserting text"
        case .succeeded: "dictation inserted"
        case .cancelled: "cancelled"
        case .failed: "needs attention"
        }
    }

    public var dictationReady: Bool {
        permissions.dictationReady && transcriber.isOnDeviceAvailable
    }

    public var speechAvailability: String {
        transcriber.availabilityDescription
    }

    public var shortcutDescription: String {
        "Control–Option–Space"
    }

    public func start() async {
        guard !started else { return }
        started = true
        refreshPermissions()

        let service = GlobalHotKeyService(
            pressed: { [weak self] in self?.hotKeyPressed() },
            released: { [weak self] in self?.hotKeyReleased() }
        )
        hotKeyService = service
        do {
            try service.start()
            let guidanceService = GlobalHotKeyService(
                keyCode: UInt32(kVK_ANSI_G),
                identifier: 2,
                pressed: { [weak self] in
                    Task { await self?.guideCurrentScreen() }
                },
                released: {}
            )
            try guidanceService.start()
            guidanceHotKeyService = guidanceService
            statusMessage = dictationReady
                ? "Ready. Hold \(shortcutDescription) to dictate."
                : "Complete the three dictation permissions to begin."
            if !dictationReady {
                presentation.mode = .ready
                presentation.caption = "Open Guide Companion in the menu bar to finish setup"
                companionController.refresh()
                Task { [weak self] in
                    try? await Task.sleep(for: .seconds(10))
                    guard let self, !phase.isActive, !guidancePhase.isActive else { return }
                    presentation.caption = ""
                    companionController.refresh()
                }
            }
        } catch {
            presentFailure(
                GuideFailure(
                    stage: .activation,
                    message: error.localizedDescription,
                    recovery: "Quit the app using that shortcut, then relaunch Guide Companion."
                )
            )
        }
        applyCompanionVisibility()
    }

    public func stop() {
        hotKeyService?.stop()
        hotKeyService = nil
        guidanceHotKeyService?.stop()
        guidanceHotKeyService = nil
        transcriber.cancel()
        companionController.hide()
    }

    public func refreshPermissions() {
        permissions = permissionService.snapshot()
        if dictationReady, !phase.isActive {
            statusMessage = "Ready. Hold \(shortcutDescription) to dictate."
            recoveryMessage = ""
        }
    }

    public func requestVoicePermissions() async {
        let microphoneGranted = await requestMicrophonePermission()
        guard microphoneGranted else { return }
        _ = await requestSpeechPermission()
    }

    @discardableResult
    public func requestMicrophonePermission() async -> Bool {
        NSApplication.shared.activate(ignoringOtherApps: true)
        statusMessage = "Waiting for macOS Microphone permission…"
        recoveryMessage = "Respond to the macOS prompt. If no prompt appears, use Open Settings beside Microphone."
        let granted = await permissionService.requestMicrophone()
        refreshPermissions()
        if granted {
            statusMessage = "Microphone granted. Speech Recognition is the next voice permission."
            recoveryMessage = ""
        } else {
            presentFailure(
                GuideFailure(
                    stage: .permission,
                    message: "Microphone access was not granted.",
                    recovery: "Open Microphone settings and enable Guide Companion when you are ready."
                )
            )
        }
        return granted
    }

    @discardableResult
    public func requestSpeechPermission() async -> Bool {
        NSApplication.shared.activate(ignoringOtherApps: true)
        statusMessage = "Waiting for macOS Speech Recognition permission…"
        recoveryMessage = "Respond to the macOS prompt. If no prompt appears, use Open Settings beside Speech Recognition."
        let granted = await permissionService.requestSpeechRecognition()
        refreshPermissions()
        if granted {
            statusMessage = permissions.dictationReady
                ? "Voice permissions granted. Enable Accessibility to insert dictated text."
                : "Speech Recognition granted."
            recoveryMessage = ""
        } else {
            presentFailure(
                GuideFailure(
                    stage: .permission,
                    message: "Speech Recognition access was not granted.",
                    recovery: "Open Speech Recognition settings and enable Guide Companion."
                )
            )
        }
        return granted
    }

    public func requestAccessibility() {
        statusMessage = "Accessibility lets Guide Companion place your transcript in the field you selected."
        _ = permissionService.requestAccessibility()
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            self?.refreshPermissions()
        }
    }

    public func openSettings(for permission: GuidePermission) {
        permissionService.openSystemSettings(for: permission)
    }

    public func guideCurrentScreen() async {
        guard !guidancePhase.isActive else { return }
        let question = guidanceQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else {
            guidanceAnswer = "Type a short question about the current screen first."
            return
        }

        refreshPermissions()
        if !permissions.screenRecording.isGranted {
            guidancePhase = .requestingPermission
            statusMessage = "Screen access is used only for this guide request. macOS will ask now."
            let granted = permissionService.requestScreenRecording()
            refreshPermissions()
            guard granted || permissions.screenRecording.isGranted else {
                let failure = GuideFailure(
                    stage: .permission,
                    message: "Screen access was not granted.",
                    recovery: "Open Screen & System Audio Recording settings, enable Guide Companion, then try again."
                )
                guidancePhase = .failed(failure)
                guidanceAnswer = failure.recovery
                presentGuidanceCaption(failure.message, mode: .error)
                return
            }
        }

        do {
            guidancePhase = .capturing
            presentGuidanceCaption("Reading current window…", mode: .working)
            let context = try await screenContextService.captureFrontmostContext()
            guard !context.promptText.isEmpty else {
                throw GuideFailure(
                    stage: .understanding,
                    message: "I could not read useful text in that window.",
                    recovery: "Bring the relevant window forward and try again."
                )
            }
            guidancePhase = .thinking
            presentGuidanceCaption("Thinking locally…", mode: .working)
            let plan = try await localGuidanceService.answer(question: question, context: context)
            let validated = GuidancePlanValidator.validate(plan, in: context.windowFrame)
            guidanceAnswer = validated.answer
            guidancePhase = .presenting
            statusMessage = "Local guidance is ready."
            recoveryMessage = ""
            presentGuidanceCaption(validated.answer, mode: .success)
        } catch {
            let failure = normalize(error, stage: .guidance)
            guidancePhase = .failed(failure)
            guidanceAnswer = failure.message + " " + failure.recovery
            presentGuidanceCaption(failure.message, mode: .error)
        }
    }

    public func cancelDictation() {
        guard phase.isActive else { return }
        transcriber.cancel()
        dictationMachine.cancel()
        phase = dictationMachine.phase
        focusedTarget = nil
        partialTranscript = ""
        statusMessage = "Dictation cancelled."
        presentation.mode = .ready
        presentation.caption = "Cancelled"
        companionController.refresh()
        scheduleReset()
    }

    private func hotKeyPressed() {
        refreshPermissions()
        guard dictationReady else {
            presentFailure(
                GuideFailure(
                    stage: .permission,
                    message: "Dictation setup is incomplete.",
                    recovery: "Open Guide Companion from the menu bar and complete Microphone, Speech Recognition, and Accessibility."
                )
            )
            return
        }
        guard !phase.isActive else { return }

        do {
            dictationMachine.reset()
            try dictationMachine.prepare()
            phase = dictationMachine.phase
            focusedTarget = try insertionService.captureFocusedTarget()
            partialTranscript = ""
            recoveryMessage = ""
            try transcriber.start { [weak self] text in
                self?.partialTranscript = text
            }
            try dictationMachine.beginRecording()
            phase = dictationMachine.phase
            statusMessage = "Listening… release \(shortcutDescription) to insert."
            presentation.mode = .recording
            presentation.caption = "Listening…"
            companionController.refresh()
        } catch {
            focusedTarget = nil
            presentFailure(normalize(error, stage: .recording))
        }
    }

    private func hotKeyReleased() {
        guard phase == .recording, let focusedTarget else { return }
        do {
            try dictationMachine.beginTranscription()
            phase = dictationMachine.phase
            statusMessage = "Finishing local transcription…"
            presentation.mode = .working
            presentation.caption = "Transcribing…"
            companionController.refresh()
        } catch {
            presentFailure(normalize(error, stage: .transcription))
            return
        }

        Task { [weak self] in
            guard let self else { return }
            do {
                let transcript = try await transcriber.stop()
                try dictationMachine.beginInsertion()
                phase = dictationMachine.phase
                statusMessage = "Inserting text…"
                lastInsertionMethod = try await insertionService.insert(transcript, into: focusedTarget)
                try dictationMachine.succeed()
                phase = dictationMachine.phase
                partialTranscript = transcript
                statusMessage = "Dictation inserted locally."
                recoveryMessage = ""
                self.focusedTarget = nil
                presentation.mode = .success
                presentation.caption = "Inserted"
                companionController.refresh()
                scheduleReset()
            } catch is CancellationError {
                cancelDictation()
            } catch {
                self.focusedTarget = nil
                presentFailure(normalize(error, stage: .transcription))
            }
        }
    }

    private func presentFailure(_ failure: GuideFailure) {
        if phase.isActive {
            dictationMachine.fail(failure)
            phase = dictationMachine.phase
        } else {
            phase = .failed(failure)
        }
        statusMessage = failure.message
        recoveryMessage = failure.recovery
        presentation.mode = .error
        presentation.caption = failure.message
        companionController.refresh()
        scheduleReset(after: 4)
    }

    private func presentGuidanceCaption(_ text: String, mode: CompanionMode) {
        presentation.mode = mode
        presentation.caption = text
        companionController.refresh()
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(mode == .success ? 8 : 4))
            guard let self, !guidancePhase.isActive else { return }
            guidancePhase = .idle
            presentation.mode = .ready
            presentation.caption = ""
            companionController.refresh()
        }
    }

    private func normalize(_ error: Error, stage: GuideFailureStage) -> GuideFailure {
        if let failure = error as? GuideFailure {
            return failure
        }
        return GuideFailure(
            stage: stage,
            message: error.localizedDescription,
            recovery: "Try again. If the problem continues, open Guide Companion and check permissions."
        )
    }

    private func scheduleReset(after seconds: Double = 1.4) {
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard let self, !phase.isActive else { return }
            dictationMachine.reset()
            phase = .idle
            partialTranscript = ""
            presentation.mode = .ready
            presentation.caption = ""
            companionController.refresh()
            refreshPermissions()
        }
    }

    private func applyCompanionVisibility() {
        switch companionMachine.visibility {
        case .visible:
            companionController.show()
        case .disabled, .blocked, .temporarilyHidden:
            companionController.hide()
        }
    }
}
