import AppKit
import GuideCore
import XCTest

@MainActor
class GoldenUITestCase: XCTestCase {
    private(set) var application: XCUIApplication!
    private let productBundleIdentifier = "com.serpcompany.guidecompanion.internal"
    private var preexistingProcessIDs: Set<pid_t> = []
    private(set) var sessionRoot: URL!
    private var sessionParent: URL!
    private var sessionTemporaryRoot: URL!
    private var runToken = ""
    private var sessionID = ""

    func launch(
        flow: String,
        openTranscript: Bool = false,
        recoveryVariant: String? = nil,
        extraArguments: [String] = []
    ) {
        preexistingProcessIDs = Set(NSRunningApplication.runningApplications(
            withBundleIdentifier: productBundleIdentifier
        ).map(\.processIdentifier))
        let application = XCUIApplication()
        self.application = application
        if sessionRoot == nil {
            do {
                let session = try UITestRunSessionProvisioner.provision(
                    environment: ProcessInfo.processInfo.environment
                )
                runToken = session.runToken
                sessionTemporaryRoot = session.temporaryRoot
                sessionParent = session.parent
                sessionID = session.sessionID
                sessionRoot = session.root
            } catch {
                XCTFail("could not provision an authorized isolated UI-test session: \(error)")
                return
            }
        }
        addTeardownBlock {
            if application.state != .notRunning { application.terminate() }
            XCTAssertTrue(application.wait(for: .notRunning, timeout: 5))
            let remaining = Set(NSRunningApplication.runningApplications(
                withBundleIdentifier: self.productBundleIdentifier
            ).map(\.processIdentifier))
            XCTAssertEqual(remaining, self.preexistingProcessIDs)
            try? FileManager.default.removeItem(at: self.sessionParent)
            XCTAssertFalse(FileManager.default.fileExists(atPath: self.sessionRoot.path))
            XCTAssertFalse(FileManager.default.fileExists(atPath: self.sessionParent.path))
        }
        application.launchArguments = [
            "--ui-testing",
            "--golden-flow=\(flow)",
        ]
        if openTranscript { application.launchArguments.append("--open-guide-transcript") }
        if let recoveryVariant { application.launchArguments.append("--recovery-variant=\(recoveryVariant)") }
        application.launchArguments.append(contentsOf: extraArguments)
        if ProcessInfo.processInfo.environment["SERPY_INJECT_GUIDE_FAILURE"] == "1" {
            application.launchArguments.append("--inject-guide-failure")
        }
        application.launchEnvironment = [
            "SENTRY_DSN": "",
            "SERPY_NETWORK_DISABLED": "1",
            "SERPY_STORAGE_MODE": "memory",
            "SERPY_TEST_SESSION_ID": sessionID,
            "SERPY_TEST_ROOT": sessionRoot.path,
            "SERPY_TEST_PARENT": sessionParent.path,
            "SERPY_TEST_TEMP_ROOT": sessionTemporaryRoot.path,
            "SERPY_XCUI_RUN_TOKEN": runToken,
        ]
        application.launch()
        XCTAssertTrue(application.wait(for: .runningForeground, timeout: 5))
        let expectedWindow = openTranscript ? "SERPy Voice Transcript" : "SERPy Settings"
        XCTAssertTrue(application.windows[expectedWindow].waitForExistence(timeout: 5))
        XCTAssertEqual(
            NSRunningApplication.runningApplications(withBundleIdentifier: productBundleIdentifier)
                .filter { !preexistingProcessIDs.contains($0.processIdentifier) }.count,
            1
        )
    }

    func tap(_ title: String) {
        let button = application.buttons[title]
        XCTAssertTrue(button.waitForExistence(timeout: 3))
        button.tap()
    }

    func expectValue(identifier: String, value: String, timeout: TimeInterval = 5) {
        let element = application.descendants(matching: .any)[identifier]
        XCTAssertTrue(element.waitForExistence(timeout: timeout))
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", value),
            object: element
        )
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: timeout), .completed)
    }

    func releaseFixture(_ name: String) {
        XCTAssertNoThrow(try Data().write(
            to: sessionRoot.appendingPathComponent("\(name).release"),
            options: .atomic
        ))
    }
}
