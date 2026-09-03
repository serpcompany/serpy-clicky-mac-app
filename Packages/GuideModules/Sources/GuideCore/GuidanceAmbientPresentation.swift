import Foundation

public struct GuidanceLiveTranscriptPreview: Sendable {
    public let maxCharacters: Int

    public init(maxCharacters: Int = 180) {
        self.maxCharacters = max(2, maxCharacters)
    }

    public func displayText(for transcript: String) -> String {
        let singleLine = transcript
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard singleLine.count > maxCharacters else { return singleLine }
        return "…" + singleLine.suffix(maxCharacters - 1)
    }
}

public struct ScreenContextIdentity: Equatable, Sendable {
    public let applicationName: String
    public let windowTitle: String

    public init(applicationName: String, windowTitle: String) {
        self.applicationName = applicationName
        self.windowTitle = windowTitle
    }

    public var compactLabel: String {
        let app = applicationName.replacingOccurrences(of: "\n", with: " ")
        let title = windowTitle.replacingOccurrences(of: "\n", with: " ")
        return String("\(app) — \(title)".prefix(72))
    }
}

public enum GuidanceAmbientStage: Equatable, Sendable {
    case ready
    case listening
    case liveTranscript
    case capturing
    case thinking
    case speaking
    case readyForFollowUp
    case error
    case cancelled
}

public struct GuidanceAmbientInput: Equatable, Sendable {
    public let phase: GuidancePhase
    public let partialTranscript: String
    public let context: ScreenContextIdentity?
    public let isSpeaking: Bool
    public let wasCancelled: Bool

    public init(
        phase: GuidancePhase,
        partialTranscript: String = "",
        context: ScreenContextIdentity? = nil,
        isSpeaking: Bool = false,
        wasCancelled: Bool = false
    ) {
        self.phase = phase
        self.partialTranscript = partialTranscript
        self.context = context
        self.isSpeaking = isSpeaking
        self.wasCancelled = wasCancelled
    }
}

public struct GuidanceAmbientPresentation: Equatable, Sendable {
    public let stage: GuidanceAmbientStage
    public let statusText: String
    public let contextLabel: String?

    public init(stage: GuidanceAmbientStage, statusText: String, contextLabel: String?) {
        self.stage = stage
        self.statusText = statusText
        self.contextLabel = contextLabel
    }
}

public struct GuidanceAmbientPresentationPolicy: Sendable {
    public init() {}

    public func presentation(for input: GuidanceAmbientInput) -> GuidanceAmbientPresentation {
        let stage: GuidanceAmbientStage
        let statusText: String

        switch input.phase {
        case .idle:
            stage = input.wasCancelled ? .cancelled : .ready
            statusText = input.wasCancelled ? "Cancelled" : "Ready"
        case .requestingPermission:
            stage = .capturing
            statusText = "Preparing screen access"
        case .listening where !input.partialTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty:
            stage = .liveTranscript
            statusText = input.partialTranscript
        case .listening:
            stage = .listening
            statusText = "Listening…"
        case .transcribing, .capturing, .reading:
            stage = .capturing
            statusText = "Reading this screen…"
        case .thinking:
            stage = .thinking
            statusText = "Thinking locally…"
        case .presenting where input.isSpeaking:
            stage = .speaking
            statusText = "Speaking…"
        case .presenting:
            stage = .readyForFollowUp
            statusText = "Ready for a follow-up"
        case let .failed(failure):
            stage = .error
            statusText = failure.message
        }

        return GuidanceAmbientPresentation(
            stage: stage,
            statusText: statusText,
            contextLabel: input.context?.compactLabel
        )
    }
}
