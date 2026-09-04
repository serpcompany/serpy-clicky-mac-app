import XCTest

@MainActor
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
        XCTAssertEqual(application.staticTexts["golden.lifecycle"].label, "windows=1 overlays=0 running=true")
        tap("Close Settings fixture")
        XCTAssertEqual(application.staticTexts["golden.lifecycle"].label, "windows=0 overlays=0 running=true")
        tap("Reopen Settings fixture")
        XCTAssertEqual(application.staticTexts["golden.lifecycle"].label, "windows=1 overlays=0 running=true")
        tap("Quit fixture")
        expectPhase("terminated")
        XCTAssertEqual(application.staticTexts["golden.lifecycle"].label, "windows=0 overlays=0 running=false")
    }
}
