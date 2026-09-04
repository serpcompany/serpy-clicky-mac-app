@preconcurrency import AVFoundation
import Foundation
import GuideCore
import os
import Speech

public enum StreamingRecoveryInputMode: Equatable, Sendable {
    case streamCheckpointBuffers
    case transcriberReadsCheckpointURL
}

public protocol StreamingTranscriber: AnyObject, Sendable {
    var onPartial: (@Sendable (String) -> Void)? { get set }
    var recoveryInputMode: StreamingRecoveryInputMode { get }
    func begin(locale: Locale) async throws
    func feed(_ buffer: AVAudioPCMBuffer)
    func finish(recoveryAudioURL: URL?) async throws -> String
    func cancel()
}

public extension StreamingTranscriber {
    var recoveryInputMode: StreamingRecoveryInputMode { .streamCheckpointBuffers }
}

private final class TranscriptionFailureBox: @unchecked Sendable {
    private let lock = NSLock()
    private var value: GuideFailure?

    func store(_ failure: GuideFailure) {
        lock.withLock {
            if value == nil { value = failure }
        }
    }

    func load() -> GuideFailure? { lock.withLock { value } }
    func reset() { lock.withLock { value = nil } }
}

@available(macOS 26.0, *)
final class SpeechAnalyzerStreamingTranscriber: StreamingTranscriber, @unchecked Sendable {
    var onPartial: (@Sendable (String) -> Void)?
    private var transcriber: SpeechTranscriber?
    private var analyzer: SpeechAnalyzer?
    private var inputBuilder: AsyncStream<AnalyzerInput>.Continuation?
    private var recognizerTask: Task<Void, Never>?
    private let converter = BufferConverter()
    private var analyzerFormat: AVAudioFormat?
    private var transcript = StreamingTranscriptAccumulator()
    private let failure = TranscriptionFailureBox()

    func begin(locale: Locale) async throws {
        transcript.reset()
        failure.reset()
        let installed = await SpeechTranscriber.installedLocales
        guard let resolved = SpeechLocaleMatcher.bestMatch(for: locale, in: installed) else {
            throw GuideFailure(
                stage: .transcription,
                message: "On-device speech is unavailable for the current language.",
                recovery: "Install the matching Apple speech model in System Settings and try again."
            )
        }

        let transcriber = SpeechTranscriber(
            locale: resolved,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],
            attributeOptions: [.audioTimeRange]
        )
        self.transcriber = transcriber
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        self.analyzer = analyzer
        guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
            throw transcriptionFailure(
                "Apple Speech could not choose an audio format.",
                recovery: "Reconnect the microphone and try again."
            )
        }
        analyzerFormat = format
        let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
        inputBuilder = continuation

        recognizerTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await result in transcriber.results {
                    try Task.checkCancellation()
                    let text = String(result.text.characters)
                    transcript.receive(result.isFinal ? .finalized(text) : .volatile(text))
                    onPartial?(transcript.visibleText)
                }
            } catch is CancellationError {
                return
            } catch {
                failure.store(transcriptionFailure(
                    "Local speech recognition failed before the recording was complete.",
                    recovery: "Retry from Last Dictation after checking the installed speech model."
                ))
            }
        }
        do {
            try await analyzer.start(inputSequence: stream)
        } catch {
            reset()
            throw transcriptionFailure(
                "Apple Speech could not start analyzing audio.",
                recovery: "Check the installed speech model and try again."
            )
        }
    }

    func feed(_ buffer: AVAudioPCMBuffer) {
        guard failure.load() == nil, let analyzerFormat, let inputBuilder else { return }
        do {
            inputBuilder.yield(AnalyzerInput(buffer: try converter.convert(buffer, to: analyzerFormat)))
        } catch {
            failure.store(transcriptionFailure(
                "Microphone audio could not be converted for local recognition.",
                recovery: "Reconnect the microphone and retry from the recoverable audio checkpoint."
            ))
            inputBuilder.finish()
        }
    }

    func finish(recoveryAudioURL: URL?) async throws -> String {
        inputBuilder?.finish()
        do {
            try await analyzer?.finalizeAndFinishThroughEndOfInput()
        } catch {
            failure.store(transcriptionFailure(
                "Local speech recognition could not finalize the complete recording.",
                recovery: "Retry from Last Dictation; the raw recovery audio was retained."
            ))
        }
        await recognizerTask?.value
        if let failure = failure.load() {
            reset()
            throw failure
        }
        let result = transcript.completeText
        reset()
        guard !result.isEmpty else {
            throw transcriptionFailure(
                "No speech was detected.",
                recovery: "Try again and speak while the recording indicator is visible."
            )
        }
        return result
    }

    func cancel() {
        inputBuilder?.finish()
        recognizerTask?.cancel()
        reset()
    }

    private func reset() {
        recognizerTask = nil
        transcriber = nil
        analyzer = nil
        inputBuilder = nil
        analyzerFormat = nil
        transcript.reset()
        failure.reset()
    }
}

