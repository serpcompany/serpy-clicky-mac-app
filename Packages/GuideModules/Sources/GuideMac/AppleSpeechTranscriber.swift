import AVFoundation
import Foundation
import GuideCore
import Speech

private final class SpeechAudioSink: @unchecked Sendable {
    private let request: SFSpeechAudioBufferRecognitionRequest
    private let recordingFile: AVAudioFile?

    init(request: SFSpeechAudioBufferRecognitionRequest, recordingFile: AVAudioFile?) {
        self.request = request
        self.recordingFile = recordingFile
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        request.append(buffer)
        try? recordingFile?.write(from: buffer)
    }
}

private struct SpeechResultPacket: @unchecked Sendable {
    let result: SFSpeechRecognitionResult?
    let error: Error?
}

private func installSpeechInputTap(
    on inputNode: AVAudioInputNode,
    format: AVAudioFormat,
    sink: SpeechAudioSink
) {
    inputNode.installTap(onBus: 0, bufferSize: 1_024, format: format) { buffer, _ in
        sink.append(buffer)
    }
}

private func beginSpeechRecognition(
    recognizer: SFSpeechRecognizer,
    request: SFSpeechAudioBufferRecognitionRequest,
    deliver: @escaping @Sendable (SpeechResultPacket) -> Void
) -> SFSpeechRecognitionTask {
    recognizer.recognitionTask(with: request) { result, error in
        deliver(SpeechResultPacket(result: result, error: error))
    }
}

@MainActor
public final class AppleSpeechTranscriber {
    public typealias PartialHandler = @MainActor @Sendable (String) -> Void

    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var completion: CheckedContinuation<SpeechTranscriptionResult, Error>?
    private var latestTranscript = ""
    private var partialHandler: PartialHandler?
    private var stopTimeoutTask: Task<Void, Never>?
    private var inputTapInstalled = false
    private var completionGate = SpeechCompletionGate()
    private var temporaryAudioURL: URL?

    public init() {}

    public var availabilityDescription: String {
        guard let recognizer = makeRecognizer() else {
            return "No speech recognizer is available for this language."
        }
        if recognizer.supportsOnDeviceRecognition {
            return "Apple on-device speech is ready."
        }
        return "Apple does not provide on-device speech for the current language."
    }

    public var isOnDeviceAvailable: Bool {
        makeRecognizer()?.supportsOnDeviceRecognition == true
    }

    public func start(saveAudio: Bool = false, onPartial: @escaping PartialHandler) throws {
        guard recognitionTask == nil else {
            throw speechFailure("A recording is already active.", recovery: "Stop or cancel it first.")
        }
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            throw speechFailure("Speech Recognition permission is not granted.", recovery: "Enable Speech Recognition in System Settings.")
        }
        guard AVCaptureDevice.authorizationStatus(for: .audio) == .authorized else {
            throw speechFailure("Microphone permission is not granted.", recovery: "Enable Microphone access in System Settings.")
        }
        guard let recognizer = makeRecognizer(), recognizer.supportsOnDeviceRecognition else {
            throw speechFailure(
                "On-device speech is unavailable for the current language.",
                recovery: "Choose a supported language or install the local speech model in a later build."
            )
        }

