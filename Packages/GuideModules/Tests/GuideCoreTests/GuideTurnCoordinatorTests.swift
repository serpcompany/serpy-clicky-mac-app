import CoreGraphics
import GuideCore
import XCTest

@MainActor
final class GuideTurnCoordinatorTests: XCTestCase {
    func testAmbientTurnLocksTargetBeforeListeningAndAnswersWithFreshContext() async throws {
        let target = GuideWindowTarget(
            processIdentifier: 41,
            windowIdentifier: 901,
            applicationName: "Fixture App",
            windowTitle: "Unique phrase",
            frame: CGRect(x: 40, y: 50, width: 900, height: 700)
        )
        let events = EventRecorder()
        let context = ScreenContext(
            applicationName: target.applicationName,
            windowTitle: target.windowTitle,
            windowFrame: target.frame,
            textBlocks: [.init(text: "ORCHID RIVER 731", normalizedBounds: .zero, confidence: 0.99)]
        )
        let capture = FakeCapture(target: target, context: context, events: events)
        let transcription = FakeTranscription(result: "What phrase is visible?", events: events)
        let generation = FakeGeneration(answer: "The visible phrase is ORCHID RIVER 731.", events: events)
        let speech = FakeSpeech(events: events)
        let overlay = FakeOverlay(events: events)
        let coordinator = GuideTurnCoordinator(
            capture: capture,
            transcription: transcription,
            generation: generation,
            speech: speech,
            overlay: overlay
        )

        try coordinator.start()
        await Task.yield()
        coordinator.finishListening()
        await coordinator.waitUntilIdle()

        XCTAssertEqual(events.values.first, "target:901")
        XCTAssertLessThan(
            try XCTUnwrap(events.values.firstIndex(of: "present:listening")),
            try XCTUnwrap(events.values.firstIndex(of: "capture:901"))
        )
        XCTAssertEqual(capture.capturedTargets, [target])
        XCTAssertEqual(generation.receivedContexts.first?.promptText, "ORCHID RIVER 731")
        XCTAssertEqual(coordinator.conversation.map(\.content), [
            "What phrase is visible?",
            "The visible phrase is ORCHID RIVER 731."
        ])
        XCTAssertEqual(overlay.presentations.last?.stage, .readyForFollowUp)
    }

    func testCancellingListeningStopsEveryBoundaryAndReturnsThroughCancelledToReady() async throws {
        let events = EventRecorder()
        let target = fixtureTarget
        let capture = FakeCapture(target: target, context: fixtureContext(target), events: events)
        let transcription = FakeTranscription(result: "unused", events: events)
        let speech = FakeSpeech(events: events)
        let overlay = FakeOverlay(events: events)
        let coordinator = GuideTurnCoordinator(
            capture: capture,
            transcription: transcription,
            generation: FakeGeneration(answer: "unused", events: events),
            speech: speech,
            overlay: overlay
        )

        try coordinator.start()
        await Task.yield()
        coordinator.cancel()
        coordinator.cancel()
        await coordinator.waitUntilIdle()

        XCTAssertTrue(events.values.contains("transcription:cancel"))
        XCTAssertTrue(events.values.contains("speech:stop"))
        XCTAssertTrue(events.values.contains("response:dismiss"))
        XCTAssertEqual(overlay.presentations.last?.stage, .cancelled)
        XCTAssertEqual(overlay.presentations.last?.target, target)
        XCTAssertEqual(overlay.scheduledRestoreDelays, [.milliseconds(1_200)])
        XCTAssertTrue(coordinator.conversation.isEmpty)
    }

    func testImmediateCancellationBeforeTurnTaskRunsStartsNoSystemBoundaryWork() async throws {
        let events = EventRecorder()
        let target = fixtureTarget
        let coordinator = GuideTurnCoordinator(
            capture: FakeCapture(target: target, context: fixtureContext(target), events: events),
            transcription: FakeTranscription(result: "must not be used", events: events),
            generation: FakeGeneration(answer: "must not appear", events: events),
            speech: FakeSpeech(events: events),
            overlay: FakeOverlay(events: events)
        )

        try coordinator.start()
        coordinator.cancel()
        await coordinator.waitUntilIdle()

        XCTAssertFalse(events.values.contains("transcription:start"))
        XCTAssertFalse(events.values.contains { $0.hasPrefix("capture:") })
        XCTAssertFalse(events.values.contains("generation"))
        XCTAssertFalse(events.values.contains("speech"))
        XCTAssertTrue(coordinator.conversation.isEmpty)
    }

