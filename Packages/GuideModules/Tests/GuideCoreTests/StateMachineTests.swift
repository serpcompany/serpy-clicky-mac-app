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

    func testActiveVoiceGuideForcesCompanionVisibleWithoutChangingPreference() {
        let policy = CompanionVisibilityPolicy()

        XCTAssertEqual(
            policy.visibility(persistedEnabled: false, guidancePhase: .listening),
            .visible
        )
        XCTAssertEqual(
            policy.visibility(persistedEnabled: false, guidancePhase: .presenting),
            .visible
        )
        XCTAssertEqual(
            policy.visibility(persistedEnabled: false, guidancePhase: .idle),
            .disabled
        )
    }
}

final class GuidanceValidationTests: XCTestCase {
    func testCapturedChatGPTContextRejectsFalseCannotSeeAnswer() {
        let policy = GuidanceAnswerGroundingPolicy()
        let context = ScreenContextIdentity(applicationName: "ChatGPT", windowTitle: "ChatGPT")

        XCTAssertEqual(
            policy.disposition(
                for: "I can't see the application.",
                context: context,
                hasVisibleText: true
            ),
            .retryWithGroundedContext
        )
    }

    func testRepeatedFalseCannotSeeAnswerFallsBackToCapturedApp() {
        let policy = GuidanceAnswerGroundingPolicy()
        let context = ScreenContextIdentity(applicationName: "ChatGPT", windowTitle: "ChatGPT")

        XCTAssertEqual(
            policy.resolvedAnswer(
                initial: "I can't see the application.",
                retry: "I cannot access the app.",
                context: context,
                hasVisibleText: true
            ),
            "I captured ChatGPT, but I could not identify the specific control from the visible text. Bring that control into view and ask again."
        )
    }

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

final class CompanionResponseLayoutPolicyTests: XCTestCase {
    func testStreamingResponseKeepsOriginButGrowsUntilActualOverflow() {
        let anchor = CompanionResponseAnchorPolicy()
        let sizing = CompanionResponseSizingPolicy()
        let initial = CGRect(x: 200, y: 180, width: 600, height: 92)

        let medium = sizing.resolve(
            width: 600,
            measuredContentHeight: 280,
            maximumPanelHeight: 500,
            minimumPanelHeight: 92
        )
        let grown = anchor.frame(
            current: initial,
            proposed: CGRect(x: 40, y: 40, width: medium.size.width, height: medium.size.height),
            responseIsVisible: true
        )

        XCTAssertEqual(grown.origin, initial.origin)
        XCTAssertEqual(grown.height, 280)
        XCTAssertEqual(medium.interactionMode, .clickThrough)

        let overflow = sizing.resolve(
            width: 600,
            measuredContentHeight: 720,
            maximumPanelHeight: 500,
            minimumPanelHeight: 92
        )
        let capped = anchor.frame(
            current: grown,
            proposed: CGRect(x: 20, y: 20, width: overflow.size.width, height: overflow.size.height),
            responseIsVisible: true
        )

        XCTAssertEqual(capped.origin, initial.origin)
        XCTAssertEqual(capped.height, 500)
        XCTAssertEqual(overflow.interactionMode, .scrollableVisibleControl)
    }

    func testGrowingAnchorAdjustsOnlyWhenNeededToStayOnscreenAndAvoidStatus() {
        let layout = CompanionResponseLayoutPolicy()
        let anchor = CompanionResponseAnchorPolicy()

        for visibleFrame in [
            CGRect(x: 0, y: 0, width: 1_200, height: 800),
            CGRect(x: -700, y: 40, width: 700, height: 500)
        ] {
            let status = CGRect(
                x: visibleFrame.midX - 175,
                y: visibleFrame.midY - 50,
                width: 350,
                height: 100
            )
            let maximumHeight = CompanionResponseInteractionPolicy().maximumNonOverlappingHeight(
                visibleFrame: visibleFrame,
                avoidedFrame: status
            )
            var current: CGRect?
            for height in [min(92, maximumHeight), max(92, maximumHeight * 0.65), maximumHeight] {
                let proposed = layout.frame(
                    pointer: CGPoint(x: status.midX, y: status.midY),
                    visibleFrame: visibleFrame,
                    contentSize: CGSize(width: min(600, visibleFrame.width - 16), height: height),
                    avoiding: status
                )
                let resolved = anchor.frame(
                    current: current,
                    proposed: proposed,
                    responseIsVisible: current != nil,
                    visibleFrame: visibleFrame,
                    avoiding: status
                )
                XCTAssertTrue(visibleFrame.insetBy(dx: 8, dy: 8).contains(resolved))
                XCTAssertFalse(resolved.intersects(status))
                current = resolved
            }
        }
    }

    func testOnlyOverflowingVisibleAnswerBecomesIntentionallyScrollable() {
        let policy = CompanionResponseInteractionPolicy()

        XCTAssertEqual(
            policy.mode(measuredContentHeight: 320, maximumPanelHeight: 600),
            .clickThrough
        )
        XCTAssertEqual(
            policy.mode(measuredContentHeight: 720, maximumPanelHeight: 600),
            .scrollableVisibleControl
        )
    }

    func testOverflowHeightReservesSpaceForGuideStatusWithoutOverlap() {
        let interaction = CompanionResponseInteractionPolicy()
        let layout = CompanionResponseLayoutPolicy()
        let visibleFrame = CGRect(x: 0, y: 0, width: 1_200, height: 800)
        let statusFrame = CGRect(x: 425, y: 350, width: 350, height: 100)
        let maximumHeight = interaction.maximumNonOverlappingHeight(
            visibleFrame: visibleFrame,
            avoidedFrame: statusFrame
        )
        let responseFrame = layout.frame(
            pointer: CGPoint(x: statusFrame.midX, y: statusFrame.midY),
            visibleFrame: visibleFrame,
            contentSize: CGSize(width: 600, height: maximumHeight),
            avoiding: statusFrame
        )

        XCTAssertEqual(maximumHeight, 328, accuracy: 0.001)
        XCTAssertFalse(responseFrame.intersects(statusFrame))
        XCTAssertTrue(visibleFrame.insetBy(dx: 8, dy: 8).contains(responseFrame))
    }