        latestTranscript = ""
        partialHandler = onPartial
        completionGate.reset()

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        request.addsPunctuation = true
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            cleanup()
            throw speechFailure("The selected microphone has no usable audio format.", recovery: "Choose another input device and try again.")
        }

        let recordingFile: AVAudioFile?
        if saveAudio {
            let url = FileManager.default.temporaryDirectory
                .appending(path: "GuideCompanion-\(UUID().uuidString).wav")
            do {
                recordingFile = try AVAudioFile(forWriting: url, settings: format.settings)
                temporaryAudioURL = url
            } catch {
                cleanup()
                throw speechFailure(
                    "The optional audio archive could not be prepared.",
                    recovery: "Turn off Save audio history or check available disk space."
                )
            }
        } else {
            recordingFile = nil
            temporaryAudioURL = nil
        }

        installSpeechInputTap(
            on: inputNode,
            format: format,
            sink: SpeechAudioSink(request: request, recordingFile: recordingFile)
        )
        inputTapInstalled = true

        let deliver = MainActorCallbackBridge.make { [weak self] (packet: SpeechResultPacket) in
            self?.handle(result: packet.result, error: packet.error)
        }
        recognitionTask = beginSpeechRecognition(
            recognizer: recognizer,
            request: request,
            deliver: deliver
        )

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            cleanup()
            throw speechFailure("The microphone could not start.", recovery: "Check the input device and try again.")
        }
    }

    public func stop() async throws -> SpeechTranscriptionResult {
        guard recognitionTask != nil, let recognitionRequest else {
            throw speechFailure("No recording is active.", recovery: "Start dictation and try again.")
        }

        return try await withCheckedThrowingContinuation { continuation in
            completion = continuation
            if completionGate.shouldFinishWhenStopped {
                finishSuccessfully()
                return
            }
            stopCapturingAudio()
            recognitionRequest.endAudio()
            stopTimeoutTask?.cancel()
            stopTimeoutTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { return }
                self?.finishAfterTimeout()
            }
        }
    }

    public func cancel() {
        completion?.resume(throwing: CancellationError())
        completion = nil
        cleanup(discardAudio: true)
    }

    private func handle(result: SFSpeechRecognitionResult?, error: Error?) {
        if let result {
            latestTranscript = result.bestTranscription.formattedString
            partialHandler?(latestTranscript)
            if result.isFinal {
                completionGate.receiveFinalResult()
                if completion != nil {
                    finishSuccessfully()
                } else {
                    stopCapturingAudio()
                    recognitionRequest?.endAudio()
                }
                return
            }
        }

        if error != nil, completion != nil {
            if latestTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                finish(
                    throwing: speechFailure(
                        "No speech could be transcribed.",
                        recovery: "Speak closer to the microphone and try again."
                    )
                )
            } else {
                finishSuccessfully()
            }
        }
    }

    private func finishAfterTimeout() {
        guard completion != nil else { return }
        if latestTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            finish(
                throwing: speechFailure(
                    "Dictation timed out without a final transcript.",
                    recovery: "Try a shorter phrase and verify the input device."
                )
            )
        } else {
            finishSuccessfully()
        }
    }

    private func finishSuccessfully() {
        let transcript = latestTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !transcript.isEmpty else {
            finish(
                throwing: speechFailure(
                    "No speech was detected.",
                    recovery: "Try again and speak while the recording indicator is visible."
                )
            )
            return
        }
        completion?.resume(returning: SpeechTranscriptionResult(
            transcript: transcript,
            temporaryAudioURL: temporaryAudioURL
        ))
        completion = nil
        cleanup(discardAudio: false)
    }

    private func finish(throwing error: Error) {
        completion?.resume(throwing: error)
        completion = nil
        cleanup(discardAudio: true)
    }

    private func cleanup(discardAudio: Bool = true) {
        stopTimeoutTask?.cancel()
        stopTimeoutTask = nil
        stopCapturingAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        partialHandler = nil
        completionGate.reset()
        if discardAudio, let temporaryAudioURL {
            try? FileManager.default.removeItem(at: temporaryAudioURL)
        }
        temporaryAudioURL = nil
    }

    private func stopCapturingAudio() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        if inputTapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            inputTapInstalled = false
        }
    }

    private func makeRecognizer() -> SFSpeechRecognizer? {
        let preferred = SFSpeechRecognizer(locale: .current)
        if preferred?.supportsOnDeviceRecognition == true {
            return preferred
        }
        return SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }

    private func speechFailure(_ message: String, recovery: String) -> GuideFailure {
        GuideFailure(stage: .transcription, message: message, recovery: recovery)
    }
}

struct SpeechCompletionGate: Equatable, Sendable {
    private(set) var didReceiveFinalResult = false

    var shouldFinishWhenStopped: Bool { didReceiveFinalResult }

    mutating func receiveFinalResult() {
        didReceiveFinalResult = true
    }

    mutating func reset() {
        didReceiveFinalResult = false
    }
}
