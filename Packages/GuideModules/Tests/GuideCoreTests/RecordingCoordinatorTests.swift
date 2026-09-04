import Foundation
import GuideCore
import Testing

@MainActor
@Suite("Durable dictation recording coordinator")
struct RecordingCoordinatorTests {
    @Test("preparing acknowledgement is published before focused-target capture")
    func acknowledgesBeforePotentiallySlowTargetCapture() {
        let order = MainActorEventLog()
        let coordinator = RecordingCoordinator(
            session: CoordinatorSession(text: "unused"),
            targetReader: OrderedTargetReader(order: order),
            inserter: CoordinatorInserter(events: EventLog()),
            history: CoordinatorStore(events: EventLog())
        )
        coordinator.onStateChange = { order.values.append("state:\(coordinator.phase)") }

        coordinator.start(saveAudio: false)

        #expect(Array(order.values.prefix(2)) == ["state:preparing", "capture"])
        coordinator.cancel()
    }

    @Test("final transcript is preserved before delivery")
    func preservesBeforeDelivery() async throws {
        let events = EventLog()
        let session = CoordinatorSession(text: "BEGIN BEFORE-60 AFTER-60 MIDDLE END")
        let targetReader = CoordinatorTargetReader()
        let inserter = CoordinatorInserter(events: events)
        let store = CoordinatorStore(events: events)
        let coordinator = RecordingCoordinator(
            session: session,
            targetReader: targetReader,
            inserter: inserter,
            history: store
        )

        coordinator.start(saveAudio: false)
        await coordinator.waitUntilSettled()
        #expect(coordinator.phase == .recording)

        coordinator.finish()
        await coordinator.waitUntilSettled()

        #expect(await events.snapshot() == ["preserve", "insert", "delivery:confirmed"])
        #expect(coordinator.phase == .succeeded)
        #expect(coordinator.lastInsertionMethod == .accessibility)
    }

    @Test("cancellation suppresses a late transcript and all delivery")
    func cancellationSuppressesLateOutput() async {
        let events = EventLog()
        let session = BlockingCoordinatorSession()
        let coordinator = RecordingCoordinator(
            session: session,
            targetReader: CoordinatorTargetReader(),
            inserter: CoordinatorInserter(events: events),
            history: CoordinatorStore(events: events)
        )

        coordinator.start(saveAudio: false)
        await coordinator.waitUntilSettled()
        coordinator.finish()
        await session.waitUntilStopStarted()
        coordinator.cancel()
        session.completeLate(with: "late transcript must not insert")
        for _ in 0..<20 { await Task.yield() }

        #expect(coordinator.phase == .cancelled)
        #expect(await events.snapshot().isEmpty)
        #expect(session.cancelCount == 1)
    }

    @Test("checkpoint failure is visible and prevents persistence and insertion")
    func checkpointFailureStopsCompletion() async {
        let events = EventLog()
        let failure = GuideFailure(
            stage: .storage,
            message: "Active Dictation audio could not be checkpointed.",
            recovery: "Check available disk space and try again."
        )
        let session = CoordinatorSession(text: "unused", stopError: failure)
        let coordinator = RecordingCoordinator(
            session: session,
            targetReader: CoordinatorTargetReader(),
            inserter: CoordinatorInserter(events: events),
            history: CoordinatorStore(events: events)
        )

        coordinator.start(saveAudio: false)
        await coordinator.waitUntilSettled()
        coordinator.finish()
        await coordinator.waitUntilSettled()

        #expect(coordinator.phase == .failed(failure))
        #expect(await events.snapshot().isEmpty)
    }

    @Test("an unconfirmed paste remains recoverable and is never called confirmed")
    func unconfirmedDeliveryRemainsRecoverable() async {
        let events = EventLog()
        let inserter = CoordinatorInserter(events: events, method: .pasteUnconfirmed)
        let coordinator = RecordingCoordinator(
            session: CoordinatorSession(text: "recover this"),
            targetReader: CoordinatorTargetReader(),
            inserter: inserter,
            history: CoordinatorStore(events: events)
        )

        coordinator.start(saveAudio: false)
        await coordinator.waitUntilSettled()
        coordinator.finish()
        await coordinator.waitUntilSettled()

        #expect(coordinator.phase == .succeeded)
        #expect(coordinator.transcriptHistory.first?.deliveryState == .unconfirmed)
        #expect(coordinator.transcriptHistory.first?.text == "recover this")
    }

