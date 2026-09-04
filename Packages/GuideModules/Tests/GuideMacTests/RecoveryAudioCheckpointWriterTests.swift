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

    @Test("real-time callback only enqueues while disk writes stay ordered off-callback")
    func serializedWriterDoesNotBlockCaptureCallback() throws {
        let sink = BlockingOrderedCheckpointSink()
        let writer = SerializedAudioCheckpointWriter(
            writer: RecoverableAudioCheckpointWriter(sink: sink),
            maximumPendingBuffers: 4
        )

        #expect(writer.enqueue(try markerBuffer(1)))
        sink.waitUntilFirstWriteStarts()
        #expect(writer.enqueue(try markerBuffer(2)))
        sink.releaseWrites()
        _ = try writer.finish()

        #expect(sink.markers == [1, 2])
    }

    @Test("bounded queue overflow is explicit and can never return truncated success")
    func serializedWriterReportsOverflow() throws {
        let sink = BlockingOrderedCheckpointSink()
        let writer = SerializedAudioCheckpointWriter(
            writer: RecoverableAudioCheckpointWriter(sink: sink),
            maximumPendingBuffers: 1
        )

        #expect(writer.enqueue(try markerBuffer(1)))
        sink.waitUntilFirstWriteStarts()
        #expect(!writer.enqueue(try markerBuffer(2)))
        sink.releaseWrites()

        do {
            _ = try writer.finish()
            Issue.record("Expected checkpoint queue overflow")
        } catch let failure as GuideFailure {
            #expect(failure.stage == .storage)
            #expect(failure.message.contains("queue"))
            #expect(!failure.recovery.isEmpty)
        }
    }

    private func markerBuffer(_ marker: Float) throws -> AVAudioPCMBuffer {
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 16_000, channels: 1))
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 32))
        buffer.frameLength = 32
        buffer.floatChannelData?[0].initialize(repeating: marker, count: 32)
        return buffer
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

private final class BlockingOrderedCheckpointSink: AudioCheckpointSink, @unchecked Sendable {
    private let condition = NSCondition()
    private var firstWriteStarted = false
    private var released = false
    private var storedMarkers: [Float] = []

    var markers: [Float] {
        condition.withLock { storedMarkers }
    }

    func append(_ buffer: AVAudioPCMBuffer) throws {
        condition.lock()
        if !firstWriteStarted {
            firstWriteStarted = true
            condition.broadcast()
            while !released { condition.wait() }
        }
        storedMarkers.append(buffer.floatChannelData?[0][0] ?? -1)
        condition.unlock()
    }

    func waitUntilFirstWriteStarts() {
        condition.lock()
        while !firstWriteStarted { condition.wait() }
        condition.unlock()
    }

    func releaseWrites() {
        condition.withLock {
            released = true
            condition.broadcast()
        }
    }

    func finish() throws -> URL? { nil }
    func cancel() throws { releaseWrites() }
}
