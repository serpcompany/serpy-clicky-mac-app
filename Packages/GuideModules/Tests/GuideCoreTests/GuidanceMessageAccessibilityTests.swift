import GuideCore
import Testing
@testable import GuideUI

@Suite("Guide message accessibility")
struct GuidanceMessageAccessibilityTests {
    @Test("guide content is the observable label and role remains descriptive metadata")
    func exposesGuideContent() {
        let accessibility = GuidanceMessageAccessibility(
            message: GuidanceMessage(role: .guide, content: "Choose New Window.")
        )

        #expect(accessibility.identifier == "guide.message.guide")
        #expect(accessibility.label == "Choose New Window.")
        #expect(accessibility.speaker == "serpy")
    }

    @Test("ambient failures expose recovery text without discarding a readable answer")
    func exposesAmbientFailureRecovery() {
        let failure = GuideFailure(
            stage: .guidance,
            message: "Malformed guidance.",
            recovery: "Try the question again."
        )
        let turn = GuideTurnPresentation(
            stage: .error,
            statusText: failure.message,
            responseText: "Last readable step.",
            failure: failure
        )

        #expect(GuideAmbientResponseText.resolve(turn) == "Last readable step.\n\nTry the question again.")
    }
}