    func testCancellingWhileExactWindowCaptureIsPendingCannotProduceAnAnswer() async throws {
        let events = EventRecorder()
        let target = fixtureTarget
        let capture = BlockingCapture(target: target, events: events)
        let overlay = FakeOverlay(events: events)
        let coordinator = GuideTurnCoordinator(
            capture: capture,
            transcription: FakeTranscription(result: "What phrase is visible?", events: events),
            generation: FakeGeneration(answer: "must not appear", events: events),
            speech: FakeSpeech(events: events),
            overlay: overlay
        )

        try coordinator.start()
        await wait(for: "capture:pending", in: events)
        coordinator.finishListening()
        await wait(for: "present:capturing", in: events)
        XCTAssertEqual(coordinator.phase, .capturing)
        coordinator.cancel()
        await coordinator.waitUntilIdle()

        XCTAssertFalse(events.values.contains("generation"))
        XCTAssertTrue(coordinator.conversation.isEmpty)
        XCTAssertEqual(overlay.presentations.last?.stage, .cancelled)
    }

    func testCancellationRetainsTaskOwnershipUntilStructuredWorkTerminates() async throws {
        let events = EventRecorder()
        let target = fixtureTarget
        let coordinator = GuideTurnCoordinator(
            capture: BlockingCapture(target: target, events: events),
            transcription: FakeTranscription(result: "unused", events: events),
            generation: FakeGeneration(answer: "unused", events: events),
            speech: FakeSpeech(events: events),
            overlay: FakeOverlay(events: events)
        )

        try coordinator.start()
        await wait(for: "capture:pending", in: events)
        coordinator.cancel()
        XCTAssertThrowsError(try coordinator.start(target: target)) { error in
            XCTAssertEqual(error as? GuidanceConversationError, .turnAlreadyActive)
        }
        await coordinator.waitUntilIdle()
        XCTAssertNoThrow(try coordinator.start(target: target))
        coordinator.cancel()
        await coordinator.waitUntilIdle()
    }

    func testCaptureFailurePreservesStageCauseAndExactRecovery() async throws {
        let events = EventRecorder()
        let target = fixtureTarget
        let overlay = FakeOverlay(events: events)
        let failure = GuideFailure(
            stage: .capture,
            message: "The selected window disappeared.",
            recovery: "Bring that exact window forward and start again."
        )
        let coordinator = GuideTurnCoordinator(
            capture: FailingCapture(target: target, failure: failure),
            transcription: FakeTranscription(result: "Where is it?", events: events),
            generation: FakeGeneration(answer: "unused", events: events),
            speech: FakeSpeech(events: events),
            overlay: overlay
        )

        try coordinator.start()
        await Task.yield()
        coordinator.finishListening()
        await coordinator.waitUntilIdle()

        XCTAssertEqual(overlay.presentations.last?.failure, failure)
        XCTAssertEqual(overlay.scheduledRestoreDelays, [.seconds(4)])
    }

    func testCancellingWhileThinkingDiscardsTheUnfinishedTurn() async throws {
        let events = EventRecorder()
        let target = fixtureTarget
        let overlay = FakeOverlay(events: events)
        let coordinator = GuideTurnCoordinator(
            capture: FakeCapture(target: target, context: fixtureContext(target), events: events),
            transcription: FakeTranscription(result: "What phrase is visible?", events: events),
            generation: BlockingGeneration(events: events),
            speech: FakeSpeech(events: events),
            overlay: overlay
        )

        try coordinator.start()
        await Task.yield()
        coordinator.finishListening()
        await wait(for: "generation:pending", in: events)
        XCTAssertEqual(coordinator.phase, .thinking)
        coordinator.cancel()
        await coordinator.waitUntilIdle()

        XCTAssertFalse(events.values.contains("speech"))
        XCTAssertTrue(coordinator.conversation.isEmpty)
        XCTAssertEqual(overlay.presentations.last?.stage, .cancelled)
    }

    func testCancellingStreamingGenerationCancelsProviderAndCannotRevealLateText() async throws {
        let events = EventRecorder()
        let target = fixtureTarget
        let generation = BlockingStreamingGeneration(events: events)
        let overlay = FakeOverlay(events: events)
        let coordinator = GuideTurnCoordinator(
            capture: FakeCapture(target: target, context: fixtureContext(target), events: events),
            transcription: FakeTranscription(result: "What phrase is visible?", events: events),
            generation: generation,
            speech: FakeSpeech(events: events),
            overlay: overlay
        )

        try coordinator.start()
        await Task.yield()
        coordinator.finishListening()
        await wait(for: "generation:stream-pending", in: events)
        coordinator.cancel()
        generation.attemptLateText()
        await coordinator.waitUntilIdle()

        XCTAssertTrue(events.values.contains("generation:cancel"))
        XCTAssertFalse(overlay.presentations.contains { $0.responseText.contains("late answer") })
        XCTAssertTrue(coordinator.conversation.isEmpty)
        XCTAssertEqual(overlay.presentations.last?.stage, .cancelled)
    }

