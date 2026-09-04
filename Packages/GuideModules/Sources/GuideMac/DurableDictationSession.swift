@preconcurrency import AVFoundation
import Foundation
import GuideCore
import os
import Speech

/// Production Dictation session. macOS 26 uses Yap's streaming
/// SpeechAnalyzer/SpeechTranscriber design; older supported systems retain the
/// existing on-device SFSpeechRecognizer adapter.
@MainActor
public final class DurableDictationSession: DictationSessioning {
    public var onPartial: (@MainActor @Sendable (String) -> Void)? {
        didSet { backend.onPartial = onPartial }
    }

    private let backend: any DictationSessionBackend

    public init() {
        if #available(macOS 26.0, *) {
            backend = SpeechAnalyzerDictationBackend()
        } else {
            backend = LegacyAppleSpeechBackend()
        }
    }

    public var isOnDeviceAvailable: Bool { backend.isOnDeviceAvailable }
    public var availabilityDescription: String { backend.availabilityDescription }

    public func start(saveAudio: Bool) async throws {
        backend.onPartial = onPartial
        try await backend.start(saveAudio: saveAudio)
    }

    public func stop() async throws -> SpeechTranscriptionResult {
        try await backend.stop()
    }

    public func cancel() {
        backend.cancel()
    }

    public func recoverInterruptedAudio() async throws -> SpeechTranscriptionResult? {
        try await backend.recoverInterruptedAudio()
    }
}

@MainActor
private protocol DictationSessionBackend: AnyObject {
    var onPartial: (@MainActor @Sendable (String) -> Void)? { get set }
    var isOnDeviceAvailable: Bool { get }
    var availabilityDescription: String { get }
    func start(saveAudio: Bool) async throws
    func stop() async throws -> SpeechTranscriptionResult
    func cancel()
    func recoverInterruptedAudio() async throws -> SpeechTranscriptionResult?
}

@MainActor
private final class LegacyAppleSpeechBackend: DictationSessionBackend {
    var onPartial: (@MainActor @Sendable (String) -> Void)?
    private let transcriber = AppleSpeechTranscriber()

    var isOnDeviceAvailable: Bool { transcriber.isOnDeviceAvailable }
    var availabilityDescription: String { transcriber.availabilityDescription }

    func start(saveAudio: Bool) async throws {
        try transcriber.start(saveAudio: saveAudio) { [weak self] text in
            self?.onPartial?(text)
        }
    }

    func stop() async throws -> SpeechTranscriptionResult {
        try await transcriber.stop()
    }

    func cancel() { transcriber.cancel() }
    func recoverInterruptedAudio() async throws -> SpeechTranscriptionResult? { nil }
}

@available(macOS 26.0, *)
@MainActor
private final class SpeechAnalyzerDictationBackend: DictationSessionBackend {
    var onPartial: (@MainActor @Sendable (String) -> Void)?
    private let capture = YapAudioCaptureService()
    private let relay = YapAudioBufferRelay()
    private var transcriber: (any StreamingTranscriber)?
    private var checkpoint: RecoverableAudioCheckpointWriter?
    private let stopTail = DictationStopTail()
    private let locale: Locale

    init(locale: Locale = .current) {
        self.locale = locale
    }

    var isOnDeviceAvailable: Bool { true }
    var availabilityDescription: String { "Apple on-device streaming speech is ready." }

    func start(saveAudio: Bool) async throws {
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

        relay.reset()
        let checkpoint = try RecoverableAudioCheckpointWriter()
        self.checkpoint = checkpoint
        capture.onBuffer = { [weak self] buffer in
            self?.checkpoint?.append(buffer)
            self?.relay.receive(buffer)
        }

        // Yap opens the microphone before preparing SpeechAnalyzer. Buffers
        // captured during model/format setup wait in the bounded relay.
        try capture.start()

        let engine = SpeechAnalyzerStreamingTranscriber()
        engine.onPartial = { [weak self] text in
            Task { @MainActor in self?.onPartial?(text) }
        }
        transcriber = engine

        do {
            try await engine.begin(locale: locale)
        } catch {
            capture.stop()
            relay.reset()
            checkpoint.cancel()
            self.checkpoint = nil
            transcriber = nil
            throw error
        }
        relay.attach { buffer in engine.feed(buffer) }
    }

    func stop() async throws -> SpeechTranscriptionResult {
        try await stopTail.wait()

        capture.stop()
        relay.reset()
        let audioURL = try checkpoint?.finish()
        let text = try await transcriber?.finish() ?? ""
        checkpoint = nil
        transcriber = nil
        return SpeechTranscriptionResult(transcript: text, temporaryAudioURL: audioURL)
    }

