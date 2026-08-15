import XCTest

final class GuideCompanionUITests: XCTestCase {
    func testApplicationLaunchesAsMenuBarUtility() {
        let application = XCUIApplication()
        application.launchArguments = ["--ui-testing"]
        application.launch()

        XCTAssertTrue(application.wait(for: .runningBackground, timeout: 5))
    }
}