    func testCancellingWhileSpeakingStopsAudioAndDismissesTheReadableAnswer() async throws {
        let events = EventRecorder()
        let target = fixtureTarget
        let overlay = FakeOverlay(events: events)
        let speech = BlockingSpeech(events: events)
        let coordinator = GuideTurnCoordinator(
            capture: FakeCapture(target: target, context: fixtureContext(target), events: events),
            transcription: FakeTranscription(result: "What phrase is visible?", events: events),
            generation: FakeGeneration(answer: "The phrase is ORCHID RIVER 731.", events: events),
            speech: speech,
            overlay: overlay
        )

        try coordinator.start()
        await Task.yield()
        coordinator.finishListening()
        await wait(for: "speech:pending", in: events)
        XCTAssertEqual(coordinator.phase, .presenting)
        XCTAssertFalse(overlay.presentations.last?.responseText.isEmpty == true)
        coordinator.cancel()
        await coordinator.waitUntilIdle()

        XCTAssertTrue(events.values.contains("speech:stop"))
        XCTAssertTrue(events.values.contains("response:dismiss"))
        XCTAssertEqual(overlay.presentations.last?.stage, .cancelled)
    }

    func testCompleteAnswerReachesConversationAmbientPresentationAndSpeechWithoutTruncation() async throws {
        let events = EventRecorder()
        let target = fixtureTarget
        let complete = (1...70).map { "word\($0)" }.joined(separator: " ")
        let speech = FakeSpeech(events: events)
        let overlay = FakeOverlay(events: events)
        let coordinator = GuideTurnCoordinator(
            capture: FakeCapture(target: target, context: fixtureContext(target), events: events),
            transcription: FakeTranscription(result: "Explain this", events: events),
            generation: FakeGeneration(answer: complete, events: events),
            speech: speech,
            overlay: overlay
        )

        try coordinator.start()
        await Task.yield()
        coordinator.finishListening()
        await coordinator.waitUntilIdle()

        XCTAssertEqual(coordinator.conversation.last?.content, complete)
        XCTAssertEqual(overlay.presentations.last?.responseText, complete)
        XCTAssertEqual(speech.spokenTexts.last, complete)
    }

    func testStreamingAnswerAppearsIncrementallyAndSpeaksOnlyCompleteSentences() async throws {
        let events = EventRecorder()
        let target = fixtureTarget
        let speech = FakeSpeech(events: events)
        let overlay = FakeOverlay(events: events)
        let coordinator = GuideTurnCoordinator(
            capture: FakeCapture(target: target, context: fixtureContext(target), events: events),
            transcription: FakeTranscription(result: "What phrase is visible?", events: events),
            generation: FakeStreamingGeneration(events: events),
            speech: speech,
            overlay: overlay
        )

        try coordinator.start()
        await Task.yield()
        coordinator.finishListening()
        await coordinator.waitUntilIdle()

        let streamedTexts = overlay.presentations
            .filter { $0.statusText == "Answering…" }
            .map(\.responseText)
        XCTAssertEqual(streamedTexts, ["The phrase is", "The phrase is ORCHID RIVER 731. Next step"])
        XCTAssertEqual(speech.spokenTexts, ["The phrase is ORCHID RIVER 731.", "Next step"])
        XCTAssertEqual(coordinator.conversation.last?.content, "The phrase is ORCHID RIVER 731. Next step")
    }

    func testValidatedSpatialPointIsPresentedWithoutPointerControl() async throws {
        let events = EventRecorder()
        let target = fixtureTarget
        let overlay = FakeOverlay(events: events)
        let coordinator = GuideTurnCoordinator(
            capture: FakeCapture(target: target, context: fixtureContext(target), events: events),
            transcription: FakeTranscription(result: "Where is the control?", events: events),
            generation: FakeSpatialStreamingGeneration(events: events),
            speech: FakeSpeech(events: events),
            overlay: overlay
        )

        try coordinator.start()
        await Task.yield()
        coordinator.finishListening()
        await coordinator.waitUntilIdle()

        XCTAssertEqual(
            overlay.presentations.last?.pointCue,
            GuidePointCue(target: target, normalizedPoint: CGPoint(x: 0.25, y: 0.75), label: "Continue")
        )
        XCTAssertFalse(events.values.contains("pointer:move"))
        XCTAssertFalse(events.values.contains("pointer:click"))
    }

