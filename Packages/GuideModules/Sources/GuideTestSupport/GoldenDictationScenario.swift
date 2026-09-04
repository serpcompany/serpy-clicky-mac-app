import Foundation
import GuideCore

public struct GoldenDictationScenarioObservation: Equatable, Sendable {
    public let transcript: String
    public let transcriptPreserved: Bool
    public let targetMutationCount: Int
    public let deliveryConfirmed: Bool
}

public struct GoldenRecoveryScenarioObservation: Equatable, Sendable {
    public let variant: GoldenRecoveryVariant
    public let entry: TranscriptHistoryEntry
}

@MainActor
public enum GoldenDictationScenario {
    public static func runConfirmed() async -> GoldenDictationScenarioObservation {
        let session = FixtureDictationSession()
        let target = FixtureTargetReader()
        let inserter = FixtureInserter()
        let store = FixtureLastDictationStore()
        let coordinator = RecordingCoordinator(
            session: session,
            targetReader: target,
            inserter: inserter,
            history: store
        )
        coordinator.start(retainAudioInHistory: false)
        await coordinator.waitUntilSettled()
        coordinator.finish()
        await coordinator.waitUntilSettled()
        let entries = await store.load()
        return GoldenDictationScenarioObservation(
            transcript: coordinator.partialTranscript,
            transcriptPreserved: entries.first?.text == "alpha beta",
            targetMutationCount: inserter.mutations.count,
            deliveryConfirmed: entries.first?.deliveryState == .confirmed
        )
    }

    public static func runRecovery(
        variant: GoldenRecoveryVariant
    ) async -> GoldenRecoveryScenarioObservation? {
        let session = FixtureDictationSession(
            recoveryResults: variant == .interrupted
                ? [SpeechTranscriptionResult(transcript: "alpha beta", temporaryAudioURL: nil)]
                : []
        )
        let inserter = FixtureInserter(
            method: variant == .unconfirmed ? .pasteUnconfirmed : .accessibility,
            shouldFail: variant == .failed
        )
        let store = FixtureLastDictationStore()
        let coordinator = RecordingCoordinator(
            session: session,
            targetReader: FixtureTargetReader(),
            inserter: inserter,
            history: store
        )
        if variant == .interrupted {
            coordinator.recoverInterruptedSession(retainInHistory: false, retainAudioInHistory: false)
        } else {
            coordinator.start(retainAudioInHistory: false)
            await coordinator.waitUntilSettled()
            coordinator.finish()
        }
        await coordinator.waitUntilSettled()
        guard let entry = await store.load().first else { return nil }
        return GoldenRecoveryScenarioObservation(variant: variant, entry: entry)
    }
}

private struct FixtureTextTarget: FocusedTextTargetRepresenting {
    let bundleIdentifier: String? = "fixture.target"
}

@MainActor
private final class FixtureTargetReader: FocusedTextTargetReading {
    func captureFocusedTarget() throws -> FixtureTextTarget { FixtureTextTarget() }
}

@MainActor
private final class FixtureInserter: TextInserting {
    private(set) var mutations: [String] = []
    private let method: TextInsertionMethod
    private let shouldFail: Bool

    init(method: TextInsertionMethod = .accessibility, shouldFail: Bool = false) {
        self.method = method
        self.shouldFail = shouldFail
    }

    func insert(_ text: String, into target: FixtureTextTarget) async throws -> TextInsertionMethod {
        if shouldFail {
            throw GuideFailure(stage: .insertion, message: "Fixture insertion failed.", recovery: "Use Last Dictation.")
        }
        mutations.append(text)
        return method
    }
}

@MainActor
private final class FixtureDictationSession: DictationSessioning {
    var onPartial: (@MainActor @Sendable (String) -> Void)?
    var isOnDeviceAvailable: Bool { true }
    var availabilityDescription: String { "fixture available" }
    private let recoveryResults: [SpeechTranscriptionResult]

    init(recoveryResults: [SpeechTranscriptionResult] = []) {
        self.recoveryResults = recoveryResults
    }
    func start(retainAudioInHistory: Bool) async throws { onPartial?("alpha beta") }
    func stop() async throws -> SpeechTranscriptionResult {
        SpeechTranscriptionResult(transcript: "alpha beta", temporaryAudioURL: nil)
    }
    func cancel() throws {}
    func recoverInterruptedAudio() async throws -> [SpeechTranscriptionResult] { recoveryResults }
    func discardTemporaryAudio(at url: URL) throws {}
}

private actor FixtureLastDictationStore: LastDictationStoring {
    private var entries: [TranscriptHistoryEntry] = []
    func load() -> [TranscriptHistoryEntry] { entries }
    func preserve(
        text: String,
        targetBundleIdentifier: String?,
        temporaryAudioURL: URL?,
        retainInHistory: Bool
    ) -> TranscriptHistoryEntry {
        let entry = TranscriptHistoryEntry(
            text: text,
            targetBundleIdentifier: targetBundleIdentifier,
            retainedInHistory: retainInHistory,
            expiresAt: .distantFuture
        )
        entries = [entry]
        return entry
    }
    func updateDelivery(
        id: UUID,
        state: TranscriptDeliveryState,
        method: String?,
        targetBundleIdentifier: String?
    ) -> [TranscriptHistoryEntry] {
        if let index = entries.firstIndex(where: { $0.id == id }) {
            entries[index].deliveryState = state
        }
        return entries
    }
}
