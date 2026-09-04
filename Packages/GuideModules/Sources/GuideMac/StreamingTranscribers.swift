@preconcurrency import AVFoundation
import Foundation
import GuideCore
import os
import Speech

public protocol StreamingTranscriber: AnyObject, Sendable {
    var onPartial: (@Sendable (String) -> Void)? { get set }
    func begin(locale: Locale) async throws
    func feed(_ buffer: AVAudioPCMBuffer)
    func finish(recoveryAudioURL: URL?) async throws -> String
    func cancel()
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

final class ChunkedSFSpeechTranscriber: StreamingTranscriber, @unchecked Sendable {
    var onPartial: (@Sendable (String) -> Void)?
    private let recognizer: any AudioChunkRecognizing
    private var cancelled = false
    private let maximumChunkDuration: TimeInterval
    private let temporaryDirectory: URL

    init(
        recognizer: any AudioChunkRecognizing = OnDeviceSFSpeechChunkRecognizer(),
        maximumChunkDuration: TimeInterval = 50,
        temporaryDirectory: URL = FileManager.default.temporaryDirectory
    ) {
        self.recognizer = recognizer
        self.maximumChunkDuration = maximumChunkDuration
        self.temporaryDirectory = temporaryDirectory
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
        var finalized: [String] = []
        do {
            for chunk in chunks.urls {
                try Task.checkCancellation()
                guard !cancelled else { throw CancellationError() }
                let text = try await recognizer.recognize(chunk)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    finalized.append(text)
                    onPartial?(finalized.joined(separator: " "))
                }
            }
            try chunks.cleanup()
        } catch {
            do { try chunks.cleanup() } catch let cleanupFailure { throw cleanupFailure }
            throw error
        }
        let text = finalized.joined(separator: " ")
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
        let source = try AVAudioFile(forReading: sourceURL)
        let framesPerChunk = AVAudioFramePosition(source.processingFormat.sampleRate * maximumChunkDuration)
        guard source.length > framesPerChunk else {
            return TemporaryAudioChunks(urls: [sourceURL], temporaryURLs: [])
        }

        var urls: [URL] = []
        while source.framePosition < source.length {
            let url = temporaryDirectory
                .appending(path: "serpy-speech-chunk-\(UUID().uuidString).caf")
            let file = try AVAudioFile(
                forWriting: url,
                settings: source.processingFormat.settings,
                commonFormat: source.processingFormat.commonFormat,
                interleaved: source.processingFormat.isInterleaved
            )
            var written: AVAudioFramePosition = 0
            while written < framesPerChunk, source.framePosition < source.length {
                let remainingInSource = source.length - source.framePosition
                let remainingInChunk = framesPerChunk - written
                let requested = AVAudioFrameCount(min(remainingInSource, remainingInChunk))
                guard let buffer = AVAudioPCMBuffer(
                    pcmFormat: source.processingFormat,
                    frameCapacity: requested
                ) else {
                    throw transcriptionFailure(
                        "A long recording could not be divided safely.",
                        recovery: "Retry from the retained raw audio checkpoint."
                    )
                }
                try source.read(into: buffer, frameCount: requested)
                guard buffer.frameLength > 0 else { break }
                try file.write(from: buffer)
                written += AVAudioFramePosition(buffer.frameLength)
            }
            guard written > 0 else {
                do { try FileManager.default.removeItem(at: url) } catch {
                    throw GuideFailure(
                        stage: .storage,
                        message: "An empty temporary Dictation chunk could not be deleted.",
                        recovery: "Remove the temporary file and retry recovery."
                    )
                }
                break
            }
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
            urls.append(url)
        }
        return TemporaryAudioChunks(urls: urls, temporaryURLs: urls)
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

    func cleanup() throws {
        for url in temporaryURLs where FileManager.default.fileExists(atPath: url.path) {
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                throw GuideFailure(
                    stage: .storage,
                    message: "A temporary Dictation chunk could not be deleted.",
                    recovery: "Remove the temporary file after closing other processes, then try again."
                )
            }
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
