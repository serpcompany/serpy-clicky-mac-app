import Testing
@testable import GuideTestSupport

@Suite("Golden user-flow harness")
struct GoldenUserFlowHarnessTests {
    @Test("GT-UF01-001 Permission explanation precedes request and denial exposes recovery")
    func permissionJourney() throws {
        var harness = GoldenUserFlowHarness(flow: .permissions)
        #expect(harness.phase == .permissionExplanation)
        try harness.apply(.continueFlow)
        #expect(harness.phase == .permissionRequestReady)
        try harness.apply(.deny)
        #expect(harness.phase == .permissionRecovery)
        #expect(harness.observableState.recoveryAction == "Open Settings")
    }

    @Test("GT-UF02-001 Lifecycle keeps one Settings window and no idle overlay")
    func lifecycleJourney() throws {
        var harness = GoldenUserFlowHarness(flow: .lifecycle)
        #expect(harness.observableState.windowCount == 1)
        #expect(harness.observableState.overlayCount == 0)
        try harness.apply(.closeSettings)
        #expect(harness.observableState.windowCount == 0)
        #expect(harness.observableState.applicationRunning)
        try harness.apply(.reopenSettings)
        #expect(harness.observableState.windowCount == 1)
        try harness.apply(.quit)
        #expect(!harness.observableState.applicationRunning)
    }

    @Test("GT-UF03-001 Dictation preserves transcript before reporting delivery")
    func dictationJourney() throws {
        var harness = GoldenUserFlowHarness(flow: .dictation)
        try harness.apply(.start)
        #expect(harness.phase == .listening)
        try harness.apply(.receivePartial("alpha beta"))
        #expect(harness.observableState.transcript == "alpha beta")
        try harness.apply(.stop)
        #expect(harness.observableState.transcriptPreserved)
        #expect(harness.phase == .deliveryConfirmed)
        #expect(harness.observableState.targetMutationCount == 1)
    }

    @Test("GT-UF04-001 Cancellation suppresses target mutation and late output", arguments: [
        GoldenHarnessPhase.listening,
        .transcribing,
        .inserting,
    ])
    func dictationCancellation(phase: GoldenHarnessPhase) throws {
        var harness = GoldenUserFlowHarness(flow: .cancelDictation, initialPhase: phase)
        try harness.apply(.cancel)
        try harness.apply(.lateResult("must be ignored"))
        #expect(harness.phase == .cancelled)
        #expect(harness.observableState.targetMutationCount == 0)
        #expect(harness.observableState.transcript.isEmpty)
    }

    @Test("GT-UF05-001 Recovery exposes Copy Retry Delete for bounded Last Dictation")
    func recoveryJourney() {
        let harness = GoldenUserFlowHarness(flow: .recovery)
        #expect(harness.phase == .recoveryAvailable)
        #expect(harness.observableState.availableActions == ["Copy", "Retry", "Delete"])
        #expect(harness.observableState.transcriptPreserved)
    }

    @Test("GT-UF08-001 Guide question reaches readable follow-up-ready answer")
    func guideQuestionJourney() throws {
        var harness = GoldenUserFlowHarness(flow: .guideQuestion)
        for expected in [GoldenHarnessPhase.listening, .transcribing, .capturing, .thinking, .speaking, .followUpReady] {
            try harness.apply(.continueFlow)
            #expect(harness.phase == expected)
        }
        #expect(harness.observableState.answer == "Open the File menu, then choose New Window.")
        #expect(!harness.observableState.hasTypingComposer)
        #expect(harness.observableState.autonomousActionCount == 0)
    }

    @Test("GT-UF09-001 Walkthrough advances only after fresh evidence")
    func walkthroughJourney() throws {
        var harness = GoldenUserFlowHarness(flow: .walkthrough)
        #expect(harness.observableState.stepLabel == "Step 1 of 2")
        try harness.apply(.staleEvidence)
        #expect(harness.observableState.stepLabel == "Step 1 of 2")
        try harness.apply(.freshEvidence)
        #expect(harness.observableState.stepLabel == "Step 2 of 2")
        try harness.apply(.freshEvidence)
        #expect(harness.phase == .completed)
        #expect(harness.observableState.autonomousActionCount == 0)
    }

    @Test("GT-UF10-001 Guide cancellation clears UI and suppresses late output", arguments: [
        GoldenHarnessPhase.listening,
        .capturing,
        .thinking,
        .speaking,
        .followUpReady,
    ])
    func guideCancellation(phase: GoldenHarnessPhase) throws {
        var harness = GoldenUserFlowHarness(flow: .cancelGuide, initialPhase: phase)
        try harness.apply(.cancel)
        try harness.apply(.lateResult("must be ignored"))
        #expect(harness.phase == .cancelled)
        #expect(harness.observableState.overlayCount == 0)
        #expect(harness.observableState.answer.isEmpty)
    }

    @Test("GT-UF11-001 OpenAI fixture requires selection disclosure and verified credential")
    func openAITalkJourney() throws {
        var harness = GoldenUserFlowHarness(flow: .openAITalk)
        try harness.apply(.selectProvider)
        try harness.apply(.acceptDisclosure)
        #expect(harness.phase == .credentialRequired)
        try harness.apply(.verifyFixtureCredential)
        #expect(harness.phase == .fixtureResponse)
        #expect(harness.observableState.networkRequestCount == 0)
        #expect(harness.observableState.credentialStorage == .memoryOnly)
    }

    @Test("GT-UF12-001 Malformed guidance exposes stage cause recovery and in-memory incident")
    func diagnosticJourney() {
        let harness = GoldenUserFlowHarness(flow: .diagnostics)
        #expect(harness.phase == .handledFailure)
        #expect(harness.observableState.failureStage == "generation")
        #expect(harness.observableState.failureCause == "The local guide returned malformed structured guidance.")
        #expect(harness.observableState.recoveryAction == "Try Again")
        #expect(harness.observableState.incidentCodes == ["guidance.plan.malformed"])
        #expect(harness.observableState.networkRequestCount == 0)
    }
}
