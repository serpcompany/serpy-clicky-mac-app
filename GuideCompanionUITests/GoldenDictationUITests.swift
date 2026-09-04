import XCTest

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
        launch(flow: "UF-04")
        tap("Cancel")
        tap("Deliver Late Result fixture")
        expectPhase("cancelled")
        XCTAssertFalse(application.staticTexts["must be ignored"].exists)
    }

    func test_GT_UF05_001_recoveryExposesCopyRetryDelete() {
        launch(flow: "UF-05")
        expectPhase("recoveryAvailable")
        for action in ["Copy", "Retry", "Delete"] {
            XCTAssertTrue(application.buttons[action].exists)
        }
    }
}
