import XCTest
@testable import GuideUI

@MainActor
final class SettingsWindowPresentationTests: XCTestCase {
    func testMenuSettingsActionActivatesApplicationBeforeOpeningWindow() {
        var events: [String] = []
        let presentation = SettingsWindowPresentation(
            activateApplication: { events.append("activate") },
            openSettings: { events.append("open") }
        )

        presentation.present()

        XCTAssertEqual(events, ["activate", "open"])
    }
}
