import AppKit
import Carbon
import GuideCore
import GuideMac
import Observation
import OSLog

@MainActor
@Observable
public final class GuideAppModel: GuideTurnOverlayPresenting {
    public static let shared = GuideAppModel()

    public private(set) var phase: DictationPhase = .idle
    public private(set) var partialTranscript = ""
    public private(set) var statusMessage = "Starting…"
    public private(set) var recoveryMessage = ""
    public private(set) var permissions: PermissionSnapshot
    public private(set) var lastInsertionMethod: TextInsertionMethod?
    public private(set) var guidancePhase: GuidancePhase = .idle
    public private(set) var guidanceMessages: [GuidanceMessage] = []
    public private(set) var guidanceContextLabel = "No screen context captured yet"
    public private(set) var guidancePartialTranscript = ""
    public private(set) var hotKeyRegistered = false
    public private(set) var dictationAttemptCount = 0
    public private(set) var lastActivationMessage = "No dictation activation received yet."
    public private(set) var lastDictationStage = "Waiting"
    public private(set) var lastFailureMessage = "None"
    public private(set) var transcriptRecovery = EphemeralTranscriptRecovery()
    public private(set) var transcriptHistory: [TranscriptHistoryEntry] = []
    public private(set) var historyStatusMessage = "Loading local history…"
    public private(set) var dictationShortcut: GlobalHotKeyConfiguration
    public var companionEnabled: Bool {
        didSet {
            guard oldValue != companionEnabled else { return }
            defaults.set(companionEnabled, forKey: Keys.companionEnabled)
            companionMachine.setEnabled(companionEnabled)
            applyCompanionVisibility()
        }
    }
    public var historyEnabled: Bool {
        didSet {
            guard oldValue != historyEnabled else { return }
            defaults.set(historyEnabled, forKey: Keys.historyEnabled)
            if !historyEnabled, saveAudioHistory {
                saveAudioHistory = false
            }
        }
    }
    public var saveAudioHistory: Bool {
        didSet {
            guard oldValue != saveAudioHistory else { return }
            defaults.set(saveAudioHistory, forKey: Keys.saveAudioHistory)
        }
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let permissionService: PermissionService
    @ObservationIgnored private let transcriber: AppleSpeechTranscriber
    @ObservationIgnored private let insertionService: TextInsertionService
    @ObservationIgnored private let historyStore: TranscriptHistoryStore
    @ObservationIgnored private let screenContextService: ScreenContextService
    @ObservationIgnored private let localGuidanceService: LocalGuidanceService
    @ObservationIgnored private let guidanceTranscriber: AppleSpeechTranscriber
    @ObservationIgnored private let guidanceSpeaker: LocalSpeechOutputService
    @ObservationIgnored private let presentation: CompanionPresentation
    @ObservationIgnored private let companionController: CompanionPanelController
    @ObservationIgnored private var hotKeyService: GlobalHotKeyService?
    @ObservationIgnored private var guidanceHotKeyService: GlobalHotKeyService?
    @ObservationIgnored private var dictationMachine = DictationStateMachine()
    @ObservationIgnored private let activationPolicy = DictationActivationPolicy()
    @ObservationIgnored private var companionMachine: CompanionStateMachine
    @ObservationIgnored private let companionVisibilityPolicy = CompanionVisibilityPolicy()
    @ObservationIgnored private var focusedTarget: FocusedTextTarget?
    @ObservationIgnored private var guideWindowController: GuideConversationWindowController?
    @ObservationIgnored private var guideResponseDismissalTask: Task<Void, Never>?
    @ObservationIgnored private lazy var guideTurnCoordinator = GuideTurnCoordinator(
        capture: screenContextService,
        transcription: AppleSpeechGuideTurnTranscriber(transcriber: guidanceTranscriber),
        generation: localGuidanceService,
        speech: LocalGuideTurnSpeaker(speaker: guidanceSpeaker),
        overlay: self
    )
    @ObservationIgnored private var started = false

    @ObservationIgnored private static let logger = Logger(
        subsystem: "com.serpcompany.guidecompanion.internal",
        category: "dictation"
    )

    private enum Keys {
        static let companionEnabled = "GuideCompanion.companionEnabled"
        static let historyEnabled = "GuideCompanion.historyEnabled"
        static let saveAudioHistory = "GuideCompanion.saveAudioHistory"
        static let dictationShortcut = "SERPy.dictationShortcut"
    }

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        permissionService = PermissionService()
        transcriber = AppleSpeechTranscriber()
        insertionService = TextInsertionService()
        historyStore = TranscriptHistoryStore()
        screenContextService = ScreenContextService()
        localGuidanceService = LocalGuidanceService()
        guidanceTranscriber = AppleSpeechTranscriber()
        guidanceSpeaker = LocalSpeechOutputService()
        let presentation = CompanionPresentation()
        self.presentation = presentation
        companionController = CompanionPanelController(presentation: presentation)
        let enabled = defaults.object(forKey: Keys.companionEnabled) as? Bool ?? true
        dictationShortcut = defaults.data(forKey: Keys.dictationShortcut)
            .flatMap { try? JSONDecoder().decode(GlobalHotKeyConfiguration.self, from: $0) }
            ?? .dictation
        historyEnabled = defaults.object(forKey: Keys.historyEnabled) as? Bool ?? false
        saveAudioHistory = defaults.object(forKey: Keys.saveAudioHistory) as? Bool ?? false
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
        if guidancePhase == .listening {
            return "waveform.circle.fill"
        }
        if guidancePhase.isActive {
            return "ellipsis.circle.fill"
        }
        return switch phase {
        case .recording: "waveform.circle.fill"
        case .preparing, .transcribing, .inserting: "ellipsis.circle.fill"
        case .failed: "exclamationmark.circle.fill"
        default: hasRecoveryRequiringAttention ? "exclamationmark.bubble.fill" : "location.north.circle.fill"
        }
    }

