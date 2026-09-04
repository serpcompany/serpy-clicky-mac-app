import AppKit
import GuideCore
import GuideMac
import GuideUI
import SwiftUI

@MainActor
private enum GuideAppComposition {
    static let incidentReporter: any DiagnosticIncidentReporting = {
        let environment = ProcessInfo.processInfo.environment
#if DEBUG
        let sentryConfiguration = SentryRuntimeConfiguration.resolve(
            processEnvironment: environment,
            bundleInfo: Bundle.main.infoDictionary ?? [:]
        )
        let sentryEnabled = sentryConfiguration.map {
            SentryDiagnosticBootstrap.startIfConfigured(
                dsn: $0.dsn,
                environment: $0.environment,
                debug: $0.debug
            )
        } ?? false
#else
        let sentryEnabled = false
#endif
        return sentryEnabled
            ? SentryDiagnosticReporter()
            : NullDiagnosticIncidentReporter()
    }()

    static let model: GuideAppModel = {
        let local = LocalGuidanceService()
        let credentialStore = KeychainTalkCredentialStore()
        let credentialVerifier = OpenAITalkCredentialVerifier()
        let cloud = OpenAIMultimodalGuidanceGenerator(credentialStore: credentialStore)
        let router = TalkGenerationRouter(
            local: local,
            cloud: cloud,
            credentialStore: credentialStore
        )
        return GuideAppModel(
            localGuidanceService: local,
            talkCredentialStore: credentialStore,
            talkCredentialVerifier: credentialVerifier,
            talkVerificationExpirySleeper: SystemTalkVerificationExpirySleeper(),
            talkGenerator: router,
            incidentReporter: incidentReporter,
            shortcutMonitorFactory: makeShortcutMonitor
        )
    }()
    static let settingsWindow = GuideSettingsWindowController(model: model)
    static var uiTestCoordinator: GuideTurnCoordinator?

    static func runMalformedGuidanceFixture() async {
        let target = GuideWindowTarget(
            processIdentifier: Int32(ProcessInfo.processInfo.processIdentifier),
            windowIdentifier: 1,
            applicationName: "Fixture App",
            windowTitle: "Benign Fixture",
            frame: CGRect(x: 120, y: 120, width: 800, height: 600),
            displayIdentifier: nil
        )
        let overlay = PersistentFixtureOverlay(model: model)
        let coordinator = GuideTurnCoordinator(
            capture: MalformedFixtureCapture(target: target),
            transcription: MalformedFixtureTranscription(),
            generation: MalformedFixtureGeneration(),
            speech: MalformedFixtureSpeech(),
            overlay: overlay,
            incidentReporter: incidentReporter
        )
        uiTestCoordinator = coordinator
        do {
            try coordinator.start(target: target)
            await Task.yield()
            coordinator.finishListening()
            await coordinator.waitUntilIdle()
        } catch {
            uiTestCoordinator = nil
        }
    }

    private static func makeShortcutMonitor(
        configuration: GlobalShortcutConfigurationSet,
        callbacks: GlobalShortcutCallbacks
    ) -> any GlobalShortcutMonitoring {
        GlobalShortcutService(
            bindings: [
                .init(id: .dictation, gesture: .key(configuration.dictation)),
                .init(
                    id: .guide,
                    gesture: .modifierChord(configuration.guide)
                )
            ],
            delivered: { delivery in
                switch (delivery.id, delivery.transition) {
                case (.dictation, .pressed): callbacks.dictationPressed()
                case (.dictation, .released): callbacks.dictationReleased()
                case (.guide, .pressed): callbacks.guidePressed()
                case (.guide, .released): callbacks.guideReleased()
                }
            },
            cancelled: callbacks.cancelled
        )
    }
}

private final class MalformedFixtureCapture: GuideTurnContextCapturing, @unchecked Sendable {
    let target: GuideWindowTarget

    init(target: GuideWindowTarget) {
        self.target = target
    }

    @MainActor
    func snapshotTarget() throws -> GuideWindowTarget { target }

    func capture(_ target: GuideWindowTarget) async throws -> ScreenContext {
        ScreenContext(
            applicationName: target.applicationName,
            windowTitle: target.windowTitle,
            windowFrame: target.frame,
            textBlocks: []
        )
    }
}

@MainActor
private final class MalformedFixtureTranscription: GuideTurnTranscribing {
    func start(onPartial: @escaping @MainActor @Sendable (String) -> Void) throws {}
    func stop() async throws -> String { "Benign fixture question" }
    func cancel() {}
}

@MainActor
private final class MalformedFixtureGeneration: GuideTurnGenerating {
    func answer(
        question: String,
        context: ScreenContext,
        conversation: [GuidanceMessage]
    ) async throws -> GuidancePlan {
        throw GuideFailure.malformedGuidance(provider: .local)
    }
}

@MainActor
private final class MalformedFixtureSpeech: GuideTurnSpeaking {
    func speak(_ text: String) async throws {}
    func stop() {}
}

@MainActor
private final class PersistentFixtureOverlay: GuideTurnOverlayPresenting {
    let model: GuideAppModel

    init(model: GuideAppModel) {
        self.model = model
    }

    func present(_ presentation: GuideTurnPresentation) { model.present(presentation) }
    func dismissResponse() { model.dismissResponse() }
    func restoreIdleVisibility(after delay: Duration) {}
}

@main
struct GuideCompanionApp: App {
    @NSApplicationDelegateAdaptor(GuideAppDelegate.self) private var appDelegate
    @State private var model = GuideAppComposition.model

    var body: some Scene {
        MenuBarExtra {
            MenuPanelView(
                model: model,
                openSettings: { GuideAppComposition.settingsWindow.present() }
            )
        } label: {
            Label("SERPy", systemImage: model.menuBarSymbol)
                .accessibilityLabel("SERPy, \(model.shortStatus)")
        }
        .menuBarExtraStyle(.menu)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    GuideAppComposition.settingsWindow.present()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}

@MainActor
final class GuideAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        applyPresence(for: .running(settingsVisible: NSApp.windows.contains(where: \.isVisible)))
        GuideAppComposition.settingsWindow.present()
        Task {
            await GuideAppComposition.model.start()
            if CommandLine.arguments.contains("--ui-testing"),
               CommandLine.arguments.contains("--open-guide-transcript") {
                GuideAppComposition.model.openGuidanceTranscript()
            }
            if CommandLine.arguments.contains("--ui-testing"),
               CommandLine.arguments.contains("--guide-fixture=malformed-plan") {
                await GuideAppComposition.runMalformedGuidanceFixture()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        applyPresence(for: .terminating)
        GuideAppComposition.model.stop()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        applyPresence(for: .running(settingsVisible: flag))
        GuideAppComposition.settingsWindow.present()
        return true
    }

    private func applyPresence(for state: ApplicationLifetimeState) {
        let policy = ApplicationPresencePolicy()
        let activationPolicy: NSApplication.ActivationPolicy = switch policy.presence(for: state) {
        case .regular: .regular
        case .prohibited: .prohibited
        }
        NSApp.setActivationPolicy(activationPolicy)
    }
}