    func cancel() {
        stopTail.cancel()
        capture.stop()
        relay.reset()
        transcriber?.cancel()
        transcriber = nil
        checkpoint?.cancel()
        checkpoint = nil
    }

    func recoverInterruptedAudio() async throws -> SpeechTranscriptionResult? {
        guard let url = RecoverableAudioCheckpointWriter.recoverableAudioURLs(
            in: RecoverableAudioCheckpointWriter.defaultRecoveryDirectory()
        ).first else { return nil }

        let engine = SpeechAnalyzerStreamingTranscriber()
        engine.onPartial = { [weak self] text in
            Task { @MainActor in self?.onPartial?(text) }
        }
        try await engine.begin(locale: locale)
        do {
            let file = try AVAudioFile(forReading: url)
            let capacity: AVAudioFrameCount = 2_048
            while file.framePosition < file.length {
                guard let buffer = AVAudioPCMBuffer(
                    pcmFormat: file.processingFormat,
                    frameCapacity: capacity
                ) else { break }
                try file.read(into: buffer, frameCount: capacity)
                if buffer.frameLength == 0 { break }
                engine.feed(buffer)
            }
            let text = try await engine.finish()
            return .init(transcript: text, temporaryAudioURL: url)
        } catch {
            engine.cancel()
            throw error
        }
    }
}

@available(macOS 26.0, *)
private protocol StreamingTranscriber: AnyObject, Sendable {
    var onPartial: ((String) -> Void)? { get set }
    func begin(locale: Locale) async throws
    func feed(_ buffer: AVAudioPCMBuffer)
    func finish() async throws -> String
    func cancel()
}

/// Yap's finalized-plus-volatile SpeechAnalyzer implementation, adapted to use
/// GuideCore's independently tested accumulator and installed models only.
@available(macOS 26.0, *)
private final class SpeechAnalyzerStreamingTranscriber: StreamingTranscriber, @unchecked Sendable {
    var onPartial: ((String) -> Void)?
    private var transcriber: SpeechTranscriber?
    private var analyzer: SpeechAnalyzer?
    private var inputBuilder: AsyncStream<AnalyzerInput>.Continuation?
    private var recognizerTask: Task<Void, Never>?
    private let converter = YapBufferConverter()
    private var analyzerFormat: AVAudioFormat?
    private var transcript = StreamingTranscriptAccumulator()

    func begin(locale: Locale) async throws {
        transcript.reset()
        let installed = await SpeechTranscriber.installedLocales
        guard let resolved = Self.bestMatch(for: locale, in: installed) else {
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
            throw GuideFailure(
                stage: .transcription,
                message: "Apple Speech could not choose an audio format.",
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
            } catch {
                // finish/cancel owns the terminal result and failure surface.
            }
        }
        try await analyzer.start(inputSequence: stream)
    }

    func feed(_ buffer: AVAudioPCMBuffer) {
        guard let analyzerFormat, let inputBuilder else { return }
        do {
            inputBuilder.yield(AnalyzerInput(buffer: try converter.convert(buffer, to: analyzerFormat)))
        } catch {
            inputBuilder.finish()
        }
    }

