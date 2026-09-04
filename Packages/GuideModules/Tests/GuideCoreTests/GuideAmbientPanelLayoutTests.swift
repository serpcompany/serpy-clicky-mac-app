import CoreGraphics
import GuideCore
import Testing
@testable import GuideUI

@Suite("Ambient Guide panel layout")
struct GuideAmbientPanelLayoutTests {
    @Test("expanded ambient response exposes the visible instruction to accessibility")
    func ambientResponseAccessibility() {
        let accessibility = CompanionAmbientAccessibility(
            stage: .readyForFollowUp,
            caption: "Step 2 of 2",
            contextLabel: "Fixture Browser — Fixture Window",
            responseText: "Choose New Window."
        )

        #expect(accessibility.label.contains("Step 2 of 2"))
        #expect(accessibility.value == "Choose New Window.")
        #expect(CompanionAmbientAccessibility(
            stage: .liveTranscript,
            caption: "Open a new window",
            contextLabel: "Fixture Browser — Fixture Window",
            responseText: ""
        ).value == "Fixture Browser — Fixture Window")
        #expect(CompanionAmbientAccessibility(
            stage: .cancelled,
            caption: "Cancelled",
            contextLabel: "Fixture Browser — Fixture Window",
            responseText: ""
        ).value.isEmpty)
    }

    @Test("missing display metadata falls back to the target frame instead of abandoning panel layout")
    func targetWithoutDisplayIdentifierStillSelectsAVisibleDisplay() {
        let displays = [
            GuideDisplayFrame(identifier: 10, frame: CGRect(x: -1440, y: 0, width: 1440, height: 900)),
            GuideDisplayFrame(identifier: 20, frame: CGRect(x: 0, y: 0, width: 1728, height: 1117)),
        ]
        let policy = GuideTargetDisplaySelectionPolicy()

        #expect(policy.index(
            targetDisplayIdentifier: nil,
            targetFrame: CGRect(x: 200, y: 200, width: 900, height: 700),
            displays: displays
        ) == 1)
        #expect(policy.index(
            targetDisplayIdentifier: 10,
            targetFrame: CGRect(x: 200, y: 200, width: 900, height: 700),
            displays: displays
        ) == 0)
    }

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

@Suite("Transient companion surface visibility")
struct TransientCompanionSurfaceVisibilityTests {
    @Test("idle never shows the rejected persistent cursor badge")
    func idleBadgeIsRemoved() {
        let policy = TransientCompanionSurfaceVisibilityPolicy()

        #expect(!policy.isVisible(guidePhase: .idle, hasTransientCaption: false))
        #expect(policy.isVisible(guidePhase: .listening, hasTransientCaption: false))
        #expect(policy.isVisible(guidePhase: .idle, hasTransientCaption: true))
    }
}

@Suite("Guide surface interaction")
struct GuideSurfaceInteractionTests {
    @Test("every Guide-owned overlay stays click-through")
    func overlaysDoNotBlockTheWorkSurface() {
        let policy = GuideSurfaceInteractionPolicy()

        #expect(policy.mode == .clickThrough)
    }
}
