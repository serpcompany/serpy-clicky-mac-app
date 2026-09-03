import AVFoundation
import GuideCore

@MainActor
public final class LocalSpeechOutputService: GuidanceSpeaking {
    private let synthesizer = AVSpeechSynthesizer()

    public init() {}

    public var isSpeaking: Bool {
        synthesizer.isSpeaking
    }

    @discardableResult
    public func speak(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        stop()
        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.volume = 0.85
        synthesizer.speak(utterance)
        return true
    }

    public func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }
}
