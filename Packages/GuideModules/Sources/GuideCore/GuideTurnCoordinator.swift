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

/// Optional richer generation seam used by providers that can reveal an answer
/// incrementally. The original `answer` contract remains the local-provider
/// baseline and keeps existing adapters source compatible.
@MainActor
public protocol GuideTurnStreamingGenerating: GuideTurnGenerating {
    var thinkingStatusText: String { get }
    func streamAnswer(
        question: String,
        target: GuideWindowTarget,
        context: ScreenContext,
        conversation: [GuidanceMessage]
    ) throws -> AsyncThrowingStream<GuidanceStreamEvent, Error>
    func cancelGeneration()
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
    public let pointCue: GuidePointCue?
    public let target: GuideWindowTarget?

    public init(
        stage: GuidanceAmbientStage,
        statusText: String,
        context: ScreenContextIdentity? = nil,
        responseText: String = "",
        failure: GuideFailure? = nil,
        pointCue: GuidePointCue? = nil,
        target: GuideWindowTarget? = nil
    ) {
        self.stage = stage
        self.statusText = statusText
        self.context = context
        self.responseText = responseText
        self.failure = failure
        self.pointCue = pointCue
        self.target = target
    }

    public var guidancePhase: GuidancePhase {
        switch stage {
        case .ready, .cancelled: .idle
        case .listening, .liveTranscript: .listening
        case .capturing: .capturing
        case .thinking: .thinking
        case .speaking, .readyForFollowUp: .presenting
        case .error:
            .failed(failure ?? GuideFailure(
                stage: .guidance,
                message: statusText,
                recovery: "Try again. If the problem continues, open SERPy and check permissions."
            ))
        }
    }
}

@MainActor
public protocol GuideTurnOverlayPresenting: AnyObject {
    func present(_ presentation: GuideTurnPresentation)
    func dismissResponse()
    func restoreIdleVisibility(after delay: Duration)
}

public enum GuideTurnBoundary: Equatable, Sendable {
    case microphoneStart
    case transcription
    case capture
    case generation
    case speaking
}

public struct GuideTurnFailurePolicy: Sendable {
    public init() {}

    public func failure(for error: Error, at boundary: GuideTurnBoundary) -> GuideFailure {
        if let failure = error as? GuideFailure { return failure }
        let cause = error.localizedDescription
        return switch boundary {
        case .microphoneStart:
            GuideFailure(stage: .recording, message: "The microphone could not start. \(cause)", recovery: "Check Microphone and Speech Recognition permissions, then try again.")
        case .transcription:
            GuideFailure(stage: .transcription, message: "The spoken question could not be transcribed. \(cause)", recovery: "Speak closer to the microphone and try the question again.")
        case .capture:
            GuideFailure(stage: .capture, message: "The selected window could not be captured. \(cause)", recovery: "Bring that exact window forward and start the voice guide again.")
        case .generation:
            GuideFailure(stage: .guidance, message: "The selected Talk provider could not answer. \(cause)", recovery: "Check the selected provider in SERPy Settings, then ask again. SERPy will not switch providers automatically.")
        case .speaking:
            GuideFailure(stage: .presentation, message: "The answer could not be spoken. \(cause)", recovery: "Read the visible answer, check sound output, and try again.")
        }
    }
}

@MainActor
public final class GuideTurnCoordinator {
    private struct GeneratedTurn {
        let plan: GuidancePlan
        let speechCompleted: Bool
        let pointCue: GuidePointCue?
    }
    public private(set) var conversation: [GuidanceMessage] = []
    public private(set) var phase: GuidancePhase = .idle