    public var shortStatus: String {
        switch guidancePhase {
        case .listening: return "listening to question"
        case .transcribing: return "understanding question"
        case .capturing, .reading: return "reading screen"
        case .thinking: return "thinking locally"
        case .requestingPermission: return "guide setup needed"
        case .idle, .presenting, .failed: break
        }
        return switch phase {
        case .idle: hasRecoveryRequiringAttention ? "dictation recovered" : (permissions.dictationReady ? "ready" : "setup needed")
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
        dictationShortcut.displayName
    }

    public var hasRecoverableTranscript: Bool {
        transcriptRecovery.isAvailable || !transcriptHistory.isEmpty
    }

    public var recoverableTranscript: String {
        transcriptRecovery.transcript ?? transcriptHistory.first?.text ?? ""
    }

    public var hasRecoveryRequiringAttention: Bool {
        guard let state = transcriptHistory.first?.deliveryState else { return false }
        return state == .pending || state == .unconfirmed || state == .failed
    }

    public func start() async {
        guard !started else { return }
        started = true
        refreshPermissions()
        await loadTranscriptHistory()

        let service = makeDictationHotKeyService(configuration: dictationShortcut)
        hotKeyService = service
        do {
            try service.start()
            hotKeyRegistered = true
            Self.logger.notice("Global dictation shortcut registered")
            let guidanceService = GlobalHotKeyService(
                configuration: GlobalHotKeyConfiguration(
                    keyCode: UInt32(kVK_ANSI_G),
                    modifiers: UInt32(controlKey | optionKey),
                    displayName: "Control–Option–G"
                ),
                pressed: { [weak self] in self?.guidanceHotKeyPressed() },
                released: {},
                cancelled: { [weak self] in self?.guidanceEscapePressed() }
            )
            try guidanceService.start()
            guidanceHotKeyService = guidanceService
            statusMessage = hasRecoveryRequiringAttention
                ? "A saved dictation still needs confirmation or retry."
                : (dictationReady
                    ? "Ready. Press \(shortcutDescription) to start or stop dictation."
                    : "Complete the three dictation permissions to begin.")
            if !dictationReady {
                presentation.mode = .ready
                presentation.caption = "Open SERPy in the menu bar to finish setup"
                companionController.refresh()
                Task { [weak self] in
                    try? await Task.sleep(for: .seconds(10))
                    guard let self, !phase.isActive, !guidancePhase.isActive else { return }
                    presentation.caption = ""
                    companionController.refresh()
                }
            }
        } catch {
            hotKeyRegistered = false
            presentFailure(
                GuideFailure(
                    stage: .activation,
                    message: error.localizedDescription,
                    recovery: "Quit the other app using that shortcut, or choose a different shortcut in SERPy Settings."
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
        guidanceTranscriber.cancel()
        guidanceSpeaker.stop()
        guideTurnCoordinator.cancel()
        guideResponseDismissalTask?.cancel()
        guideResponseDismissalTask = nil
        companionController.hide()
        hotKeyRegistered = false
    }

    public func refreshPermissions() {
        permissions = permissionService.snapshot()
        if dictationReady, !phase.isActive {
            if hasRecoveryRequiringAttention {
                statusMessage = "A saved dictation still needs confirmation or retry."
                recoveryMessage = "Open History to Copy, Retry, or Delete it."
            } else {
                statusMessage = "Ready. Press \(shortcutDescription) to start or stop dictation."
                recoveryMessage = ""
            }
        }
    }

    public func requestVoicePermissions() async {
        let microphoneGranted = await requestMicrophonePermission()
        guard microphoneGranted else { return }
        _ = await requestSpeechPermission()
    }

    public func setDictationShortcut(_ configuration: GlobalHotKeyConfiguration) {
        guard configuration != dictationShortcut else { return }
        let previous = dictationShortcut
        hotKeyService?.stop()

        let replacement = makeDictationHotKeyService(configuration: configuration)
        do {
            try replacement.start()
            hotKeyService = replacement
            dictationShortcut = configuration
            if let data = try? JSONEncoder().encode(configuration) {
                defaults.set(data, forKey: Keys.dictationShortcut)
            }
            hotKeyRegistered = true
            statusMessage = "Dictation shortcut changed to \(configuration.displayName)."
            recoveryMessage = "Press once to start, press again to insert, or press Escape to cancel."
        } catch {
            let fallback = makeDictationHotKeyService(configuration: previous)
            hotKeyService = fallback
            hotKeyRegistered = (try? fallback.start()) != nil
            statusMessage = "\(configuration.displayName) is unavailable."
            recoveryMessage = "Quit the other app using it, or record a different shortcut. \(previous.displayName) remains active."
        }
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
                    recovery: "Open Microphone settings and enable SERPy when you are ready."
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
                    recovery: "Open Speech Recognition settings and enable SERPy."
                )
            )
        }
        return granted
    }

    public func requestAccessibility() {
        statusMessage = "Accessibility lets SERPy place your transcript in the field you selected."
        _ = permissionService.requestAccessibility()
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            self?.refreshPermissions()
        }
    }

