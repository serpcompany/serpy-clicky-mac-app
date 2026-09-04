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
    ) async {
        preexistingProcessIDs = Set(NSRunningApplication.runningApplications(
            withBundleIdentifier: productBundleIdentifier
        ).map(\.processIdentifier))
        let application = XCUIApplication()
        self.application = application
        if sessionRoot == nil {
            do {
                let environment = ProcessInfo.processInfo.environment
                let session = try await Task.detached {
                    try UITestRunSessionProvisioner.provision(environment: environment)
                }.value
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

    func expectAmbient(labelContains: String, value: String? = nil, timeout: TimeInterval = 5) {
        let ambient = application.descendants(matching: .any)["guide.ambient"]
        XCTAssertTrue(ambient.waitForExistence(timeout: timeout))
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS %@", labelContains),
            object: ambient
        )
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: timeout), .completed)
        if let value {
            XCTAssertEqual(ambient.value as? String, value)
            if !value.isEmpty {
                XCTAssertGreaterThanOrEqual(ambient.frame.width, 300)
                XCTAssertGreaterThan(ambient.frame.height, 46)
            }
        }
    }

    func closeSettingsForAmbientGuide() {
        let settings = application.windows["SERPy Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        let closeButton = settings.buttons["_XCUI:CloseWindow"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 3))
        closeButton.tap()
        let closed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: settings
        )
        XCTAssertEqual(XCTWaiter.wait(for: [closed], timeout: 5), .completed)
        XCTAssertFalse(application.windows["SERPy Voice Transcript"].exists)
    }

    func triggerShortcut(_ action: String) {
        let signal = sessionRoot.appendingPathComponent("shortcut.\(UUID().uuidString).\(action).trigger")
        XCTAssertNoThrow(try Data().write(to: signal, options: .atomic))
    }

    func assertAmbientSurfaceOnly() {
        let ambient = application.descendants(matching: .any).matching(identifier: "guide.ambient")
        XCTAssertEqual(ambient.count, 1)
        XCTAssertFalse(application.windows["SERPy Voice Transcript"].exists)
        XCTAssertFalse(application.windows["SERPy Settings"].exists)
    }

    func attachAmbientScreenshot(named name: String) {
        let ambient = application.descendants(matching: .any)["guide.ambient"]
        XCTAssertTrue(ambient.exists)
        let attachment = XCTAttachment(screenshot: ambient.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func expectAmbientGone(timeout: TimeInterval) {
        let ambient = application.descendants(matching: .any)["guide.ambient"]
        let gone = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: ambient
        )
        XCTAssertEqual(XCTWaiter.wait(for: [gone], timeout: timeout), .completed)
    }

    func releaseFixture(_ name: String) {
        writeFixtureSignal("\(name).release")
    }

    func writeFixtureSignal(_ name: String) {
        XCTAssertNoThrow(try Data().write(to: sessionRoot.appendingPathComponent(name), options: .atomic))
    }

    func waitForFixture(_ name: String, timeout: TimeInterval = 5) {
        let url = sessionRoot.appendingPathComponent(name)
        let written = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in FileManager.default.fileExists(atPath: url.path) },
            object: nil
        )
        XCTAssertEqual(XCTWaiter.wait(for: [written], timeout: timeout), .completed)
    }
}
