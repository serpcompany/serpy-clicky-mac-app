import Foundation

/// A provider-neutral transcript update emitted by a streaming local speech
/// engine. Finalized text is permanent; volatile text replaces only the current
/// in-progress suffix.
public enum StreamingTranscriptUpdate: Equatable, Sendable {
    case finalized(String)
    case volatile(String)
}

/// Accumulates the finalized and volatile result stream used by the pinned Yap
/// donor's SpeechAnalyzer transcriber. Keeping these two channels separate
/// prevents a later volatile result from replacing an already committed prefix.
public struct StreamingTranscriptAccumulator: Equatable, Sendable {
    private var finalized = ""
    private var volatile = ""

    public init() {}

    public var visibleText: String {
        (finalized + volatile).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var completeText: String {
        finalized.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public mutating func receive(_ update: StreamingTranscriptUpdate) {
        switch update {
        case let .finalized(text):
            finalized += text
            volatile = ""
        case let .volatile(text):
            volatile = text
        }
    }

    public mutating func reset() {
        finalized = ""
        volatile = ""
    }
}

public struct SpeechTranscriptionResult: Equatable, Sendable {
    public let transcript: String
    public let temporaryAudioURL: URL?

    public init(transcript: String, temporaryAudioURL: URL?) {
        self.transcript = transcript
        self.temporaryAudioURL = temporaryAudioURL
    }
}

@MainActor
public protocol DictationSessioning: AnyObject {
    var onPartial: (@MainActor @Sendable (String) -> Void)? { get set }
    var isOnDeviceAvailable: Bool { get }
    var availabilityDescription: String { get }
    func start(retainAudioInHistory: Bool) async throws
    func stop() async throws -> SpeechTranscriptionResult
    func cancel() throws
    func recoverInterruptedAudio() async throws -> [SpeechTranscriptionResult]
    func discardTemporaryAudio(at url: URL) throws
}

public extension DictationSessioning {
    func recoverInterruptedAudio() async throws -> [SpeechTranscriptionResult] { [] }
}

/// The bounded final-word capture interval adapted from OpenSuperWhisper. The
/// owner can cancel the wait so Escape or termination cannot leave stop work
/// running in the background.
@MainActor
public final class DictationStopTail {
    public let duration: Duration
    private var task: Task<Void, Error>?

    public init(duration: Duration = .milliseconds(250)) {
        self.duration = duration
    }

    public func wait() async throws {
        let task = Task { try await Task.sleep(for: duration) }
        self.task = task
        defer { self.task = nil }
        try await task.value
    }

    public func cancel() {
        task?.cancel()
        task = nil
    }
}

public protocol FocusedTextTargetRepresenting: Sendable {
    var bundleIdentifier: String? { get }
}

@MainActor
public protocol FocusedTextTargetReading<FocusedTarget>: AnyObject {
    associatedtype FocusedTarget: FocusedTextTargetRepresenting
    func captureFocusedTarget() throws -> FocusedTarget
}

public enum TextInsertionMethod: String, Equatable, Sendable {
    case accessibility
    case accessibilityValue
    case paste
    case pasteUnconfirmed

    public var isConfirmed: Bool {
        self != .pasteUnconfirmed
    }
}

@MainActor
public protocol TextInserting<FocusedTarget>: AnyObject {
    associatedtype FocusedTarget: FocusedTextTargetRepresenting
    func insert(_ text: String, into target: FocusedTarget) async throws -> TextInsertionMethod
    func cancel()
}

public extension TextInserting {
    func cancel() {}
}

public protocol LastDictationStoring: Sendable {
    func load() async throws -> [TranscriptHistoryEntry]

    func preserve(
        text: String,
        targetBundleIdentifier: String?,
        temporaryAudioURL: URL?,
        retainInHistory: Bool
    ) async throws -> TranscriptHistoryEntry

    func updateDelivery(
        id: UUID,
        state: TranscriptDeliveryState,
        method: String?,
        targetBundleIdentifier: String?
    ) async throws -> [TranscriptHistoryEntry]
}