    public func openSettings(for permission: GuidePermission) {
        permissionService.openSystemSettings(for: permission)
    }

    public func openGuidanceTranscript() {
        if guideWindowController == nil {
            guideWindowController = GuideConversationWindowController(model: self)
        }
        guideWindowController?.present()
    }

    public func startNewGuidanceConversation() {
        guard !guidancePhase.isActive else { return }
        guideTurnCoordinator.resetConversation()
        guidanceMessages = guideTurnCoordinator.conversation
        guidancePhase = .idle
        guidanceContextLabel = "No screen context captured yet"
        guidancePartialTranscript = ""
        presentation.guideStage = nil
        presentation.contextLabel = nil
        presentation.responseText = ""
        applyCompanionVisibility()
    }

    public func toggleGuidanceVoice() {
        guidanceHotKeyPressed()
    }

    public func toggleDictationFromMenu() {
        hotKeyPressed()
    }

    public func cancelGuidanceVoice() {
        guideTurnCoordinator.cancel()
    }

    private func guidanceHotKeyPressed() {
        switch guidancePhase {
        case .listening:
            guideTurnCoordinator.finishListening()
        case .idle, .presenting, .failed:
            startGuidanceVoiceTurn()
        case .requestingPermission, .transcribing, .capturing, .reading, .thinking:
            break
        }
    }

