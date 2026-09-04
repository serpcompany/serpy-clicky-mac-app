import AVFoundation
import GuideCore
@testable import GuideMac
import Testing

@MainActor
@Suite("Production durable Dictation session")
struct DurableDictationSessionTests {
    @Test("multi-minute PCM input preserves sentinels across the one-minute boundary")
    func multiMinuteAudioPreservesAllSentinels() async throws {
        let capture = SyntheticAudioCapture()
        let transcriber = FrameDrivenTranscriber()
        let checkpoint = CountingCheckpointSink()
        let session = DurableDictationSession(
            capture: capture,
            makeTranscriber: { transcriber },
            makeCheckpointWriter: { RecoverableAudioCheckpointWriter(sink: checkpoint) },
            stopTail: DictationStopTail(duration: .zero),
            checkReadiness: {}
        )

        try await session.start(retainAudioInHistory: false)
        for second in 1...130 {
            let marker: Float? = switch second {
            case 1: 0.10
            case 59: 0.20
            case 61: 0.30
            case 90: 0.40
            case 130: 0.50
            default: nil
            }
            capture.emit(try oneSecondBuffer(marker: marker))
        }
        let result = try await session.stop()

        let expected = "BEGIN alpha BEFORE-60 beta AFTER-60 gamma MIDDLE delta END omega"
        #expect(result.transcript == expected)
        #expect(checkpoint.framesWritten == 130 * 16_000)
        var searchStart = expected.startIndex
        for sentinel in ["BEGIN", "BEFORE-60", "AFTER-60", "MIDDLE", "END"] {
            #expect(expected.components(separatedBy: sentinel).count - 1 == 1)
            let range = expected.range(of: sentinel, range: searchStart..<expected.endIndex)
            #expect(range != nil)
            if let range { searchStart = range.upperBound }
        }
    }

    @Test("recognition failure after a prefix never returns truncated success")
    func recognitionFailureRejectsPrefix() async throws {
        let capture = SyntheticAudioCapture()
        let transcriber = FrameDrivenTranscriber(failAfterFrames: 61 * 16_000)
        let session = DurableDictationSession(
            capture: capture,
            makeTranscriber: { transcriber },
            makeCheckpointWriter: { RecoverableAudioCheckpointWriter(sink: CountingCheckpointSink()) },
            stopTail: DictationStopTail(duration: .zero),
            checkReadiness: {}
        )

        try await session.start(retainAudioInHistory: false)
        for _ in 0..<70 { capture.emit(try oneSecondBuffer()) }

        do {
            _ = try await session.stop()
            Issue.record("Expected recognition failure")
        } catch let failure as GuideFailure {
            #expect(failure.stage == .transcription)
            #expect(failure.message.contains("limit"))
            #expect(!failure.recovery.isEmpty)
        }
    }

    @Test("macOS 14–25 fallback splits real long audio below the recognizer limit")
    func legacyFallbackUsesSequentialSubMinuteChunks() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "serpy-legacy-chunks-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let sourceURL = directory.appending(path: "long-session.caf")
        let format = try #require(AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16_000,
            channels: 1,
            interleaved: false
        ))
        try {
            let file = try AVAudioFile(
                forWriting: sourceURL,
                settings: format.settings,
                commonFormat: .pcmFormatFloat32,
                interleaved: false
            )
            for _ in 0..<130 { try file.write(from: oneSecondBuffer()) }
        }()

        let recognizer = FixtureChunkRecognizer(results: [
            "BEGIN alpha BEFORE-60 beta",
            "AFTER-60 gamma MIDDLE delta",
            "END omega"
        ])
        let transcriber = ChunkedSFSpeechTranscriber(
            recognizer: recognizer,
            maximumChunkDuration: 50,
            temporaryDirectory: directory
        )
        try await transcriber.begin(locale: .init(identifier: "en-US"))

        let result = try await transcriber.finish(recoveryAudioURL: sourceURL)

        #expect(result == "BEGIN alpha BEFORE-60 beta AFTER-60 gamma MIDDLE delta END omega")
        #expect(recognizer.durations == [50, 50, 30])
        #expect(recognizer.durations.allSatisfy { $0 <= 50.01 })
        #expect(recognizer.durations.reduce(0, +) > 129.9)
    }

    @Test("device restart failure rejects a captured prefix as success")
    func deviceFailureIsStagedAndNotTruncated() async throws {
        let capture = SyntheticAudioCapture()
        let session = DurableDictationSession(
            capture: capture,
            makeTranscriber: { FrameDrivenTranscriber() },
            makeCheckpointWriter: { RecoverableAudioCheckpointWriter(sink: CountingCheckpointSink()) },
            stopTail: DictationStopTail(duration: .zero),
            checkReadiness: {}
        )
        try await session.start(retainAudioInHistory: false)
        capture.emit(try oneSecondBuffer())
        let failure = GuideFailure(
            stage: .recording,
            message: "The microphone stopped after its input device changed.",
            recovery: "Reconnect the microphone and start Dictation again."
        )
        capture.emitFailure(failure)

        do {
            _ = try await session.stop()
            Issue.record("Expected device failure")
        } catch let received as GuideFailure {
            #expect(received == failure)
        }
    }

    @Test("recovery transcribes every discoverable active checkpoint")
    func recoveryReadsEveryCheckpoint() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "serpy-recovery-all-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        for _ in 0..<2 {
            let writer = try RecoverableAudioCheckpointWriter(directoryURL: directory)
            writer.append(try oneSecondBuffer())
            _ = try writer.finish()
        }
        let factory = FixedTranscriberFactory(results: ["first recovered", "second recovered"])
        let session = DurableDictationSession(
            capture: SyntheticAudioCapture(),
            makeTranscriber: { factory.make() },
            makeCheckpointWriter: { RecoverableAudioCheckpointWriter(sink: CountingCheckpointSink()) },
            stopTail: DictationStopTail(duration: .zero),
            checkReadiness: {},
            recoveryDirectory: directory
        )

        let recovered = try await session.recoverInterruptedAudio()

        #expect(Set(recovered.map(\.transcript)) == Set(["first recovered", "second recovered"]))
        #expect(recovered.compactMap(\.temporaryAudioURL).count == 2)
    }

    @Test("checkpoint deletion failure is visible instead of silently ignored")
    func deletionFailureIsVisible() async throws {
        let session = DurableDictationSession(
            capture: SyntheticAudioCapture(),
            makeTranscriber: { FrameDrivenTranscriber() },
            makeCheckpointWriter: {
                RecoverableAudioCheckpointWriter(sink: DeletionFailingCheckpointSink())
            },
            stopTail: DictationStopTail(duration: .zero),
            checkReadiness: {}
        )
        try await session.start(retainAudioInHistory: false)

        do {
            try session.cancel()
            Issue.record("Expected cleanup failure")
        } catch let failure as GuideFailure {
            #expect(failure.stage == .storage)
            #expect(failure.message.contains("deleted"))
            #expect(!failure.recovery.isEmpty)
        }
    }

    private func oneSecondBuffer(marker: Float? = nil) throws -> AVAudioPCMBuffer {
        let format = try #require(AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16_000,
            channels: 1,
            interleaved: false
        ))
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 16_000))
        buffer.frameLength = 16_000
        if let samples = buffer.floatChannelData?[0] {
            samples.initialize(repeating: marker ?? 0, count: Int(buffer.frameLength))
        }
        return buffer
    }
}

