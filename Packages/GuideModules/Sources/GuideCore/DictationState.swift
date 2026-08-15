import Foundation

public enum DictationPhase: Equatable, Sendable {
    case idle
    case preparing
    case recording
    case transcribing
    case inserting
    case succeeded
    case cancelled
    case failed(GuideFailure)

    public var isActive: Bool {
        switch self {
        case .preparing, .recording, .transcribing, .inserting:
            true
        default:
            false
        }
    }
}

public struct DictationStateMachine: Equatable, Sendable {
    public private(set) var phase: DictationPhase = .idle

    public init() {}

    public mutating func prepare() throws {
        guard canBegin else {
            throw invalidTransition("A dictation session is already active.")
        }
        phase = .preparing
    }

    public mutating func beginRecording() throws {
        guard phase == .preparing else {
            throw invalidTransition("Recording can begin only after preparation.")
        }
        phase = .recording
    }

    public mutating func beginTranscription() throws {
        guard phase == .recording else {
            throw invalidTransition("Transcription can begin only after recording.")
        }
        phase = .transcribing
    }

    public mutating func beginInsertion() throws {
        guard phase == .transcribing else {
            throw invalidTransition("Insertion can begin only after transcription.")
        }
        phase = .inserting
    }

    public mutating func succeed() throws {
        guard phase == .inserting else {
            throw invalidTransition("A session can succeed only after insertion.")
        }
        phase = .succeeded
    }

    public mutating func cancel() {
        guard phase.isActive else { return }
        phase = .cancelled
    }

    public mutating func fail(_ failure: GuideFailure) {
        guard phase.isActive else { return }
        phase = .failed(failure)
    }

    public mutating func reset() {
        guard !phase.isActive else { return }
        phase = .idle
    }

    private var canBegin: Bool {
        switch phase {
        case .idle, .succeeded, .cancelled, .failed:
            true
        default:
            false
        }
    }

    private func invalidTransition(_ message: String) -> GuideFailure {
        GuideFailure(
            stage: .activation,
            message: message,
            recovery: "Finish or cancel the current dictation and try again."
        )
    }
}

