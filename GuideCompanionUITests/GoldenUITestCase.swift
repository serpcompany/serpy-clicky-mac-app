import XCTest

class GoldenUITestCase: XCTestCase {
    private(set) var application: XCUIApplication!

    func launch(flow: String) {
        let application = XCUIApplication()
        self.application = application
        addTeardownBlock {
            if application.state != .notRunning {
                application.terminate()
            }
            XCTAssertTrue(application.wait(for: .notRunning, timeout: 5))
        }
        application.launchArguments = ["--ui-testing", "--golden-flow=\(flow)"]
        application.launchEnvironment = [
            "SENTRY_DSN": "",
            "SENTRY_ENVIRONMENT": "ui-test",
            "SERPY_NETWORK_DISABLED": "1",
            "SERPY_STORAGE_MODE": "ephemeral",
        ]
        application.launch()
        XCTAssertTrue(application.wait(for: .runningForeground, timeout: 5))
        XCTAssertTrue(application.otherElements["golden.harness"].waitForExistence(timeout: 5))
        XCTAssertEqual(XCUIApplication().state, .runningForeground)
    }

    func expectPhase(_ phase: String) {
        let phaseLabel = application.staticTexts["golden.phase"]
        XCTAssertTrue(phaseLabel.waitForExistence(timeout: 2))
        XCTAssertEqual(phaseLabel.label, phase)
    }

    func tap(_ title: String) {
        let button = application.buttons[title]
        XCTAssertTrue(button.waitForExistence(timeout: 2))
        button.tap()
    }
}
