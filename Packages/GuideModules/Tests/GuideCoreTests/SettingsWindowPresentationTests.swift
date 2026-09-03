import XCTest
@testable import GuideUI

@MainActor
final class SettingsWindowPresentationTests: XCTestCase {
    func testMenuSettingsActionActivatesApplicationBeforeOpeningWindow() {
        var events: [String] = []
        var scheduledRaise: (() -> Void)?
        let presentation = SettingsWindowPresentation(
            enterRegularMode: { events.append("regular") },
            activateApplication: { events.append("activate") },
            openSettings: { events.append("open") },
            scheduleAfterMenuCloses: { action in
                events.append("schedule")
                scheduledRaise = action
            }
        )

        presentation.present()

        XCTAssertEqual(events, ["regular", "activate", "open", "schedule"])

        scheduledRaise?()

        XCTAssertEqual(events, ["regular", "activate", "open", "schedule", "activate"])
    }

    func testSettingsVisibilityNeverRequestsAnAccessoryMode() {
        var events: [String] = []
        let lifecycle = SettingsWindowVisibilityLifecycle(
            enterRegularMode: { events.append("regular") },
            activateApplication: { events.append("activate") }
        )

        lifecycle.didAppear()
        XCTAssertEqual(events, ["regular", "activate"])
    }
}