    private func guidanceEscapePressed() {
        if guidancePhase != .idle {
            cancelGuidanceVoice()
        }
    }

    private func startGuidanceVoiceTurn() {
        guard !phase.isActive else {
            presentGuidanceFailure(
                GuideFailure(
                    stage: .recording,
                    message: "Dictation is already active.",
                    recovery: "Finish or cancel dictation, then talk to SERPy."
                )
            )
            return
        }

        guideResponseDismissalTask?.cancel()
        guideResponseDismissalTask = nil
        screenContextService.rememberFrontmostApplication()
        let lockedTarget: GuideWindowTarget
        do {
            lockedTarget = try screenContextService.snapshotTarget()
        } catch {
            presentGuidanceFailure(normalize(error, stage: .capture))
            return
        }

        refreshPermissions()
        guard permissions.microphone.isGranted,
              permissions.speechRecognition.isGranted,
              guidanceTranscriber.isOnDeviceAvailable
        else {
            presentGuidanceFailure(
                GuideFailure(
                    stage: .permission,
                    message: "Voice guide setup is incomplete.",
                    recovery: "Open SERPy Settings and enable Microphone and Speech Recognition."
                )
            )
            return
        }

        if !permissions.screenRecording.isGranted {
            guidancePhase = .requestingPermission
            applyCompanionVisibility()
            statusMessage = "Screen access is used only for this voice question. macOS will ask now."
            let granted = permissionService.requestScreenRecording()
            refreshPermissions()
            guard granted || permissions.screenRecording.isGranted else {
                presentGuidanceFailure(
                    GuideFailure(
                        stage: .permission,
                        message: "Screen access was not granted.",
                        recovery: "Enable SERPy in Screen & System Audio Recording settings, then try again."
                    )
                )
                return
            }
        }

        guidancePartialTranscript = ""
        do {
            try guideTurnCoordinator.start(target: lockedTarget)
            statusMessage = "Listening for your guide question. Press Control–Option–G again to ask, or Escape to cancel."
            recoveryMessage = ""
        } catch {
            presentGuidanceFailure(normalize(error, stage: .recording))
        }
    }

    private func presentGuidanceFailure(_ failure: GuideFailure) {
        guidancePhase = .failed(failure)
        statusMessage = failure.message
        recoveryMessage = failure.recovery
        presentGuidanceCaption(failure.message, mode: .error)
    }

    public func cancelDictation() {
        guard phase.isActive else { return }
        transcriber.cancel()
        dictationMachine.cancel()
        phase = dictationMachine.phase
        focusedTarget = nil
        partialTranscript = ""
        statusMessage = "Dictation cancelled."
        lastDictationStage = "Cancelled"
        Self.logger.notice("Dictation cancelled")
        presentation.mode = .ready
        presentation.caption = "Cancelled"
        companionController.refresh()
        scheduleReset()
    }

