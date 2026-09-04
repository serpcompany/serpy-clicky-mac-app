public enum GoldenFlowID: String, CaseIterable, Codable, Sendable {
    case permissions = "UF-01"
    case lifecycle = "UF-02"
    case dictation = "UF-03"
    case cancelDictation = "UF-04"
    case recovery = "UF-05"
    case guideQuestion = "UF-08"
    case walkthrough = "UF-09"
    case cancelGuide = "UF-10"
    case openAITalk = "UF-11"
    case diagnostics = "UF-12"
}

public enum GoldenHarnessPhase: String, Equatable, Sendable {
    case idle
    case permissionExplanation
    case permissionRequestReady
    case permissionRecovery
    case listening
    case transcribing
    case capturing
    case thinking
    case speaking
    case inserting
    case deliveryConfirmed
    case recoveryAvailable
    case followUpReady
    case walkthroughStepOne
    case walkthroughStepTwo
    case credentialRequired
    case fixtureResponse
    case handledFailure
    case completed
    case cancelled
    case terminated
}

public enum GoldenCredentialStorage: String, Equatable, Sendable {
    case none
    case memoryOnly
}

public struct GoldenHarnessObservableState: Equatable, Sendable {
    public var transcript = ""
    public var answer = ""
    public var stepLabel = ""
    public var failureStage = ""
    public var failureCause = ""
    public var recoveryAction = ""
    public var availableActions: [String] = []
    public var incidentCodes: [String] = []
    public var transcriptPreserved = false
    public var hasTypingComposer = false
    public var applicationRunning = true
    public var windowCount = 1
    public var overlayCount = 0
    public var targetMutationCount = 0
    public var autonomousActionCount = 0
    public var networkRequestCount = 0
    public var credentialStorage: GoldenCredentialStorage = .none

    public init() {}
}

public enum GoldenHarnessAction: Equatable, Sendable {
    case continueFlow
    case deny
    case start
    case receivePartial(String)
    case stop
    case cancel
    case lateResult(String)
    case staleEvidence
    case freshEvidence
    case closeSettings
    case reopenSettings
    case quit
    case selectProvider
    case acceptDisclosure
    case verifyFixtureCredential
}

public enum GoldenHarnessError: Error, Equatable, Sendable {
    case invalidAction(flow: GoldenFlowID, phase: GoldenHarnessPhase)
}

/// Deterministic public-state oracle used by the headless and isolated UI
/// lanes. It models observable outcomes only and owns no macOS capability.
public struct GoldenUserFlowHarness: Sendable {
    public let flow: GoldenFlowID
    public private(set) var phase: GoldenHarnessPhase
    public private(set) var observableState: GoldenHarnessObservableState
    private var providerSelected = false
    private var disclosureAccepted = false

    public init(flow: GoldenFlowID, initialPhase: GoldenHarnessPhase? = nil) {
        self.flow = flow
        var state = GoldenHarnessObservableState()
        let defaultPhase: GoldenHarnessPhase
        switch flow {
        case .permissions:
            defaultPhase = .permissionExplanation
        case .lifecycle:
            defaultPhase = .idle
        case .dictation, .cancelDictation:
            defaultPhase = .idle
        case .recovery:
            defaultPhase = .recoveryAvailable
            state.transcript = "Recovered fixture dictation"
            state.transcriptPreserved = true
            state.availableActions = ["Copy", "Retry", "Delete"]
        case .guideQuestion:
            defaultPhase = .idle
        case .walkthrough:
            defaultPhase = .walkthroughStepOne
            state.stepLabel = "Step 1 of 2"
            state.answer = "Open the File menu."
            state.overlayCount = 1
        case .cancelGuide:
            defaultPhase = .idle
        case .openAITalk:
            defaultPhase = .idle
        case .diagnostics:
            defaultPhase = .handledFailure
            state.failureStage = "generation"
            state.failureCause = "The local guide returned malformed structured guidance."
            state.recoveryAction = "Try Again"
            state.incidentCodes = ["guidance.plan.malformed"]
            state.overlayCount = 1
        }
        phase = initialPhase ?? defaultPhase
        if phase != .idle && phase != .cancelled && state.overlayCount == 0,
           flow == .cancelGuide {
            state.overlayCount = 1
        }
        observableState = state
    }

    public mutating func apply(_ action: GoldenHarnessAction) throws {
        switch (flow, phase, action) {
        case (.permissions, .permissionExplanation, .continueFlow):
            phase = .permissionRequestReady
        case (.permissions, .permissionRequestReady, .deny):
            phase = .permissionRecovery
            observableState.recoveryAction = "Open Settings"

        case (.lifecycle, _, .closeSettings):
            observableState.windowCount = 0
        case (.lifecycle, _, .reopenSettings):
            observableState.windowCount = 1
        case (.lifecycle, _, .quit):
            observableState.applicationRunning = false
            observableState.windowCount = 0
            phase = .terminated

        case (.dictation, .idle, .start):
            phase = .listening
            observableState.overlayCount = 1
        case (.dictation, .listening, .receivePartial(let text)):
            observableState.transcript = text
        case (.dictation, .listening, .stop):
            phase = .deliveryConfirmed
            observableState.transcriptPreserved = true
            observableState.targetMutationCount = 1
            observableState.overlayCount = 0

        case (.cancelDictation, _, .cancel), (.cancelGuide, _, .cancel):
            phase = .cancelled
            observableState.transcript = ""
            observableState.answer = ""
            observableState.overlayCount = 0
        case (.cancelDictation, .cancelled, .lateResult),
             (.cancelGuide, .cancelled, .lateResult):
            break

        case (.guideQuestion, .idle, .continueFlow):
            phase = .listening
            observableState.overlayCount = 1
        case (.guideQuestion, .listening, .continueFlow): phase = .transcribing
        case (.guideQuestion, .transcribing, .continueFlow): phase = .capturing
        case (.guideQuestion, .capturing, .continueFlow): phase = .thinking
        case (.guideQuestion, .thinking, .continueFlow):
            phase = .speaking
            observableState.answer = "Open the File menu, then choose New Window."
        case (.guideQuestion, .speaking, .continueFlow): phase = .followUpReady

        case (.walkthrough, .walkthroughStepOne, .staleEvidence),
             (.walkthrough, .walkthroughStepTwo, .staleEvidence):
            break
        case (.walkthrough, .walkthroughStepOne, .freshEvidence):
            phase = .walkthroughStepTwo
            observableState.stepLabel = "Step 2 of 2"
            observableState.answer = "Choose New Window."
        case (.walkthrough, .walkthroughStepTwo, .freshEvidence):
            phase = .completed
            observableState.stepLabel = "Complete"
            observableState.answer = "Walkthrough complete."
            observableState.overlayCount = 0

        case (.openAITalk, .idle, .selectProvider):
            providerSelected = true
        case (.openAITalk, .idle, .acceptDisclosure):
            disclosureAccepted = true
            if providerSelected { phase = .credentialRequired }
        case (.openAITalk, .credentialRequired, .verifyFixtureCredential):
            guard providerSelected, disclosureAccepted else {
                throw GoldenHarnessError.invalidAction(flow: flow, phase: phase)
            }
            phase = .fixtureResponse
            observableState.credentialStorage = .memoryOnly
            observableState.answer = "Fixture response"

        default:
            throw GoldenHarnessError.invalidAction(flow: flow, phase: phase)
        }
    }
}
