import XCTest

@MainActor
final class GoldenGuideUITests: GoldenUITestCase {
    func test_GT_UF08_001_realGuideAnswersOneFixtureQuestion() {
        launch(flow: "UF-08", openTranscript: true)
        tap("Talk")
        tap("Finish Question")
        expectValue(
            identifier: "guide.message.guide",
            value: "Open the File menu, then choose New Window."
        )
    }

    func test_GT_UF09_001_walkthroughRequiresFreshEvidenceForEachStep() {
        launch(flow: "UF-09", openTranscript: true)

        tap("Talk")
        XCTAssertTrue(application.buttons["Finish Question"].waitForExistence(timeout: 3))
        tap("Finish Question")
        expectValue(
            identifier: "guide.message.guide",
            value: "Open the File menu, then choose New Window."
        )

        tap("Talk")
        tap("Finish Question")
        expectValue(identifier: "guide.message.guide", value: "Choose New Window.")

        tap("Talk")
        tap("Finish Question")
        expectValue(identifier: "guide.message.guide", value: "Done. This walkthrough is complete.")
    }

    func test_GT_UF10_001_escapeCancelsTheRealGuideModel() {
        launch(flow: "UF-10", openTranscript: true)
        tap("Talk")
        application.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(application.buttons["Talk"].waitForExistence(timeout: 5))
        XCTAssertFalse(application.descendants(matching: .any)["guide.message.guide"].exists)
    }

    func test_GT_UF10_002_escapeCancelsRealCapture() {
        assertGuideCancellation(extraArgument: "--block-guide-capture", activity: "Reading the selected window…")
    }

    func test_GT_UF10_003_escapeCancelsRealThinking() {
        assertGuideCancellation(extraArgument: "--block-guide-generation", activity: "Thinking locally…")
    }

    func test_GT_UF10_004_escapeCancelsRealSpeaking() {
        launch(flow: "UF-10", openTranscript: true, extraArguments: ["--block-guide-speech"])
        tap("Talk")
        tap("Finish Question")
        XCTAssertTrue(application.descendants(matching: .any)["guide.message.guide"].waitForExistence(timeout: 5))
        application.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(application.buttons["Talk"].waitForExistence(timeout: 5))
    }

    func test_GT_UF10_005_escapeClearsRealFollowUpState() {
        launch(flow: "UF-10", openTranscript: true)
        tap("Talk")
        tap("Finish Question")
        expectValue(identifier: "guide.message.guide", value: "Open the File menu, then choose New Window.")
        application.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(application.buttons["Talk"].waitForExistence(timeout: 5))
    }

    private func assertGuideCancellation(extraArgument: String, activity: String) {
        launch(flow: "UF-10", openTranscript: true, extraArguments: [extraArgument])
        tap("Talk")
        tap("Finish Question")
        expectValue(identifier: "guide.activity", value: activity)
        application.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(application.buttons["Talk"].waitForExistence(timeout: 5))
    }

    func test_GT_UF11_001_realSettingsEnforcesInMemoryTalkAuthorization() {
        launch(flow: "UF-11")
        tap("Configure OpenAI Fixture")
        XCTAssertTrue(
            application.staticTexts[
                "Provider verified for 15 minutes. OpenAI Talk may now send an explicitly disclosed turn."
            ].waitForExistence(timeout: 5)
        )
    }

    func test_GT_UF12_001_realUIShowsMalformedPlanFailureAndRecovery() {
        launch(flow: "UF-12", openTranscript: true)
        tap("Talk")
        tap("Finish Question")
        XCTAssertTrue(
            application.staticTexts["The local guide returned malformed structured guidance."]
                .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(
            application.staticTexts["Try the question again. SERPy did not present incomplete steps."]
                .waitForExistence(timeout: 5)
        )
        XCTAssertEqual(
            try? String(contentsOf: sessionRoot.appendingPathComponent("incident.fixture"), encoding: .utf8),
            "guidance.plan.malformed"
        )
    }
}