    public func beginManualDictationTest() {
        guard !phase.isActive else { return }
        statusMessage = "Click the destination text field now. Listening starts in 4 seconds."
        recoveryMessage = "After speaking, reopen SERPy and click Stop & Insert."
        presentation.mode = .working
        presentation.caption = "Click a text field — listening starts in 4…"
        companionController.refresh()
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard let self else { return }
            startDictation(source: "Manual test")
        }
    }

    public func finishManualDictationTest() {
        finishDictation(source: "Manual test button")
    }

    public func beginInsertionTest() {
        guard !phase.isActive else { return }
        statusMessage = "Click the destination text field now. The test phrase inserts in 4 seconds."
        recoveryMessage = ""
        lastDictationStage = "Waiting for insertion test target"
        presentation.mode = .working
        presentation.caption = "Click a text field — test inserts in 4…"
        companionController.refresh()
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard let self else { return }
            do {
                lastDictationStage = "Testing text insertion"
                let target = try insertionService.captureFocusedTarget()
                lastInsertionMethod = try await insertionService.insert(
                    "SERPy insertion test.",
                    into: target
                )
                lastDictationStage = "Insertion test succeeded via \(lastInsertionMethod?.rawValue ?? "unknown")"
                statusMessage = "The insertion test succeeded."
                lastFailureMessage = "None"
                presentation.mode = .success
                presentation.caption = "Insertion works"
                companionController.refresh()
            } catch {
                lastDictationStage = "Insertion test failed"
                presentFailure(normalize(error, stage: .insertion))
            }
        }
    }

    public func copyLastTranscript() {
        guard !recoverableTranscript.isEmpty else { return }
        copyTranscript(recoverableTranscript)
    }

    public func copyHistoryEntry(_ entry: TranscriptHistoryEntry) {
        copyTranscript(entry.text)
    }

    private func copyTranscript(_ transcript: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        guard pasteboard.setString(transcript, forType: .string) else {
            statusMessage = "The last dictation could not be copied."
            return
        }
        statusMessage = "Last dictation copied. Paste it wherever you need it."
        recoveryMessage = "The saved transcript remains available in local history."
    }

    public func retryLastTranscript() {
        guard !phase.isActive, !recoverableTranscript.isEmpty else { return }
        retryTranscript(recoverableTranscript, historyID: transcriptHistory.first?.id)
    }

    public func retryHistoryEntry(_ entry: TranscriptHistoryEntry) {
        guard !phase.isActive else { return }
        retryTranscript(entry.text, historyID: entry.id)
    }

    private func retryTranscript(_ transcript: String, historyID: UUID?) {
        lastInsertionMethod = nil
        statusMessage = "Click the destination text field now. Retrying in 4 seconds."
        recoveryMessage = "The transcript stays saved even if this attempt fails."
        lastDictationStage = "Waiting for retry target"
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard let self else { return }
            do {
                lastDictationStage = "Retrying last dictation"
                let target = try insertionService.captureFocusedTarget()
                lastInsertionMethod = try await insertionService.insert(transcript, into: target)
                let confirmed = lastInsertionMethod?.isConfirmed == true
                if let historyID {
                    transcriptHistory = try await historyStore.updateDelivery(
                        id: historyID,
                        state: confirmed ? .confirmed : .unconfirmed,
                        method: lastInsertionMethod?.rawValue,
                        targetBundleIdentifier: target.bundleIdentifier
                    )
                }
                statusMessage = confirmed
                    ? "Saved dictation inserted locally."
                    : "Paste sent, but the destination could not be verified."
                recoveryMessage = confirmed
                    ? "The transcript remains in local history."
                    : "Check the destination. Use Copy or Retry only if the text is missing."
                lastFailureMessage = "None"
                lastDictationStage = "Retry succeeded via \(lastInsertionMethod?.rawValue ?? "unknown")"
                presentation.mode = confirmed ? .success : .error
                presentation.caption = confirmed ? "Inserted" : "Saved — verify paste"
                companionController.refresh()
            } catch {
                if let historyID {
                    transcriptHistory = (try? await historyStore.updateDelivery(
                        id: historyID,
                        state: .failed,
                        method: lastInsertionMethod?.rawValue
                    )) ?? transcriptHistory
                }
                lastDictationStage = "Retry failed"
                presentFailure(normalize(error, stage: .insertion))
            }
        }
    }

    public func clearLastTranscript() {
        transcriptRecovery.clear()
        guard let id = transcriptHistory.first?.id else {
            statusMessage = "Last dictation cleared."
            recoveryMessage = ""
            return
        }
        deleteHistoryEntry(id: id)
    }

    public func deleteHistoryEntry(id: UUID) {
        Task { [weak self] in
            guard let self else { return }
            do {
                transcriptHistory = try await historyStore.delete(id: id)
                if let latest = transcriptHistory.first {
                    transcriptRecovery = EphemeralTranscriptRecovery(transcript: latest.text)
                } else {
                    transcriptRecovery.clear()
                }
                statusMessage = "Saved dictation deleted."
                recoveryMessage = ""
                historyStatusMessage = historySummary
            } catch {
                historyStatusMessage = "History deletion failed. Try again."
            }
        }
    }

    public func clearTranscriptHistory() {
        Task { [weak self] in
            guard let self else { return }
            do {
                try await historyStore.clear()
                transcriptHistory = []
                transcriptRecovery.clear()
                historyStatusMessage = "No saved dictations."
                statusMessage = "Local transcript and audio history cleared."
                recoveryMessage = ""
            } catch {
                historyStatusMessage = "History could not be cleared. Try again."
            }
        }
    }

    public var historySummary: String {
        switch transcriptHistory.count {
        case 0: "No saved dictations."
        case 1: "1 saved dictation."
        default: "\(transcriptHistory.count) saved dictations."
        }
    }

    private func loadTranscriptHistory() async {
        do {
            transcriptHistory = try await historyStore.load()
            if let latest = transcriptHistory.first {
                transcriptRecovery.preserve(latest.text)
                if latest.deliveryState == .pending {
                    statusMessage = "A dictation was recovered before delivery completed."
                    recoveryMessage = "Use Copy or Retry after focusing the intended field."
                }
            }
            historyStatusMessage = historySummary
        } catch {
            historyStatusMessage = "Local history could not be read. Existing data was not overwritten."
            recoveryMessage = "SERPy will not overwrite unreadable history."
        }
    }

    private func hotKeyPressed() {
        switch activationPolicy.shortcutAction(for: phase) {
        case .start:
            startDictation(source: "Shortcut toggle")
        case .finish:
            finishDictation(source: "Shortcut toggle")
        case .cancel:
            cancelDictation()
        case .none:
            break
        }
    }

    private func startDictation(source: String) {
        dictationAttemptCount += 1
        lastActivationMessage = "\(source) received at \(Date.now.formatted(date: .omitted, time: .standard))"
        lastDictationStage = "Checking permissions"
        Self.logger.notice("Dictation activation received; source=\(source, privacy: .public)")
        refreshPermissions()
        guard dictationReady else {
            presentFailure(
                GuideFailure(
                    stage: .permission,
                    message: "Dictation setup is incomplete.",
                    recovery: "Open SERPy from the menu bar and complete Microphone, Speech Recognition, and Accessibility."
                )
            )
            lastDictationStage = "Blocked: setup incomplete"
            Self.logger.error("Dictation blocked because setup is incomplete")
            return
        }
        guard !phase.isActive else { return }

        do {
            dictationMachine.reset()
            try dictationMachine.prepare()
            phase = dictationMachine.phase
            lastDictationStage = "Capturing focused text field"
            focusedTarget = try insertionService.captureFocusedTarget()
            lastInsertionMethod = nil
            partialTranscript = ""
            recoveryMessage = ""
            try transcriber.start(saveAudio: historyEnabled && saveAudioHistory) { [weak self] text in
                self?.partialTranscript = text
                if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    self?.lastDictationStage = "Speech detected (\(text.count) characters)"
                }
            }
            try dictationMachine.beginRecording()
            phase = dictationMachine.phase
            statusMessage = "Listening… press \(shortcutDescription) again to insert, or Escape to cancel."
            lastDictationStage = "Listening"
            Self.logger.notice("Microphone recording started")
            presentation.mode = .recording
            presentation.caption = "Listening…"
            companionController.refresh()
        } catch {
            focusedTarget = nil
            lastDictationStage = "Failed before recording"
            Self.logger.error("Dictation failed before recording: \(error.localizedDescription, privacy: .public)")
            presentFailure(normalize(error, stage: .recording))
        }
    }

    private func hotKeyReleased() {
        // Toggle dictation intentionally continues after every key is released.
    }

    private func escapePressed() {
        guard activationPolicy.escapeAction(for: phase) == .cancel else { return }
        cancelDictation()
    }

    private func makeDictationHotKeyService(
        configuration: GlobalHotKeyConfiguration
    ) -> GlobalHotKeyService {
        GlobalHotKeyService(
            configuration: configuration,
            pressed: { [weak self] in self?.hotKeyPressed() },
            released: { [weak self] in self?.hotKeyReleased() },
            cancelled: { [weak self] in self?.escapePressed() }
        )
    }

    private func finishDictation(source: String) {
        guard phase == .recording, let focusedTarget else { return }
        Self.logger.notice("Dictation finish received; source=\(source, privacy: .public)")
        do {
            try dictationMachine.beginTranscription()
            phase = dictationMachine.phase
            statusMessage = "Finishing local transcription…"
            lastDictationStage = "Finishing transcription"
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
                let result = try await transcriber.stop()
                let transcript = result.transcript
                transcriptRecovery.preserve(transcript)
                partialTranscript = transcript
                let historyEntry: TranscriptHistoryEntry
                do {
                    let entry = try await historyStore.preserve(
                        text: transcript,
                        targetBundleIdentifier: focusedTarget.bundleIdentifier,
                        temporaryAudioURL: result.temporaryAudioURL,
                        retainInHistory: historyEnabled
                    )
                    historyEntry = entry
                    transcriptHistory = try await historyStore.load()
                    historyStatusMessage = historySummary
                    lastDictationStage = "Transcript saved before delivery"
                } catch {
                    if let url = result.temporaryAudioURL {
                        try? FileManager.default.removeItem(at: url)
                    }
                    copyTranscript(transcript)
                    throw GuideFailure(
                        stage: .storage,
                        message: "The transcript could not be saved safely, so automatic insertion was stopped.",
                        recovery: "The transcript is still shown in SERPy and copied to the clipboard. Check available disk space, then paste it manually."
                    )
                }
                try dictationMachine.beginInsertion()
                phase = dictationMachine.phase
                statusMessage = "Inserting text…"
                lastDictationStage = "Inserting text"
                do {
                    lastInsertionMethod = try await insertionService.insert(transcript, into: focusedTarget)
                } catch {
                    transcriptHistory = (try? await historyStore.updateDelivery(
                        id: historyEntry.id,
                        state: .failed,
                        method: lastInsertionMethod?.rawValue
                    )) ?? transcriptHistory
                    throw error
                }
                let confirmed = lastInsertionMethod?.isConfirmed == true
                transcriptHistory = (try? await historyStore.updateDelivery(
                    id: historyEntry.id,
                    state: confirmed ? .confirmed : .unconfirmed,
                    method: lastInsertionMethod?.rawValue
                )) ?? transcriptHistory
                historyStatusMessage = historySummary
                try dictationMachine.succeed()
                phase = dictationMachine.phase
                statusMessage = confirmed
                    ? "Dictation inserted locally."
                    : "Paste sent, but the destination could not be verified."
                lastDictationStage = confirmed
                    ? "Confirmed via \(lastInsertionMethod?.rawValue ?? "unknown")"
                    : "Unconfirmed via \(lastInsertionMethod?.rawValue ?? "unknown")"
                Self.logger.notice(
                    "Dictation delivery completed; method=\(self.lastInsertionMethod?.rawValue ?? "unknown", privacy: .public) confirmed=\(confirmed)"
                )
                recoveryMessage = confirmed
                    ? (historyEnabled ? "Saved in local history." : "A short-lived recovery copy is available.")
                    : "Check the destination. The transcript is saved; use Copy or Retry only if it is missing."
                lastFailureMessage = "None"
                self.focusedTarget = nil
                presentation.mode = confirmed ? .success : .error
                presentation.caption = confirmed ? "Inserted" : "Saved — verify paste"
                companionController.refresh()
                scheduleReset(after: confirmed ? 0.8 : 12)
            } catch is CancellationError {
                cancelDictation()
            } catch {
                self.focusedTarget = nil
                lastDictationStage = "Failed while finishing or inserting"
                Self.logger.error("Dictation failed while finishing: \(error.localizedDescription, privacy: .public)")
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
        lastFailureMessage = "\(failure.message) \(failure.recovery)"
        if !lastDictationStage.hasPrefix("Failed") && !lastDictationStage.hasPrefix("Blocked") {
            lastDictationStage = "Failed: \(failure.stage.rawValue)"
        }
        presentation.mode = .error
        presentation.caption = hasRecoverableTranscript
            ? "Saved — \(failure.message)"
            : failure.message
        companionController.refresh()
        scheduleReset(after: hasRecoverableTranscript ? 12 : 4)
    }

    private func presentGuidanceCaption(_ text: String, mode: CompanionMode) {
        presentation.mode = mode
        if mode == .success {
            presentation.responseText = text
        } else {
            presentation.responseText = ""
        }
        presentation.guideStage = .error
        presentation.caption = text
        applyCompanionVisibility()
        companionController.refresh()
        guard mode != .success else { return }
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard let self, !guidancePhase.isActive else { return }
            guidancePhase = .idle
            presentation.mode = .ready
            presentation.caption = ""
            presentation.responseText = ""
            presentation.guideStage = nil
            presentation.contextLabel = nil
            applyCompanionVisibility()
            companionController.refresh()
        }
    }

    public func present(_ turn: GuideTurnPresentation) {
        guidancePhase = turn.guidancePhase
        guidancePartialTranscript = turn.stage == .liveTranscript ? turn.statusText : ""
        guidanceContextLabel = turn.context?.compactLabel ?? "No screen context captured yet"
        guidanceMessages = guideTurnCoordinator.conversation
        presentation.mode = switch turn.stage {
        case .listening, .liveTranscript: .recording
        case .capturing, .thinking, .speaking: .working
        case .readyForFollowUp: .success
        case .error: .error
        case .ready, .cancelled: .ready
        }
        presentation.guideStage = turn.stage
        presentation.caption = turn.statusText
        presentation.contextLabel = turn.context?.compactLabel
        presentation.responseText = turn.responseText
        statusMessage = turn.statusText
        recoveryMessage = turn.failure?.recovery ?? ""
        applyCompanionVisibility()
        companionController.refresh()
        if turn.stage == .readyForFollowUp {
            restoreIdleVisibility(after: .seconds(8))
        }
    }

    public func dismissResponse() {
        presentation.responseText = ""
        companionController.refresh()
    }

    public func restoreIdleVisibility(after delay: Duration) {
        guideResponseDismissalTask?.cancel()
        guideResponseDismissalTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled, let self else { return }
            guidancePhase = .idle
            guidancePartialTranscript = ""
            presentation.guideStage = nil
            presentation.caption = ""
            presentation.contextLabel = nil
            presentation.responseText = ""
            applyCompanionVisibility()
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
            recovery: "Try again. If the problem continues, open SERPy and check permissions."
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
        let resolvedVisibility = companionVisibilityPolicy.visibility(
            persistedEnabled: companionEnabled,
            guidancePhase: guidancePhase
        )
        switch resolvedVisibility {
        case .visible:
            companionController.show()
        case .disabled, .blocked, .temporarilyHidden:
            companionController.hide()
        }
    }
}
