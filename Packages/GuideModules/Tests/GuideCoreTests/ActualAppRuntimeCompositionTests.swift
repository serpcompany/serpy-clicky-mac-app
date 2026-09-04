import Foundation
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
    func rejectsUnownedSessionRoot() throws {
        let sessionID = "9E8EA177-1513-4E7A-88D7-180BB516E820"
        let run = try makeOwnedRunParent()
        defer { try? FileManager.default.removeItem(at: run.parent) }
        let root = run.parent.appendingPathComponent("serpy-real-ui-\(sessionID)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        #expect(throws: UITestSessionRootError.missingOwnership) {
            try UITestSessionRootPolicy.validate(environment: [
                "SERPY_TEST_SESSION_ID": sessionID,
                "SERPY_XCUI_RUN_TOKEN": run.token,
                "SERPY_TEST_ROOT": root.path,
                "SERPY_TEST_PARENT": run.parent.path,
            ])
        }
    }

    @Test("GT-COMPOSITION-004 UI session accepts one UUID-owned temp root")
    func acceptsOwnedSessionRoot() throws {
        let sessionID = UUID().uuidString
        let run = try makeOwnedRunParent()
        let root = run.parent
            .appendingPathComponent("serpy-real-ui-\(sessionID)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: run.parent) }
        try sessionID.write(
            to: root.appendingPathComponent(".serpy-real-ui-owner"),
            atomically: true,
            encoding: .utf8
        )
        #expect(try UITestSessionRootPolicy.validate(environment: [
            "SERPY_TEST_SESSION_ID": sessionID,
            "SERPY_XCUI_RUN_TOKEN": run.token,
            "SERPY_TEST_ROOT": root.path,
            "SERPY_TEST_PARENT": run.parent.path,
        ]).path == root.path)
    }

    @Test("GT-COMPOSITION-004A UI session rejects a matching suffix outside the system temp root")
    func rejectsSpoofedSuffixInPersistentParent() throws {
        let sessionID = UUID().uuidString
        let runToken = UUID().uuidString
        let unrelatedParent = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(".serpy-root-policy-\(sessionID)")
        let root = unrelatedParent.appendingPathComponent("serpy-real-ui-\(sessionID)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: unrelatedParent) }
        try sessionID.write(to: root.appendingPathComponent(".serpy-real-ui-owner"), atomically: true, encoding: .utf8)
        try runToken.write(
            to: unrelatedParent.appendingPathComponent(".serpy-local-xcui-owner"),
            atomically: true,
            encoding: .utf8
        )
        #expect(throws: UITestSessionRootError.invalidLocation) {
            try UITestSessionRootPolicy.validate(environment: [
                "SERPY_TEST_SESSION_ID": sessionID,
                "SERPY_XCUI_RUN_TOKEN": runToken,
                "SERPY_TEST_ROOT": root.path,
                "SERPY_TEST_PARENT": unrelatedParent.path,
            ])
        }
    }

    @Test("GT-COMPOSITION-004B UI session rejects a symlinked parent")
    func rejectsSymlinkedParent() throws {
        let sessionID = UUID().uuidString
        let run = try makeOwnedRunParent()
        let symlinkName = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        let symlinkParent = sharedTemporaryDirectory().appendingPathComponent("serpy-local-xcui.\(symlinkName)")
        let root = run.parent.appendingPathComponent("serpy-real-ui-\(sessionID)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        try FileManager.default.createSymbolicLink(at: symlinkParent, withDestinationURL: run.parent)
        defer {
            try? FileManager.default.removeItem(at: symlinkParent)
            try? FileManager.default.removeItem(at: run.parent)
        }
        try sessionID.write(to: root.appendingPathComponent(".serpy-real-ui-owner"), atomically: true, encoding: .utf8)
        #expect(throws: UITestSessionRootError.invalidLocation) {
            try UITestSessionRootPolicy.validate(environment: [
                "SERPY_TEST_SESSION_ID": sessionID,
                "SERPY_XCUI_RUN_TOKEN": run.token,
                "SERPY_TEST_ROOT": symlinkParent.appendingPathComponent(root.lastPathComponent).path,
                "SERPY_TEST_PARENT": symlinkParent.path,
            ])
        }
    }

    @Test("GT-COMPOSITION-004C shared session root ignores process-specific temporary directories")
    func acceptsCrossProcessSharedRoot() throws {
        let sessionID = UUID().uuidString
        let run = try makeOwnedRunParent()
        let root = run.parent.appendingPathComponent("serpy-real-ui-\(sessionID)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: run.parent) }
        try sessionID.write(
            to: root.appendingPathComponent(".serpy-real-ui-owner"),
            atomically: true,
            encoding: .utf8
        )

        #expect(try UITestSessionRootPolicy.validate(environment: [
            "TMPDIR": "/private/tmp/a-different-process-temp",
            "SERPY_TEST_SESSION_ID": sessionID,
            "SERPY_XCUI_RUN_TOKEN": run.token,
            "SERPY_TEST_ROOT": root.path,
            "SERPY_TEST_PARENT": run.parent.path,
        ]).path == root.path)
    }

    @Test("GT-COMPOSITION-005 UI dependency audit requires every deterministic external role")
    func validatesCompleteAdapterGraph() {
        let fixture = CompositionFixtureAdapter()
        let allowlist = Dictionary(
            uniqueKeysWithValues: RuntimeAdapterRole.allCases.map {
                ($0, RuntimeAdapterIdentity(CompositionFixtureAdapter.self))
            }
        )
        let complete = RuntimeCompositionAudit.deterministic(
            Dictionary(uniqueKeysWithValues: RuntimeAdapterRole.allCases.map { ($0, fixture) }),
            allowlist: allowlist
        )
        #expect(complete.isValid(for: .uiTest))
        var missing = Dictionary(uniqueKeysWithValues: RuntimeAdapterRole.allCases.map { ($0, fixture) })
        missing.removeValue(forKey: .credentialStore)
        #expect(!RuntimeCompositionAudit.deterministic(missing, allowlist: allowlist).isValid(for: .uiTest))
    }

    private func sharedTemporaryDirectory() -> URL {
        URL(fileURLWithPath: "/private/tmp", isDirectory: true)
    }

    private func makeOwnedRunParent() throws -> (parent: URL, token: String) {
        let suffix = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        let parent = sharedTemporaryDirectory().appendingPathComponent("serpy-local-xcui.\(suffix)")
        let token = UUID().uuidString
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: false)
        try token.write(
            to: parent.appendingPathComponent(".serpy-local-xcui-owner"),
            atomically: true,
            encoding: .utf8
        )
        return (parent, token)
    }
}

private final class CompositionFixtureAdapter: DeterministicUITestAdapter {}
