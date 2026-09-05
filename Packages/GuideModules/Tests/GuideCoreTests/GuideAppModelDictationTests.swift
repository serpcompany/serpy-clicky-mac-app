import Foundation
import GuideCore
@testable import GuideMac
import GuideUI
import Testing

@MainActor
@Suite("Guide app Dictation presentation")
struct GuideAppModelDictationTests {
    @Test("insertion diagnostic distinguishes confirmed and unconfirmed delivery",
          arguments: [TextInsertionMethod.accessibility, .accessibilityValue, .paste, .pasteUnconfirmed])
    func insertionDiagnosticReportsEvidence(method: TextInsertionMethod) async throws {
        let failure = GuideFailure(stage: .storage, message: "unused", recovery: "unused")
        let history = TranscriptHistoryStore(fileURL: FileManager.default.temporaryDirectory
            .appending(path: "serpy-insertion-status-\(UUID().uuidString)/transcripts.json"))
        let insertion = ModelDiagnosticInserter(method: method)
        let local = LocalGuidanceService()
        let credentials = ModelCredentialStore()
        let model = GuideAppModel(
            defaults: UserDefaults(suiteName: "serpy-insertion-status-\(UUID().uuidString)")!,
            permissionService: PermissionService(),
            recordingCoordinator: RecordingCoordinator(
                session: CleanupFailingSession(failure: failure),
                targetReader: ModelTargetReader(), inserter: ModelNoopInserter(), history: history),
            insertionService: insertion,
            historyStore: history,
            screenContextService: ScreenContextService(),
            guidanceTranscriber: AppleSpeechGuideTurnTranscriber(transcriber: AppleSpeechTranscriber()),
            guidanceSpeaker: LocalGuideTurnSpeaker(speaker: LocalSpeechOutputService()),
            localGuidanceService: local,
            talkCredentialStore: credentials,
            talkCredentialVerifier: ModelCredentialVerifier(),
            talkVerificationExpirySleeper: ModelExpirySleeper(),
            talkGenerator: TalkGenerationRouter(local: local, cloud: ModelNoopGuidanceGenerator(),
                                                 credentialStore: credentials),
            shortcutMonitorFactory: { _, _ in ModelNoopShortcutMonitor() }
        )
        model.beginInsertionTest()
        let deadline = ContinuousClock.now + .seconds(6)
        while insertion.calls == 0 && ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(insertion.calls == 1)
        #expect(model.lastInsertionMethod == method)
        if method.isConfirmed {
            #expect(model.statusMessage == "The insertion test succeeded.")
        } else {
            #expect(model.statusMessage == "Paste sent, but the destination could not be verified.")
            #expect(model.lastDictationStage == "Insertion test unconfirmed")
            #expect(model.recoveryMessage == "Check the destination. Run the test again only if the text is missing.")
        }
    }

    @Test("cleanup failure is not overwritten by a false cancelled message")
    func cleanupFailureRemainsVisible() async throws {
        let failure = GuideFailure(
            stage: .storage,
            message: "Temporary Dictation audio could not be deleted safely.",
            recovery: "Close processes using the recovery file and try cleanup again."
        )
        let session = CleanupFailingSession(failure: failure)
        let history = TranscriptHistoryStore(
            fileURL: FileManager.default.temporaryDirectory
                .appending(path: "serpy-model-cancel-\(UUID().uuidString)/transcripts.json")
        )
        let coordinator = RecordingCoordinator(
            session: session,
            targetReader: ModelTargetReader(),
            inserter: ModelNoopInserter(),
            history: history
        )
        let insertion = TextInsertionService()
        let local = LocalGuidanceService()
        let credentials = ModelCredentialStore()
        let router = TalkGenerationRouter(
            local: local,
            cloud: ModelNoopGuidanceGenerator(),
            credentialStore: credentials
        )
        let model = GuideAppModel(
            defaults: UserDefaults(suiteName: "serpy-model-cancel-\(UUID().uuidString)")!,
            permissionService: PermissionService(),
            recordingCoordinator: coordinator,
            insertionService: insertion,
            historyStore: history,
            screenContextService: ScreenContextService(),
            guidanceTranscriber: AppleSpeechGuideTurnTranscriber(transcriber: AppleSpeechTranscriber()),
            guidanceSpeaker: LocalGuideTurnSpeaker(speaker: LocalSpeechOutputService()),
            localGuidanceService: local,
            talkCredentialStore: credentials,
            talkCredentialVerifier: ModelCredentialVerifier(),
            talkVerificationExpirySleeper: ModelExpirySleeper(),
            talkGenerator: router,
            shortcutMonitorFactory: { _, _ in ModelNoopShortcutMonitor() }
        )

        coordinator.start(retainAudioInHistory: false)
        await coordinator.waitUntilSettled()
        #expect(model.phase == .recording)

        model.cancelDictation()

        #expect(model.phase == .failed(failure))
        #expect(model.statusMessage == failure.message)
        #expect(model.recoveryMessage == failure.recovery)
    }
}

@MainActor
private final class ModelDiagnosticInserter: AppTextInsertionServicing {
    let method: TextInsertionMethod
    var calls = 0
    init(method: TextInsertionMethod) { self.method = method }
    func captureFocusedTarget() throws -> FocusedTextTarget {
        FocusedTextTarget(processIdentifier: 42, element: nil, bundleIdentifier: "com.example.target")
    }
    func insert(_ text: String, into target: FocusedTextTarget) async throws -> TextInsertionMethod {
        calls += 1
        return method
    }
}

@MainActor
private final class ModelTargetReader: FocusedTextTargetReading {
    func captureFocusedTarget() throws -> FocusedTextTarget {
        FocusedTextTarget(
            processIdentifier: 42,
            element: nil,
            bundleIdentifier: "com.example.target"
        )
    }
}

@MainActor
private final class ModelNoopInserter: TextInserting {
    func insert(_ text: String, into target: FocusedTextTarget) async throws -> TextInsertionMethod {
        .accessibility
    }
}

@MainActor
private final class CleanupFailingSession: DictationSessioning {
    var onPartial: (@MainActor @Sendable (String) -> Void)?
    let failure: GuideFailure
    init(failure: GuideFailure) { self.failure = failure }
    var isOnDeviceAvailable: Bool { true }
    var availabilityDescription: String { "available" }
    func start(retainAudioInHistory: Bool) async throws {}
    func stop() async throws -> SpeechTranscriptionResult {
        .init(transcript: "unused", temporaryAudioURL: nil)
    }
    func cancel() throws { throw failure }
    func discardTemporaryAudio(at url: URL) throws {}
}

private final class ModelCredentialStore: TalkCredentialStoring, @unchecked Sendable {
    func credential() throws -> String? { nil }
    func saveCredential(_ credential: String) throws {}
    func deleteCredential() throws {}
}

private struct ModelCredentialVerifier: TalkCredentialVerifying {
    func verifyCredential(_ credential: String) async throws -> Bool { false }
}

private struct ModelExpirySleeper: TalkVerificationExpirySleeping {
    func sleep(until: Date) async throws {}
}

private final class ModelNoopGuidanceGenerator: GuidanceGenerating, @unchecked Sendable {
    func stream(_ request: MultimodalGuideRequest) -> AsyncThrowingStream<GuidanceStreamEvent, Error> {
        AsyncThrowingStream { $0.finish() }
    }
    func cancel() {}
}

@MainActor
private final class ModelNoopShortcutMonitor: GlobalShortcutMonitoring {
    func start() throws {}
    func stop() {}
}
