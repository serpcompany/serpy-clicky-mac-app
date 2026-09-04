import XCTest

@MainActor
final class GoldenGuideUITests: GoldenUITestCase {
    func test_GT_UF08_001_realAmbientGuideAnswersOneFixtureQuestion() async {
        await launch(flow: "UF-08", extraArguments: ["--stepwise-guide"])
        closeSettingsForAmbientGuide()
        triggerShortcut("guide-pressed")
        expectAmbient(labelContains: "SERPy is listening", value: "")
        expectAmbient(labelContains: "Open a new window", value: "")
        triggerShortcut("guide-released")
        expectAmbient(labelContains: "Reading this screen", value: "")
        expectAmbient(labelContains: "Fixture Browser — Fixture Window", value: "")
        releaseFixture("capture")
        expectAmbient(labelContains: "Thinking locally", value: "")
        releaseFixture("generation")
        expectAmbient(labelContains: "SERPy is speaking", value: "Open the File menu.")
        expectAmbient(labelContains: "Step 1 of 2", value: "Open the File menu.")
        releaseFixture("speech")
        expectAmbient(labelContains: "SERPy is ready for a follow-up", value: "Open the File menu.")
        expectAmbient(labelContains: "Step 1 of 2", value: "Open the File menu.")
        assertAmbientSurfaceOnly()
    }

    func test_GT_UF09_001_walkthroughRequiresFreshEvidenceForEachStep() async {
        await launch(flow: "UF-09")
        closeSettingsForAmbientGuide()
        askAmbientGuide()
        expectAmbient(labelContains: "Step 1 of 2", value: "Open the File menu.")
        askAmbientGuide()
        expectAmbient(labelContains: "The expected result for Step 1 is not visible yet.", value: "Open the File menu.")
        askAmbientGuide()
        expectAmbient(labelContains: "Step 2 of 2", value: "Choose New Window.")
        askAmbientGuide()
        expectAmbient(labelContains: "Done", value: "Done. This walkthrough is complete.")
        assertAmbientSurfaceOnly()
    }

    func test_GT_UF10_001_shortcutCancelClearsAmbientListening() async {
        await launch(flow: "UF-10")
        closeSettingsForAmbientGuide()
        triggerShortcut("guide-pressed")
        expectAmbient(labelContains: "Open a new window", value: "")
        cancelAmbientGuide()
    }

    func test_GT_UF10_002_shortcutCancelClearsAmbientCapture() async {
        await assertAmbientCancellation(extraArgument: "--block-guide-capture", label: "Reading this screen", lateAdapter: "capture")
    }

    func test_GT_UF10_003_shortcutCancelClearsAmbientThinking() async {
        await assertAmbientCancellation(extraArgument: "--block-guide-generation", label: "Thinking locally", lateAdapter: "generation")
    }

    func test_GT_UF10_004_shortcutCancelClearsAmbientSpeaking() async {
        await assertAmbientCancellation(extraArgument: "--block-guide-speech", label: "Step 1 of 2", lateAdapter: "speech")
    }

    func test_GT_UF10_005_shortcutCancelClearsAmbientFollowUp() async {
        await launch(flow: "UF-10")
        closeSettingsForAmbientGuide()
        askAmbientGuide()
        expectAmbient(labelContains: "Step 1 of 2", value: "Open the File menu.")
        cancelAmbientGuide()
    }

    func test_GT_UF11_001_realSettingsEnforcesInMemoryTalkAuthorization() async {
        await launch(flow: "UF-11", extraArguments: ["--block-cloud-generation"])
        tap("Guidance")
        tap("OpenAI multimodal")
        let disclosure = application.checkBoxes["talk.disclosure"]
        XCTAssertTrue(disclosure.waitForExistence(timeout: 5))
        disclosure.click()
        let credential = application.secureTextFields["talk.credential"]
        XCTAssertTrue(credential.waitForExistence(timeout: 5))
        credential.click()
        credential.typeText("fixture-key")
        application.buttons["talk.credential.save"].click()
        application.buttons["talk.credential.verify"].click()
        expectValue(
            identifier: "talk.credential.status",
            value: "Provider verified for 15 minutes. OpenAI Talk may now send an explicitly disclosed turn."
        )
        closeSettingsForAmbientGuide()
        askAmbientGuide()
        let requestReceipt = sessionRoot.appendingPathComponent("cloud-request.fixture")
        let requestWritten = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in FileManager.default.fileExists(atPath: requestReceipt.path) },
            object: nil
        )
        XCTAssertEqual(XCTWaiter.wait(for: [requestWritten], timeout: 5), .completed)
        XCTAssertEqual(try? String(contentsOf: requestReceipt, encoding: .utf8), "question=Open a new window;raster=3;evidence=0")
        triggerShortcut("cancelled")
        expectAmbient(labelContains: "Cancelled", value: "")
    }

    func test_GT_UF12_001_realAmbientUIShowsMalformedPlanFailure() async {
        await launch(flow: "UF-12")
        closeSettingsForAmbientGuide()
        askAmbientGuide()
        expectAmbient(
            labelContains: "The local guide returned malformed structured guidance.",
            value: "Try the question again. SERPy did not present incomplete steps."
        )
        let incident = sessionRoot.appendingPathComponent("incident.fixture")
        let reported = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in FileManager.default.fileExists(atPath: incident.path) },
            object: nil
        )
        XCTAssertEqual(XCTWaiter.wait(for: [reported], timeout: 5), .completed)
        XCTAssertEqual(try? String(contentsOf: incident, encoding: .utf8), "count=1;code=guidance.plan.malformed")
        assertAmbientSurfaceOnly()
    }

    private func askAmbientGuide() {
        triggerShortcut("guide-pressed")
        expectAmbient(labelContains: "Open a new window", value: "")
        triggerShortcut("guide-released")
    }

    private func assertAmbientCancellation(extraArgument: String, label: String, lateAdapter: String) async {
        await launch(flow: "UF-10", extraArguments: [extraArgument])
        closeSettingsForAmbientGuide()
        triggerShortcut("guide-pressed")
        expectAmbient(labelContains: "Open a new window", value: "")
        triggerShortcut("guide-released")
        expectAmbient(labelContains: label)
        cancelAmbientGuide(lateAdapter: lateAdapter)
    }

    private func cancelAmbientGuide(lateAdapter: String? = nil) {
        triggerShortcut("cancelled")
        expectAmbient(labelContains: "Cancelled", value: "")
        expectAmbientGone(timeout: 3)
        if let lateAdapter {
            writeFixtureSignal("\(lateAdapter).late-release")
            waitForFixture("\(lateAdapter).late-returned")
            XCTAssertFalse(application.descendants(matching: .any)["guide.ambient"].exists)
        }
        XCTAssertFalse(application.windows["SERPy Voice Transcript"].exists)
    }
}
