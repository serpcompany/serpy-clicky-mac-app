import AVFoundation
import GuideCore
import GuideMac
import Testing

@Suite("Active audio recovery checkpoints")
struct RecoveryAudioCheckpointWriterTests {
    @Test("every captured buffer is recoverably checkpointed")
    func checkpointsEveryBuffer() throws {
        let sink = CountingCheckpointSink()
        let writer = RecoverableAudioCheckpointWriter(sink: sink)
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 16_000, channels: 1))
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 2_048))
        buffer.frameLength = 2_048

        for _ in 0..<80 { writer.append(buffer) }
        _ = try writer.finish()

        #expect(sink.appendCount == 80)
        #expect(sink.checkpointedDuration > 10)
    }

    @Test("checkpoint write failure blocks unsafe completion with recovery")
    func checkpointFailureIsExplicit() throws {
        let writer = RecoverableAudioCheckpointWriter(sink: FailingCheckpointSink())
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 16_000, channels: 1))
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 2_048))
        buffer.frameLength = 2_048

        writer.append(buffer)

        do {
            _ = try writer.finish()
            Issue.record("Expected checkpoint completion to fail")
        } catch let failure as GuideFailure {
            #expect(failure.stage == .storage)
            #expect(failure.message.contains("checkpointed"))
            #expect(!failure.recovery.isEmpty)
        }
    }

    @Test("an interrupted session leaves a discoverable recovery source")
    func interruptedCheckpointIsDiscoverable() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "serpy-checkpoint-test-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let writer = try RecoverableAudioCheckpointWriter(directoryURL: directory)
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 16_000, channels: 1))
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 2_048))
        buffer.frameLength = 2_048

        writer.append(buffer)

        let recoverable = try RecoverableAudioCheckpointWriter.recoverableAudioURLs(in: directory)
        #expect(recoverable.count == 1)
        #expect(recoverable[0].lastPathComponent.hasPrefix("active-"))

        try writer.cancel()
        #expect(try RecoverableAudioCheckpointWriter.recoverableAudioURLs(in: directory).isEmpty)
    }
}

private final class CountingCheckpointSink: AudioCheckpointSink, @unchecked Sendable {
    var appendCount = 0
    var checkpointedDuration: TimeInterval = 0

    func append(_ buffer: AVAudioPCMBuffer) throws {
        appendCount += 1
        checkpointedDuration += Double(buffer.frameLength) / buffer.format.sampleRate
    }
    func finish() throws -> URL? { nil }
    func cancel() throws {}
}

private final class FailingCheckpointSink: AudioCheckpointSink, @unchecked Sendable {
    struct WriteFailure: Error {}
    func append(_ buffer: AVAudioPCMBuffer) throws { throw WriteFailure() }
    func finish() throws -> URL? { nil }
    func cancel() throws {}
}
