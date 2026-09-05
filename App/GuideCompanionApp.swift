import AppKit
import Darwin
import Foundation
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

    static private(set) var model: GuideAppModel!
    static private(set) var runtimeMode: AppRuntimeMode = .production

#if DEBUG
    // [DEBUG-cloud-launch] Temporary, fixed-name receipts in the owned test root.
    static func recordLaunchStage(_ stage: String) {
        guard AppRuntimeMode.resolve(arguments: CommandLine.arguments) == .uiTest,
              let root = try? UITestSessionRootPolicy.validate(environment: ProcessInfo.processInfo.environment)
        else { return }
        try? Data().write(to: root.appendingPathComponent("launch-stage.\(stage)"), options: .atomic)
    }
#endif

    static func configure(for mode: AppRuntimeMode) -> GuideAppModel {
        if let model { return model }
        runtimeMode = mode
        let configured: GuideAppModel
#if DEBUG
        configured = mode == .uiTest
            ? makeUITestModelOrExit()
            : makeProductionModel()
#else
        precondition(mode == .production, "UI-test composition is unavailable in Release builds")
        configured = makeProductionModel()
#endif
        model = configured
        return configured
    }

#if DEBUG
    private static func makeUITestModelOrExit() -> GuideAppModel {
        do {
            return try GuideUITestComposition.makeModel(arguments: CommandLine.arguments)
        } catch {
            let message = "serpy UI-test startup rejected: session root is not owned by this run (\(error))\n"
            FileHandle.standardError.write(Data(message.utf8))
            Darwin.exit(EX_CONFIG)
        }
    }
#endif

    private static func makeProductionModel() -> GuideAppModel {
        let local = LocalGuidanceService()
        let permissionService = PermissionService()
        let dictationSession = DurableDictationSession()
        let insertionService = TextInsertionService()
        let historyStore = TranscriptHistoryStore()
        let recordingCoordinator = RecordingCoordinator(
            session: dictationSession,
            targetReader: insertionService,
            inserter: insertionService,
            history: historyStore
        )
        let screenContextService = ScreenContextService()
        let guidanceTranscriber = AppleSpeechGuideTurnTranscriber(transcriber: AppleSpeechTranscriber())
        let guidanceSpeaker = LocalGuideTurnSpeaker(speaker: LocalSpeechOutputService())
        let credentialStore = KeychainTalkCredentialStore()
        let credentialVerifier = OpenAITalkCredentialVerifier()
        let cloud = OpenAIMultimodalGuidanceGenerator(credentialStore: credentialStore)
        let router = TalkGenerationRouter(
            local: local,
            cloud: cloud,
            credentialStore: credentialStore
        )
        return GuideAppModel(
            permissionService: permissionService,
            recordingCoordinator: recordingCoordinator,
            insertionService: insertionService,
            historyStore: historyStore,
            screenContextService: screenContextService,
            guidanceTranscriber: guidanceTranscriber,
            guidanceSpeaker: guidanceSpeaker,
            localGuidanceService: local,
            talkCredentialStore: credentialStore,
            talkCredentialVerifier: credentialVerifier,
            talkVerificationExpirySleeper: SystemTalkVerificationExpirySleeper(),
            talkGenerator: router,
            incidentReporter: incidentReporter,
            shortcutMonitorFactory: makeShortcutMonitor
        )
    }
    static var settingsWindow = GuideSettingsWindowController(model: GuideAppComposition.model)
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
    @State private var model: GuideAppModel

    init() {
        let mode = AppRuntimeMode.resolve(arguments: CommandLine.arguments)
#if DEBUG
        GuideAppComposition.recordLaunchStage("init-entered")
#endif
        _model = State(initialValue: GuideAppComposition.configure(for: mode))
#if DEBUG
        GuideAppComposition.recordLaunchStage("model-configured")
#endif
    }

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
#if DEBUG
        GuideAppComposition.recordLaunchStage("did-finish-launching")
#endif
        applyPresence(for: .running(settingsVisible: NSApp.windows.contains(where: \.isVisible)))
#if DEBUG
        GuideAppComposition.recordLaunchStage("presence-applied")
#endif
        GuideAppComposition.settingsWindow.present()
#if DEBUG
        GuideAppComposition.recordLaunchStage("settings-present-returned")
#endif
        Task {
            await GuideAppComposition.model.start()
#if DEBUG
            GuideAppComposition.recordLaunchStage("model-start-returned")
#endif
            if CommandLine.arguments.contains("--ui-testing"),
               CommandLine.arguments.contains("--open-guide-transcript") {
                GuideAppComposition.model.openGuidanceTranscript()
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
