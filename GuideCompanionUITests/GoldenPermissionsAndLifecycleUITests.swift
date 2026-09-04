import XCTest

final class GoldenPermissionsAndLifecycleUITests: GoldenUITestCase {
    func test_GT_UF01_001_permissionDenialShowsOneRecoveryRoute() {
        launch(flow: "UF-01")
        expectPhase("permissionExplanation")
        tap("Continue")
        expectPhase("permissionRequestReady")
        tap("Deny fixture")
        expectPhase("permissionRecovery")
        XCTAssertEqual(application.staticTexts["golden.failure.recovery"].label, "Open Settings")
    }

    func test_GT_UF02_001_launchesOneHarnessWindowWithoutIdleOverlay() {
        launch(flow: "UF-02")
        expectPhase("idle")
        XCTAssertEqual(application.windows.count, 1)
    }
}