    func finish() async throws -> String {
        inputBuilder?.finish()
        try await analyzer?.finalizeAndFinishThroughEndOfInput()
        await recognizerTask?.value
        let result = transcript.completeText
        reset()
        guard !result.isEmpty else {
            throw GuideFailure(
                stage: .transcription,
                message: "No speech was detected.",
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
    }

    private static func bestMatch(for locale: Locale, in candidates: [Locale]) -> Locale? {
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

/// Bounded early-buffer relay copied from Yap. Audio capture may begin before
/// SpeechAnalyzer setup without losing the opening words.
private final class YapAudioBufferRelay: @unchecked Sendable {
    private let lock = NSLock()
    private var pending: [AVAudioPCMBuffer] = []
    private var sink: ((AVAudioPCMBuffer) -> Void)?
    private let maximumPending = 250

    func receive(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        if let sink {
            lock.unlock()
            sink(buffer)
            return
        }
        if pending.count < maximumPending { pending.append(buffer) }
        lock.unlock()
    }

    func attach(_ sink: @escaping (AVAudioPCMBuffer) -> Void) {
        lock.lock()
        let buffered = pending
        pending.removeAll()
        self.sink = sink
        lock.unlock()
        for buffer in buffered { sink(buffer) }
    }

    func reset() {
        lock.lock()
        sink = nil
        pending.removeAll()
        lock.unlock()
    }
}

/// Fresh-engine capture adapted from Yap so a changed input device cannot leave
/// a stale format on a reused AVAudioEngine graph.
private final class YapAudioCaptureService: @unchecked Sendable {
    var onBuffer: ((AVAudioPCMBuffer) -> Void)?
    private var engine = AVAudioEngine()
    private var isRunning = false
    private var configObserver: NSObjectProtocol?
    private var handlingConfigChange = false

    func start() throws {
        try restart()
        isRunning = true
    }

    func stop() {
        removeObserver()
        guard isRunning else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRunning = false
    }

    private func restart() throws {
        removeObserver()
        engine.stop()
        engine = AVAudioEngine()
        let input = engine.inputNode
        input.removeTap(onBus: 0)
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw GuideFailure(
                stage: .recording,
                message: "The selected microphone has no usable audio format.",
                recovery: "Reconnect or choose another input device and try again."
            )
        }
        input.installTap(onBus: 0, bufferSize: 2_048, format: format) { [weak self] buffer, _ in
            self?.onBuffer?(buffer)
        }
        addObserver()
        engine.prepare()
        do {
            try engine.start()
        } catch {
            removeObserver()
            input.removeTap(onBus: 0)
            throw error
        }
    }

    private func addObserver() {
        configObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { [weak self] _ in self?.handleConfigurationChange() }
    }

    private func removeObserver() {
        guard let configObserver else { return }
        NotificationCenter.default.removeObserver(configObserver)
        self.configObserver = nil
    }

    private func handleConfigurationChange() {
        guard isRunning, !handlingConfigChange else { return }
        handlingConfigChange = true
        defer { handlingConfigChange = false }
        do {
            try restart()
        } catch {
            stop()
        }
    }
}

@available(macOS 26.0, *)
private final class YapBufferConverter {
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

/// Writes every received audio buffer to owner-only recovery storage. Each
/// successful append is a checkpoint, which is strictly stronger than the
/// required ten-second interval. The first write failure is retained and makes
/// completion fail before transcript insertion.
public protocol AudioCheckpointSink: AnyObject, Sendable {
    func append(_ buffer: AVAudioPCMBuffer) throws
    func finish() throws -> URL?
    func cancel()
}

public final class RecoverableAudioCheckpointWriter: @unchecked Sendable {
    private let lock = NSLock()
    private let sink: any AudioCheckpointSink
    private var failure: GuideFailure?

    public init(sink: any AudioCheckpointSink) {
        self.sink = sink
    }

    convenience init(fileManager: FileManager = .default) throws {
        try self.init(directoryURL: Self.defaultRecoveryDirectory(fileManager: fileManager))
    }

    public convenience init(directoryURL: URL) throws {
        try self.init(sink: AudioFileCheckpointSink(directoryURL: directoryURL))
    }

    public static func defaultRecoveryDirectory(fileManager: FileManager = .default) -> URL {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "SERPy/RecoveryAudio", directoryHint: .isDirectory)
    }

    public static func recoverableAudioURLs(
        in directoryURL: URL,
        fileManager: FileManager = .default
    ) -> [URL] {
        ((try? fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? [])
            .filter { $0.lastPathComponent.hasPrefix("active-") && $0.pathExtension == "caf" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    public func append(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        defer { lock.unlock() }
        guard failure == nil else { return }
        do {
            try sink.append(buffer)
        } catch {
            failure = GuideFailure(
                stage: .storage,
                message: "Active Dictation audio could not be checkpointed.",
                recovery: "Dictation stopped before unsafe completion. Check available disk space and try again."
            )
        }
    }

    public func finish() throws -> URL? {
        lock.lock()
        defer { lock.unlock() }
        if let failure { throw failure }
        return try sink.finish()
    }

    public func cancel() {
        lock.lock()
        sink.cancel()
        lock.unlock()
    }
}

private final class AudioFileCheckpointSink: AudioCheckpointSink, @unchecked Sendable {
    private let url: URL
    private var file: AVAudioFile?

    init(directoryURL base: URL, fileManager: FileManager = .default) throws {
        try fileManager.createDirectory(
            at: base,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: base.path)
        url = base.appending(path: "active-\(UUID().uuidString).caf")
    }

    func append(_ buffer: AVAudioPCMBuffer) throws {
        if file == nil {
            file = try AVAudioFile(forWriting: url, settings: buffer.format.settings)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        }
        try file?.write(from: buffer)
    }

    func finish() throws -> URL? {
        file = nil
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func cancel() {
        file = nil
        try? FileManager.default.removeItem(at: url)
    }
}
