import AppKit
import GuideCore
import GuideMac
import GuideUI
import SwiftUI

@MainActor
private enum GuideAppComposition {
    static let model: GuideAppModel = {
        let environment = ProcessInfo.processInfo.environment
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
        let incidentReporter: any DiagnosticIncidentReporting = sentryEnabled
            ? SentryDiagnosticReporter()
            : NullDiagnosticIncidentReporter()
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
                GuideAppComposition.model.presentMalformedGuidanceFixtureForTesting()
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