    func testFollowUpLocksFreshWindowContextAndReceivesPriorConversation() async throws {
        let events = EventRecorder()
        let secondTarget = GuideWindowTarget(
            processIdentifier: 52,
            windowIdentifier: 902,
            applicationName: "Fixture App",
            windowTitle: "Updated phrase",
            frame: fixtureTarget.frame
        )
        let capture = SequenceCapture(targets: [fixtureTarget, secondTarget], events: events)
        let generation = SequenceGeneration(events: events)
        let coordinator = GuideTurnCoordinator(
            capture: capture,
            transcription: SequenceTranscription(
                results: ["What phrase is visible?", "What changed?"],
                events: events
            ),
            generation: generation,
            speech: FakeSpeech(events: events),
            overlay: FakeOverlay(events: events)
        )

        try coordinator.start()
        await Task.yield()
        coordinator.finishListening()
        await coordinator.waitUntilIdle()
        try coordinator.start()
        await Task.yield()
        coordinator.finishListening()
        await coordinator.waitUntilIdle()

        XCTAssertEqual(capture.capturedWindowIDs, [901, 902])
        XCTAssertEqual(generation.receivedConversations.count, 2)
        XCTAssertEqual(generation.receivedConversations[1].map(\.content), [
            "What phrase is visible?",
            "Answer for Unique phrase"
        ])
        XCTAssertEqual(coordinator.conversation.last?.content, "Answer for Updated phrase")
    }

    func testExplicitReinvocationUsesFreshCaptureAndShowsOnlyTheAdvancedStep() async throws {
        let events = EventRecorder()
        let updatedTarget = GuideWindowTarget(
            processIdentifier: fixtureTarget.processIdentifier,
            windowIdentifier: 902,
            applicationName: fixtureTarget.applicationName,
            windowTitle: "Updated phrase",
            frame: fixtureTarget.frame
        )
        let capture = SequenceCapture(targets: [fixtureTarget, updatedTarget], events: events)
        let generation = PlanGeneration(events: events)
        let overlay = FakeOverlay(events: events)
        let coordinator = GuideTurnCoordinator(
            capture: capture,
            transcription: SequenceTranscription(results: ["Show me how", "Next"], events: events),
            generation: generation,
            speech: FakeSpeech(events: events),
            overlay: overlay
        )

        try coordinator.start()
        await Task.yield()
        coordinator.finishListening()
        await coordinator.waitUntilIdle()
        XCTAssertEqual(overlay.presentations.last?.stepNumber, 1)
        XCTAssertEqual(overlay.presentations.last?.stepCount, 2)
        XCTAssertEqual(overlay.presentations.last?.responseText, "Open File.")

        try coordinator.start()
        await Task.yield()
        coordinator.finishListening()
        await coordinator.waitUntilIdle()

        XCTAssertEqual(capture.capturedWindowIDs, [901, 902])
        XCTAssertEqual(generation.requestCount, 1)
        XCTAssertEqual(overlay.presentations.last?.stepNumber, 2)
        XCTAssertEqual(overlay.presentations.last?.responseText, "Choose New Window.")
        XCTAssertNil(overlay.presentations.last?.pointCue)
    }

    func testStructuredStreamingPlanSpeaksOnlyTheActiveStepExactlyOnce() async throws {
        let events = EventRecorder()
        let speech = FakeSpeech(events: events)
        let overlay = FakeOverlay(events: events)
        let coordinator = GuideTurnCoordinator(
            capture: FakeCapture(target: fixtureTarget, context: fixtureContext(fixtureTarget), events: events),
            transcription: FakeTranscription(result: "Show me how", events: events),
            generation: StreamingPlanGeneration(),
            speech: speech,
            overlay: overlay
        )

        try coordinator.start()
        await Task.yield()
        coordinator.finishListening()
        await coordinator.waitUntilIdle()

        XCTAssertEqual(speech.spokenTexts, ["Open File."])
        XCTAssertEqual(overlay.presentations.last?.responseText, "Open File.")
        XCTAssertEqual(overlay.presentations.last?.stepNumber, 1)
    }

