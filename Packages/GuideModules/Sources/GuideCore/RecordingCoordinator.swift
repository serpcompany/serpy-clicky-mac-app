import Foundation

/// Owns one Dictation attempt from target capture through durable transcript
/// preservation and delivery. Adapted from the pinned Yap RecordingCoordinator;
/// serpy preserves before delivery and records conservative delivery states.
@MainActor
public final class RecordingCoordinator<Target: FocusedTextTargetRepresenting> {
    public private(set) var phase: DictationPhase = .idle
    public private(set) var partialTranscript = ""
    public private(set) var lastInsertionMethod: TextInsertionMethod?
    public private(set) var transcriptHistory: [TranscriptHistoryEntry] = []
    public private(set) var lastFailure: GuideFailure?
    public var onStateChange: (@MainActor @Sendable () -> Void)?

    private let session: any DictationSessioning
    private let targetReader: any FocusedTextTargetReading<Target>
    private let inserter: any TextInserting<Target>
    private let history: any LastDictationStoring
    private var machine = DictationStateMachine()
    private var target: Target?
    private var attemptID: UUID?
    private var operationTask: Task<Void, Never>?
    private var retainAudioInHistory = false

    public init(
        session: any DictationSessioning,
        targetReader: any FocusedTextTargetReading<Target>,
        inserter: any TextInserting<Target>,
        history: any LastDictationStoring
    ) {
        self.session = session
        self.targetReader = targetReader
        self.inserter = inserter
        self.history = history
        session.onPartial = { [weak self] text in
            guard let self, self.attemptID != nil else { return }
            self.partialTranscript = text
            self.onStateChange?()
        }
    }

    public var isOnDeviceAvailable: Bool { session.isOnDeviceAvailable }
    public var availabilityDescription: String { session.availabilityDescription }

