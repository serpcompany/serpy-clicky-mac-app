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
        dictationConfiguration: GlobalHotKeyConfiguration,
        guideConfiguration: GlobalModifierChordConfiguration,
        dictationPressed: @escaping @MainActor @Sendable () -> Void,
        dictationReleased: @escaping @MainActor @Sendable () -> Void,
        guidePressed: @escaping @MainActor @Sendable () -> Void,
        guideReleased: @escaping @MainActor @Sendable () -> Void,
        cancelled: @escaping @MainActor @Sendable () -> Void
    ) -> any GlobalShortcutMonitoring {
        GlobalShortcutService(
            bindings: [
                .init(id: .dictation, gesture: .key(dictationConfiguration)),
                .init(
                    id: .guide,
                    gesture: .modifierChord(
                        modifiers: guideConfiguration.modifiers,
                        displayName: guideConfiguration.displayName
                    )
                )
            ],
            delivered: { delivery in
                switch (delivery.id, delivery.transition) {
                case (.dictation, .pressed): dictationPressed()
                case (.dictation, .released): dictationReleased()
                case (.guide, .pressed): guidePressed()
                case (.guide, .released): guideReleased()
                }
            },
            cancelled: cancelled
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
