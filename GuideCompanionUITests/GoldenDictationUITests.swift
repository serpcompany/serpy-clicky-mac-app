import XCTest

@MainActor
final class GoldenDictationUITests: GoldenUITestCase {
    func test_GT_UF03_001_realModelCompletesDeterministicDictation() async throws {
        try await launch(flow: "UF-03")
        triggerShortcut("dictation-pressed")
        expectAmbient(labelContains: "alpha beta")
        triggerShortcut("dictation-pressed")
        XCTAssertTrue(application.staticTexts["Dictation inserted locally."].waitForExistence(timeout: 5))
        XCTAssertEqual(
            try? String(contentsOf: sessionRoot.appendingPathComponent("insertion.fixture"), encoding: .utf8),
            "alpha beta"
        )
        let recoveryRecord = try? String(
            contentsOf: sessionRoot.appendingPathComponent("transcript-history.fixture.json"),
            encoding: .utf8
        )
        XCTAssertTrue(recoveryRecord?.contains("alpha beta") == true)
        XCTAssertTrue(recoveryRecord?.contains("confirmed") == true)
    }

    func test_GT_UF04_001_escapeCancelsRealDictationWithoutLateDelivery() async throws {
        try await launch(flow: "UF-04")
        triggerShortcut("dictation-pressed")
        expectAmbient(labelContains: "alpha beta")
        triggerShortcut("cancelled")
        XCTAssertTrue(application.staticTexts["Dictation cancelled."].waitForExistence(timeout: 5))
        XCTAssertFalse(application.staticTexts["Dictation inserted locally."].exists)
    }

    func test_GT_UF04_002_escapeCancelsRealTranscription() async throws {
        try await launch(flow: "UF-04", extraArguments: ["--block-dictation-stop"])
        triggerShortcut("dictation-pressed")
        expectAmbient(labelContains: "alpha beta")
        triggerShortcut("dictation-pressed")
        expectAmbient(labelContains: "Transcribing")
        triggerShortcut("cancelled")
        XCTAssertTrue(application.staticTexts["Dictation cancelled."].waitForExistence(timeout: 5))
        assertNoLateDictationOutput(adapter: "transcription")
    }

    func test_GT_UF04_003_escapeCancelsRealPrecommitInsertion() async throws {
        try await launch(flow: "UF-04", extraArguments: ["--block-dictation-insertion"])
        triggerShortcut("dictation-pressed")
        expectAmbient(labelContains: "alpha beta")
        triggerShortcut("dictation-pressed")
        expectAmbient(labelContains: "Inserting")
        triggerShortcut("cancelled")
        XCTAssertTrue(application.staticTexts["Dictation cancelled."].waitForExistence(timeout: 5))
        assertNoLateDictationOutput(adapter: "insertion")
    }

    func test_GT_UF05_001_realRecoveryUIShowsFailedLastDictation() async throws {
        try await launch(flow: "UF-05", recoveryVariant: "failed")
        selectSettingsTab("History")
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
        selectSettingsTab("History")
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

    func test_GT_UF05_002_realRecoveryUIShowsUnconfirmedState() async throws {
        try await launch(flow: "UF-05", recoveryVariant: "unconfirmed")
        selectSettingsTab("History")
        XCTAssertTrue(application.staticTexts["Unconfirmed"].waitForExistence(timeout: 5))
    }

    func test_GT_UF05_003_realRecoveryUIShowsInterruptedState() async throws {
        try await launch(flow: "UF-05", recoveryVariant: "interrupted")
        selectSettingsTab("History")
        XCTAssertTrue(application.staticTexts["Pending"].waitForExistence(timeout: 5))
    }

    private func assertNoLateDictationOutput(adapter: String) {
        writeFixtureSignal("\(adapter).late-release")
        waitForFixture("\(adapter).late-returned")
        expectAmbientGone(timeout: 3)
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: sessionRoot.appendingPathComponent("insertion.fixture").path
        ))
        XCTAssertFalse(application.staticTexts["Last dictation recovery"].exists)
        XCTAssertFalse(application.staticTexts["alpha beta"].exists)
    }
}