    func testCancellationAtReadyForFollowUpClearsPlanCueAndPendingProgressionIdempotently() async throws {
        let events = EventRecorder()
        let generation = PlanGeneration(events: events)
        let overlay = FakeOverlay(events: events)
        let coordinator = GuideTurnCoordinator(
            capture: FakeCapture(target: fixtureTarget, context: fixtureContext(fixtureTarget), events: events),
            transcription: FakeTranscription(result: "Show me how", events: events),
            generation: generation,
            speech: FakeSpeech(events: events),
            overlay: overlay
        )

        try coordinator.start()
        await Task.yield()
        coordinator.finishListening()
        await coordinator.waitUntilIdle()
        XCTAssertEqual(coordinator.phase, .presenting)

        coordinator.cancel()
        coordinator.cancel()

        XCTAssertEqual(coordinator.phase, .idle)
        XCTAssertEqual(overlay.presentations.last?.stage, .cancelled)
        XCTAssertEqual(overlay.scheduledRestoreDelays, [.milliseconds(1_200)])
        XCTAssertEqual(events.values.filter { $0 == "response:dismiss" }.count, 2)
    }

    func testResetConversationClearsThePresentedCueAtTheCoordinatorSeam() async throws {
        let events = EventRecorder()
        let overlay = FakeOverlay(events: events)
        let coordinator = GuideTurnCoordinator(
            capture: FakeCapture(target: fixtureTarget, context: fixtureContext(fixtureTarget), events: events),
            transcription: FakeTranscription(result: "Show me how", events: events),
            generation: PlanGeneration(events: events),
            speech: FakeSpeech(events: events),
            overlay: overlay
        )
        try coordinator.start()
        await Task.yield()
        coordinator.finishListening()
        await coordinator.waitUntilIdle()
        let dismissalsBeforeReset = events.values.filter { $0 == "response:dismiss" }.count

        coordinator.resetConversation()

        XCTAssertEqual(coordinator.phase, .idle)
        XCTAssertEqual(events.values.filter { $0 == "response:dismiss" }.count, dismissalsBeforeReset + 1)
    }

    func testSpeechFailureKeepsTheSanitizedVisibleAnswerAndRecovery() async throws {
        let events = EventRecorder()
        let overlay = FakeOverlay(events: events)
        let coordinator = GuideTurnCoordinator(
            capture: FakeCapture(target: fixtureTarget, context: fixtureContext(fixtureTarget), events: events),
            transcription: FakeTranscription(result: "What is visible?", events: events),
            generation: FakeGeneration(answer: "“Read this answer.”", events: events),
            speech: FailingSpeech(),
            overlay: overlay
        )

        try coordinator.start()
        await Task.yield()
        coordinator.finishListening()
        await coordinator.waitUntilIdle()

        XCTAssertEqual(overlay.presentations.last?.stage, .error)
        XCTAssertEqual(overlay.presentations.last?.responseText, "Read this answer.")
        XCTAssertEqual(overlay.presentations.last?.failure?.stage, .presentation)
    }

    private var fixtureTarget: GuideWindowTarget {
        GuideWindowTarget(
            processIdentifier: 41,
            windowIdentifier: 901,
            applicationName: "Fixture App",
            windowTitle: "Unique phrase",
            frame: CGRect(x: 40, y: 50, width: 900, height: 700)
        )
    }

    private func fixtureContext(_ target: GuideWindowTarget) -> ScreenContext {
        ScreenContext(
            applicationName: target.applicationName,
            windowTitle: target.windowTitle,
            windowFrame: target.frame,
            textBlocks: [.init(text: "ORCHID RIVER 731", normalizedBounds: .zero, confidence: 0.99)]
        )
    }

    private func wait(for event: String, in recorder: EventRecorder) async {
        for _ in 0..<2_000 {
            if recorder.values.contains(event) { return }
            await Task.yield()
        }
        XCTFail("Timed out waiting for \(event)")
    }
}

final class ExactWindowTargetPolicyTests: XCTestCase {
    func testFrontToBackCandidateLocksTheVisibleWindowAmongSameProcessWindows() throws {
        let policy = ExactWindowTargetPolicy()
        let front = GuideWindowTarget(
            processIdentifier: 101,
            windowIdentifier: 42,
            applicationName: "ChatGPT",
            windowTitle: "Billing",
            frame: CGRect(x: 10, y: 20, width: 800, height: 600)
        )
        let behind = GuideWindowTarget(
            processIdentifier: 101,
            windowIdentifier: 41,
            applicationName: "ChatGPT",
            windowTitle: "Other chat",
            frame: CGRect(x: 80, y: 90, width: 700, height: 500)
        )

        XCTAssertEqual(try policy.lockTarget(frontToBack: [front, behind], processIdentifier: 101), front)
    }

