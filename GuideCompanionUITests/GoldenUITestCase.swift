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
    private var runToken = ""
    private var ownsSessionParent = false
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
                let provisioning = try UITestRunParentPolicy.resolve(
                    environment: ProcessInfo.processInfo.environment
                )
                switch provisioning {
                case let .boundedWrapper(parentPath, suppliedRunToken):
                    runToken = suppliedRunToken
                    sessionParent = URL(fileURLWithPath: parentPath, isDirectory: true)
                case .verifiedXcodeCloud:
                    runToken = UUID().uuidString
                    let suffix = UUID().uuidString.replacingOccurrences(of: "-", with: "")
                    sessionParent = URL(fileURLWithPath: "/private/tmp", isDirectory: true)
                        .appendingPathComponent("serpy-local-xcui.\(suffix)")
                    try FileManager.default.createDirectory(at: sessionParent, withIntermediateDirectories: false)
                    try runToken.write(
                        to: sessionParent.appendingPathComponent(".serpy-local-xcui-owner"),
                        atomically: true,
                        encoding: .utf8
                    )
                    ownsSessionParent = true
                }
                sessionID = UUID().uuidString
                sessionRoot = sessionParent.appendingPathComponent("serpy-real-ui-\(sessionID)")
                try FileManager.default.createDirectory(at: sessionRoot, withIntermediateDirectories: false)
                try sessionID.write(
                    to: sessionRoot.appendingPathComponent(".serpy-real-ui-owner"),
                    atomically: true,
                    encoding: .utf8
                )
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
            try? FileManager.default.removeItem(
                at: self.ownsSessionParent ? self.sessionParent : self.sessionRoot
            )
            XCTAssertFalse(FileManager.default.fileExists(atPath: self.sessionRoot.path))
            if self.ownsSessionParent {
                XCTAssertFalse(FileManager.default.fileExists(atPath: self.sessionParent.path))
            }
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
