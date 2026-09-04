import XCTest

@MainActor
final class GoldenPermissionsAndLifecycleUITests: GoldenUITestCase {
    func test_GT_UF01_001_permissionDenialShowsRecoveryAcrossRelaunch() {
        launch(flow: "UF-01")
        XCTAssertTrue(
            application.staticTexts[
                "macOS prompts only once. If a request was denied, use Open Settings on its row."
            ].waitForExistence(timeout: 5)
        )
        XCTAssertTrue(application.staticTexts["Not requested"].waitForExistence(timeout: 5))
        XCTAssertTrue(application.buttons["Request Microphone"].isEnabled)
        tap("Request Microphone")
        XCTAssertTrue(application.staticTexts["Microphone access was not granted."].waitForExistence(timeout: 5))
        application.terminate()
        XCTAssertTrue(application.wait(for: .notRunning, timeout: 5))
        application.launch()
        XCTAssertTrue(application.windows["SERPy Settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(application.staticTexts["Denied"].waitForExistence(timeout: 5))
    }

    func test_GT_UF02_001_realSettingsClosesAndReopensAsOneWindow() {
        launch(flow: "UF-02")
        XCTAssertFalse(application.descendants(matching: .any)["guide.ambient"].exists)
        XCTAssertEqual(application.windows.matching(identifier: "SERPy Settings").count, 1)
        application.windows["SERPy Settings"].buttons[XCUIIdentifierCloseWindow].click()
        XCTAssertFalse(application.windows["SERPy Settings"].exists)
        application.activate()
        XCTAssertTrue(application.windows["SERPy Settings"].waitForExistence(timeout: 5))
        XCTAssertEqual(application.windows.matching(identifier: "SERPy Settings").count, 1)
        application.terminate()
        XCTAssertTrue(application.wait(for: .notRunning, timeout: 5))
    }
}
