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
    case loadingFixture
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

public enum GoldenRecoveryVariant: String, Equatable, Sendable {
    case failed
    case unconfirmed
    case interrupted
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
    public var recoveryDisposition = "pending"
    public var recoveryVariant = ""

    public init() {}
}

public enum GoldenHarnessAction: Equatable, Sendable {
    case advancePhase
    case deny
    case start
    case receivePartial(String)
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
    case copyRecovery
    case retryRecovery
    case deleteRecovery
    case acceptDictationObservation(GoldenDictationScenarioObservation)
    case acceptRecoveryObservation(GoldenRecoveryScenarioObservation)
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
    private var permissionMachine = PermissionStateMachine(state: .explained)
    private var dictationMachine = DictationStateMachine()
    private var guideConversation = GuidanceConversationStateMachine()
    private var activeWalkthroughStep = 0
    private let progressionPolicy = GuideProgressionPolicy()
    private let walkthroughPlan = GuidancePlan(
        answer: "Open the File menu, then choose New Window.",
        confidence: 1,
        steps: [
            GuidanceStep(id: 1, text: "Open the File menu.", completionEvidence: ["File menu open"]),
            GuidanceStep(id: 2, text: "Choose New Window.", completionEvidence: ["New Window visible"]),
        ]
    )

    public init(
        flow: GoldenFlowID,
        initialPhase: GoldenHarnessPhase? = nil,
        recoveryWasRestored: Bool = false,
        permissionWasDenied: Bool = false
    ) {
        self.flow = flow
        var state = GoldenHarnessObservableState()
        let defaultPhase: GoldenHarnessPhase
        switch flow {
        case .permissions:
            defaultPhase = permissionWasDenied ? .permissionRecovery : .permissionExplanation
            if permissionWasDenied {
                state.recoveryAction = "Open Settings"
            }
        case .lifecycle:
            defaultPhase = .idle
        case .dictation, .cancelDictation:
            defaultPhase = .idle
        case .recovery:
            defaultPhase = .loadingFixture
            state.recoveryDisposition = recoveryWasRestored ? "restored" : "pending"
            state.recoveryVariant = ""
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
            let failure = GuideFailure.malformedGuidance(provider: .local)
            let incident = DiagnosticIncident(failure: failure)
            state.failureStage = failure.stage.rawValue
            state.failureCause = failure.message
            state.recoveryAction = failure.recovery
            state.incidentCodes = [incident.code.rawValue]
            state.overlayCount = 1
        }
        phase = initialPhase ?? defaultPhase
        observableState = state
        if flow == .cancelDictation, let initialPhase {
            try? dictationMachine.prepare()
            if [.listening, .transcribing, .inserting].contains(initialPhase) {
                try? dictationMachine.beginRecording()
            }
            if [.transcribing, .inserting].contains(initialPhase) {
                try? dictationMachine.beginTranscription()
            }
            if initialPhase == .inserting { try? dictationMachine.beginInsertion() }
        }
        if phase != .idle && phase != .cancelled && state.overlayCount == 0,
           flow == .cancelGuide {
            observableState.overlayCount = 1
        }
    }

