import XCTest

@MainActor
final class GoldenGuideUITests: GoldenUITestCase {
    func test_GT_UF08_001_realGuideAnswersOneFixtureQuestion() {
        launch(flow: "UF-08", openTranscript: true, extraArguments: ["--stepwise-guide"])
        tap("Talk")
        expectValue(identifier: "guide.activity", value: "Heard: Open a new window")
        tap("Finish Question")
        expectValue(identifier: "guide.activity", value: "Reading the selected window…")
        releaseFixture("capture")
        expectValue(identifier: "guide.activity", value: "Thinking locally…")
        releaseFixture("generation")
        expectLatestLabel(
            identifier: "guide.message.guide",
            label: "Open the File menu, then choose New Window."
        )
        releaseFixture("speech")
        XCTAssertTrue(application.buttons["Talk"].waitForExistence(timeout: 5))
    }

    func test_GT_UF09_001_walkthroughRequiresFreshEvidenceForEachStep() {
        launch(flow: "UF-09", openTranscript: true)

        tap("Talk")
        XCTAssertTrue(application.buttons["Finish Question"].waitForExistence(timeout: 3))
        tap("Finish Question")
        expectLatestLabel(
            identifier: "guide.message.guide",
            label: "Open the File menu, then choose New Window."
        )

        tap("Talk")
        tap("Finish Question")
        expectLatestLabel(identifier: "guide.message.guide", label: "Open the File menu.")

        tap("Talk")
        tap("Finish Question")
        expectLatestLabel(identifier: "guide.message.guide", label: "Choose New Window.")

        tap("Talk")
        tap("Finish Question")
        expectLatestLabel(identifier: "guide.message.guide", label: "Done. This walkthrough is complete.")
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
        expectLatestLabel(identifier: "guide.message.guide", label: "Open the File menu, then choose New Window.")
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
        launch(flow: "UF-11", extraArguments: ["--block-cloud-generation"])
        tap("Configure OpenAI Fixture")
        XCTAssertTrue(
            application.staticTexts[
                "Provider verified for 15 minutes. OpenAI Talk may now send an explicitly disclosed turn."
            ].waitForExistence(timeout: 5)
        )
        tap("Open Guide Transcript")
        XCTAssertTrue(application.windows["SERPy Voice Transcript"].waitForExistence(timeout: 5))
        tap("Talk")
        tap("Finish Question")
        let requestReceipt = sessionRoot.appendingPathComponent("cloud-request.fixture")
        let requestWritten = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in FileManager.default.fileExists(atPath: requestReceipt.path) },
            object: nil
        )
        XCTAssertEqual(XCTWaiter.wait(for: [requestWritten], timeout: 5), .completed)
        XCTAssertEqual(
            try? String(contentsOf: requestReceipt, encoding: .utf8),
            "question=Open a new window;raster=3;evidence=0"
        )
        application.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(application.buttons["Talk"].waitForExistence(timeout: 5))
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
            "count=1;code=guidance.plan.malformed"
        )
    }
}
