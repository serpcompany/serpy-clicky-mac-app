import Foundation
import GuideUI
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
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("serpy-real-ui-\(sessionID)")
        #expect(throws: UITestSessionRootError.missingOwnership) {
            try UITestSessionRootPolicy.validate(environment: [
                "SERPY_TEST_SESSION_ID": sessionID,
                "SERPY_TEST_ROOT": root.path,
            ])
        }
    }

    @Test("GT-COMPOSITION-004 UI session accepts one UUID-owned temp root")
    func acceptsOwnedSessionRoot() throws {
        let sessionID = UUID().uuidString
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("serpy-real-ui-\(sessionID)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        try sessionID.write(
            to: root.appendingPathComponent(".serpy-real-ui-owner"),
            atomically: true,
            encoding: .utf8
        )
        #expect(try UITestSessionRootPolicy.validate(environment: [
            "SERPY_TEST_SESSION_ID": sessionID,
            "SERPY_TEST_ROOT": root.path,
        ]) == root.standardizedFileURL)
    }

    @Test("GT-COMPOSITION-005 UI dependency audit requires every deterministic external role")
    func validatesCompleteAdapterGraph() {
        let complete = RuntimeCompositionAudit(
            adapters: Dictionary(uniqueKeysWithValues: RuntimeAdapterRole.allCases.map { ($0, .deterministic) })
        )
        #expect(complete.isValid(for: .uiTest))
        var missing = complete.adapters
        missing.removeValue(forKey: .credentialStore)
        #expect(!RuntimeCompositionAudit(adapters: missing).isValid(for: .uiTest))
        var unsafe = complete.adapters
        unsafe[.credentialStore] = .production
        #expect(!RuntimeCompositionAudit(adapters: unsafe).isValid(for: .uiTest))
    }

    @Test("GT-COMPOSITION-006 Actual UI-test model constructs the audited safe graph")
    @MainActor
    func constructsActualSafeModel() throws {
        let sessionID = UUID().uuidString
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("serpy-real-ui-\(sessionID)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
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
            ]
        )
        #expect(model.runtimeMode == .uiTest)
        #expect(model.runtimeCompositionAudit.isValid(for: .uiTest))
        #expect(model.runtimeCompositionAudit.adapters.values.allSatisfy { $0 == .deterministic })
    }
}
