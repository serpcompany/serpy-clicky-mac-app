import XCTest

final class GuideCompanionUITests: XCTestCase {
    func testApplicationLaunchesAsMenuBarUtility() {
        let application = XCUIApplication()
        application.launchArguments = ["--ui-testing"]
        application.launch()

        XCTAssertTrue(application.wait(for: .runningBackground, timeout: 5))
    }

    func testAIGuideOpensAsAConversationWindow() {
        let application = XCUIApplication()
        application.launchArguments = ["--ui-testing", "--open-ai-guide"]
        application.launch()

        let window = application.windows["SERPy AI Guide"]
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        XCTAssertTrue(window.staticTexts["AI Guide"].exists)
        XCTAssertTrue(window.textFields["Ask something about the current app…"].exists)
        XCTAssertTrue(window.buttons["Send"].exists)
        XCTAssertTrue(window.buttons["New Conversation"].exists)
    }
}