    func testMissingLockedWindowDoesNotFallBackToSiblingFromSameProcess() throws {
        let policy = ExactWindowTargetPolicy()
        let locked = GuideWindowTarget(
            processIdentifier: 101,
            windowIdentifier: 42,
            applicationName: "ChatGPT",
            windowTitle: "Billing",
            frame: CGRect(x: 10, y: 20, width: 800, height: 600)
        )
        let sibling = GuideWindowTarget(
            processIdentifier: 101,
            windowIdentifier: 41,
            applicationName: "ChatGPT",
            windowTitle: "Other chat",
            frame: CGRect(x: 80, y: 90, width: 700, height: 500)
        )

        XCTAssertThrowsError(try policy.resolveExactTarget(locked, available: [sibling])) { error in
            XCTAssertEqual((error as? GuideFailure)?.stage, .capture)
        }
    }
}

@MainActor
private final class EventRecorder {
    var values: [String] = []
}

@MainActor
private final class FakeCapture: GuideTurnContextCapturing, @unchecked Sendable {
    let target: GuideWindowTarget
    let context: ScreenContext
    let events: EventRecorder
    var capturedTargets: [GuideWindowTarget] = []

    init(target: GuideWindowTarget, context: ScreenContext, events: EventRecorder) {
        self.target = target
        self.context = context
        self.events = events
    }

    func snapshotTarget() throws -> GuideWindowTarget {
        events.values.append("target:\(target.windowIdentifier)")
        return target
    }

    nonisolated func capture(_ target: GuideWindowTarget) async throws -> ScreenContext {
        await MainActor.run {
            events.values.append("capture:\(target.windowIdentifier)")
            capturedTargets.append(target)
        }
        return context
    }
}

@MainActor
private final class BlockingCapture: GuideTurnContextCapturing, @unchecked Sendable {
    let target: GuideWindowTarget
    let events: EventRecorder

    init(target: GuideWindowTarget, events: EventRecorder) {
        self.target = target
        self.events = events
    }

    func snapshotTarget() throws -> GuideWindowTarget {
        events.values.append("target:\(target.windowIdentifier)")
        return target
    }

    nonisolated func capture(_ target: GuideWindowTarget) async throws -> ScreenContext {
        await MainActor.run { events.values.append("capture:pending") }
        while !Task.isCancelled { await Task.yield() }
        throw CancellationError()
    }
}

@MainActor
private final class FailingCapture: GuideTurnContextCapturing, @unchecked Sendable {
    let target: GuideWindowTarget
    let failure: GuideFailure

    init(target: GuideWindowTarget, failure: GuideFailure) {
        self.target = target
        self.failure = failure
    }

    func snapshotTarget() throws -> GuideWindowTarget { target }

    nonisolated func capture(_ target: GuideWindowTarget) async throws -> ScreenContext {
        throw failure
    }
}

@MainActor
private final class SequenceCapture: GuideTurnContextCapturing, @unchecked Sendable {
    private var targets: [GuideWindowTarget]
    let events: EventRecorder
    var capturedWindowIDs: [UInt32] = []

    init(targets: [GuideWindowTarget], events: EventRecorder) {
        self.targets = targets
        self.events = events
    }

    func snapshotTarget() throws -> GuideWindowTarget {
        targets.removeFirst()
    }

    nonisolated func capture(_ target: GuideWindowTarget) async throws -> ScreenContext {
        await MainActor.run { capturedWindowIDs.append(target.windowIdentifier) }
        return ScreenContext(
            applicationName: target.applicationName,
            windowTitle: target.windowTitle,
            windowFrame: target.frame,
            textBlocks: [.init(text: target.windowTitle, normalizedBounds: .zero, confidence: 0.99)]
        )
    }
}

@MainActor
private final class FakeTranscription: GuideTurnTranscribing {
    let result: String
    let events: EventRecorder

    init(result: String, events: EventRecorder) {
        self.result = result
        self.events = events
    }

    func start(onPartial: @escaping @MainActor @Sendable (String) -> Void) throws {
        events.values.append("transcription:start")
    }

    func stop() async throws -> String {
        events.values.append("transcription:stop")
        return result
    }

    func cancel() {
        events.values.append("transcription:cancel")
    }
}

