import GuideTestSupport
import SwiftUI

@main
struct GoldenHarnessApp: App {
    var body: some Scene {
        WindowGroup("serpy Golden Harness") {
            GoldenHarnessView(arguments: CommandLine.arguments)
        }
    }
}

private struct GoldenHarnessView: View {
    @State private var harness: GoldenUserFlowHarness

    init(arguments: [String]) {
        let rawFlow = arguments
            .first(where: { $0.hasPrefix("--golden-flow=") })?
            .dropFirst("--golden-flow=".count)
        let flow = rawFlow.flatMap { GoldenFlowID(rawValue: String($0)) } ?? .lifecycle
        _harness = State(initialValue: GoldenUserFlowHarness(flow: flow))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(harness.flow.rawValue).accessibilityIdentifier("golden.flow")
            Text(harness.phase.rawValue).accessibilityIdentifier("golden.phase")
            if !harness.observableState.transcript.isEmpty {
                Text(harness.observableState.transcript).accessibilityIdentifier("golden.transcript")
            }
            if !harness.observableState.answer.isEmpty {
                Text(harness.observableState.answer).accessibilityIdentifier("golden.answer")
            }
            if !harness.observableState.stepLabel.isEmpty {
                Text(harness.observableState.stepLabel).accessibilityIdentifier("golden.step")
            }
            if !harness.observableState.failureCause.isEmpty {
                Text(harness.observableState.failureCause).accessibilityIdentifier("golden.failure.cause")
                Text(harness.observableState.recoveryAction).accessibilityIdentifier("golden.failure.recovery")
            }
            if !harness.observableState.availableActions.isEmpty {
                HStack {
                    ForEach(harness.observableState.availableActions, id: \.self) { action in
                        Button(action) {}
                    }
                }
            }
            controls
            Text("network=\(harness.observableState.networkRequestCount) keychain=\(harness.observableState.credentialStorage.rawValue)")
                .accessibilityIdentifier("golden.safety")
        }
        .padding(24)
        .frame(minWidth: 520, minHeight: 300)
        .accessibilityIdentifier("golden.harness")
    }

    @ViewBuilder
    private var controls: some View {
        switch harness.flow {
        case .permissions:
            actionButton("Continue", .continueFlow)
            actionButton("Deny fixture", .deny)
        case .lifecycle:
            actionButton("Close Settings fixture", .closeSettings)
            actionButton("Reopen Settings fixture", .reopenSettings)
        case .dictation:
            actionButton("Start Dictation fixture", .start)
            actionButton("Receive Partial fixture", .receivePartial("alpha beta"))
            actionButton("Stop Dictation fixture", .stop)
        case .cancelDictation, .cancelGuide:
            actionButton("Cancel", .cancel)
            actionButton("Deliver Late Result fixture", .lateResult("must be ignored"))
        case .guideQuestion:
            actionButton("Advance fixture", .continueFlow)
        case .walkthrough:
            actionButton("Stale Evidence fixture", .staleEvidence)
            actionButton("Fresh Evidence fixture", .freshEvidence)
        case .openAITalk:
            actionButton("Select OpenAI fixture", .selectProvider)
            actionButton("Accept Disclosure fixture", .acceptDisclosure)
            actionButton("Verify In-Memory Credential", .verifyFixtureCredential)
        case .recovery, .diagnostics:
            EmptyView()
        }
    }

    private func actionButton(_ title: String, _ action: GoldenHarnessAction) -> some View {
        Button(title) { try? harness.apply(action) }
            .accessibilityIdentifier("golden.action.\(title)")
    }
}
