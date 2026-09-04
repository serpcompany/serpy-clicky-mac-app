import AppKit
import Foundation
import GuideCore
import GuideMac
import GuideUI

@MainActor
enum GuideUITestComposition {
    static func makeModel(arguments: [String]) -> GuideAppModel {
        precondition(AppRuntimeMode.resolve(arguments: arguments) == .uiTest)
        let sessionRoot = validatedSessionRoot(environment: ProcessInfo.processInfo.environment)
        let flow = arguments.first(where: { $0.hasPrefix("--golden-flow=") }) ?? ""
        let permissions = UITestPermissionService(
            denyMicrophone: flow == "--golden-flow=UF-01",
            sessionRoot: sessionRoot
        )
        let insertion = UITestTextInsertionService(
            sessionRoot: sessionRoot,
            block: arguments.contains("--block-dictation-insertion")
        )
        let history = UITestHistoryStore(arguments: arguments)
        let session = UITestDictationSession(blockStop: arguments.contains("--block-dictation-stop"))
        let recording = RecordingCoordinator(
            session: session,
            targetReader: insertion,
            inserter: insertion,
            history: history
        )
        let capture = UITestScreenContextService(block: arguments.contains("--block-guide-capture"))
        let transcription = UITestGuideTranscriber()
        let generation = UITestGuideGenerator(arguments: arguments)
        let credentialStore = UITestCredentialStore()
        let localService = LocalGuidanceService(provider: UITestLocalModelProvider())
        let router = TalkGenerationRouter(
            local: generation,
            cloud: UITestCloudGenerator(),
            credentialStore: credentialStore
        )
        return GuideAppModel(
            defaults: UITestPreferences(),
            runtimeMode: .uiTest,
            permissionService: permissions,
            recordingCoordinator: recording,
            insertionService: insertion,
            historyStore: history,
            screenContextService: capture,
            guidanceTranscriber: transcription,
            guidanceSpeaker: UITestGuideSpeaker(block: arguments.contains("--block-guide-speech")),
            localGuidanceService: localService,
            talkCredentialStore: credentialStore,
            talkCredentialVerifier: UITestCredentialVerifier(),
            talkVerificationExpirySleeper: UITestExpirySleeper(),
            talkGenerator: router,
            incidentReporter: UITestIncidentReporter(sessionRoot: sessionRoot),
            shortcutMonitorFactory: { _, _ in UITestShortcutMonitor() }
        )
    }

    private static func validatedSessionRoot(environment: [String: String]) -> URL {
        guard let sessionID = environment["SERPY_TEST_SESSION_ID"], UUID(uuidString: sessionID) != nil,
              let rawRoot = environment["SERPY_TEST_ROOT"] else {
            preconditionFailure("UI-test mode requires an isolated session root")
        }
        let root = URL(fileURLWithPath: rawRoot).standardizedFileURL
        guard root.lastPathComponent == "serpy-real-ui-\(sessionID)",
              FileManager.default.fileExists(atPath: root.path) else {
            preconditionFailure("UI-test session root is not owned by this run")
        }
        return root
    }
}

private final class UITestPreferences: AppPreferences {
    private var values: [String: Any] = [:]
    func set(_ value: Any?, forKey defaultName: String) { values[defaultName] = value }
    func string(forKey defaultName: String) -> String? { values[defaultName] as? String }
    func bool(forKey defaultName: String) -> Bool { values[defaultName] as? Bool ?? false }
    func data(forKey defaultName: String) -> Data? { values[defaultName] as? Data }
    func object(forKey defaultName: String) -> Any? { values[defaultName] }
}

@MainActor
private final class UITestPermissionService: AppPermissionServicing {
    private var microphone: PermissionState
    private let denyMicrophone: Bool
    private let stateURL: URL

    init(denyMicrophone: Bool, sessionRoot: URL) {
        self.denyMicrophone = denyMicrophone
        stateURL = sessionRoot.appendingPathComponent("permission-denied.fixture")
        microphone = FileManager.default.fileExists(atPath: stateURL.path)
            ? .denied
            : (denyMicrophone ? .unknown : .granted)
    }