@MainActor
private final class SequenceTranscription: GuideTurnTranscribing {
    private var results: [String]
    let events: EventRecorder

    init(results: [String], events: EventRecorder) {
        self.results = results
        self.events = events
    }

    func start(onPartial: @escaping @MainActor @Sendable (String) -> Void) throws {}

    func stop() async throws -> String {
        results.removeFirst()
    }

    func cancel() {}
}

@MainActor
private final class FakeGeneration: GuideTurnGenerating {
    let answer: String
    let events: EventRecorder
    var receivedContexts: [ScreenContext] = []

    init(answer: String, events: EventRecorder) {
        self.answer = answer
        self.events = events
    }

    func answer(
        question: String,
        context: ScreenContext,
        conversation: [GuidanceMessage]
    ) async throws -> GuidancePlan {
        events.values.append("generation")
        receivedContexts.append(context)
        return GuidancePlan(answer: answer, confidence: 0.7)
    }
}

@MainActor
private final class BlockingGeneration: GuideTurnGenerating {
    let events: EventRecorder

    init(events: EventRecorder) {
        self.events = events
    }

    func answer(
        question: String,
        context: ScreenContext,
        conversation: [GuidanceMessage]
    ) async throws -> GuidancePlan {
        events.values.append("generation:pending")
        while !Task.isCancelled { await Task.yield() }
        throw CancellationError()
    }
}

@MainActor
private final class FakeStreamingGeneration: GuideTurnStreamingGenerating {
    let events: EventRecorder
    let thinkingStatusText = "Looking at this window with fixture provider…"

    init(events: EventRecorder) {
        self.events = events
    }

    func answer(
        question: String,
        context: ScreenContext,
        conversation: [GuidanceMessage]
    ) async throws -> GuidancePlan {
        XCTFail("Streaming coordinator must not call the legacy answer seam")
        return GuidancePlan(answer: "", confidence: 0)
    }

    func streamAnswer(
        question: String,
        target: GuideWindowTarget,
        context: ScreenContext,
        conversation: [GuidanceMessage]
    ) throws -> AsyncThrowingStream<GuidanceStreamEvent, Error> {
        events.values.append("generation:stream")
        return AsyncThrowingStream { continuation in
            continuation.yield(.textDelta("The phrase is "))
            continuation.yield(.textDelta("ORCHID RIVER 731. Next step"))
            continuation.yield(.sentenceReady("The phrase is ORCHID RIVER 731."))
            continuation.yield(.sentenceReady("Next step"))
            continuation.yield(.completed)
            continuation.finish()
        }
    }

    func cancelGeneration() {
        events.values.append("generation:cancel")
    }
}

@MainActor
private final class FakeSpatialStreamingGeneration: GuideTurnStreamingGenerating {
    let events: EventRecorder
    let thinkingStatusText = "Looking at this window with fixture provider…"

    init(events: EventRecorder) { self.events = events }

    func answer(question: String, context: ScreenContext, conversation: [GuidanceMessage]) async throws -> GuidancePlan {
        GuidancePlan(answer: "unused", confidence: 0)
    }

    func streamAnswer(
        question: String,
        target: GuideWindowTarget,
        context: ScreenContext,
        conversation: [GuidanceMessage]
    ) throws -> AsyncThrowingStream<GuidanceStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(.textDelta("Select Continue."))
            continuation.yield(.sentenceReady("Select Continue."))
            continuation.yield(.spatialAction(.point(
                evidenceID: "locked-window",
                normalizedPoint: CGPoint(x: 0.25, y: 0.75),
                confidence: 0.92,
                label: "Continue"
            )))
            continuation.yield(.completed)
            continuation.finish()
        }
    }

    func cancelGeneration() {}
}

@MainActor
private final class BlockingStreamingGeneration: GuideTurnStreamingGenerating {
    let events: EventRecorder
    let thinkingStatusText = "Looking at this window with fixture provider…"
    private var continuation: AsyncThrowingStream<GuidanceStreamEvent, Error>.Continuation?

    init(events: EventRecorder) { self.events = events }

    func answer(
        question: String,
        context: ScreenContext,
        conversation: [GuidanceMessage]
    ) async throws -> GuidancePlan {
        GuidancePlan(answer: "unused", confidence: 0)
    }

    func streamAnswer(
        question: String,
        target: GuideWindowTarget,
        context: ScreenContext,
        conversation: [GuidanceMessage]
    ) throws -> AsyncThrowingStream<GuidanceStreamEvent, Error> {
        events.values.append("generation:stream-pending")
        return AsyncThrowingStream { continuation in self.continuation = continuation }
    }

