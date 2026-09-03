import CoreGraphics
import Foundation

public enum GuidancePhase: Equatable, Sendable {
    case idle
    case requestingPermission
    case capturing
    case reading
    case thinking
    case presenting
    case failed(GuideFailure)

    public var isActive: Bool {
        switch self {
        case .requestingPermission, .capturing, .reading, .thinking: true
        default: false
        }
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

    public init(applicationName: String, windowTitle: String, windowFrame: CGRect, textBlocks: [ScreenTextBlock]) {
        self.applicationName = applicationName
        self.windowTitle = windowTitle
        self.windowFrame = windowFrame
        self.textBlocks = textBlocks
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
