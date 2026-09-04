import AppKit
import XCTest

@MainActor
class GoldenUITestCase: XCTestCase {
    private(set) var application: XCUIApplication!
    private let goldenBundleIdentifier = "com.serpcompany.guidecompanion.internal.golden-host"

    func launch(flow: String, phase: String? = nil, variant: String? = nil) {
        let application = XCUIApplication()
        self.application = application
        guard let fixtureCatalog = ProcessInfo.processInfo.environment["SERPY_GOLDEN_FIXTURE_CATALOG"],
              fixtureCatalog.split(separator: ",").map(String.init).contains(flow) else {
            XCTFail("fixture \(flow) is not selected by GuideCompanionGolden.xctestplan")
            return
        }
        let sessionID = UUID().uuidString
        let sessionRoot = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("serpy-golden-\(sessionID)", isDirectory: true)
            .resolvingSymlinksInPath()
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
        if let phase { application.launchArguments.append("--golden-phase=\(phase)") }
        if let variant { application.launchArguments.append("--golden-variant=\(variant)") }
        application.launchEnvironment = [
            "SENTRY_DSN": "",
            "SENTRY_ENVIRONMENT": "ui-test",
            "SERPY_NETWORK_DISABLED": "1",
            "SERPY_STORAGE_MODE": "ephemeral",
            "SERPY_GOLDEN_FIXTURE_CATALOG": fixtureCatalog,
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
        let reachedPhase = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", phase),
            object: phaseLabel
        )
        XCTAssertEqual(XCTWaiter.wait(for: [reachedPhase], timeout: 2), .completed)
    }

    func tap(_ title: String) {
        let button = application.buttons[title]
        XCTAssertTrue(button.waitForExistence(timeout: 2))
        button.tap()
    }
}