    public func start(retainAudioInHistory: Bool) {
        guard !phase.isActive else { return }
        operationTask?.cancel()
        machine.reset()
        do {
            try machine.prepare()
            phase = machine.phase
            onStateChange?()
            target = try targetReader.captureFocusedTarget()
        } catch {
            fail(error, defaultStage: .activation)
            return
        }

        let id = UUID()
        attemptID = id
        self.retainAudioInHistory = retainAudioInHistory
        partialTranscript = ""
        lastInsertionMethod = nil
        lastFailure = nil
        operationTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await session.start(retainAudioInHistory: retainAudioInHistory)
                try Task.checkCancellation()
                guard attemptID == id else { throw CancellationError() }
                try machine.beginRecording()
                phase = machine.phase
                onStateChange?()
            } catch is CancellationError {
                cancelAttempt(id: id)
            } catch {
                fail(error, defaultStage: .recording)
            }
            operationTask = nil
        }
    }

    public func finish(retainInHistory: Bool = false) {
        guard phase == .recording, let target, let id = attemptID else { return }
        do {
            try machine.beginTranscription()
            phase = machine.phase
            onStateChange?()
        } catch {
            fail(error, defaultStage: .transcription)
            return
        }

        operationTask?.cancel()
        operationTask = Task { [weak self] in
            guard let self else { return }
            var historyEntry: TranscriptHistoryEntry?
            do {
                let result = try await session.stop()
                try validateActiveAttempt(id)
                partialTranscript = result.transcript

                let entry = try await history.preserve(
                    text: result.transcript,
                    targetBundleIdentifier: target.bundleIdentifier,
                    temporaryAudioURL: retainAudioInHistory ? result.temporaryAudioURL : nil,
                    retainInHistory: retainInHistory
                )
                historyEntry = entry
                if !retainAudioInHistory, let temporaryAudioURL = result.temporaryAudioURL {
                    try session.discardTemporaryAudio(at: temporaryAudioURL)
                }
                try validateActiveAttempt(id)

                try machine.beginInsertion()
                phase = machine.phase
                onStateChange?()
                let method = try await inserter.insert(result.transcript, into: target)
                try validateActiveAttempt(id)
                lastInsertionMethod = method
                transcriptHistory = try await history.updateDelivery(
                    id: entry.id,
                    state: method.isConfirmed ? .confirmed : .unconfirmed,
                    method: method.rawValue,
                    targetBundleIdentifier: target.bundleIdentifier
                )
                try validateActiveAttempt(id)
                try machine.succeed()
                phase = machine.phase
                self.target = nil
                attemptID = nil
                onStateChange?()
            } catch is CancellationError {
                cancelAttempt(id: id)
            } catch {
                if let historyEntry {
                    transcriptHistory = (try? await history.updateDelivery(
                        id: historyEntry.id,
                        state: .failed,
                        method: lastInsertionMethod?.rawValue,
                        targetBundleIdentifier: target.bundleIdentifier
                    )) ?? transcriptHistory
                }
                fail(error, defaultStage: historyEntry == nil ? .storage : .insertion)
            }
            operationTask = nil
        }
    }

    public func cancel() {
        guard phase.isActive else { return }
        attemptID = nil
        operationTask?.cancel()
        operationTask = nil
        inserter.cancel()
        do {
            try session.cancel()
        } catch {
            fail(error, defaultStage: .storage)
            return
        }
        machine.cancel()
        phase = machine.phase
        target = nil
        partialTranscript = ""
        onStateChange?()
    }

    public func stop() {
        if phase.isActive {
            cancel()
        } else {
            attemptID = nil
            operationTask?.cancel()
            operationTask = nil
            inserter.cancel()
            do {
                try session.cancel()
            } catch {
                fail(error, defaultStage: .storage)
            }
            target = nil
        }
    }

    /// Converts a crash-surviving raw-audio checkpoint into a pending Last
    /// Dictation. Recovery never inserts automatically because the original
    /// focused destination cannot be trusted after relaunch.
    public func recoverInterruptedSession(
        retainInHistory: Bool,
        retainAudioInHistory: Bool
    ) {
        guard phase == .idle, operationTask == nil else { return }
        operationTask = Task { [weak self] in
            guard let self else { return }
            do {
                let results = try await session.recoverInterruptedAudio()
                guard !results.isEmpty else {
                    operationTask = nil
                    return
                }
                let recoveredText = results
                    .map(\.transcript)
                    .filter { !$0.isEmpty }
                    .joined(separator: "\n")
                guard !recoveredText.isEmpty else {
                    operationTask = nil
                    return
                }
                let entry = try await history.preserve(
                    text: recoveredText,
                    targetBundleIdentifier: nil,
                    temporaryAudioURL: retainAudioInHistory && results.count == 1
                        ? results[0].temporaryAudioURL
                        : nil,
                    retainInHistory: retainInHistory
                )
                for result in results where !retainAudioInHistory || results.count > 1 {
                    if let temporaryAudioURL = result.temporaryAudioURL {
                        try session.discardTemporaryAudio(at: temporaryAudioURL)
                    }
                }
                transcriptHistory = try await history.load()
                if transcriptHistory.isEmpty { transcriptHistory = [entry] }
                partialTranscript = recoveredText
                onStateChange?()
            } catch {
                fail(error, defaultStage: .storage)
            }
            operationTask = nil
        }
    }

    public func waitUntilSettled() async {
        while let task = operationTask {
            await task.value
            if operationTask == nil { break }
            await Task.yield()
        }
    }

    private func validateActiveAttempt(_ id: UUID) throws {
        try Task.checkCancellation()
        guard attemptID == id else { throw CancellationError() }
    }

    private func cancelAttempt(id: UUID) {
        guard attemptID == id else { return }
        attemptID = nil
        inserter.cancel()
        do {
            try session.cancel()
        } catch {
            fail(error, defaultStage: .storage)
            return
        }
        machine.cancel()
        phase = machine.phase
        target = nil
        partialTranscript = ""
    }

    private func fail(_ error: Error, defaultStage: GuideFailureStage) {
        let failure = (error as? GuideFailure) ?? GuideFailure(
            stage: defaultStage,
            message: error.localizedDescription,
            recovery: "Try again. Your completed transcript remains available when recovery succeeded."
        )
        if phase.isActive {
            machine.fail(failure)
        }
        phase = .failed(failure)
        lastFailure = failure
        target = nil
        attemptID = nil
        onStateChange?()
    }
}
