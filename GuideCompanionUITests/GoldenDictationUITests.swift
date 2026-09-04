import XCTest

@MainActor
final class GoldenDictationUITests: GoldenUITestCase {
    func test_GT_UF03_001_dictationShowsPartialThenConfirmedDelivery() {
        launch(flow: "UF-03")
        tap("Start Dictation fixture")
        expectPhase("listening")
        tap("Receive Partial fixture")
        XCTAssertEqual(application.staticTexts["golden.transcript"].label, "alpha beta")
        tap("Stop Dictation fixture")
        expectPhase("deliveryConfirmed")
    }

    func test_GT_UF04_001_cancelSuppressesLateDictationResult() {
        launch(flow: "UF-04", phase: "listening")
        application.typeKey(.escape, modifierFlags: [])
        tap("Deliver Late Result fixture")
        expectPhase("cancelled")
        XCTAssertFalse(application.staticTexts["must be ignored"].exists)
    }

    func test_GT_UF04_002_escapeCancelsTranscription() {
        launch(flow: "UF-04", phase: "transcribing")
        application.typeKey(.escape, modifierFlags: [])
        expectPhase("cancelled")
    }

    func test_GT_UF04_003_escapeCancelsPrecommitInsertion() {
        launch(flow: "UF-04", phase: "inserting")
        application.typeKey(.escape, modifierFlags: [])
        expectPhase("cancelled")
    }

    func test_GT_UF05_001_recoveryExposesCopyRetryDelete() {
        launch(flow: "UF-05", variant: "failed")
        expectPhase("recoveryAvailable")
        XCTAssertEqual(application.staticTexts["golden.recovery.disposition"].label, "pending")
        application.terminate()
        XCTAssertTrue(application.wait(for: .notRunning, timeout: 5))
        application.launch()
        XCTAssertTrue(application.wait(for: .runningForeground, timeout: 5))
        XCTAssertEqual(application.staticTexts["golden.recovery.disposition"].label, "restored")
        XCTAssertEqual(application.staticTexts["golden.recovery.variant"].label, "failed")
        for action in ["Copy", "Retry", "Delete"] {
            XCTAssertTrue(application.buttons[action].exists)
        }
        tap("Copy recovery fixture")
        XCTAssertEqual(application.staticTexts["golden.recovery.disposition"].label, "copied")
        tap("Retry recovery fixture")
        XCTAssertEqual(application.staticTexts["golden.recovery.disposition"].label, "retryRequested")
        tap("Delete recovery fixture")
        XCTAssertEqual(application.staticTexts["golden.recovery.disposition"].label, "deleted")
    }

    func test_GT_UF05_002_unconfirmedRecoveryVariantIsVisible() {
        launch(flow: "UF-05", variant: "unconfirmed")
        XCTAssertEqual(application.staticTexts["golden.recovery.variant"].label, "unconfirmed")
    }

    func test_GT_UF05_003_interruptedRecoveryVariantIsVisible() {
        launch(flow: "UF-05", variant: "interrupted")
        XCTAssertEqual(application.staticTexts["golden.recovery.variant"].label, "interrupted")
    }
}