    func cancelGeneration() {
        events.values.append("generation:cancel")
        continuation?.finish(throwing: CancellationError())
        continuation = nil
    }

    func attemptLateText() {
        continuation?.yield(.textDelta("late answer"))
    }
}

@MainActor
private final class SequenceGeneration: GuideTurnGenerating {
    let events: EventRecorder
    var receivedConversations: [[GuidanceMessage]] = []

    init(events: EventRecorder) {
        self.events = events
    }

    func answer(
        question: String,
        context: ScreenContext,
        conversation: [GuidanceMessage]
    ) async throws -> GuidancePlan {
        receivedConversations.append(conversation)
        return GuidancePlan(answer: "Answer for \(context.windowTitle)", confidence: 0.7)
    }
}

@MainActor
private final class PlanGeneration: GuideTurnGenerating {
    let events: EventRecorder
    var requestCount = 0

    init(events: EventRecorder) { self.events = events }

    func answer(question: String, context: ScreenContext, conversation: [GuidanceMessage]) async throws -> GuidancePlan {
        requestCount += 1
        return GuidancePlan(
            answer: "Open a new window.",
            confidence: 0.96,
            steps: [
                GuidanceStep(id: 1, text: "Open File.", completionEvidence: ["Updated phrase"]),
                GuidanceStep(
                    id: 2,
                    text: "Choose New Window.",
                    point: GuidanceStepPoint(normalizedPoint: CGPoint(x: 0.25, y: 0.2), confidence: 0.96, label: "New Window"),
                    completionEvidence: ["Done"]
                )
            ]
        )
    }
}

@MainActor
private final class StreamingPlanGeneration: GuideTurnStreamingGenerating {
    let thinkingStatusText = "Planning…"

    func answer(question: String, context: ScreenContext, conversation: [GuidanceMessage]) async throws -> GuidancePlan {
        GuidancePlan(answer: "unused", confidence: 0)
    }

    func streamAnswer(
        question: String,
        target: GuideWindowTarget,
        context: ScreenContext,
        conversation: [GuidanceMessage]
    ) throws -> AsyncThrowingStream<GuidanceStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let plan = GuidancePlan(
                answer: "Open a new window.",
                confidence: 0.96,
                steps: [
                    GuidanceStep(id: 1, text: "Open File.", completionEvidence: ["New Window"]),
                    GuidanceStep(id: 2, text: "Choose New Window.", completionEvidence: ["New Tab"])
                ]
            )
            continuation.yield(.textDelta(plan.answer))
            continuation.yield(.sentenceReady(plan.answer))
            continuation.yield(.planReady(plan))
            continuation.yield(.completed)
            continuation.finish()
        }
    }

    func cancelGeneration() {}
}

@MainActor
private final class FakeSpeech: GuideTurnSpeaking {
    let events: EventRecorder
    var spokenTexts: [String] = []

    init(events: EventRecorder) {
        self.events = events
    }

    func speak(_ text: String) async throws {
        events.values.append("speech")
        spokenTexts.append(text)
    }

    func stop() {
        events.values.append("speech:stop")
    }
}

@MainActor
private final class BlockingSpeech: GuideTurnSpeaking {
    let events: EventRecorder

    init(events: EventRecorder) {
        self.events = events
    }

    func speak(_ text: String) async throws {
        events.values.append("speech:pending")
        while !Task.isCancelled { await Task.yield() }
        throw CancellationError()
    }

    func stop() {
        events.values.append("speech:stop")
    }
}

@MainActor
private final class FailingSpeech: GuideTurnSpeaking {
    func speak(_ text: String) async throws {
        throw GuideFailure(
            stage: .presentation,
            message: "Speech output is unavailable.",
            recovery: "Read the visible answer and check sound output."
        )
    }

    func stop() {}
}

@MainActor
private final class FakeOverlay: GuideTurnOverlayPresenting {
    let events: EventRecorder
    var presentations: [GuideTurnPresentation] = []
    var scheduledRestoreDelays: [Duration] = []

    init(events: EventRecorder) {
        self.events = events
    }

    func present(_ presentation: GuideTurnPresentation) {
        events.values.append("present:\(presentation.stage)")
        presentations.append(presentation)
    }

    func dismissResponse() {
        events.values.append("response:dismiss")
    }

    func restoreIdleVisibility(after delay: Duration) {
        events.values.append("visibility:restore-scheduled")
        scheduledRestoreDelays.append(delay)
    }
}
