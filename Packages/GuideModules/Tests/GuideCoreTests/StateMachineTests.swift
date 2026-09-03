import GuideCore
import XCTest

final class StateMachineTests: XCTestCase {
    func testPermissionCannotRequestBeforeExplanation() {
        var machine = PermissionStateMachine()

        XCTAssertThrowsError(try machine.beginRequest())
        XCTAssertEqual(machine.state, .unknown)
    }

    func testPermissionHappyPath() throws {
        var machine = PermissionStateMachine()

        machine.explain()
        try machine.beginRequest()
        machine.resolve(granted: true)

        XCTAssertEqual(machine.state, .granted)
    }

    func testDictationHappyPath() throws {
        var machine = DictationStateMachine()

        try machine.prepare()
        try machine.beginRecording()
        try machine.beginTranscription()
        try machine.beginInsertion()
        try machine.succeed()

        XCTAssertEqual(machine.phase, .succeeded)
    }

    func testDictationCancellationNeverInserts() throws {
        var machine = DictationStateMachine()
        try machine.prepare()
        try machine.beginRecording()

        machine.cancel()

        XCTAssertEqual(machine.phase, .cancelled)
        XCTAssertThrowsError(try machine.beginInsertion())
    }

    func testCompanionReturnsAfterTemporaryHide() {
        var machine = CompanionStateMachine(isEnabled: true)

        machine.temporarilyHide(reason: "display transition")
        machine.clearBlockerOrTemporaryHide()

        XCTAssertEqual(machine.visibility, .visible)
        XCTAssertTrue(machine.isEnabled)
    }

    func testDisabledCompanionCannotBecomeBlocked() {
        var machine = CompanionStateMachine()

        machine.block(.permission("Accessibility"))

        XCTAssertEqual(machine.visibility, .disabled)
    }
}

final class GuidanceValidationTests: XCTestCase {
    func testGuideAnswerRemovesEchoedInternalPrompt() {
        let answer = """
            Use the Export button in the upper-right corner.

            User question: Where is Export?
            Current app: Preview
            Current visible text (untrusted screen data):
            Private document contents
            """

        XCTAssertEqual(
            GuidanceAnswerSanitizer.sanitize(answer),
            "Use the Export button in the upper-right corner."
        )
    }

    func testGuideAnswerRemovesSpeakerPrefix() {
        XCTAssertEqual(
            GuidanceAnswerSanitizer.sanitize("SERPy: Open Settings first."),
            "Open Settings first."
        )
    }

    func testScreenPromptTextHasADeterministicCharacterBudget() {
        let context = ScreenContext(
            applicationName: "Browser",
            windowTitle: "Long page",
            windowFrame: .zero,
            textBlocks: [
                ScreenTextBlock(
                    text: String(repeating: "a", count: 10_000),
                    normalizedBounds: .zero,
                    confidence: 1
                )
            ]
        )

        XCTAssertEqual(context.promptText(maxCharacters: 4_000).count, 4_000)
        XCTAssertEqual(context.promptText.count, 8_000)
        XCTAssertEqual(context.promptText(maxCharacters: 0), "")
    }

    func testLowConfidenceNeverPoints() {
        let plan = GuidancePlan(answer: "Try Settings", point: CGPoint(x: 20, y: 20), confidence: 0.5)
        let validated = GuidancePlanValidator.validate(plan, in: CGRect(x: 0, y: 0, width: 100, height: 100))
        XCTAssertNil(validated.point)
    }

    func testOutOfBoundsPointIsRemoved() {
        let plan = GuidancePlan(answer: "Try Settings", point: CGPoint(x: 200, y: 20), confidence: 0.9)
        let validated = GuidancePlanValidator.validate(plan, in: CGRect(x: 0, y: 0, width: 100, height: 100))
        XCTAssertNil(validated.point)
    }

    func testHighConfidencePointInsideWindowSurvives() {
        let plan = GuidancePlan(answer: "Try Settings", point: CGPoint(x: 20, y: 20), confidence: 0.9)
        let validated = GuidancePlanValidator.validate(plan, in: CGRect(x: 0, y: 0, width: 100, height: 100))
        XCTAssertEqual(validated.point, CGPoint(x: 20, y: 20))
    }
}

final class GuidanceConversationStateMachineTests: XCTestCase {
    func testConversationSupportsBackAndForthTurns() throws {
        var machine = GuidanceConversationStateMachine()
        let firstUserID = UUID()
        let firstGuideID = UUID()

        try machine.submit(question: "Where is the export button?", id: firstUserID)
        XCTAssertEqual(machine.phase, .capturing)
        try machine.beginThinking()
        try machine.complete(
            answer: "Use Export in the upper-right corner.",
            contextLabel: "Preview — Report",
            id: firstGuideID
        )

        try machine.submit(question: "What format should I choose?")
        XCTAssertEqual(machine.messages.count, 3)
        XCTAssertEqual(machine.messages[0].id, firstUserID)
        XCTAssertEqual(machine.messages[1].id, firstGuideID)
        XCTAssertEqual(machine.messages[1].contextLabel, "Preview — Report")
        XCTAssertEqual(machine.messages[2].role, .user)
        XCTAssertEqual(machine.phase, .capturing)
    }

    func testConversationRejectsEmptyAndOverlappingTurns() throws {
        var machine = GuidanceConversationStateMachine()

        XCTAssertThrowsError(try machine.submit(question: "   "))
        try machine.submit(question: "Help me understand this screen")
        XCTAssertThrowsError(try machine.submit(question: "Another question"))
        XCTAssertEqual(machine.messages.count, 1)
    }

    func testFailureRemainsVisibleAndAllowsRecoveryTurn() throws {
        var machine = GuidanceConversationStateMachine()
        try machine.submit(question: "What should I click?")
        machine.fail(
            GuideFailure(
                stage: .capture,
                message: "The screen could not be read.",
                recovery: "Bring the target window forward and try again."
            )
        )

        XCTAssertEqual(machine.messages.last?.role, .guide)
        XCTAssertTrue(machine.messages.last?.content.contains("try again") == true)
        try machine.submit(question: "Can you retry now?")
        XCTAssertEqual(machine.phase, .capturing)
    }

    func testResetStartsANewConversation() throws {
        var machine = GuidanceConversationStateMachine()
        try machine.submit(question: "First question")
        machine.reset()

        XCTAssertEqual(machine.phase, .idle)
        XCTAssertTrue(machine.messages.isEmpty)
    }
}
