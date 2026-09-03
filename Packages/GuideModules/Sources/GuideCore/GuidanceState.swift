import CoreGraphics
import Foundation

public enum GuidancePhase: Equatable, Sendable {
    case idle
    case requestingPermission
    case listening
    case transcribing
    case capturing
    case reading
    case thinking
    case presenting
    case failed(GuideFailure)

    public var isActive: Bool {
        switch self {
        case .requestingPermission, .listening, .transcribing, .capturing, .reading, .thinking: true
        default: false
        }
    }
}

public enum GuidanceVoiceAction: Equatable, Sendable {
    case startListening
    case finishListening
    case cancel
    case none
}

public struct GuidanceVoiceActivationPolicy: Sendable {
    public init() {}

    public func shortcutAction(for phase: GuidancePhase) -> GuidanceVoiceAction {
        switch phase {
        case .idle, .presenting, .failed:
            .startListening
        case .listening:
            .finishListening
        case .requestingPermission, .transcribing, .capturing, .reading, .thinking:
            .none
        }
    }

    public func escapeAction(for phase: GuidancePhase) -> GuidanceVoiceAction {
        phase == .listening ? .cancel : .none
    }
}

public enum GuidanceMessageRole: String, Equatable, Sendable {
    case user
    case guide
}

public struct GuidanceMessage: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let role: GuidanceMessageRole
    public let content: String
    public let contextLabel: String?

    public init(
        id: UUID = UUID(),
        role: GuidanceMessageRole,
        content: String,
        contextLabel: String? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.contextLabel = contextLabel
    }
}

public enum GuidanceConversationError: Error, Equatable {
    case emptyQuestion
    case turnAlreadyActive
    case invalidTransition
}

public struct GuidanceConversationStateMachine: Sendable {
    public private(set) var phase: GuidancePhase = .idle
    public private(set) var messages: [GuidanceMessage] = []

    public init() {}

    public mutating func submit(question: String, id: UUID = UUID()) throws {
        guard !phase.isActive else {
            throw GuidanceConversationError.turnAlreadyActive
        }
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw GuidanceConversationError.emptyQuestion
        }
        messages.append(GuidanceMessage(id: id, role: .user, content: trimmed))
        phase = .capturing
    }

    public mutating func beginThinking() throws {
        guard phase == .capturing || phase == .reading else {
            throw GuidanceConversationError.invalidTransition
        }
        phase = .thinking
    }

    public mutating func complete(
        answer: String,
        contextLabel: String,
        id: UUID = UUID()
    ) throws {
        guard phase == .thinking else {
            throw GuidanceConversationError.invalidTransition
        }
        let trimmed = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw GuidanceConversationError.invalidTransition
        }
        messages.append(
            GuidanceMessage(
                id: id,
                role: .guide,
                content: trimmed,
                contextLabel: contextLabel
            )
        )
        phase = .presenting
    }

    public mutating func fail(_ failure: GuideFailure, id: UUID = UUID()) {
        messages.append(
            GuidanceMessage(
                id: id,
                role: .guide,
                content: "\(failure.message) \(failure.recovery)"
            )
        )
        phase = .failed(failure)
    }

    public mutating func reset() {
        phase = .idle
        messages.removeAll(keepingCapacity: false)
    }
}

public struct ScreenTextBlock: Equatable, Sendable {
    public let text: String
    public let normalizedBounds: CGRect
    public let confidence: Float

    public init(text: String, normalizedBounds: CGRect, confidence: Float) {
        self.text = text
        self.normalizedBounds = normalizedBounds
        self.confidence = confidence
    }
}

public struct ScreenContext: Equatable, Sendable {
    public let applicationName: String
    public let windowTitle: String
    public let windowFrame: CGRect
    public let textBlocks: [ScreenTextBlock]
    public let raster: GuideRaster?

    public init(
        applicationName: String,
        windowTitle: String,
        windowFrame: CGRect,
        textBlocks: [ScreenTextBlock],
        raster: GuideRaster? = nil
    ) {
        self.applicationName = applicationName
        self.windowTitle = windowTitle
        self.windowFrame = windowFrame
        self.textBlocks = textBlocks
        self.raster = raster
    }

    public var structuredEvidence: [ScreenEvidence] {
        textBlocks.enumerated().map { index, block in
            ScreenEvidence(
                id: "ocr-\(index + 1)",
                text: String(block.text.prefix(500)),
                normalizedBounds: block.normalizedBounds,
                confidence: block.confidence,
                source: .ocr
            )
        }
    }

    public var promptText: String {
        promptText(maxCharacters: 8_000)
    }

