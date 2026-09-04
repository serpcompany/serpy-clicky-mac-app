import AppKit
import XCTest

@MainActor
class GoldenUITestCase: XCTestCase {
    private(set) var application: XCUIApplication!
    private let goldenBundleIdentifier = "com.serpcompany.guidecompanion.internal.golden-host"

    func launch(flow: String) {
        let application = XCUIApplication()
        self.application = application
        let sessionID = UUID().uuidString
        let sessionRoot = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("serpy-golden-\(sessionID)", isDirectory: true)
        try? FileManager.default.createDirectory(at: sessionRoot, withIntermediateDirectories: true)
        addTeardownBlock {
            if application.state != .notRunning {
                application.terminate()
            }
            XCTAssertTrue(application.wait(for: .notRunning, timeout: 5))
            XCTAssertTrue(NSRunningApplication.runningApplications(
                withBundleIdentifier: self.goldenBundleIdentifier
            ).isEmpty)
            try? FileManager.default.removeItem(at: sessionRoot)
            XCTAssertFalse(FileManager.default.fileExists(atPath: sessionRoot.path))
        }
        application.launchArguments = ["--ui-testing", "--golden-flow=\(flow)"]
        application.launchEnvironment = [
            "SENTRY_DSN": "",
            "SENTRY_ENVIRONMENT": "ui-test",
            "SERPY_NETWORK_DISABLED": "1",
            "SERPY_STORAGE_MODE": "ephemeral",
            "SERPY_TEST_SESSION_ID": sessionID,
            "SERPY_TEST_ROOT": sessionRoot.path,
        ]
        application.launch()
        XCTAssertTrue(application.wait(for: .runningForeground, timeout: 5))
        XCTAssertTrue(application.otherElements["golden.harness"].waitForExistence(timeout: 5))
        XCTAssertEqual(
            NSRunningApplication.runningApplications(withBundleIdentifier: goldenBundleIdentifier).count,
            1
        )
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
