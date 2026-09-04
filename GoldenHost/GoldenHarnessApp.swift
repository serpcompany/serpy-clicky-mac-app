import Foundation
import GuideTestSupport
import SwiftUI

@main
struct GoldenHarnessApp: App {
    private let runtimeMode: AppRuntimeMode

    init() {
        do {
            runtimeMode = try GoldenHostRuntimeContract.resolve(arguments: CommandLine.arguments)
        } catch {
            preconditionFailure("serpyGoldenHost may run only with --ui-testing")
        }
    }

    var body: some Scene {
        WindowGroup("serpy Golden Harness") {
            GoldenHarnessView(arguments: CommandLine.arguments, runtimeMode: runtimeMode)
        }
    }
}

private struct GoldenHarnessView: View {
    @State private var harness: GoldenUserFlowHarness

    init(arguments: [String], runtimeMode: AppRuntimeMode) {
        precondition(runtimeMode == .uiTest)
        let rawFlow = arguments
            .first(where: { $0.hasPrefix("--golden-flow=") })?
            .dropFirst("--golden-flow=".count)
        let flow = rawFlow.flatMap { GoldenFlowID(rawValue: String($0)) } ?? .lifecycle
        let rawPhase = arguments
            .first(where: { $0.hasPrefix("--golden-phase=") })?
            .dropFirst("--golden-phase=".count)
        let phase = rawPhase.flatMap { GoldenHarnessPhase(rawValue: String($0)) }
        let recoveryWasRestored: Bool
        if flow == .recovery,
           let root = ProcessInfo.processInfo.environment["SERPY_TEST_ROOT"] {
            let marker = URL(fileURLWithPath: root).appendingPathComponent("last-dictation.fixture")
            recoveryWasRestored = FileManager.default.fileExists(atPath: marker.path)
            if !recoveryWasRestored {
                try? Data("bounded fixture".utf8).write(to: marker, options: .atomic)
            }
        } else {
            recoveryWasRestored = false
        }
        _harness = State(initialValue: GoldenUserFlowHarness(
            flow: flow,
            initialPhase: phase,
            recoveryWasRestored: recoveryWasRestored
        ))
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
            Text("windows=\(harness.observableState.windowCount) overlays=\(harness.observableState.overlayCount) running=\(harness.observableState.applicationRunning)")
                .accessibilityIdentifier("golden.lifecycle")
            Text(harness.observableState.recoveryDisposition)
                .accessibilityIdentifier("golden.recovery.disposition")
        }
        .padding(24)
        .frame(minWidth: 520, minHeight: 300)
        .accessibilityIdentifier("golden.harness")
        .onExitCommand { try? harness.apply(.cancel) }
    }

    @ViewBuilder
    private var controls: some View {
        switch harness.flow {
        case .permissions:
            actionButton("Continue", .advancePhase)
            actionButton("Deny fixture", .deny)
        case .lifecycle:
            actionButton("Close Settings fixture", .closeSettings)
            actionButton("Reopen Settings fixture", .reopenSettings)
            actionButton("Quit fixture", .quit)
        case .dictation:
            actionButton("Start Dictation fixture", .start)
            actionButton("Receive Partial fixture", .receivePartial("alpha beta"))
            actionButton("Stop Dictation fixture", .stop)
        case .cancelDictation, .cancelGuide:
            actionButton("Cancel", .cancel)
            actionButton("Deliver Late Result fixture", .lateResult("must be ignored"))
        case .guideQuestion:
            actionButton("Advance fixture", .advancePhase)
        case .walkthrough:
            actionButton("Stale Evidence fixture", .staleEvidence)
            actionButton("Fresh Evidence fixture", .freshEvidence)
        case .openAITalk:
            actionButton("Select OpenAI fixture", .selectProvider)
            actionButton("Accept Disclosure fixture", .acceptDisclosure)
            actionButton("Verify In-Memory Credential", .verifyFixtureCredential)
        case .recovery:
            actionButton("Copy recovery fixture", .copyRecovery)
            actionButton("Retry recovery fixture", .retryRecovery)
            actionButton("Delete recovery fixture", .deleteRecovery)
        case .diagnostics:
            EmptyView()
        }
    }

    private func actionButton(_ title: String, _ action: GoldenHarnessAction) -> some View {
        Button(title) { try? harness.apply(action) }
            .accessibilityIdentifier("golden.action.\(title)")
    }
}
