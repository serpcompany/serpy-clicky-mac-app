import GuideCore

@MainActor
public final class AppleSpeechGuideTurnTranscriber: GuideTurnTranscribing {
    private let transcriber: AppleSpeechTranscriber

    public init(transcriber: AppleSpeechTranscriber) {
        self.transcriber = transcriber
    }

    public func start(onPartial: @escaping @MainActor @Sendable (String) -> Void) throws {
        try transcriber.start(onPartial: onPartial)
    }

    public func stop() async throws -> String {
        try await transcriber.stop().transcript
    }

    public func cancel() {
        transcriber.cancel()
    }
}

extension LocalGuidanceService: GuideTurnGenerating {}

@MainActor
public final class LocalGuideTurnSpeaker: GuideTurnSpeaking {
    private let speaker: LocalSpeechOutputService

    public init(speaker: LocalSpeechOutputService) {
        self.speaker = speaker
    }

    public func speak(_ text: String) async throws {
        guard speaker.speak(text) else {
            throw GuideFailure(
                stage: .guidance,
                message: "The answer is ready, but spoken playback could not start.",
                recovery: "Read the visible answer, check sound output, and try again."
            )
        }
        while speaker.isSpeaking {
            try Task.checkCancellation()
            try await Task.sleep(for: .milliseconds(100))
        }
    }

    public func stop() {
        speaker.stop()
    }
}
