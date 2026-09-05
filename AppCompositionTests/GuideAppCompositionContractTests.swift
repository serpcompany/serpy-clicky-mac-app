import Foundation
import Darwin
import GuideCore
import GuideMac
import XCTest

extension KeychainTalkCredentialStore: @retroactive DeterministicUITestAdapter {}

@MainActor
final class GuideAppCompositionContractTests: XCTestCase {
    func testAccessibilityRequestShowsItsOwnRecoveryRoute() throws {
        let owned = try makeOwnedSessionRoot()
        defer { owned.remove() }
        let model = try GuideUITestComposition.makeModel(
            arguments: ["serpy", "--ui-testing", "--golden-flow=UF-01"],
            environment: owned.environment
        )

        model.requestAccessibility()

        XCTAssertEqual(model.recoveryMessage,
            "Open Settings beside Accessibility, enable SERPy, then return here and click Refresh.")
    }

    func testActualAppCompositionConstructsOnlyTheExactAllowlistedAdapterTypes() throws {
        let owned = try makeOwnedSessionRoot()
        defer { owned.remove() }

        let model = try GuideUITestComposition.makeModel(
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

    func testInvalidSharedRootFailsBeforeConstructingTheModel() {
        XCTAssertThrowsError(try GuideUITestComposition.makeModel(
            arguments: ["serpy", "--ui-testing", "--golden-flow=UF-09"],
            environment: [:]
        )) { error in
            XCTAssertEqual(error as? UITestSessionRootError, .invalidIdentity)
        }
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

    func testTokenOwnedShortcutSignalsInvokeInstalledCallbacksInSequence() async throws {
        let owned = try makeOwnedSessionRoot()
        defer { owned.remove() }
        let recorder = ShortcutCallbackRecorder()
        let monitor = UITestShortcutMonitor(sessionRoot: owned.root)
        monitor.install(callbacks: GlobalShortcutCallbacks(
            dictationPressed: { recorder.events.append("dictation-pressed") },
            dictationReleased: { recorder.events.append("dictation-released") },
            guidePressed: { recorder.events.append("pressed") },
            guideReleased: { recorder.events.append("released") },
            cancelled: { recorder.events.append("cancelled") }
        ))
        try monitor.start()
        defer { monitor.stop() }

        let actions = ["dictation-pressed", "dictation-released", "guide-pressed", "guide-released", "cancelled"]
        for (index, action) in actions.enumerated() {
            let name = "shortcut.00000000-0000-4000-8000-00000000000\(index).\(action).trigger"
            try Data().write(to: owned.root.appendingPathComponent(name), options: .atomic)
        }
        for _ in 0..<100 where recorder.events.count < actions.count {
            try await Task.sleep(for: .milliseconds(25))
        }
        XCTAssertEqual(recorder.events, [
            "dictation-pressed", "dictation-released", "pressed", "released", "cancelled",
        ])
    }

    private func makeOwnedSessionRoot() throws -> OwnedSessionRoot {
        let sessionID = UUID().uuidString
        let runToken = UUID().uuidString
        let suffix = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        let rawTemporaryPath = FileManager.default.temporaryDirectory.path
        guard let resolvedTemporaryPath = Darwin.realpath(rawTemporaryPath, nil) else {
            throw UITestSessionRootError.invalidLocation
        }
        defer { Darwin.free(resolvedTemporaryPath) }
        let temporaryRoot = URL(
            fileURLWithPath: String(cString: resolvedTemporaryPath),
            isDirectory: true
        )
        let parent = temporaryRoot.appendingPathComponent("serpy-xctest-session.\(suffix)")
        let root = parent.appendingPathComponent("serpy-real-ui-\(sessionID)")
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: false)
        try runToken.write(
            to: parent.appendingPathComponent(".serpy-xctest-run-owner"),
            atomically: true,
            encoding: .utf8
        )
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        try sessionID.write(
            to: root.appendingPathComponent(".serpy-real-ui-owner"),
            atomically: true,
            encoding: .utf8
        )
        return OwnedSessionRoot(
            parent: parent,
            root: root,
            environment: [
                "SERPY_TEST_SESSION_ID": sessionID,
                "SERPY_XCUI_RUN_TOKEN": runToken,
                "SERPY_TEST_ROOT": root.path,
                "SERPY_TEST_PARENT": parent.path,
                "SERPY_TEST_TEMP_ROOT": temporaryRoot.path,
            ]
        )
    }
}

private final class ContractFixtureAdapter: DeterministicUITestAdapter {}

private struct OwnedSessionRoot {
    let parent: URL
    let root: URL
    let environment: [String: String]

    func remove() {
        try? FileManager.default.removeItem(at: parent)
    }
}

@MainActor
private final class ShortcutCallbackRecorder {
    var events: [String] = []
}
