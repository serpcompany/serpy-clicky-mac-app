import AppKit
import Foundation
import GuideCore
import GuideMac
import GuideUI

@MainActor
public enum GuideUITestComposition {
    public static func makeModel(arguments: [String], environment: [String: String] = ProcessInfo.processInfo.environment) throws -> GuideAppModel {
        precondition(AppRuntimeMode.resolve(arguments: arguments) == .uiTest)
        let sessionRoot = try UITestSessionRootPolicy.validate(environment: environment)
        let flow = arguments.first(where: { $0.hasPrefix("--golden-flow=") }) ?? ""
        let preferences = UITestPreferences()
        let clipboard = UITestClipboardService(sessionRoot: sessionRoot)
        let permissions = UITestPermissionService(
            denyMicrophone: flow == "--golden-flow=UF-01",
            sessionRoot: sessionRoot
        )
        let insertion = UITestTextInsertionService(
            sessionRoot: sessionRoot,
            block: arguments.contains("--block-dictation-insertion")
        )
        let history = UITestHistoryStore(arguments: arguments, sessionRoot: sessionRoot)
        let session = UITestDictationSession(blockStop: arguments.contains("--block-dictation-stop"))
        let recording = RecordingCoordinator(
            session: session,
            targetReader: insertion,
            inserter: insertion,
            history: history
        )
        let capture = UITestScreenContextService(
            block: arguments.contains("--block-guide-capture"),
            stepwise: arguments.contains("--stepwise-guide"),
            sessionRoot: sessionRoot
        )
        let transcription = UITestGuideTranscriber()
        let speaker = UITestGuideSpeaker(
            block: arguments.contains("--block-guide-speech"),
            stepwise: arguments.contains("--stepwise-guide"),
            sessionRoot: sessionRoot
        )
        let generation = UITestGuideGenerator(arguments: arguments, sessionRoot: sessionRoot)
        let credentialStore = UITestCredentialStore()
        let credentialVerifier = UITestCredentialVerifier()
        let expirySleeper = UITestExpirySleeper()
        let localProvider = UITestLocalModelProvider()
        let localService = LocalGuidanceService(provider: localProvider)
        let cloudProvider = UITestCloudGenerator(
            sessionRoot: sessionRoot,
            block: arguments.contains("--block-cloud-generation")
        )
        let router = TalkGenerationRouter(
            local: generation,
            cloud: cloudProvider,
            credentialStore: credentialStore
        )
        let incidentReporter = UITestIncidentReporter(sessionRoot: sessionRoot)
        let shortcutMonitor = UITestShortcutMonitor(sessionRoot: sessionRoot)
        let constructedAdapters: [RuntimeAdapterRole: any DeterministicUITestAdapter] = [
            .dictationSession: session,
            .guideTranscription: transcription,
            .guideSpeech: speaker,
            .permissions: permissions,
            .textInsertion: insertion,
            .screenCapture: capture,
            .guidePlanGenerator: generation,
            .localGuidanceProvider: localProvider,
            .cloudGuidanceProvider: cloudProvider,
            .credentialStore: credentialStore,
            .credentialVerifier: credentialVerifier,
            .verificationSleeper: expirySleeper,
            .diagnosticReporter: incidentReporter,
            .transcriptStore: history,
            .preferences: preferences,
            .clipboard: clipboard,
            .globalShortcuts: shortcutMonitor,
        ]
        let allowlist: [RuntimeAdapterRole: RuntimeAdapterIdentity] = [
            .dictationSession: RuntimeAdapterIdentity(UITestDictationSession.self),
            .guideTranscription: RuntimeAdapterIdentity(UITestGuideTranscriber.self),
            .guideSpeech: RuntimeAdapterIdentity(UITestGuideSpeaker.self),
            .permissions: RuntimeAdapterIdentity(UITestPermissionService.self),
            .textInsertion: RuntimeAdapterIdentity(UITestTextInsertionService.self),
            .screenCapture: RuntimeAdapterIdentity(UITestScreenContextService.self),
            .guidePlanGenerator: RuntimeAdapterIdentity(UITestGuideGenerator.self),
            .localGuidanceProvider: RuntimeAdapterIdentity(UITestLocalModelProvider.self),
            .cloudGuidanceProvider: RuntimeAdapterIdentity(UITestCloudGenerator.self),
            .credentialStore: RuntimeAdapterIdentity(UITestCredentialStore.self),
            .credentialVerifier: RuntimeAdapterIdentity(UITestCredentialVerifier.self),
            .verificationSleeper: RuntimeAdapterIdentity(UITestExpirySleeper.self),
            .diagnosticReporter: RuntimeAdapterIdentity(UITestIncidentReporter.self),
            .transcriptStore: RuntimeAdapterIdentity(UITestHistoryStore.self),
            .preferences: RuntimeAdapterIdentity(UITestPreferences.self),
            .clipboard: RuntimeAdapterIdentity(UITestClipboardService.self),
            .globalShortcuts: RuntimeAdapterIdentity(UITestShortcutMonitor.self),
        ]
        let audit = RuntimeCompositionAudit.deterministic(constructedAdapters, allowlist: allowlist)
        return GuideAppModel(
            defaults: preferences,
            runtimeMode: .uiTest,
            runtimeCompositionAudit: audit,
            clipboard: clipboard,
            permissionService: permissions,
            recordingCoordinator: recording,
            insertionService: insertion,
            historyStore: history,
            screenContextService: capture,
            guidanceTranscriber: transcription,
            guidanceSpeaker: speaker,
            localGuidanceService: localService,
            talkCredentialStore: credentialStore,
            talkCredentialVerifier: credentialVerifier,
            talkVerificationExpirySleeper: expirySleeper,
            talkGenerator: router,
            incidentReporter: incidentReporter,
            shortcutMonitorFactory: { _, callbacks in
                shortcutMonitor.install(callbacks: callbacks)
                return shortcutMonitor
            }
        )
    }

}