    public mutating func apply(_ action: GoldenHarnessAction) throws {
        switch (flow, phase, action) {
        case (.permissions, .permissionExplanation, .advancePhase):
            try permissionMachine.beginRequest()
            phase = .permissionRequestReady
        case (.permissions, .permissionRequestReady, .deny):
            permissionMachine.resolve(granted: false)
            guard permissionMachine.state == .denied else {
                throw GoldenHarnessError.invalidAction(flow: flow, phase: phase)
            }
            phase = .permissionRecovery
            observableState.recoveryAction = "Open Settings"

        case (.lifecycle, _, .closeSettings):
            guard ApplicationPresencePolicy().presence(for: .running(settingsVisible: false)) == .regular else {
                throw GoldenHarnessError.invalidAction(flow: flow, phase: phase)
            }
            observableState.windowCount = 0
        case (.lifecycle, _, .reopenSettings):
            guard ApplicationPresencePolicy().presence(for: .running(settingsVisible: true)) == .regular else {
                throw GoldenHarnessError.invalidAction(flow: flow, phase: phase)
            }
            observableState.windowCount = 1
        case (.lifecycle, _, .quit):
            guard ApplicationPresencePolicy().presence(for: .terminating) == .prohibited else {
                throw GoldenHarnessError.invalidAction(flow: flow, phase: phase)
            }
            observableState.applicationRunning = false
            observableState.windowCount = 0
            phase = .terminated

        case (.dictation, .idle, .start):
            try dictationMachine.prepare()
            try dictationMachine.beginRecording()
            phase = .listening
            observableState.overlayCount = 1
        case (.dictation, .listening, .receivePartial(let text)):
            observableState.transcript = text
        case (.dictation, .listening, .acceptDictationObservation(let observation)):
            try dictationMachine.beginTranscription()
            try dictationMachine.beginInsertion()
            try dictationMachine.succeed()
            guard observation.transcriptPreserved,
                  observation.deliveryConfirmed,
                  observation.targetMutationCount == 1 else {
                throw GoldenHarnessError.invalidAction(flow: flow, phase: phase)
            }
            phase = .deliveryConfirmed
            observableState.transcript = observation.transcript
            observableState.transcriptPreserved = observation.transcriptPreserved
            observableState.targetMutationCount = observation.targetMutationCount
            observableState.overlayCount = 0

        case (.recovery, .recoveryAvailable, .copyRecovery):
            observableState.recoveryDisposition = "copied"
        case (.recovery, .recoveryAvailable, .retryRecovery):
            observableState.recoveryDisposition = "retryRequested"
        case (.recovery, .recoveryAvailable, .deleteRecovery):
            observableState.recoveryDisposition = "deleted"
            observableState.transcript = ""
            observableState.transcriptPreserved = false
            observableState.availableActions = []
        case (.recovery, .loadingFixture, .acceptRecoveryObservation(let observation)):
            let expectedState: TranscriptDeliveryState = switch observation.variant {
            case .failed: .failed
            case .unconfirmed: .unconfirmed
            case .interrupted: .pending
            }
            guard observation.entry.deliveryState == expectedState,
                  !observation.entry.text.isEmpty else {
                throw GoldenHarnessError.invalidAction(flow: flow, phase: phase)
            }
            phase = .recoveryAvailable
            observableState.transcript = observation.entry.text
            observableState.transcriptPreserved = true
            observableState.availableActions = ["Copy", "Retry", "Delete"]
            observableState.recoveryVariant = observation.variant.rawValue

        case (.cancelDictation, _, .cancel), (.cancelGuide, _, .cancel):
            if flow == .cancelDictation {
                dictationMachine.cancel()
                guard dictationMachine.phase == .cancelled else {
                    throw GoldenHarnessError.invalidAction(flow: flow, phase: phase)
                }
            }
            phase = .cancelled
            observableState.transcript = ""
            observableState.answer = ""
            observableState.overlayCount = 0
        case (.cancelDictation, .cancelled, .lateResult),
             (.cancelGuide, .cancelled, .lateResult):
            break

        case (.guideQuestion, .idle, .advancePhase):
            guard GuidanceVoiceActivationPolicy().shortcutAction(for: .idle) == .startListening else {
                throw GoldenHarnessError.invalidAction(flow: flow, phase: phase)
            }
            phase = .listening
            observableState.overlayCount = 1
        case (.guideQuestion, .listening, .advancePhase):
            guard GuidanceVoiceActivationPolicy().shortcutAction(for: .listening) == .finishListening else {
                throw GoldenHarnessError.invalidAction(flow: flow, phase: phase)
            }
            phase = .transcribing
        case (.guideQuestion, .transcribing, .advancePhase):
            try guideConversation.submit(question: "How do I open a new window?")
            guard guideConversation.phase == .capturing else {
                throw GoldenHarnessError.invalidAction(flow: flow, phase: phase)
            }
            phase = .capturing
        case (.guideQuestion, .capturing, .advancePhase):
            try guideConversation.beginThinking()
            guard guideConversation.phase == .thinking else {
                throw GoldenHarnessError.invalidAction(flow: flow, phase: phase)
            }
            phase = .thinking
        case (.guideQuestion, .thinking, .advancePhase):
            try guideConversation.complete(
                answer: "Open the File menu, then choose New Window.",
                contextLabel: "Fixture Window"
            )
            phase = .speaking
            observableState.answer = guideConversation.messages.last?.content ?? ""
        case (.guideQuestion, .speaking, .advancePhase): phase = .followUpReady

        case (.walkthrough, .walkthroughStepOne, .staleEvidence),
             (.walkthrough, .walkthroughStepTwo, .staleEvidence):
            guard case .stay = progressionPolicy.evaluate(
                plan: walkthroughPlan,
                activeStepIndex: activeWalkthroughStep,
                observation: GuideProgressionObservation(visibleText: "Unchanged fixture")
            ) else { throw GoldenHarnessError.invalidAction(flow: flow, phase: phase) }
        case (.walkthrough, .walkthroughStepOne, .freshEvidence):
            guard case .advance(let next) = progressionPolicy.evaluate(
                plan: walkthroughPlan,
                activeStepIndex: activeWalkthroughStep,
                observation: GuideProgressionObservation(visibleText: "File menu open")
            ) else { throw GoldenHarnessError.invalidAction(flow: flow, phase: phase) }
            activeWalkthroughStep = next
            phase = .walkthroughStepTwo
            observableState.stepLabel = "Step 2 of 2"
            observableState.answer = "Choose New Window."
        case (.walkthrough, .walkthroughStepTwo, .freshEvidence):
            guard progressionPolicy.evaluate(
                plan: walkthroughPlan,
                activeStepIndex: activeWalkthroughStep,
                observation: GuideProgressionObservation(visibleText: "New Window visible")
            ) == .complete else { throw GoldenHarnessError.invalidAction(flow: flow, phase: phase) }
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
            let now = Date(timeIntervalSince1970: 1_800_000_000)
            guard TalkAuthorizationPolicy().mayTransmit(
                TalkAuthorization(
                    selection: .openAI,
                    disclosureAccepted: disclosureAccepted,
                    credentialAvailable: true,
                    credentialVerifiedUntil: now.addingTimeInterval(60),
                    credentialMatchesVerification: true
                ),
                now: now
            ) else { throw GoldenHarnessError.invalidAction(flow: flow, phase: phase) }
            phase = .fixtureResponse
            observableState.credentialStorage = .memoryOnly
            observableState.answer = "Fixture response"

        default:
            throw GoldenHarnessError.invalidAction(flow: flow, phase: phase)
        }
    }

    public mutating func recordFixtureFailure(_ cause: String) {
        phase = .handledFailure
        observableState.failureStage = "fixture"
        observableState.failureCause = cause
        observableState.recoveryAction = "Fix the deterministic fixture before another UI run."
        observableState.overlayCount = 1
    }
}
import Foundation
import GuideCore
