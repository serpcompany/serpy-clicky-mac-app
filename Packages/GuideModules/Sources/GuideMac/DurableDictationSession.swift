@preconcurrency import AVFoundation
import Foundation
import GuideCore
import Speech

private final class SessionFailureBox: @unchecked Sendable {
    private let lock = NSLock()
    private var failure: GuideFailure?

    func store(_ failure: GuideFailure) {
        lock.withLock {
            if self.failure == nil { self.failure = failure }
        }
    }

    func load() -> GuideFailure? { lock.withLock { failure } }
    func reset() { lock.withLock { failure = nil } }
}

/// Durable local Dictation pipeline. Capture, recognition, checkpointing, and
/// the stop tail are external adapters at this public session seam.
@MainActor
public final class DurableDictationSession: DictationSessioning {
    public typealias TranscriberFactory = @MainActor @Sendable () -> any StreamingTranscriber
    public typealias CheckpointFactory = @MainActor @Sendable () throws -> RecoverableAudioCheckpointWriter
    public typealias ReadinessCheck = @MainActor @Sendable () throws -> Void

    public var onPartial: (@MainActor @Sendable (String) -> Void)?

    private let capture: any AudioCapturing
    private let makeTranscriber: TranscriberFactory
    private let makeCheckpointWriter: CheckpointFactory
    private let stopTail: DictationStopTail
    private let checkReadiness: ReadinessCheck
    private let locale: Locale
    private let recoveryDirectory: URL
    private let relay = AudioBufferRelay()
    private let failure = SessionFailureBox()
    private var transcriber: (any StreamingTranscriber)?
    private var checkpoint: SerializedAudioCheckpointWriter?

    public init() {
        capture = YapAudioCaptureService()
        makeTranscriber = {
            if #available(macOS 26.0, *) {
                return SpeechAnalyzerStreamingTranscriber()
            }
            return ChunkedSFSpeechTranscriber()
        }
        makeCheckpointWriter = { try RecoverableAudioCheckpointWriter() }
        stopTail = DictationStopTail()
        checkReadiness = {
            guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
                throw GuideFailure(
                    stage: .permission,
                    message: "Speech Recognition permission is not granted.",
                    recovery: "Enable Speech Recognition in System Settings."
                )
            }
            guard AVCaptureDevice.authorizationStatus(for: .audio) == .authorized else {
                throw GuideFailure(
                    stage: .permission,
                    message: "Microphone permission is not granted.",
                    recovery: "Enable Microphone access in System Settings."
                )
            }
        }
        locale = .current
        recoveryDirectory = RecoverableAudioCheckpointWriter.defaultRecoveryDirectory()
    }

    public init(
        capture: any AudioCapturing,
        makeTranscriber: @escaping TranscriberFactory,
        makeCheckpointWriter: @escaping CheckpointFactory,
        stopTail: DictationStopTail,
        checkReadiness: @escaping ReadinessCheck,
        locale: Locale = .init(identifier: "en-US"),
        recoveryDirectory: URL = RecoverableAudioCheckpointWriter.defaultRecoveryDirectory()
    ) {
        self.capture = capture
        self.makeTranscriber = makeTranscriber
        self.makeCheckpointWriter = makeCheckpointWriter
        self.stopTail = stopTail
        self.checkReadiness = checkReadiness
        self.locale = locale
        self.recoveryDirectory = recoveryDirectory
    }

    public var isOnDeviceAvailable: Bool { true }
    public var availabilityDescription: String {
        if #available(macOS 26.0, *) {
            return "Apple on-device streaming speech is ready."
        }
        return "Apple on-device chunked speech is ready."
    }

    public func start(retainAudioInHistory: Bool) async throws {
        try checkReadiness()
        failure.reset()
        relay.reset()
        let checkpoint = SerializedAudioCheckpointWriter(writer: try makeCheckpointWriter())
        self.checkpoint = checkpoint
        capture.onFailure = { [failure] value in failure.store(value) }
        capture.onBuffer = { [weak self, checkpoint] buffer in
            _ = checkpoint.enqueue(buffer)
            self?.relay.receive(buffer)
        }

        // Yap's ordering: capture before speech-stack preparation, with the
        // bounded relay holding the early buffers.
        try capture.start()
        let transcriber = makeTranscriber()
        transcriber.onPartial = { [weak self] text in
            Task { @MainActor in self?.onPartial?(text) }
        }
        self.transcriber = transcriber
        do {
            try await transcriber.begin(locale: locale)
        } catch {
            capture.stop()
            relay.reset()
            do { try checkpoint.cancel() } catch { throw deletionFailure(error) }
            self.checkpoint = nil
            self.transcriber = nil
            throw error
        }
        relay.attach { buffer in transcriber.feed(buffer) }
    }

    public func stop() async throws -> SpeechTranscriptionResult {
        try await stopTail.wait()
        capture.stop()
        relay.reset()
        if let failure = failure.load() { throw failure }
        let audioURL = try checkpoint?.finish()
        if let failure = failure.load() { throw failure }
        let text = try await transcriber?.finish(recoveryAudioURL: audioURL) ?? ""
        if let failure = failure.load() { throw failure }
        checkpoint = nil
        transcriber = nil
        return .init(transcript: text, temporaryAudioURL: audioURL)
    }

    public func cancel() throws {
        stopTail.cancel()
        capture.stop()
        relay.reset()
        transcriber?.cancel()
        transcriber = nil
        if let checkpoint {
            do {
                try checkpoint.cancel()
            } catch {
                throw deletionFailure(error)
            }
        }
        checkpoint = nil
        failure.reset()
    }

    public func recoverInterruptedAudio() async throws -> [SpeechTranscriptionResult] {
        let urls = try RecoverableAudioCheckpointWriter.recoverableAudioURLs(
            in: recoveryDirectory
        )
        var recovered: [SpeechTranscriptionResult] = []
        for url in urls {
            let transcriber = makeTranscriber()
            transcriber.onPartial = { [weak self] text in
                Task { @MainActor in self?.onPartial?(text) }
            }
            try await transcriber.begin(locale: locale)
            do {
                if transcriber.recoveryInputMode == .streamCheckpointBuffers {
                    try feedFile(url, to: transcriber)
                }
                let text = try await transcriber.finish(recoveryAudioURL: url)
                recovered.append(.init(transcript: text, temporaryAudioURL: url))
            } catch {
                transcriber.cancel()
                throw error
            }
        }
        return recovered
    }

    public func discardTemporaryAudio(at url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            throw deletionFailure(error)
        }
    }

    private func feedFile(_ url: URL, to transcriber: any StreamingTranscriber) throws {
        let file = try AVAudioFile(forReading: url)
        let capacity: AVAudioFrameCount = 2_048
        while file.framePosition < file.length {
            guard let buffer = AVAudioPCMBuffer(
                pcmFormat: file.processingFormat,
                frameCapacity: capacity
            ) else {
                throw GuideFailure(
                    stage: .storage,
                    message: "Recovered Dictation audio could not be read.",
                    recovery: "Keep the recovery file and try again after checking disk health."
                )
            }
            try file.read(into: buffer, frameCount: capacity)
            if buffer.frameLength == 0 { break }
            transcriber.feed(buffer)
        }
    }

    private func deletionFailure(_ error: Error) -> GuideFailure {
        GuideFailure(
            stage: .storage,
            message: "Temporary Dictation audio could not be deleted safely.",
            recovery: "Close processes using the recovery file and try the cleanup again."
        )
    }
}
