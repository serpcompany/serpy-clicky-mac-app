import XCTest

final class GuideCompanionUITests: XCTestCase {
    func testApplicationLaunchesAndRemainsAvailableWithoutAWindow() {
        let application = XCUIApplication()
        application.launchArguments = ["--ui-testing"]
        application.launch()

        XCTAssertTrue(application.wait(for: .runningBackground, timeout: 5))
    }

    func testVoiceConversationTranscriptHasNoTypingComposer() {
        let application = XCUIApplication()
        application.launchArguments = ["--ui-testing", "--open-guide-transcript"]
        application.launch()

        let window = application.windows["SERPy Voice Transcript"]
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        XCTAssertTrue(window.staticTexts["Voice Conversation"].exists)
        XCTAssertTrue(window.staticTexts["Talk to SERPy"].exists)
        XCTAssertEqual(window.textFields.count, 0)
        XCTAssertTrue(window.buttons["Talk"].exists)
        XCTAssertFalse(window.buttons["Cancel"].exists)
        XCTAssertTrue(window.buttons["New Conversation"].exists)
    }
}
