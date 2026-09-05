import Foundation
import GuideCore
@testable import GuideMac
import Testing

@MainActor
struct LocalGuidancePointingTests {
    @Test("Local Guide resolves a supplied evidence ID to the captured text bounds")
    func groundedPoint() async throws {
        let provider = PointingProvider()
        let context = ScreenContext(
            applicationName: "Fixture", windowTitle: "Document", windowFrame: .zero,
            textBlocks: [.init(text: "Preferences", normalizedBounds: CGRect(x: 0.2, y: 0.6, width: 0.2, height: 0.1), confidence: 0.98)]
        )
        let plan = try await LocalGuidanceService(provider: provider).answer(question: "Show Preferences", context: context)
        #expect(provider.prompt.contains("ocr-1"))
        let point = try #require(plan.steps.first?.point)
        #expect(abs(point.normalizedPoint.x - 0.3) < 0.0001)
        // Vision bounds are bottom-left based; overlay points are top-left based.
        #expect(abs(point.normalizedPoint.y - 0.35) < 0.0001)
        #expect(point.label == "Preferences")
        #expect(plan.steps[1].point == nil)
    }

    @Test("Unknown, low-confidence, and invalid captured bounds never produce a local point")
    func rejectsUnsafePoint() async throws {
        for block in [
            ScreenTextBlock(text: "Preferences", normalizedBounds: CGRect(x: 0.2, y: 0.6, width: 0.2, height: 0.1), confidence: 0.3),
            ScreenTextBlock(text: "Preferences", normalizedBounds: CGRect(x: -0.2, y: 0.6, width: 0.2, height: 0.1), confidence: 0.99),
            ScreenTextBlock(text: "Preferences", normalizedBounds: .zero, confidence: 0.99)
        ] {
            let plan = try await LocalGuidanceService(provider: PointingProvider()).answer(
                question: "Show Preferences",
                context: ScreenContext(applicationName: "Fixture", windowTitle: "Document", windowFrame: .zero, textBlocks: [block])
            )
            #expect(plan.steps.allSatisfy { $0.point == nil })
        }
    }
}

@MainActor
private final class PointingProvider: LocalGuidanceModelProvider, LocalGuidanceModelSession {
    var availability: LocalGuidanceAvailability { .available }
    var prompt = ""
    func makeSession(instructions: String) throws -> any LocalGuidanceModelSession { self }
    func respond(to prompt: String) async throws -> String {
        self.prompt = prompt
        return #"{"answer":"Open Preferences.","steps":[{"text":"Click Preferences.","targetEvidenceID":"ocr-1","completionEvidence":["General"]},{"text":"Choose General.","targetEvidenceID":"ocr-999","completionEvidence":["Appearance"]}]}"#
    }
}