    @Test("an interrupted audio checkpoint becomes Last Dictation without automatic insertion")
    func interruptedAudioBecomesRecoveryOnly() async {
        let events = EventLog()
        let recoveryURL = URL(fileURLWithPath: "/synthetic/interrupted.caf")
        let session = CoordinatorSession(
            text: "unused",
            recoveryResult: .init(transcript: "recovered long dictation", temporaryAudioURL: recoveryURL)
        )
        let coordinator = RecordingCoordinator(
            session: session,
            targetReader: CoordinatorTargetReader(),
            inserter: CoordinatorInserter(events: events),
            history: CoordinatorStore(events: events)
        )

        coordinator.recoverInterruptedSession(retainInHistory: false, saveAudio: false)
        await coordinator.waitUntilSettled()

        #expect(coordinator.phase == .idle)
        #expect(coordinator.transcriptHistory.first?.text == "recovered long dictation")
        #expect(coordinator.transcriptHistory.first?.deliveryState == .pending)
        #expect(await events.snapshot() == ["preserve"])
        #expect(session.discardedAudioURLs == [recoveryURL])
    }
}

private actor EventLog {
    private var values: [String] = []
    func append(_ value: String) { values.append(value) }
    func snapshot() -> [String] { values }
}

@MainActor
private final class MainActorEventLog {
    var values: [String] = []
}

@MainActor
private final class CoordinatorSession: DictationSessioning {
    var onPartial: (@MainActor @Sendable (String) -> Void)?
    let text: String
    let stopError: Error?
    let recoveryResult: SpeechTranscriptionResult?
    private(set) var discardedAudioURLs: [URL] = []

    init(
        text: String,
        stopError: Error? = nil,
        recoveryResult: SpeechTranscriptionResult? = nil
    ) {
        self.text = text
        self.stopError = stopError
        self.recoveryResult = recoveryResult
    }
    var isOnDeviceAvailable: Bool { true }
    var availabilityDescription: String { "available" }
    func start(saveAudio: Bool) async throws {}
    func stop() async throws -> SpeechTranscriptionResult {
        if let stopError { throw stopError }
        return SpeechTranscriptionResult(transcript: text, temporaryAudioURL: nil)
    }
    func cancel() {}
    func recoverInterruptedAudio() async throws -> SpeechTranscriptionResult? { recoveryResult }
    func discardTemporaryAudio(at url: URL) { discardedAudioURLs.append(url) }
}

@MainActor
private struct CoordinatorTarget: FocusedTextTargetRepresenting {
    let bundleIdentifier: String? = "com.example.target"
}

@MainActor
private final class CoordinatorTargetReader: FocusedTextTargetReading {
    func captureFocusedTarget() throws -> CoordinatorTarget { CoordinatorTarget() }
}

@MainActor
private final class OrderedTargetReader: FocusedTextTargetReading {
    let order: MainActorEventLog
    init(order: MainActorEventLog) { self.order = order }
    func captureFocusedTarget() throws -> CoordinatorTarget {
        order.values.append("capture")
        return CoordinatorTarget()
    }
}

@MainActor
private final class CoordinatorInserter: TextInserting {
    let events: EventLog
    let method: TextInsertionMethod
    init(events: EventLog, method: TextInsertionMethod = .accessibility) {
        self.events = events
        self.method = method
    }
    func insert(_ text: String, into target: CoordinatorTarget) async throws -> TextInsertionMethod {
        await events.append("insert")
        return method
    }
}

@MainActor
private final class BlockingCoordinatorSession: DictationSessioning {
    var onPartial: (@MainActor @Sendable (String) -> Void)?
    private var continuation: CheckedContinuation<SpeechTranscriptionResult, Never>?
    private(set) var stopStarted = false
    private(set) var cancelCount = 0
    var isOnDeviceAvailable: Bool { true }
    var availabilityDescription: String { "available" }

    func start(saveAudio: Bool) async throws {}
    func stop() async throws -> SpeechTranscriptionResult {
        stopStarted = true
        return await withCheckedContinuation { continuation = $0 }
    }
    func cancel() { cancelCount += 1 }
    func waitUntilStopStarted() async {
        while !stopStarted { await Task.yield() }
    }
    func completeLate(with text: String) {
        continuation?.resume(returning: .init(transcript: text, temporaryAudioURL: nil))
        continuation = nil
    }
}

private actor CoordinatorStore: LastDictationStoring {
    let events: EventLog
    private var entry: TranscriptHistoryEntry?

    init(events: EventLog) { self.events = events }

    func preserve(
        text: String,
        targetBundleIdentifier: String?,
        temporaryAudioURL: URL?,
        retainInHistory: Bool
    ) async throws -> TranscriptHistoryEntry {
        await events.append("preserve")
        let entry = TranscriptHistoryEntry(
            text: text,
            targetBundleIdentifier: targetBundleIdentifier,
            retainedInHistory: retainInHistory,
            expiresAt: .distantFuture
        )
        self.entry = entry
        return entry
    }

    func updateDelivery(
        id: UUID,
        state: TranscriptDeliveryState,
        method: String?,
        targetBundleIdentifier: String?
    ) async throws -> [TranscriptHistoryEntry] {
        await events.append("delivery:\(state.rawValue)")
        guard var entry else { return [] }
        entry.deliveryState = state
        self.entry = entry
        return [entry]
    }
}