    func snapshot() -> PermissionSnapshot {
        PermissionSnapshot(microphone: microphone, speechRecognition: .granted, accessibility: .granted, screenRecording: .granted)
    }
    func requestMicrophone() async -> Bool {
        microphone = denyMicrophone ? .denied : .granted
        if denyMicrophone {
            do { try Data().write(to: stateURL, options: .atomic) }
            catch { preconditionFailure("permission fixture state could not be persisted") }
        }
        return microphone == .granted
    }
    func requestSpeechRecognition() async -> Bool { true }
    func requestAccessibility() -> Bool { true }
    func requestScreenRecording() -> Bool { true }
    func openSystemSettings(for permission: GuidePermission) {}
}

@MainActor
private final class UITestTextInsertionService: AppTextInsertionServicing {
    private let receiptURL: URL
    private let block: Bool
    init(sessionRoot: URL, block: Bool) {
        receiptURL = sessionRoot.appendingPathComponent("insertion.fixture")
        self.block = block
    }
    func captureFocusedTarget() throws -> FocusedTextTarget {
        FocusedTextTarget(
            processIdentifier: ProcessInfo.processInfo.processIdentifier,
            element: nil,
            bundleIdentifier: "fixture.target"
        )
    }
    func insert(_ text: String, into target: FocusedTextTarget) async throws -> TextInsertionMethod {
        if block { try await Task.sleep(for: .seconds(3_600)) }
        try text.write(to: receiptURL, atomically: true, encoding: .utf8)
        return .accessibility
    }
    func cancel() -> Bool { true }
}

@MainActor
private final class UITestDictationSession: DictationSessioning {
    var onPartial: (@MainActor @Sendable (String) -> Void)?
    var isOnDeviceAvailable: Bool { true }
    var availabilityDescription: String { "Deterministic local speech fixture" }
    private let blockStop: Bool
    init(blockStop: Bool) { self.blockStop = blockStop }
    func start(retainAudioInHistory: Bool) async throws { onPartial?("alpha beta") }
    func stop() async throws -> SpeechTranscriptionResult {
        if blockStop { try await Task.sleep(for: .seconds(3_600)) }
        return .init(transcript: "alpha beta", temporaryAudioURL: nil)
    }
    func cancel() throws {}
    func discardTemporaryAudio(at url: URL) throws {}
}

private actor UITestHistoryStore: AppTranscriptHistoryServicing {
    private var entries: [TranscriptHistoryEntry]

    init(arguments: [String]) {
        guard let raw = arguments.first(where: { $0.hasPrefix("--recovery-variant=") })?
            .replacingOccurrences(of: "--recovery-variant=", with: ""),
              let state = TranscriptDeliveryState(rawValue: raw == "interrupted" ? "pending" : raw)
        else {
            entries = []
            return
        }
        entries = [TranscriptHistoryEntry(
            text: "Recovered fixture dictation",
            targetBundleIdentifier: "fixture.target",
            deliveryState: state,
            retainedInHistory: false,
            expiresAt: .distantFuture
        )]
    }
    func load() -> [TranscriptHistoryEntry] { entries }
    func preserve(text: String, targetBundleIdentifier: String?, temporaryAudioURL: URL?, retainInHistory: Bool) -> TranscriptHistoryEntry {
        let entry = TranscriptHistoryEntry(text: text, targetBundleIdentifier: targetBundleIdentifier, retainedInHistory: retainInHistory, expiresAt: .distantFuture)
        entries = [entry]
        return entry
    }
    func updateDelivery(id: UUID, state: TranscriptDeliveryState, method: String?, targetBundleIdentifier: String?) -> [TranscriptHistoryEntry] {
        if let index = entries.firstIndex(where: { $0.id == id }) {
            entries[index].deliveryState = state
            entries[index].deliveryMethod = method
        }
        return entries
    }
    func delete(id: UUID) -> [TranscriptHistoryEntry] {
        entries.removeAll { $0.id == id }
        return entries
    }
    func clear() { entries = [] }
}

