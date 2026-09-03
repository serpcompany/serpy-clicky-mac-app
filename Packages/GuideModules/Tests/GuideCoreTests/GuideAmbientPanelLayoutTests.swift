import CoreGraphics
import GuideCore
import Testing

@Suite("Ambient Guide panel layout")
struct GuideAmbientPanelLayoutTests {
    @Test("Guide stays centered below menu controls instead of following the pointer")
    func centeredBelowMenuControls() {
        let policy = GuideAmbientPanelLayoutPolicy()
        let visibleFrame = CGRect(x: -1440, y: 24, width: 1440, height: 876)

        let first = policy.frame(
            visibleFrame: visibleFrame,
            contentSize: CGSize(width: 520, height: 180)
        )
        let pointerMoved = policy.frame(
            visibleFrame: visibleFrame,
            contentSize: CGSize(width: 520, height: 180)
        )

        #expect(first == CGRect(x: -980, y: 712, width: 520, height: 180))
        #expect(pointerMoved == first)
        #expect(visibleFrame.insetBy(dx: 8, dy: 8).contains(first))
    }
}
