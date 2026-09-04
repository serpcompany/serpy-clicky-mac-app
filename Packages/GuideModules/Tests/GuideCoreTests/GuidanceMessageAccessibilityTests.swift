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
}