/// macOS 14–25 fallback. It transcribes the durable checkpoint in sequential
/// sub-minute files so no SFSpeechRecognizer request crosses Apple's limit.
public protocol AudioChunkRecognizing: AnyObject, Sendable {
    func prepare(locale: Locale) async throws
    func recognize(_ url: URL) async throws -> String
    func cancel()
}

protocol AudioChunkFileOperating: AnyObject, Sendable {
    func openForReading(_ url: URL) throws -> AVAudioFile
    func openForWriting(_ url: URL, format: AVAudioFormat) throws -> AVAudioFile
    func read(
        _ file: AVAudioFile,
        into buffer: AVAudioPCMBuffer,
        frameCount: AVAudioFrameCount
    ) throws
    func write(_ buffer: AVAudioPCMBuffer, to file: AVAudioFile) throws
    func setOwnerOnlyPermissions(_ url: URL) throws
    func fileExists(_ url: URL) -> Bool
    func remove(_ url: URL) throws
}

final class SystemAudioChunkFileOperations: AudioChunkFileOperating, @unchecked Sendable {
    func openForReading(_ url: URL) throws -> AVAudioFile {
        try AVAudioFile(forReading: url)
    }

    func openForWriting(_ url: URL, format: AVAudioFormat) throws -> AVAudioFile {
        try AVAudioFile(
            forWriting: url,
            settings: format.settings,
            commonFormat: format.commonFormat,
            interleaved: format.isInterleaved
        )
    }

    func read(
        _ file: AVAudioFile,
        into buffer: AVAudioPCMBuffer,
        frameCount: AVAudioFrameCount
    ) throws {
        try file.read(into: buffer, frameCount: frameCount)
    }

    func write(_ buffer: AVAudioPCMBuffer, to file: AVAudioFile) throws {
        try file.write(from: buffer)
    }

    func setOwnerOnlyPermissions(_ url: URL) throws {
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    func fileExists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    func remove(_ url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }
}

final class ChunkedSFSpeechTranscriber: StreamingTranscriber, @unchecked Sendable {
    var onPartial: (@Sendable (String) -> Void)?
    private let recognizer: any AudioChunkRecognizing
    private var cancelled = false
    private let maximumChunkDuration: TimeInterval
    private let overlapDuration: TimeInterval
    private let temporaryDirectory: URL
    private let fileOperations: any AudioChunkFileOperating
    var recoveryInputMode: StreamingRecoveryInputMode { .transcriberReadsCheckpointURL }

    init(
        recognizer: any AudioChunkRecognizing = OnDeviceSFSpeechChunkRecognizer(),
        maximumChunkDuration: TimeInterval = 50,
        overlapDuration: TimeInterval = 1,
        temporaryDirectory: URL = FileManager.default.temporaryDirectory,
        fileOperations: any AudioChunkFileOperating = SystemAudioChunkFileOperations()
    ) {
        self.recognizer = recognizer
        self.maximumChunkDuration = maximumChunkDuration
        self.overlapDuration = min(max(0, overlapDuration), max(0, maximumChunkDuration - 0.1))
        self.temporaryDirectory = temporaryDirectory
        self.fileOperations = fileOperations
    }

    func begin(locale: Locale) async throws {
        cancelled = false
        try await recognizer.prepare(locale: locale)
    }

    func feed(_ buffer: AVAudioPCMBuffer) {
        // The owner-only checkpoint is the source of truth on older systems.
    }

