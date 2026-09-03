import AppKit
import GuideCore
import GuideMac
import GuideUI
import SwiftUI

@MainActor
private enum GuideAppComposition {
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
            shortcutMonitorFactory: makeShortcutMonitor
        )
    }()

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
            MenuPanelView(model: model)
        } label: {
            Label("SERPy", systemImage: model.menuBarSymbol)
                .accessibilityLabel("SERPy, \(model.shortStatus)")
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView(model: model)
        }
        .defaultSize(width: 620, height: 520)
    }
}

@MainActor
final class GuideAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Task {
            await GuideAppComposition.model.start()
            if CommandLine.arguments.contains("--ui-testing"),
               CommandLine.arguments.contains("--open-guide-transcript") {
                GuideAppComposition.model.openGuidanceTranscript()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        GuideAppComposition.model.stop()
    }
}
