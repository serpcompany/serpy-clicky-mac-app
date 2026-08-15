import Foundation
import GuideCore

#if canImport(FoundationModels)
import FoundationModels
#endif

public enum LocalGuidanceAvailability: Equatable, Sendable {
    case available
    case unavailable(String)
}

@MainActor
public final class LocalGuidanceService {
    public init() {}

    public var availability: LocalGuidanceAvailability {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            if case .available = SystemLanguageModel.default.availability {
                return .available
            }
            return .unavailable("Apple Intelligence's on-device model is not ready on this Mac.")
        }
        #endif
        return .unavailable("Local screen guidance requires macOS 26 or later.")
    }

    public func answer(question: String, context: ScreenContext) async throws -> GuidancePlan {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            guard case .available = SystemLanguageModel.default.availability else {
                throw unavailableFailure
            }
            let session = LanguageModelSession(instructions: """
                You are a concise macOS guide. Answer only from the supplied visible text. Give one safe next step. Never claim to click, type, submit, or control the computer. If evidence is insufficient, say what is missing. Keep the response under 55 words.
                """)
            let prompt = """
                User question: \(question)
                App: \(context.applicationName)
                Window: \(context.windowTitle)
                Visible text:
                \(context.promptText)
                """
            let response = try await session.respond(to: prompt)
            return GuidancePlan(answer: response.content, confidence: 0.70)
        }
        #endif
        throw unavailableFailure
    }

    private var unavailableFailure: GuideFailure {
        GuideFailure(
            stage: .guidance,
            message: "On-device screen guidance is unavailable.",
            recovery: "Dictation still works. Enable Apple Intelligence and wait for its local model to finish downloading, then try again."
        )
    }
}
