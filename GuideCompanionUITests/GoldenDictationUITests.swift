import XCTest

@MainActor
final class GoldenDictationUITests: GoldenUITestCase {
    func test_GT_UF03_001_realModelCompletesDeterministicDictation() {
        launch(flow: "UF-03")
        tap("Start Dictation Fixture")
        XCTAssertTrue(application.buttons["Stop Dictation Fixture"].waitForExistence(timeout: 5))
        tap("Stop Dictation Fixture")
        XCTAssertTrue(application.staticTexts["The dictation was inserted locally."].waitForExistence(timeout: 5))
        XCTAssertEqual(
            try? String(contentsOf: sessionRoot.appendingPathComponent("insertion.fixture"), encoding: .utf8),
            "alpha beta"
        )
    }

    func test_GT_UF04_001_escapeCancelsRealDictationWithoutLateDelivery() {
        launch(flow: "UF-04")
        tap("Start Dictation Fixture")
        application.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(application.staticTexts["Dictation cancelled."].waitForExistence(timeout: 5))
        XCTAssertFalse(application.staticTexts["The dictation was inserted locally."].exists)
    }

    func test_GT_UF04_002_escapeCancelsRealTranscription() {
        launch(flow: "UF-04", extraArguments: ["--block-dictation-stop"])
        tap("Start Dictation Fixture")
        tap("Stop Dictation Fixture")
        expectValue(identifier: "test.runtime.state", value: "dictation=transcribing;guide=idle")
        application.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(application.staticTexts["Dictation cancelled."].waitForExistence(timeout: 5))
    }

    func test_GT_UF04_003_escapeCancelsRealPrecommitInsertion() {
        launch(flow: "UF-04", extraArguments: ["--block-dictation-insertion"])
        tap("Start Dictation Fixture")
        tap("Stop Dictation Fixture")
        expectValue(identifier: "test.runtime.state", value: "dictation=inserting;guide=idle")
        application.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(application.staticTexts["Dictation cancelled."].waitForExistence(timeout: 5))
        XCTAssertFalse(FileManager.default.fileExists(atPath: sessionRoot.appendingPathComponent("insertion.fixture").path))
    }

    func test_GT_UF05_001_realRecoveryUIShowsFailedLastDictation() {
        launch(flow: "UF-05", recoveryVariant: "failed")
        tap("History")
        XCTAssertTrue(application.staticTexts["Recovered fixture dictation"].waitForExistence(timeout: 5))
        XCTAssertTrue(application.staticTexts["Failed"].exists)
        XCTAssertTrue(application.buttons["Copy"].exists)
        XCTAssertTrue(application.buttons["Retry in 4 Seconds"].exists)
        XCTAssertTrue(application.buttons["Delete"].exists)
        application.terminate()
        XCTAssertTrue(application.wait(for: .notRunning, timeout: 5))
        application.launchArguments.removeAll { $0.hasPrefix("--recovery-variant=") }
        application.launch()
        XCTAssertTrue(application.windows["SERPy Settings"].waitForExistence(timeout: 5))
        tap("History")
        XCTAssertTrue(application.staticTexts["Recovered fixture dictation"].waitForExistence(timeout: 5))
        tap("Copy")
        XCTAssertEqual(
            try? String(contentsOf: sessionRoot.appendingPathComponent("clipboard.fixture"), encoding: .utf8),
            "Recovered fixture dictation"
        )
        tap("Retry in 4 Seconds")
        let insertionReceipt = sessionRoot.appendingPathComponent("insertion.fixture")
        let inserted = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in FileManager.default.fileExists(atPath: insertionReceipt.path) },
            object: nil
        )
        XCTAssertEqual(XCTWaiter.wait(for: [inserted], timeout: 7), .completed)
        tap("Delete")
        XCTAssertFalse(application.staticTexts["Recovered fixture dictation"].waitForExistence(timeout: 1))
    }

    func test_GT_UF05_002_realRecoveryUIShowsUnconfirmedState() {
        launch(flow: "UF-05", recoveryVariant: "unconfirmed")
        tap("History")
        XCTAssertTrue(application.staticTexts["Unconfirmed"].waitForExistence(timeout: 5))
    }

    func test_GT_UF05_003_realRecoveryUIShowsInterruptedState() {
        launch(flow: "UF-05", recoveryVariant: "interrupted")
        tap("History")
        XCTAssertTrue(application.staticTexts["Pending"].waitForExistence(timeout: 5))
    }
}
