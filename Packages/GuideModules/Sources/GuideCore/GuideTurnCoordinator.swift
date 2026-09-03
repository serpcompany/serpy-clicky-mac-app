import CoreGraphics
import Foundation

public struct GuideWindowTarget: Equatable, Sendable {
    public let processIdentifier: Int32
    public let windowIdentifier: UInt32
    public let applicationName: String
    public let windowTitle: String
    public let frame: CGRect

    public init(
        processIdentifier: Int32,
        windowIdentifier: UInt32,
        applicationName: String,
        windowTitle: String,
        frame: CGRect
    ) {
        self.processIdentifier = processIdentifier
        self.windowIdentifier = windowIdentifier
        self.applicationName = applicationName
        self.windowTitle = windowTitle
        self.frame = frame
    }

    public var identity: ScreenContextIdentity {
        ScreenContextIdentity(applicationName: applicationName, windowTitle: windowTitle)
    }
}

public protocol GuideTurnContextCapturing: AnyObject, Sendable {
    @MainActor
    func snapshotTarget() throws -> GuideWindowTarget
    func capture(_ target: GuideWindowTarget) async throws -> ScreenContext
}

@MainActor
public protocol GuideTurnTranscribing: AnyObject {
    func start(onPartial: @escaping @MainActor @Sendable (String) -> Void) throws
    func stop() async throws -> String
    func cancel()
}

@MainActor
public protocol GuideTurnGenerating: AnyObject {
    func answer(
        question: String,
        context: ScreenContext,
        conversation: [GuidanceMessage]
    ) async throws -> GuidancePlan
}

@MainActor
public protocol GuideTurnSpeaking: AnyObject {
    func speak(_ text: String) async throws
    func stop()
}

public struct GuideTurnPresentation: Equatable, Sendable {
    public let stage: GuidanceAmbientStage
    public let statusText: String
    public let context: ScreenContextIdentity?
    public let responseText: String
    public let failure: GuideFailure?

    public init(
        stage: GuidanceAmbientStage,
        statusText: String,
        context: ScreenContextIdentity? = nil,
        responseText: String = "",
        failure: GuideFailure? = nil
    ) {
        self.stage = stage
        self.statusText = statusText
        self.context = context
        self.responseText = responseText
        self.failure = failure
    }
}

@MainActor
public protocol GuideTurnOverlayPresenting: AnyObject {
    func present(_ presentation: GuideTurnPresentation)
    func dismissResponse()
    func restoreIdleVisibility()
}

@MainActor
public final class GuideTurnCoordinator {
    public private(set) var conversation: [GuidanceMessage] = []
    public private(set) var phase: GuidancePhase = .idle

    private let capture: any GuideTurnContextCapturing
    private let transcription: any GuideTurnTranscribing
    private let generation: any GuideTurnGenerating
    private let speech: any GuideTurnSpeaking
    private let overlay: any GuideTurnOverlayPresenting
    private let transcriptPreview = GuidanceLiveTranscriptPreview()
    private var activeTurnTask: Task<Void, Never>?
    private var activeTurnID: UUID?
    private var cancellationRequested = false
    private var finishContinuation: AsyncStream<Void>.Continuation?

    public init(
        capture: any GuideTurnContextCapturing,
        transcription: any GuideTurnTranscribing,
        generation: any GuideTurnGenerating,
        speech: any GuideTurnSpeaking,
        overlay: any GuideTurnOverlayPresenting
    ) {
        self.capture = capture
        self.transcription = transcription
        self.generation = generation
        self.speech = speech
        self.overlay = overlay
    }

    public func start() throws {
        guard activeTurnTask == nil else { throw GuidanceConversationError.turnAlreadyActive }
        try start(target: capture.snapshotTarget())
    }

    public func start(target: GuideWindowTarget) throws {
        guard activeTurnTask == nil else { throw GuidanceConversationError.turnAlreadyActive }
        overlay.dismissResponse()
        let finishStream = AsyncStream<Void> { finishContinuation = $0 }
        let turnID = UUID()
        activeTurnID = turnID
        cancellationRequested = false
        phase = .listening
        overlay.present(.init(stage: .listening, statusText: "Listening…", context: target.identity))

        activeTurnTask = Task { [weak self] in
            guard let self else { return }
            await runTurn(id: turnID, target: target, finishStream: finishStream)
        }
    }

    public func finishListening() {
        guard phase == .listening else { return }
        finishContinuation?.yield()
        finishContinuation?.finish()
        finishContinuation = nil
    }

    public func cancel() {
        guard activeTurnTask != nil, !cancellationRequested else { return }
        cancellationRequested = true
        activeTurnTask?.cancel()
        finishContinuation?.finish()
        finishContinuation = nil
        transcription.cancel()
        speech.stop()
        overlay.dismissResponse()
        phase = .idle
        overlay.present(.init(stage: .cancelled, statusText: "Cancelled"))
        overlay.present(.init(stage: .ready, statusText: "Ready"))
        overlay.restoreIdleVisibility()
    }

    public func resetConversation() {
        guard activeTurnTask == nil else { return }
        conversation.removeAll(keepingCapacity: false)
    }

    public func waitUntilIdle() async {
        while activeTurnTask != nil {
            await Task.yield()
        }
    }

    private func runTurn(
        id: UUID,
        target: GuideWindowTarget,
        finishStream: AsyncStream<Void>
    ) async {
        do {
            try transcription.start { [weak self] text in
                guard let self, phase == .listening else { return }
                overlay.present(.init(
                    stage: .liveTranscript,
                    statusText: transcriptPreview.displayText(for: text),
                    context: target.identity
                ))
            }
            async let capturedContext = capture.capture(target)
            for await _ in finishStream { break }
            try Task.checkCancellation()
            phase = .capturing
            overlay.present(.init(stage: .capturing, statusText: "Reading this screen…", context: target.identity))
            let question = try await transcription.stop()
            let context = try await capturedContext
            try Task.checkCancellation()
            let priorConversation = conversation
            phase = .thinking
            overlay.present(.init(stage: .thinking, statusText: "Thinking locally…", context: target.identity))
            let plan = try await generation.answer(
                question: question,
                context: context,
                conversation: priorConversation
            )
            try Task.checkCancellation()
            let answer = GuidanceAnswerBudget().bounded(
                GuidanceAnswerSanitizer.sanitize(plan.answer)
            )
            guard !answer.isEmpty else {
                throw GuideFailure(
                    stage: .guidance,
                    message: "The local guide returned no usable answer.",
                    recovery: "Ask the question another way and try again."
                )
            }
            conversation.append(.init(role: .user, content: question))
            conversation.append(.init(role: .guide, content: answer, contextLabel: target.identity.compactLabel))
            phase = .presenting
            overlay.present(.init(
                stage: .speaking,
                statusText: "Speaking…",
                context: target.identity,
                responseText: answer
            ))
            try await speech.speak(answer)
            try Task.checkCancellation()
            overlay.present(.init(
                stage: .readyForFollowUp,
                statusText: "Ready for a follow-up",
                context: target.identity,
                responseText: answer
            ))
        } catch is CancellationError {
            // cancel() owns visible cancellation and cleanup.
        } catch {
            let failure = error as? GuideFailure ?? GuideFailure(
                stage: .guidance,
                message: error.localizedDescription,
                recovery: "Try again."
            )
            phase = .failed(failure)
            overlay.present(.init(
                stage: .error,
                statusText: failure.message,
                context: target.identity,
                failure: failure
            ))
        }
        if activeTurnID == id {
            finishContinuation = nil
            activeTurnID = nil
            activeTurnTask = nil
            cancellationRequested = false
        }
    }
}
