import XCTest

@MainActor
final class GoldenGuideUITests: GoldenUITestCase {
    func test_GT_UF08_001_questionReachesFollowUpReadyWithoutComposer() {
        launch(flow: "UF-08")
        for phase in ["listening", "transcribing", "capturing", "thinking", "speaking", "followUpReady"] {
            tap("Advance fixture")
            expectPhase(phase)
        }
        XCTAssertEqual(
            application.staticTexts["golden.answer"].label,
            "Open the File menu, then choose New Window."
        )
        XCTAssertEqual(application.textFields.count, 0)
    }

    func test_GT_UF09_001_walkthroughRequiresFreshEvidenceForEachStep() {
        launch(flow: "UF-09")
        XCTAssertEqual(application.staticTexts["golden.step"].label, "Step 1 of 2")
        tap("Stale Evidence fixture")
        XCTAssertEqual(application.staticTexts["golden.step"].label, "Step 1 of 2")
        tap("Fresh Evidence fixture")
        XCTAssertEqual(application.staticTexts["golden.step"].label, "Step 2 of 2")
        tap("Fresh Evidence fixture")
        expectPhase("completed")
    }

    func test_GT_UF10_001_cancelSuppressesLateGuideOutput() {
        launch(flow: "UF-10", phase: "listening")
        application.typeKey(.escape, modifierFlags: [])
        tap("Deliver Late Result fixture")
        expectPhase("cancelled")
        XCTAssertFalse(application.staticTexts["must be ignored"].exists)
    }

    func test_GT_UF10_002_escapeCancelsCapture() { assertGuideEscape(phase: "capturing") }
    func test_GT_UF10_003_escapeCancelsThinking() { assertGuideEscape(phase: "thinking") }
    func test_GT_UF10_004_escapeCancelsSpeaking() { assertGuideEscape(phase: "speaking") }
    func test_GT_UF10_005_escapeCancelsFollowUp() { assertGuideEscape(phase: "followUpReady") }

    private func assertGuideEscape(phase: String) {
        launch(flow: "UF-10", phase: phase)
        application.typeKey(.escape, modifierFlags: [])
        expectPhase("cancelled")
        XCTAssertEqual(application.staticTexts["golden.lifecycle"].label, "windows=1 overlays=0 running=true")
    }

    func test_GT_UF11_001_openAITalkUsesOnlyInMemoryCredentialAndFixtureResponse() {
        launch(flow: "UF-11")
        tap("Select OpenAI fixture")
        tap("Accept Disclosure fixture")
        expectPhase("credentialRequired")
        tap("Verify In-Memory Credential")
        expectPhase("fixtureResponse")
        XCTAssertEqual(application.staticTexts["golden.safety"].label, "network=0 keychain=memoryOnly")
    }

    func test_GT_UF12_001_malformedPlanShowsTypedHandledFailure() {
        launch(flow: "UF-12")
        expectPhase("handledFailure")
        XCTAssertEqual(
            application.staticTexts["golden.failure.cause"].label,
            "The local guide returned malformed structured guidance."
        )
        XCTAssertEqual(
            application.staticTexts["golden.failure.recovery"].label,
            "Try the question again. SERPy did not present incomplete steps."
        )
        XCTAssertEqual(application.staticTexts["golden.safety"].label, "network=0 keychain=none")
    }
}
