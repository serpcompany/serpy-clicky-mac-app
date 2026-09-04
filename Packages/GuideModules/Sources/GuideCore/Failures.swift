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

public enum GuideFailureCode: String, Codable, Equatable, Sendable {
    case unclassified = "guide.failure.unclassified"
    case guidancePlanMalformed = "guidance.plan.malformed"
}

public enum GuideFailureProvider: String, Codable, Equatable, Sendable {
    case none
    case local
    case openAI = "openai"
}

public struct GuideFailure: Error, Equatable, Sendable {
    public let stage: GuideFailureStage
    public let code: GuideFailureCode
    public let provider: GuideFailureProvider
    public let message: String
    public let recovery: String

    public init(
        stage: GuideFailureStage,
        code: GuideFailureCode = .unclassified,
        provider: GuideFailureProvider = .none,
        message: String,
        recovery: String
    ) {
        self.stage = stage
        self.code = code
        self.provider = provider
        self.message = message
        self.recovery = recovery
    }
}

public struct DiagnosticIncident: Codable, Equatable, Sendable {
    public let code: GuideFailureCode
    public let stage: GuideFailureStage
    public let provider: GuideFailureProvider

    public init(failure: GuideFailure) {
        code = failure.code
        stage = failure.stage
        provider = failure.provider
    }
}

public protocol DiagnosticIncidentReporting {
    func report(_ incident: DiagnosticIncident)
}

public struct NullDiagnosticIncidentReporter: DiagnosticIncidentReporting {
    public init() {}

    public func report(_ incident: DiagnosticIncident) {}
}

extension GuideFailure: LocalizedError {
    public var errorDescription: String? { message }
    public var recoverySuggestion: String? { recovery }
}
