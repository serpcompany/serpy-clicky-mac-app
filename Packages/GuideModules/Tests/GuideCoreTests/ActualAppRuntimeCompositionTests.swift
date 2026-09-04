import Foundation
import GuideMac
@testable import GuideUI
import Testing
@testable import GuideCore

@Suite("Actual app runtime composition")
struct ActualAppRuntimeCompositionTests {
    @Test("GT-COMPOSITION-001 UI mode resolves before app composition")
    func resolvesUITestMode() {
        #expect(AppRuntimeMode.resolve(arguments: ["serpy", "--ui-testing"]) == .uiTest)
        #expect(AppRuntimeMode.resolve(arguments: ["serpy"]) == .production)
    }

    @Test("GT-COMPOSITION-002 UI mode cannot construct production side effects")
    func uiModeCapabilities() {
        #expect(AppRuntimeMode.uiTest.capabilities == [
            .actualAppLifecycle,
            .deterministicExternalAdapters,
            .ephemeralStorage,
        ])
        #expect(AppRuntimeMode.uiTest.capabilities.isDisjoint(with: [
            .globalShortcuts,
            .microphone,
            .networkProvider,
            .permissionRequests,
            .persistentUserData,
            .productionKeychain,
            .screenRecording,
            .sentryTransport,
        ]))
    }

    @Test("GT-COMPOSITION-003 UI session rejects an unowned root")
    func rejectsUnownedSessionRoot() {
        let sessionID = "9E8EA177-1513-4E7A-88D7-180BB516E820"
        let parent = canonicalTemporaryDirectory()
        let root = parent
            .appendingPathComponent("serpy-real-ui-\(sessionID)")
        #expect(throws: UITestSessionRootError.missingOwnership) {
            try UITestSessionRootPolicy.validate(environment: [
                "SERPY_TEST_SESSION_ID": sessionID,
                "SERPY_TEST_ROOT": root.path,
                "SERPY_TEST_PARENT": parent.path,
            ])
        }
    }

    @Test("GT-COMPOSITION-004 UI session accepts one UUID-owned temp root")
    func acceptsOwnedSessionRoot() throws {
        let sessionID = UUID().uuidString
        let parent = canonicalTemporaryDirectory()
        let root = parent
            .appendingPathComponent("serpy-real-ui-\(sessionID)")
        let parentOwner = parent.appendingPathComponent(".serpy-real-ui-parent-\(sessionID)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: parentOwner)
        }
        try sessionID.write(to: parentOwner, atomically: true, encoding: .utf8)
        try sessionID.write(
            to: root.appendingPathComponent(".serpy-real-ui-owner"),
            atomically: true,
            encoding: .utf8
        )
        #expect(try UITestSessionRootPolicy.validate(environment: [
            "SERPY_TEST_SESSION_ID": sessionID,
            "SERPY_TEST_ROOT": root.path,
            "SERPY_TEST_PARENT": parent.path,
        ]) == root.standardizedFileURL)
    }

    @Test("GT-COMPOSITION-004A UI session rejects a matching suffix outside the system temp root")
    func rejectsSpoofedSuffixInPersistentParent() throws {
        let sessionID = UUID().uuidString
        let unrelatedParent = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(".serpy-root-policy-\(sessionID)")
        let root = unrelatedParent.appendingPathComponent("serpy-real-ui-\(sessionID)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: unrelatedParent) }
        try sessionID.write(to: root.appendingPathComponent(".serpy-real-ui-owner"), atomically: true, encoding: .utf8)
        try sessionID.write(
            to: unrelatedParent.appendingPathComponent(".serpy-real-ui-parent-\(sessionID)"),
            atomically: true,
            encoding: .utf8
        )
        #expect(throws: UITestSessionRootError.invalidLocation) {
            try UITestSessionRootPolicy.validate(environment: [
                "SERPY_TEST_SESSION_ID": sessionID,
                "SERPY_TEST_ROOT": root.path,
                "SERPY_TEST_PARENT": unrelatedParent.path,
            ])
        }
    }

    @Test("GT-COMPOSITION-004B UI session rejects a symlinked parent")
    func rejectsSymlinkedParent() throws {
        let sessionID = UUID().uuidString
        let parent = canonicalTemporaryDirectory()
        let symlinkParent = parent.appendingPathComponent("serpy-parent-link-\(sessionID)")
        let root = parent.appendingPathComponent("serpy-real-ui-\(sessionID)")
        let parentOwner = parent.appendingPathComponent(".serpy-real-ui-parent-\(sessionID)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        try FileManager.default.createSymbolicLink(at: symlinkParent, withDestinationURL: parent)
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: symlinkParent)
            try? FileManager.default.removeItem(at: parentOwner)
        }
        try sessionID.write(to: root.appendingPathComponent(".serpy-real-ui-owner"), atomically: true, encoding: .utf8)
        try sessionID.write(to: parentOwner, atomically: true, encoding: .utf8)
        #expect(throws: UITestSessionRootError.invalidLocation) {
            try UITestSessionRootPolicy.validate(environment: [
                "SERPY_TEST_SESSION_ID": sessionID,
                "SERPY_TEST_ROOT": symlinkParent.appendingPathComponent(root.lastPathComponent).path,
                "SERPY_TEST_PARENT": symlinkParent.path,
            ])
        }
    }

    @Test("GT-COMPOSITION-005 UI dependency audit requires every deterministic external role")
    func validatesCompleteAdapterGraph() {
        let fixture = CompositionFixtureAdapter()
        let complete = RuntimeCompositionAudit.deterministic(
            Dictionary(uniqueKeysWithValues: RuntimeAdapterRole.allCases.map { ($0, fixture) })
        )
        #expect(complete.isValid(for: .uiTest))
        var missing = Dictionary(uniqueKeysWithValues: RuntimeAdapterRole.allCases.map { ($0, fixture) })
        missing.removeValue(forKey: .credentialStore)
        #expect(!RuntimeCompositionAudit.deterministic(missing).isValid(for: .uiTest))
    }

    @Test("GT-COMPOSITION-006 Actual UI-test model constructs the audited safe graph")
    @MainActor
    func constructsActualSafeModel() throws {
        let sessionID = UUID().uuidString
        let parent = canonicalTemporaryDirectory()
        let root = parent
            .appendingPathComponent("serpy-real-ui-\(sessionID)")
        let parentOwner = parent.appendingPathComponent(".serpy-real-ui-parent-\(sessionID)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: parentOwner)
        }
        try sessionID.write(to: parentOwner, atomically: true, encoding: .utf8)
        try sessionID.write(
            to: root.appendingPathComponent(".serpy-real-ui-owner"),
            atomically: true,
            encoding: .utf8
        )
        let model = GuideUITestComposition.makeModel(
            arguments: ["serpy", "--ui-testing", "--golden-flow=UF-09"],
            environment: [
                "SERPY_TEST_SESSION_ID": sessionID,
                "SERPY_TEST_ROOT": root.path,
                "SERPY_TEST_PARENT": parent.path,
            ]
        )
        #expect(model.runtimeMode == .uiTest)
        #expect(model.runtimeCompositionAudit.isValid(for: .uiTest))
        #expect(model.runtimeCompositionAudit.adapters.values.allSatisfy { $0 == .deterministic })
        let expectedTypes: Set<RuntimeAdapterIdentity> = [
            RuntimeAdapterIdentity(UITestDictationSession.self),
            RuntimeAdapterIdentity(UITestGuideTranscriber.self),
            RuntimeAdapterIdentity(UITestGuideSpeaker.self),
            RuntimeAdapterIdentity(UITestPermissionService.self),
            RuntimeAdapterIdentity(UITestTextInsertionService.self),
            RuntimeAdapterIdentity(UITestScreenContextService.self),
            RuntimeAdapterIdentity(UITestGuideGenerator.self),
            RuntimeAdapterIdentity(UITestLocalModelProvider.self),
            RuntimeAdapterIdentity(UITestCloudGenerator.self),
            RuntimeAdapterIdentity(UITestCredentialStore.self),
            RuntimeAdapterIdentity(UITestCredentialVerifier.self),
            RuntimeAdapterIdentity(UITestExpirySleeper.self),
            RuntimeAdapterIdentity(UITestIncidentReporter.self),
            RuntimeAdapterIdentity(UITestHistoryStore.self),
            RuntimeAdapterIdentity(UITestPreferences.self),
            RuntimeAdapterIdentity(UITestClipboardService.self),
            RuntimeAdapterIdentity(UITestShortcutMonitor.self),
        ]
        #expect(Set(model.runtimeCompositionAudit.identities.values) == expectedTypes)
        let forbiddenTypes: Set<RuntimeAdapterIdentity> = [
            RuntimeAdapterIdentity(KeychainTalkCredentialStore.self),
            RuntimeAdapterIdentity(SentryDiagnosticReporter.self),
            RuntimeAdapterIdentity(AppleSpeechTranscriber.self),
            RuntimeAdapterIdentity(PermissionService.self),
            RuntimeAdapterIdentity(OpenAIMultimodalGuidanceGenerator.self),
            RuntimeAdapterIdentity(GlobalShortcutService.self),
            RuntimeAdapterIdentity(TranscriptHistoryStore.self),
            RuntimeAdapterIdentity(TextInsertionService.self),
            RuntimeAdapterIdentity(ScreenContextService.self),
            RuntimeAdapterIdentity(LocalSpeechOutputService.self),
            RuntimeAdapterIdentity(UserDefaults.self),
        ]
        #expect(Set(model.runtimeCompositionAudit.identities.values).isDisjoint(with: forbiddenTypes))
    }

    @Test("GT-COMPOSITION-007 recovery fixture persists across a launch without seed arguments")
    func recoveryFixturePersistsAcrossRelaunch() async throws {
        let sessionID = UUID().uuidString
        let parent = canonicalTemporaryDirectory()
        let root = parent.appendingPathComponent("serpy-real-ui-\(sessionID)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }

        let firstLaunch = UITestHistoryStore(
            arguments: ["serpy", "--recovery-variant=failed"],
            sessionRoot: root
        )
        #expect(await firstLaunch.load().first?.text == "Recovered fixture dictation")

        let relaunched = UITestHistoryStore(arguments: ["serpy"], sessionRoot: root)
        let restored = await relaunched.load()
        #expect(restored.count == 1)
        #expect(restored.first?.deliveryState == .failed)
    }

    private func canonicalTemporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.standardizedFileURL.resolvingSymlinksInPath()
    }
}

private final class CompositionFixtureAdapter: DeterministicUITestAdapter {}