private final class FixtureChunkRecognizer: AudioChunkRecognizing, @unchecked Sendable {
    private let results: [String]
    private var index = 0
    private(set) var durations: [TimeInterval] = []

    init(results: [String]) { self.results = results }
    func prepare(locale: Locale) async throws {}
    func recognize(_ url: URL) async throws -> String {
        let file = try AVAudioFile(forReading: url)
        durations.append(Double(file.length) / file.processingFormat.sampleRate)
        defer { index += 1 }
        return index < results.count ? results[index] : ""
    }
    func cancel() {}
}

@MainActor
private final class FixedTranscriberFactory {
    private var results: [String]
    init(results: [String]) { self.results = results }
    func make() -> any StreamingTranscriber {
        FixedResultTranscriber(result: results.removeFirst())
    }
}

private final class FixedResultTranscriber: StreamingTranscriber, @unchecked Sendable {
    var onPartial: (@Sendable (String) -> Void)?
    let result: String
    init(result: String) { self.result = result }
    func begin(locale: Locale) async throws {}
    func feed(_ buffer: AVAudioPCMBuffer) {}
    func finish(recoveryAudioURL: URL?) async throws -> String { result }
    func cancel() {}
}

private final class SyntheticAudioCapture: AudioCapturing, @unchecked Sendable {
    var onBuffer: (@Sendable (AVAudioPCMBuffer) -> Void)?
    var onFailure: (@Sendable (GuideFailure) -> Void)?
    private(set) var isRunning = false
    func start() throws { isRunning = true }
    func stop() { isRunning = false }
    func emit(_ buffer: AVAudioPCMBuffer) { onBuffer?(buffer) }
    func emitFailure(_ failure: GuideFailure) { onFailure?(failure) }
}

private final class FrameDrivenTranscriber: StreamingTranscriber, @unchecked Sendable {
    var onPartial: (@Sendable (String) -> Void)?
    private var frames = 0
    private var transcript = StreamingTranscriptAccumulator()
    private let failAfterFrames: Int?
    private var failure: GuideFailure?

    init(failAfterFrames: Int? = nil) { self.failAfterFrames = failAfterFrames }
    func begin(locale: Locale) async throws { transcript.reset() }
    func feed(_ buffer: AVAudioPCMBuffer) {
        frames += Int(buffer.frameLength)
        if let failAfterFrames, frames >= failAfterFrames {
            failure = GuideFailure(
                stage: .transcription,
                message: "Injected recognition limit reached.",
                recovery: "Retry from the recoverable audio checkpoint."
            )
            return
        }
        let marker = buffer.floatChannelData?[0][0] ?? 0
        let segment: String? = switch marker {
        case 0.09...0.11: "BEGIN alpha "
        case 0.19...0.21: "BEFORE-60 beta "
        case 0.29...0.31: "AFTER-60 gamma "
        case 0.39...0.41: "MIDDLE delta "
        case 0.49...0.51: "END omega"
        default: nil
        }
        if let segment {
            transcript.receive(.finalized(segment))
            onPartial?(transcript.visibleText)
        }
    }
    func finish(recoveryAudioURL: URL?) async throws -> String {
        if let failure { throw failure }
        return transcript.completeText
    }
    func cancel() {}
}

private final class CountingCheckpointSink: AudioCheckpointSink, @unchecked Sendable {
    private(set) var framesWritten = 0
    func append(_ buffer: AVAudioPCMBuffer) throws { framesWritten += Int(buffer.frameLength) }
    func finish() throws -> URL? { nil }
    func cancel() throws {}
}

private final class DeletionFailingCheckpointSink: AudioCheckpointSink, @unchecked Sendable {
    struct DeleteFailure: Error {}
    func append(_ buffer: AVAudioPCMBuffer) throws {}
    func finish() throws -> URL? { nil }
    func cancel() throws { throw DeleteFailure() }
}