    func testResponseBubbleStaysFullyVisibleAtScreenEdges() {
        let policy = CompanionResponseLayoutPolicy()
        let visibleFrame = CGRect(x: 0, y: 40, width: 800, height: 520)
        let contentSize = CGSize(width: 360, height: 190)

        for pointer in [
            CGPoint(x: 4, y: 44),
            CGPoint(x: 796, y: 44),
            CGPoint(x: 4, y: 556),
            CGPoint(x: 796, y: 556)
        ] {
            let frame = policy.frame(
                pointer: pointer,
                visibleFrame: visibleFrame,
                contentSize: contentSize
            )

            XCTAssertTrue(visibleFrame.insetBy(dx: 8, dy: 8).contains(frame))
            XCTAssertEqual(frame.size, contentSize)
        }
    }

    func testResponseBubbleAvoidsCompanionAtCenterAndEveryScreenEdge() {
        let policy = CompanionResponseLayoutPolicy()
        let visibleFrame = CGRect(x: 0, y: 0, width: 1_200, height: 800)
        let contentSize = CGSize(width: 380, height: 190)
        let companionFrames = [
            CGRect(x: 425, y: 350, width: 350, height: 100),
            CGRect(x: 8, y: 8, width: 350, height: 100),
            CGRect(x: 842, y: 8, width: 350, height: 100),
            CGRect(x: 8, y: 692, width: 350, height: 100),
            CGRect(x: 842, y: 692, width: 350, height: 100)
        ]

        for companionFrame in companionFrames {
            let frame = policy.frame(
                pointer: CGPoint(x: companionFrame.midX, y: companionFrame.midY),
                visibleFrame: visibleFrame,
                contentSize: contentSize,
                avoiding: companionFrame
            )

            XCTAssertTrue(visibleFrame.insetBy(dx: 8, dy: 8).contains(frame))
            XCTAssertFalse(frame.intersects(companionFrame))
            XCTAssertEqual(frame.size, contentSize)
        }
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

final class GuidanceVoiceActivationPolicyTests: XCTestCase {
    private let policy = GuidanceVoiceActivationPolicy()

    func testShortcutStartsStopsAndAllowsSpokenFollowUp() {
        XCTAssertEqual(policy.shortcutAction(for: .idle), .startListening)
        XCTAssertEqual(policy.shortcutAction(for: .listening), .finishListening)
        XCTAssertEqual(policy.shortcutAction(for: .presenting), .startListening)
    }

    func testShortcutCannotInterruptProcessing() {
        XCTAssertEqual(policy.shortcutAction(for: .transcribing), .none)
        XCTAssertEqual(policy.shortcutAction(for: .capturing), .none)
        XCTAssertEqual(policy.shortcutAction(for: .thinking), .none)
    }

    func testEscapeCancelsOnlyActiveVoiceCapture() {
        XCTAssertEqual(policy.escapeAction(for: .listening), .cancel)
        XCTAssertEqual(policy.escapeAction(for: .thinking), .none)
        XCTAssertEqual(policy.escapeAction(for: .idle), .none)
    }
}

final class GuidanceAmbientPresentationPolicyTests: XCTestCase {
    func testVoiceTurnHasTruthfulDistinctAmbientStagesAndCompactContext() {
        let policy = GuidanceAmbientPresentationPolicy()
        let context = ScreenContextIdentity(applicationName: "Safari", windowTitle: "Billing")

        XCTAssertEqual(policy.presentation(for: .init(phase: .idle)).stage, .ready)
        XCTAssertEqual(
            policy.presentation(for: .init(phase: .listening, context: context)).stage,
            .listening
        )
        XCTAssertEqual(
            policy.presentation(
                for: .init(phase: .listening, partialTranscript: "How do I export this?", context: context)
            ).stage,
            .liveTranscript
        )
        XCTAssertEqual(policy.presentation(for: .init(phase: .capturing, context: context)).stage, .capturing)
        XCTAssertEqual(policy.presentation(for: .init(phase: .thinking, context: context)).stage, .thinking)
        XCTAssertEqual(
            policy.presentation(for: .init(phase: .presenting, context: context, isSpeaking: true)).stage,
            .speaking
        )
        XCTAssertEqual(
            policy.presentation(for: .init(phase: .presenting, context: context)).stage,
            .readyForFollowUp
        )
        XCTAssertEqual(
            policy.presentation(
                for: .init(
                    phase: .failed(
                        GuideFailure(stage: .guidance, message: "Could not answer.", recovery: "Try again.")
                    ),
                    context: context
                )
            ).stage,
            .error
        )
        XCTAssertEqual(
            policy.presentation(for: .init(phase: .idle, context: context, wasCancelled: true)).stage,
            .cancelled
        )
        XCTAssertEqual(
            policy.presentation(for: .init(phase: .thinking, context: context)).contextLabel,
            "Safari — Billing"
        )
    }
}

final class ScreenContextTargetPolicyTests: XCTestCase {
    func testRememberedInvocationTargetDoesNotChangeAfterAppSwitch() {
        let policy = ScreenContextTargetPolicy()

        XCTAssertEqual(
            policy.targetProcessIdentifier(
                remembered: 101,
                frontmost: 202,
                own: 999
            ),
            101
        )
    }
}
