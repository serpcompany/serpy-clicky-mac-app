import CoreGraphics
import GuideCore
@testable import GuideMac
import XCTest

final class GuidePointCueProjectorTests: XCTestCase {
    func testProjectsTopLeftNormalizedPointAcrossNegativeOriginDisplay() throws {
        let target = GuideWindowTarget(
            processIdentifier: 5,
            windowIdentifier: 9,
            applicationName: "Fixture",
            windowTitle: "Negative display",
            frame: CGRect(x: -1800, y: 100, width: 800, height: 600)
        )
        let cue = GuidePointCue(
            target: target,
            normalizedPoint: CGPoint(x: 0.25, y: 0.75),
            label: "Continue"
        )
        let displays = [GuideDisplayMapping(
            quartzFrame: CGRect(x: -1920, y: 0, width: 1920, height: 1080),
            appKitFrame: CGRect(x: -1920, y: 0, width: 1920, height: 1080)
        )]

        let point = try XCTUnwrap(GuidePointCueProjector().appKitPoint(for: cue, displays: displays))

        XCTAssertEqual(point.x, -1600, accuracy: 0.001)
        XCTAssertEqual(point.y, 530, accuracy: 0.001)
    }

    func testMissingDisplayMappingProducesNoVisibleCue() {
        let target = GuideWindowTarget(
            processIdentifier: 5,
            windowIdentifier: 9,
            applicationName: "Fixture",
            windowTitle: "Missing",
            frame: CGRect(x: 4_000, y: 4_000, width: 500, height: 400)
        )
        let cue = GuidePointCue(target: target, normalizedPoint: CGPoint(x: 0.5, y: 0.5), label: nil)

        XCTAssertNil(GuidePointCueProjector().appKitPoint(for: cue, displays: []))
    }

    func testEdgeCuePanelIsClampedInsideTheLockedWindowOnItsLockedDisplay() throws {
        let target = GuideWindowTarget(
            processIdentifier: 5,
            windowIdentifier: 9,
            applicationName: "Fixture",
            windowTitle: "Edge",
            frame: CGRect(x: -1800, y: 100, width: 800, height: 600),
            displayIdentifier: 7
        )
        let cue = GuidePointCue(target: target, normalizedPoint: CGPoint(x: 0, y: 0), label: "File")
        let displays = [GuideDisplayMapping(
            displayIdentifier: 7,
            quartzFrame: CGRect(x: -1920, y: 0, width: 1920, height: 1080),
            appKitFrame: CGRect(x: -1920, y: 0, width: 1920, height: 1080)
        )]

        let frame = try XCTUnwrap(GuidePointCueProjector().panelFrame(
            for: cue,
            panelSize: CGSize(width: 56, height: 56),
            displays: displays
        ))

        XCTAssertTrue(CGRect(x: -1800, y: 380, width: 800, height: 600).contains(frame))
    }
}