    private let capture: any GuideTurnContextCapturing
    private let transcription: any GuideTurnTranscribing
    private let generation: any GuideTurnGenerating
    private let speech: any GuideTurnSpeaking
    private let overlay: any GuideTurnOverlayPresenting
    private let transcriptPreview = GuidanceLiveTranscriptPreview()
    private let failurePolicy = GuideTurnFailurePolicy()
    private var activeTurnTask: Task<Void, Never>?
    private var activeTurnID: UUID?
    private var activeTarget: GuideWindowTarget?
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
        activeTarget = target
        cancellationRequested = false
        phase = .listening
        overlay.present(.init(stage: .listening, statusText: "Listening…", context: target.identity, target: target))

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
        (generation as? any GuideTurnStreamingGenerating)?.cancelGeneration()
        speech.stop()
        overlay.dismissResponse()
        phase = .idle
        overlay.present(.init(
            stage: .cancelled,
            statusText: "Cancelled",
            context: activeTarget?.identity,
            target: activeTarget
        ))
        overlay.restoreIdleVisibility(after: .milliseconds(1_200))
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
            try Task.checkCancellation()
            guard !cancellationRequested, activeTurnID == id else {
                throw CancellationError()
            }
            do {
                try transcription.start { [weak self] text in
                    guard let self, phase == .listening else { return }
                    overlay.present(.init(
                        stage: .liveTranscript,
                        statusText: transcriptPreview.displayText(for: text),
                        context: target.identity,
                        target: target
                    ))
                }
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                throw failurePolicy.failure(for: error, at: .microphoneStart)
            }
            try Task.checkCancellation()
            async let capturedContext = capture.capture(target)
            for await _ in finishStream { break }
            try Task.checkCancellation()
            phase = .capturing
            overlay.present(.init(stage: .capturing, statusText: "Reading this screen…", context: target.identity, target: target))
            let question: String
            do { question = try await transcription.stop() }
            catch is CancellationError { throw CancellationError() }
            catch { throw failurePolicy.failure(for: error, at: .transcription) }
            let context: ScreenContext
            do { context = try await capturedContext }
            catch is CancellationError { throw CancellationError() }
            catch { throw failurePolicy.failure(for: error, at: .capture) }
            try Task.checkCancellation()
            let priorConversation = conversation
            phase = .thinking
            let thinkingStatus = (generation as? any GuideTurnStreamingGenerating)?.thinkingStatusText
                ?? "Thinking locally…"
            overlay.present(.init(stage: .thinking, statusText: thinkingStatus, context: target.identity, target: target))
            let generated: GeneratedTurn
            do {
                if let streamingGeneration = generation as? any GuideTurnStreamingGenerating {
                    generated = try await consumeStreamingAnswer(
                        from: streamingGeneration,
                        question: question,
                        target: target,
                        context: context,
                        conversation: priorConversation
                    )
                } else {
                    generated = GeneratedTurn(plan: try await generation.answer(
                        question: question,
                        context: context,
                        conversation: priorConversation
                    ), speechCompleted: false, pointCue: nil)
                }
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                throw failurePolicy.failure(for: error, at: .generation)
            }
            try Task.checkCancellation()
            let completeAnswer = GuidanceAnswerSanitizer.sanitize(generated.plan.answer)
            guard !completeAnswer.isEmpty else {
                throw GuideFailure(
                    stage: .guidance,
                    message: "The selected Talk provider returned no usable answer.",
                    recovery: "Ask the question another way and try again. SERPy will not switch providers automatically."
                )
            }
            conversation.append(.init(role: .user, content: question))
            conversation.append(.init(role: .guide, content: completeAnswer, contextLabel: target.identity.compactLabel))
            phase = .presenting
            overlay.present(.init(
                stage: .speaking,
                statusText: "Speaking…",
                context: target.identity,
                responseText: completeAnswer,
                pointCue: generated.pointCue,
                target: target
            ))
            if !generated.speechCompleted {
                do { try await speech.speak(completeAnswer) }
                catch is CancellationError { throw CancellationError() }
                catch { throw failurePolicy.failure(for: error, at: .speaking) }
            }
            try Task.checkCancellation()
            overlay.present(.init(
                stage: .readyForFollowUp,
                statusText: "Ready for a follow-up",
                context: target.identity,
                responseText: completeAnswer,
                pointCue: generated.pointCue,
                target: target
            ))
        } catch is CancellationError {
            // cancel() owns visible cancellation and cleanup.
        } catch {
            if !cancellationRequested, !Task.isCancelled {
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
                    failure: failure,
                    target: target
                ))
                overlay.restoreIdleVisibility(after: .seconds(4))
            }
        }
        if activeTurnID == id {
            finishContinuation = nil
            activeTurnID = nil
            activeTarget = nil
            activeTurnTask = nil
            cancellationRequested = false
        }
    }

    private func consumeStreamingAnswer(
        from generation: any GuideTurnStreamingGenerating,
        question: String,
        target: GuideWindowTarget,
        context: ScreenContext,
        conversation: [GuidanceMessage]
    ) async throws -> GeneratedTurn {
        let stream = try generation.streamAnswer(
            question: question,
            target: target,
            context: context,
            conversation: conversation
        )
        var answer = ""
        var confidence: Float = 0
        var pointCue: GuidePointCue?
        var queuedSentence = false
        let evidenceBounds = ["locked-window": CGRect(x: 0, y: 0, width: 1, height: 1)]
        let validator = SpatialActionValidator()
        let (sentenceStream, sentenceContinuation) = AsyncStream<String>.makeStream()
        async let speechPlayback: Void = speakSentences(sentenceStream)
        var completed = false
        defer { sentenceContinuation.finish() }
        for try await event in stream {
            try Task.checkCancellation()
            switch event {
            case let .textDelta(delta):
                answer += delta
                let visible = GuidanceAnswerSanitizer.sanitize(answer)
                if !visible.isEmpty {
                    phase = .presenting
                    overlay.present(.init(
                        stage: .speaking,
                        statusText: "Answering…",
                        context: target.identity,
                        responseText: visible,
                        target: target
                    ))
                }
            case let .sentenceReady(sentence):
                let safeSentence = GuidanceAnswerSanitizer.sanitize(sentence)
                if !safeSentence.isEmpty {
                    queuedSentence = true
                    sentenceContinuation.yield(safeSentence)
                }
            case let .spatialAction(action):
                guard let valid = validator.validate(action, evidenceBounds: evidenceBounds) else { continue }
                if case let .point(_, normalizedPoint, score, label) = valid {
                    pointCue = GuidePointCue(
                        target: target,
                        normalizedPoint: normalizedPoint,
                        label: label
                    )
                    confidence = score
                }
            case .completed:
                completed = true
            }
        }
        guard completed else {
            throw GuideFailure(
                stage: .guidance,
                message: "The selected Talk provider ended before completing its answer.",
                recovery: "Check the network and try again. SERPy will not silently switch providers."
            )
        }
        sentenceContinuation.finish()
        do { try await speechPlayback }
        catch is CancellationError { throw CancellationError() }
        catch { throw failurePolicy.failure(for: error, at: .speaking) }
        return GeneratedTurn(
            plan: GuidancePlan(answer: answer, confidence: confidence),
            speechCompleted: queuedSentence,
            pointCue: pointCue
        )
    }

    private func speakSentences(_ sentences: AsyncStream<String>) async throws {
        for await sentence in sentences {
            try Task.checkCancellation()
            try await speech.speak(sentence)
        }
    }
}
