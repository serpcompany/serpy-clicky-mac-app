import Foundation
import GuideCore
import GuideMac
import XCTest

extension KeychainTalkCredentialStore: @retroactive DeterministicUITestAdapter {}

@MainActor
final class GuideAppCompositionContractTests: XCTestCase {
    func testActualAppCompositionConstructsOnlyTheExactAllowlistedAdapterTypes() throws {
        let owned = try makeOwnedSessionRoot()
        defer { owned.remove() }

        let model = GuideUITestComposition.makeModel(
            arguments: ["serpy", "--ui-testing", "--golden-flow=UF-09"],
            environment: owned.environment
        )

        let expected: [RuntimeAdapterRole: RuntimeAdapterIdentity] = [
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
        let productionDenylist: Set<RuntimeAdapterIdentity> = [
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

        XCTAssertEqual(model.runtimeMode, .uiTest)
        XCTAssertTrue(model.runtimeCompositionAudit.isValid(for: .uiTest))
        XCTAssertEqual(model.runtimeCompositionAudit.identities, expected)
        XCTAssertTrue(Set(model.runtimeCompositionAudit.identities.values).isDisjoint(with: productionDenylist))
    }

    func testInjectedProductionCredentialAdapterFailsTheExactAllowlist() {
        let safe = ContractFixtureAdapter()
        let safeIdentity = RuntimeAdapterIdentity(ContractFixtureAdapter.self)
        var constructed = Dictionary(
            uniqueKeysWithValues: RuntimeAdapterRole.allCases.map {
                ($0, safe as any DeterministicUITestAdapter)
            }
        )
        let allowlist = Dictionary(
            uniqueKeysWithValues: RuntimeAdapterRole.allCases.map { ($0, safeIdentity) }
        )
        constructed[.credentialStore] = KeychainTalkCredentialStore()

        let mutated = RuntimeCompositionAudit.deterministic(constructed, allowlist: allowlist)

        XCTAssertFalse(mutated.isValid(for: .uiTest))
        XCTAssertEqual(
            mutated.identities[.credentialStore],
            RuntimeAdapterIdentity(KeychainTalkCredentialStore.self)
        )
    }

    private func makeOwnedSessionRoot() throws -> OwnedSessionRoot {
        let sessionID = UUID().uuidString
        let parent = FileManager.default.temporaryDirectory
            .standardizedFileURL
            .resolvingSymlinksInPath()
        let root = parent.appendingPathComponent("serpy-real-ui-\(sessionID)")
        let parentOwner = parent.appendingPathComponent(".serpy-real-ui-parent-\(sessionID)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        try sessionID.write(to: parentOwner, atomically: true, encoding: .utf8)
        try sessionID.write(
            to: root.appendingPathComponent(".serpy-real-ui-owner"),
            atomically: true,
            encoding: .utf8
        )
        return OwnedSessionRoot(
            root: root,
            parentOwner: parentOwner,
            environment: [
                "SERPY_TEST_SESSION_ID": sessionID,
                "SERPY_TEST_ROOT": root.path,
                "SERPY_TEST_PARENT": parent.path,
            ]
        )
    }
}

private final class ContractFixtureAdapter: DeterministicUITestAdapter {}

private struct OwnedSessionRoot {
    let root: URL
    let parentOwner: URL
    let environment: [String: String]

    func remove() {
        try? FileManager.default.removeItem(at: root)
        try? FileManager.default.removeItem(at: parentOwner)
    }
}