    func finish(recoveryAudioURL: URL?) async throws -> String {
        guard let recoveryAudioURL else {
            throw transcriptionFailure(
                "The recoverable audio checkpoint is missing.",
                recovery: "Try Dictation again after checking available disk space."
            )
        }
        let chunks = try splitIfNeeded(recoveryAudioURL)
        var finalized = ""
        let reconciler = TranscriptOverlapReconciler()
        do {
            for chunk in chunks.urls {
                try Task.checkCancellation()
                guard !cancelled else { throw CancellationError() }
                let text = try await recognizer.recognize(chunk)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    finalized = reconciler.appending(finalized, next: text)
                    onPartial?(finalized)
                }
            }
            try chunks.cleanup()
        } catch {
            do { try chunks.cleanup() } catch let cleanupFailure { throw cleanupFailure }
            throw error
        }
        let text = finalized
        guard !text.isEmpty else {
            throw transcriptionFailure(
                "No speech was detected.",
                recovery: "Try again and speak while the recording indicator is visible."
            )
        }
        return text
    }

    func cancel() {
        cancelled = true
        recognizer.cancel()
    }

    private func splitIfNeeded(_ sourceURL: URL) throws -> TemporaryAudioChunks {
        let source: AVAudioFile
        do {
            source = try fileOperations.openForReading(sourceURL)
        } catch {
            throw audioSplitFailure()
        }
        let framesPerChunk = AVAudioFramePosition(source.processingFormat.sampleRate * maximumChunkDuration)
        let overlapFrames = AVAudioFramePosition(source.processingFormat.sampleRate * overlapDuration)
        guard source.length > framesPerChunk else {
            return TemporaryAudioChunks(
                urls: [sourceURL],
                temporaryURLs: [],
                fileOperations: fileOperations
            )
        }

        var urls: [URL] = []
        do {
            while source.framePosition < source.length {
                let url = temporaryDirectory
                    .appending(path: "serpy-speech-chunk-\(UUID().uuidString).caf")
                // Register ownership before creation because AVAudioFile can leave a
                // partial file behind even when its initializer throws.
                urls.append(url)
                let file = try fileOperations.openForWriting(url, format: source.processingFormat)
                var written: AVAudioFramePosition = 0
                while written < framesPerChunk, source.framePosition < source.length {
                    let remainingInSource = source.length - source.framePosition
                    let remainingInChunk = framesPerChunk - written
                    let requested = AVAudioFrameCount(min(remainingInSource, remainingInChunk))
                    guard let buffer = AVAudioPCMBuffer(
                        pcmFormat: source.processingFormat,
                        frameCapacity: requested
                    ) else {
                        throw audioSplitFailure()
                    }
                    try fileOperations.read(source, into: buffer, frameCount: requested)
                    guard buffer.frameLength > 0 else { break }
                    try fileOperations.write(buffer, to: file)
                    written += AVAudioFramePosition(buffer.frameLength)
                }
                guard written > 0 else {
                    try fileOperations.remove(url)
                    urls.removeLast()
                    break
                }
                try fileOperations.setOwnerOnlyPermissions(url)
                if source.framePosition < source.length, overlapFrames > 0 {
                    source.framePosition = max(0, source.framePosition - overlapFrames)
                }
            }
        } catch {
            let splitFailure = (error as? GuideFailure) ?? audioSplitFailure()
            do {
                try TemporaryAudioChunks.cleanup(urls, using: fileOperations)
            } catch let cleanupFailure as GuideFailure {
                throw GuideFailure(
                    stage: .storage,
                    message: "\(splitFailure.message) One or more temporary chunks could not be deleted.",
                    recovery: "\(splitFailure.recovery) \(cleanupFailure.recovery)"
                )
            }
            throw splitFailure
        }
        return TemporaryAudioChunks(
            urls: urls,
            temporaryURLs: urls,
            fileOperations: fileOperations
        )
    }

    private func audioSplitFailure() -> GuideFailure {
        GuideFailure(
            stage: .storage,
            message: "A long recording could not be divided safely.",
            recovery: "Retry from the retained raw audio checkpoint after checking available disk space."
        )
    }
}

private final class OnDeviceSFSpeechChunkRecognizer: AudioChunkRecognizing, @unchecked Sendable {
    private var recognizer: SFSpeechRecognizer?
    private var task: SFSpeechRecognitionTask?

    func prepare(locale: Locale) async throws {
        let recognizer = SFSpeechRecognizer(locale: locale)
            ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        guard let recognizer, recognizer.supportsOnDeviceRecognition else {
            throw transcriptionFailure(
                "On-device speech is unavailable for the current language.",
                recovery: "Install the matching Apple speech model and try again."
            )
        }
        self.recognizer = recognizer
    }