private final class UITestScreenContextService: AppScreenContextServicing, @unchecked Sendable {
    @MainActor private var captureCount = 0
    private let block: Bool
    init(block: Bool) { self.block = block }
    @MainActor func rememberFrontmostApplication() {}
    @MainActor func snapshotTarget() throws -> GuideWindowTarget {
        GuideWindowTarget(
            processIdentifier: Int32(ProcessInfo.processInfo.processIdentifier),
            windowIdentifier: 1,
            applicationName: "Fixture Browser",
            windowTitle: "Fixture Window",
            frame: CGRect(x: 200, y: 200, width: 900, height: 700)
        )
    }
    func capture(_ target: GuideWindowTarget) async throws -> ScreenContext {
        if block { try await Task.sleep(for: .seconds(3_600)) }
        let count = await MainActor.run { captureCount += 1; return captureCount }
        let visible = switch count {
        case 2: "File menu open"
        case 3...: "New Window visible"
        default: "File New Window"
        }
        return ScreenContext(
            applicationName: target.applicationName,
            windowTitle: target.windowTitle,
            windowFrame: target.frame,
            textBlocks: [.init(text: visible, normalizedBounds: CGRect(x: 0.1, y: 0.1, width: 0.3, height: 0.1), confidence: 1)]
        )
    }
}

@MainActor
private final class UITestGuideTranscriber: AppGuideTranscribing {
    var isOnDeviceAvailable: Bool { true }
    func start(onPartial: @escaping @MainActor @Sendable (String) -> Void) throws { onPartial("Open a new window") }
    func stop() async throws -> String { "Open a new window" }
    func cancel() {}
}

@MainActor
private final class UITestGuideGenerator: GuideTurnGenerating {
    private let malformed: Bool
    private let block: Bool
    init(arguments: [String]) {
        malformed = arguments.contains("--inject-guide-failure")
            || arguments.contains("--golden-flow=UF-12")
        block = arguments.contains("--block-guide-generation")
    }
    func answer(question: String, context: ScreenContext, conversation: [GuidanceMessage]) async throws -> GuidancePlan {
        if malformed { throw GuideFailure.malformedGuidance(provider: .local) }
        if block { try await Task.sleep(for: .seconds(3_600)) }
        return GuidancePlan(
            answer: "Open the File menu, then choose New Window.",
            confidence: 1,
            steps: [
                GuidanceStep(id: 1, text: "Open the File menu.", completionEvidence: ["File menu open"]),
                GuidanceStep(id: 2, text: "Choose New Window.", completionEvidence: ["New Window visible"]),
            ]
        )
    }
}

@MainActor
private final class UITestGuideSpeaker: GuideTurnSpeaking {
    private let block: Bool
    init(block: Bool) { self.block = block }
    func speak(_ text: String) async throws {
        if block { try await Task.sleep(for: .seconds(3_600)) }
    }
    func stop() {}
}

@MainActor
private final class UITestLocalModelProvider: LocalGuidanceModelProvider {
    var availability: LocalGuidanceAvailability { .available }
    func makeSession(instructions: String) throws -> any LocalGuidanceModelSession { UITestLocalModelSession() }
}

@MainActor
private final class UITestLocalModelSession: LocalGuidanceModelSession {
    func respond(to prompt: String) async throws -> String { "{\"answer\":\"Fixture\",\"steps\":[]}" }
}

private final class UITestCredentialStore: TalkCredentialStoring, @unchecked Sendable {
    private var value: String?
    func credential() throws -> String? { value }
    func saveCredential(_ credential: String) throws { value = credential }
    func deleteCredential() throws { value = nil }
}

private struct UITestCredentialVerifier: TalkCredentialVerifying {
    func verifyCredential(_ credential: String) async throws -> Bool { true }
}

private struct UITestExpirySleeper: TalkVerificationExpirySleeping {
    func sleep(until: Date) async throws { try await Task.sleep(for: .seconds(3_600)) }
}

private final class UITestCloudGenerator: GuidanceGenerating, @unchecked Sendable {
    func stream(_ request: MultimodalGuideRequest) -> AsyncThrowingStream<GuidanceStreamEvent, Error> {
        AsyncThrowingStream { continuation in continuation.finish() }
    }
    func cancel() {}
}

private struct UITestIncidentReporter: DiagnosticIncidentReporting {
    let sessionRoot: URL
    func report(_ incident: DiagnosticIncident) {
        do {
            try incident.code.rawValue.write(
                to: sessionRoot.appendingPathComponent("incident.fixture"),
                atomically: true,
                encoding: .utf8
            )
        } catch {
            preconditionFailure("in-memory diagnostic receipt could not be exposed to XCUI")
        }
    }
}

@MainActor
private final class UITestShortcutMonitor: GlobalShortcutMonitoring {
    func start() throws {}
    func stop() {}
}