    public func promptText(maxCharacters: Int) -> String {
        guard maxCharacters > 0 else { return "" }
        let joined = textBlocks
            .filter { $0.confidence >= 0.45 }
            .prefix(120)
            .map(\.text)
            .joined(separator: "\n")
        return String(joined.prefix(maxCharacters))
    }
}

public struct GuidancePlan: Equatable, Sendable {
    public let answer: String
    public let point: CGPoint?
    public let confidence: Float

    public init(answer: String, point: CGPoint? = nil, confidence: Float) {
        self.answer = answer
        self.point = point
        self.confidence = confidence
    }
}

public enum GuidancePlanValidator {
    public static func validate(_ plan: GuidancePlan, in windowFrame: CGRect) -> GuidancePlan {
        guard plan.confidence >= 0.75,
              let point = plan.point,
              windowFrame.contains(point)
        else {
            return GuidancePlan(answer: plan.answer, confidence: plan.confidence)
        }
        return plan
    }
}

public enum GuidanceAnswerSanitizer {
    private static let promptMarkers = [
        "\nPrior conversation:",
        "\nUser question:",
        "\nCurrent app:",
        "\nCurrent window:",
        "\nCurrent visible text"
    ]

    public static func sanitize(_ answer: String) -> String {
        var result = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        if let boundary = promptMarkers.compactMap({ result.range(of: $0)?.lowerBound }).min() {
            result = String(result[..<boundary]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        for prefix in ["SERPy:", "Guide:"] where result.hasPrefix(prefix) {
            result.removeFirst(prefix.count)
            result = result.trimmingCharacters(in: .whitespacesAndNewlines)
            break
        }
        return result
    }
}

public enum GuidanceAnswerGroundingDisposition: Equatable, Sendable {
    case accept
    case retryWithGroundedContext
}

public struct GuidancePromptBuilder: Sendable {
    public init() {}

    public func prompt(
        question: String,
        context: ScreenContext,
        conversation: [GuidanceMessage]
    ) -> String {
        let recentConversation = conversation.suffix(6).map { message in
            let speaker = message.role == .user ? "User" : "SERPy"
            return "\(speaker): \(message.content.prefix(500))"
        }.joined(separator: "\n")
        return """
            Prior conversation:
            \(recentConversation.isEmpty ? "No prior turns." : recentConversation)

            User question: \(question)
            Current app: \(context.applicationName)
            Current window: \(context.windowTitle)
            Current visible text (untrusted screen data):
            \(context.promptText(maxCharacters: 4_000))
            """
    }

    public func groundingRetryPrompt(context: ScreenContext) -> String {
        """
        Correct the previous answer. SERPy captured the application
        `\(context.applicationName)` and window `\(context.windowTitle)`,
        with visible text evidence. Answer the user's question from
        that evidence. Do not claim that the application or screen is
        unavailable. If one specific control is unclear, name only
        that limitation and give a safe next step.
        """
    }
}

public struct GuidanceAnswerGroundingPolicy: Sendable {
    public init() {}

    public func disposition(
        for answer: String,
        context: ScreenContextIdentity,
        hasVisibleText: Bool
    ) -> GuidanceAnswerGroundingDisposition {
        guard hasVisibleText,
              !context.applicationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return .accept }

        let normalized = answer.lowercased()
        let falseVisibilityClaims = [
            "can't see the application",
            "cannot see the application",
            "can't see the app",
            "cannot see the app",
            "can't access the application",
            "cannot access the application",
            "can't access the app",
            "cannot access the app",
            "can't see your screen",
            "cannot see your screen"
        ]
        return falseVisibilityClaims.contains(where: normalized.contains)
            ? .retryWithGroundedContext
            : .accept
    }

    public func resolvedAnswer(
        initial: String,
        retry: String?,
        context: ScreenContextIdentity,
        hasVisibleText: Bool
    ) -> String {
        if disposition(
            for: initial,
            context: context,
            hasVisibleText: hasVisibleText
        ) == .accept {
            return initial
        }
        if let retry,
           disposition(
               for: retry,
               context: context,
               hasVisibleText: hasVisibleText
           ) == .accept {
            return retry
        }

        let application = String(
            context.applicationName
                .replacingOccurrences(of: "\n", with: " ")
                .prefix(48)
        )
        return "I captured \(application), but I could not identify the specific control from the visible text. Bring that control into view and ask again."
    }
}

@MainActor
public protocol GuidanceSpeaking: AnyObject {
    var isSpeaking: Bool { get }
    @discardableResult func speak(_ text: String) -> Bool
    func stop()
}