    func recognize(_ url: URL) async throws -> String {
        guard let recognizer else {
            throw transcriptionFailure(
                "The local speech recognizer is unavailable.",
                recovery: "Check the installed speech model and try again."
            )
        }
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = false
        let gate = RecognitionContinuationGate()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                gate.install(continuation)
                task = recognizer.recognitionTask(with: request) { result, error in
                    if let result, result.isFinal {
                        gate.resume(returning: result.bestTranscription.formattedString)
                    } else if error != nil {
                        gate.resume(throwing: transcriptionFailure(
                            "Local speech recognition failed before the chunk completed.",
                            recovery: "Retry from Last Dictation; the raw recovery audio was retained."
                        ))
                    }
                }
            }
        } onCancel: { [weak self] in
            self?.task?.cancel()
            gate.resume(throwing: CancellationError())
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        recognizer = nil
    }
}

private struct TemporaryAudioChunks {
    let urls: [URL]
    let temporaryURLs: [URL]
    let fileOperations: any AudioChunkFileOperating

    func cleanup() throws {
        try Self.cleanup(temporaryURLs, using: fileOperations)
    }

    static func cleanup(
        _ urls: [URL],
        using fileOperations: any AudioChunkFileOperating
    ) throws {
        var deletionFailed = false
        for url in urls where fileOperations.fileExists(url) {
            do {
                try fileOperations.remove(url)
            } catch {
                deletionFailed = true
            }
        }
        guard !deletionFailed else {
            throw GuideFailure(
                stage: .storage,
                message: "One or more temporary Dictation chunks could not be deleted.",
                recovery: "Remove the temporary files after closing other processes, then try again."
            )
        }
    }
}

private final class RecognitionContinuationGate: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<String, Error>?

    func install(_ continuation: CheckedContinuation<String, Error>) {
        lock.withLock { self.continuation = continuation }
    }

    func resume(returning value: String) {
        let continuation = lock.withLock { () -> CheckedContinuation<String, Error>? in
            defer { self.continuation = nil }
            return self.continuation
        }
        continuation?.resume(returning: value)
    }

    func resume(throwing error: Error) {
        let continuation = lock.withLock { () -> CheckedContinuation<String, Error>? in
            defer { self.continuation = nil }
            return self.continuation
        }
        continuation?.resume(throwing: error)
    }
}

private enum SpeechLocaleMatcher {
    static func bestMatch(for locale: Locale, in candidates: [Locale]) -> Locale? {
        let ordered = candidates.sorted { $0.identifier(.bcp47) < $1.identifier(.bcp47) }
        if let exact = ordered.first(where: { $0.identifier(.bcp47) == locale.identifier(.bcp47) }) {
            return exact
        }
        guard let language = locale.language.languageCode?.identifier else { return nil }
        if let region = locale.language.region?.identifier,
           let regional = ordered.first(where: {
               $0.language.languageCode?.identifier == language
                   && $0.language.region?.identifier == region
           }) {
            return regional
        }
        return ordered.first { $0.language.languageCode?.identifier == language }
    }
}

@available(macOS 26.0, *)
private final class BufferConverter {
    enum ConversionError: Error {
        case failedToCreateConverter
        case failedToCreateBuffer
        case conversionFailed(NSError?)
    }

    private var converter: AVAudioConverter?

    func convert(_ buffer: AVAudioPCMBuffer, to format: AVAudioFormat) throws -> AVAudioPCMBuffer {
        guard buffer.format != format else { return buffer }
        if converter == nil || converter?.outputFormat != format {
            converter = AVAudioConverter(from: buffer.format, to: format)
            converter?.primeMethod = .none
        }
        guard let converter else { throw ConversionError.failedToCreateConverter }
        let ratio = converter.outputFormat.sampleRate / converter.inputFormat.sampleRate
        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up))
        guard let output = AVAudioPCMBuffer(pcmFormat: converter.outputFormat, frameCapacity: capacity) else {
            throw ConversionError.failedToCreateBuffer
        }
        var error: NSError?
        let consumed = OSAllocatedUnfairLock(initialState: false)
        let status = converter.convert(to: output, error: &error) { _, status in
            let used = consumed.withLock { flag -> Bool in
                let old = flag
                flag = true
                return old
            }
            status.pointee = used ? .noDataNow : .haveData
            return used ? nil : buffer
        }
        guard status != .error else { throw ConversionError.conversionFailed(error) }
        return output
    }
}

private func transcriptionFailure(_ message: String, recovery: String) -> GuideFailure {
    GuideFailure(stage: .transcription, message: message, recovery: recovery)
}
