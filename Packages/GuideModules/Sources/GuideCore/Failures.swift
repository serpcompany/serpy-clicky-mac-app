import Foundation

public enum GuideFailureStage: String, CaseIterable, Codable, Equatable, Sendable {
    case permission
    case activation
    case recording
    case transcription
    case storage
    case insertion
    case capture
    case understanding
    case guidance
    case presentation
}

public struct GuideFailure: Error, Equatable, Sendable {
    public let stage: GuideFailureStage
    public let message: String
    public let recovery: String

    public init(stage: GuideFailureStage, message: String, recovery: String) {
        self.stage = stage
        self.message = message
        self.recovery = recovery
    }
}

extension GuideFailure: LocalizedError {
    public var errorDescription: String? { message }
    public var recoverySuggestion: String? { recovery }
}
