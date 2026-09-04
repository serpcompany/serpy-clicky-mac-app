import AppKit
import XCTest

final class GuideCompanionUITests: XCTestCase {
    func testApplicationLaunchesForegroundWithNormalSettingsSurface() {
        let application = XCUIApplication()
        application.launchArguments = ["--ui-testing"]
        application.launch()

        XCTAssertTrue(application.wait(for: .runningForeground, timeout: 5))
        XCTAssertTrue(application.windows["SERPy Settings"].waitForExistence(timeout: 5))
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

    @MainActor
    func testMalformedGuidanceFixturePresentsTheHandledFailure() {
        let application = XCUIApplication()
        application.launchArguments = ["--ui-testing", "--guide-fixture=malformed-plan"]
        for key in ["SENTRY_DSN", "SENTRY_ENVIRONMENT", "SENTRY_DEBUG"] {
            if let value = ProcessInfo.processInfo.environment[key] {
                application.launchEnvironment[key] = value
            }
        }
        application.launch()

        XCTAssertTrue(application.wait(for: .runningForeground, timeout: 5))
        XCTAssertTrue(
            application.staticTexts["The local guide returned malformed structured guidance."]
                .waitForExistence(timeout: 5)
        )
        Thread.sleep(forTimeInterval: 5)
        let matchingFailures = application.staticTexts
            .matching(identifier: "The local guide returned malformed structured guidance.")
            .allElementsBoundByIndex
        let visibleScreens = NSScreen.screens.map { $0.visibleFrame }
        XCTAssertTrue(matchingFailures.contains { failure in
            !failure.frame.isEmpty && visibleScreens.contains { $0.intersects(failure.frame) }
        })
        if application.launchEnvironment["SENTRY_DSN"] != nil {
            Thread.sleep(forTimeInterval: 2)
        }
    }
}
