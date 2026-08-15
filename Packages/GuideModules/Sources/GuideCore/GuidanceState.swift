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
        textBlocks
            .filter { $0.confidence >= 0.45 }
            .prefix(120)
            .map(\.text)
            .joined(separator: "\n")
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
