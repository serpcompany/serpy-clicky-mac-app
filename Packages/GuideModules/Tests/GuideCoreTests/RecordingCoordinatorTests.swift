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

        coordinator.start(retainAudioInHistory: false)

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

        coordinator.start(retainAudioInHistory: false)
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

        coordinator.start(retainAudioInHistory: false)
        await coordinator.waitUntilSettled()
        session.emitPartial("cancelled partial must disappear")
        #expect(coordinator.partialTranscript == "cancelled partial must disappear")
        coordinator.finish()
        await session.waitUntilStopStarted()
        coordinator.cancel()
        session.completeLate(with: "late transcript must not insert")
        for _ in 0..<20 { await Task.yield() }

        #expect(coordinator.phase == .cancelled)
        #expect(coordinator.partialTranscript.isEmpty)
        #expect(coordinator.transcriptHistory.isEmpty)
        #expect(await events.snapshot().isEmpty)
        #expect(session.cancelCount == 1)
    }

    @Test("cancellation while insertion is pending prevents target mutation")
    func cancellationDuringInsertionPreventsMutation() async {
        let events = EventLog()
        let inserter = BlockingCoordinatorInserter()
        let coordinator = RecordingCoordinator(
            session: CoordinatorSession(text: "must not appear"),
            targetReader: CoordinatorTargetReader(),
            inserter: inserter,
            history: CoordinatorStore(events: events)
        )

        coordinator.start(retainAudioInHistory: false)
        await coordinator.waitUntilSettled()
        coordinator.finish()
        await inserter.waitUntilStarted()
        #expect(coordinator.phase == .inserting)

        coordinator.cancel()
        inserter.completePendingInsertion()
        for _ in 0..<20 { await Task.yield() }

        #expect(coordinator.phase == .cancelled)
        #expect(inserter.cancelCount == 1)
        #expect(inserter.mutatedTargets.isEmpty)
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

        coordinator.start(retainAudioInHistory: false)
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

        coordinator.start(retainAudioInHistory: false)
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

        coordinator.recoverInterruptedSession(
            retainInHistory: false,
            retainAudioInHistory: false
        )
        await coordinator.waitUntilSettled()

        #expect(coordinator.phase == .idle)
        #expect(coordinator.transcriptHistory.first?.text == "recovered long dictation")
        #expect(coordinator.transcriptHistory.first?.deliveryState == .pending)
        #expect(await events.snapshot() == ["preserve"])
        #expect(session.discardedAudioURLs == [recoveryURL])
    }

    @Test("all interrupted checkpoints recover even when history already exists")
    func recoversEveryCheckpointAlongsideExistingHistory() async {
        let events = EventLog()
        let firstURL = URL(fileURLWithPath: "/synthetic/first.caf")
        let secondURL = URL(fileURLWithPath: "/synthetic/second.caf")
        let existing = TranscriptHistoryEntry(
            text: "existing history",
            retainedInHistory: true,
            expiresAt: .distantFuture
        )
        let session = CoordinatorSession(
            text: "unused",
            recoveryResults: [
                .init(transcript: "first recovered", temporaryAudioURL: firstURL),
                .init(transcript: "second recovered", temporaryAudioURL: secondURL)
            ]
        )
        let store = CoordinatorStore(events: events, initialEntries: [existing])
        let coordinator = RecordingCoordinator(
            session: session,
            targetReader: CoordinatorTargetReader(),
            inserter: CoordinatorInserter(events: events),
            history: store
        )

        coordinator.recoverInterruptedSession(
            retainInHistory: true,
            retainAudioInHistory: false
        )
        await coordinator.waitUntilSettled()

        #expect(coordinator.transcriptHistory.map(\.text) == [
            "first recovered\nsecond recovered",
            "existing history"
        ])
        #expect(session.discardedAudioURLs == [firstURL, secondURL])
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
    let recoveryResults: [SpeechTranscriptionResult]
    private(set) var discardedAudioURLs: [URL] = []

    init(
        text: String,
        stopError: Error? = nil,
        recoveryResult: SpeechTranscriptionResult? = nil,
        recoveryResults: [SpeechTranscriptionResult] = []
    ) {
        self.text = text
        self.stopError = stopError
        self.recoveryResults = recoveryResult.map { [$0] } ?? recoveryResults
    }
    var isOnDeviceAvailable: Bool { true }
    var availabilityDescription: String { "available" }
    func start(retainAudioInHistory: Bool) async throws {}
    func stop() async throws -> SpeechTranscriptionResult {
        if let stopError { throw stopError }
        return SpeechTranscriptionResult(transcript: text, temporaryAudioURL: nil)
    }
    func cancel() throws {}
    func recoverInterruptedAudio() async throws -> [SpeechTranscriptionResult] {
        recoveryResults
    }
    func discardTemporaryAudio(at url: URL) throws { discardedAudioURLs.append(url) }
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
private final class BlockingCoordinatorInserter: TextInserting {
    private var continuation: CheckedContinuation<Void, Never>?
    private(set) var started = false
    private(set) var cancelled = false
    private(set) var cancelCount = 0
    private(set) var mutatedTargets: [String] = []

    func insert(_ text: String, into target: CoordinatorTarget) async throws -> TextInsertionMethod {
        started = true
        await withCheckedContinuation { continuation = $0 }
        try Task.checkCancellation()
        guard !cancelled else { throw CancellationError() }
        mutatedTargets.append(text)
        return .accessibility
    }

    func cancel() {
        cancelCount += 1
        cancelled = true
        continuation?.resume()
        continuation = nil
    }

    func waitUntilStarted() async {
        while !started { await Task.yield() }
    }

    func completePendingInsertion() {
        continuation?.resume()
        continuation = nil
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

    func start(retainAudioInHistory: Bool) async throws {}
    func stop() async throws -> SpeechTranscriptionResult {
        stopStarted = true
        return await withCheckedContinuation { continuation = $0 }
    }
    func cancel() throws { cancelCount += 1 }
    func discardTemporaryAudio(at url: URL) throws {}
    func waitUntilStopStarted() async {
        while !stopStarted { await Task.yield() }
    }
    func completeLate(with text: String) {
        continuation?.resume(returning: .init(transcript: text, temporaryAudioURL: nil))
        continuation = nil
    }
    func emitPartial(_ text: String) { onPartial?(text) }
}

private actor CoordinatorStore: LastDictationStoring {
    let events: EventLog
    private var entries: [TranscriptHistoryEntry]

    init(events: EventLog, initialEntries: [TranscriptHistoryEntry] = []) {
        self.events = events
        entries = initialEntries
    }

    func load() async throws -> [TranscriptHistoryEntry] {
        entries
    }

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
        if retainInHistory {
            entries.insert(entry, at: 0)
        } else {
            entries = [entry]
        }
        return entry
    }

    func updateDelivery(
        id: UUID,
        state: TranscriptDeliveryState,
        method: String?,
        targetBundleIdentifier: String?
    ) async throws -> [TranscriptHistoryEntry] {
        await events.append("delivery:\(state.rawValue)")
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return entries }
        entries[index].deliveryState = state
        return entries
    }
}
