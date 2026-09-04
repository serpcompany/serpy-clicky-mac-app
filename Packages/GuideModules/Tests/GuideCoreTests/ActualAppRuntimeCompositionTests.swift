import Foundation
import Darwin
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
                "SERPY_TEST_TEMP_ROOT": run.base.path,
            ], allowedTemporaryRoots: [run.base])
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
            "SERPY_TEST_TEMP_ROOT": run.base.path,
        ], allowedTemporaryRoots: [run.base]).path == root.path)
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
            to: unrelatedParent.appendingPathComponent(".serpy-xctest-run-owner"),
            atomically: true,
            encoding: .utf8
        )
        #expect(throws: UITestSessionRootError.invalidLocation) {
            try UITestSessionRootPolicy.validate(environment: [
                "SERPY_TEST_SESSION_ID": sessionID,
                "SERPY_XCUI_RUN_TOKEN": runToken,
                "SERPY_TEST_ROOT": root.path,
                "SERPY_TEST_PARENT": unrelatedParent.path,
                "SERPY_TEST_TEMP_ROOT": unrelatedParent.deletingLastPathComponent().path,
            ], allowedTemporaryRoots: [runTestTemporaryDirectory()])
        }
    }

    @Test("GT-COMPOSITION-004B UI session rejects a symlinked parent")
    func rejectsSymlinkedParent() throws {
        let sessionID = UUID().uuidString
        let run = try makeOwnedRunParent()
        let symlinkName = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        let symlinkParent = run.base.appendingPathComponent("serpy-xctest-session.\(symlinkName)")
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
                "SERPY_TEST_TEMP_ROOT": run.base.path,
            ], allowedTemporaryRoots: [run.base])
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
            "SERPY_TEST_TEMP_ROOT": run.base.path,
        ], allowedTemporaryRoots: [run.base]).path == root.path)
    }

    @Test("GT-COMPOSITION-004D local UI parent requires the bounded wrapper token")
    func resolvesBoundedWrapperParent() throws {
        let token = UUID().uuidString
        #expect(try UITestRunParentPolicy.resolve(environment: [
            "SERPY_XCUI_RUN_TOKEN": token,
        ]) == .boundedWrapper(runToken: token))
    }

    @Test("GT-COMPOSITION-004D2 XCTest session does not write into wrapper build scratch")
    func provisionsOutsideUnwritableWrapperScratch() throws {
        let token = UUID().uuidString
        let base = runTestTemporaryDirectory()
        let session = try UITestRunSessionProvisioner.provision(
            environment: [
                "SERPY_XCUI_RUN_TOKEN": token,
                "SERPY_XCUI_PARENT": "/private/tmp/serpy-local-xcui.unwritable",
            ],
            temporaryDirectory: base
        )
        defer { try? session.remove() }
        #expect(session.parent.deletingLastPathComponent() == base)
        #expect(!session.parent.path.hasPrefix("/private/tmp/serpy-local-xcui.unwritable/"))
    }

    @Test("GT-COMPOSITION-004E exact Xcode Cloud workflow may own its parent")
    func resolvesVerifiedXcodeCloudParent() throws {
        #expect(try UITestRunParentPolicy.resolve(environment: verifiedCloudEnvironment()) == .verifiedXcodeCloud)
    }

    @Test("GT-COMPOSITION-004F missing or untrusted cloud identity fails closed")
    func rejectsMissingAndUntrustedParentProvisioning() {
        #expect(throws: UITestSessionRootError.invalidIdentity) {
            try UITestRunParentPolicy.resolve(environment: [:])
        }
        var wrongWorkflow = verifiedCloudEnvironment()
        wrongWorkflow["CI_WORKFLOW"] = "untrusted-workflow"
        #expect(throws: UITestSessionRootError.invalidIdentity) {
            try UITestRunParentPolicy.resolve(environment: wrongWorkflow)
        }
        #expect(throws: UITestSessionRootError.invalidIdentity) {
            try UITestRunParentPolicy.resolve(environment: [
                "SERPY_XCUI_RUN_TOKEN": "not-a-uuid",
            ])
        }
    }

    @Test("GT-COMPOSITION-004G cloud failure after parent creation removes only its parent")
    func cleansCloudFailureAfterParentCreation() throws {
        try assertCloudProvisioningCleanup(fault: .afterParentCreation, suffix: "FaultAfterParent")
    }

    @Test("GT-COMPOSITION-004H cloud failure after session creation removes only its parent")
    func cleansCloudFailureAfterSessionCreation() throws {
        try assertCloudProvisioningCleanup(fault: .afterSessionCreation, suffix: "FaultAfterSession")
    }

    @Test("GT-COMPOSITION-004I cloud failure after token write removes only its parent")
    func cleansCloudFailureAfterSessionTokenWrite() throws {
        try assertCloudProvisioningCleanup(fault: .afterSessionTokenWrite, suffix: "FaultAfterToken")
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

    private func runTestTemporaryDirectory() -> URL {
        let rawPath = FileManager.default.temporaryDirectory.path
        guard let resolved = Darwin.realpath(rawPath, nil) else {
            return FileManager.default.temporaryDirectory
        }
        defer { Darwin.free(resolved) }
        return URL(fileURLWithPath: String(cString: resolved), isDirectory: true)
    }

    private func makeOwnedRunParent() throws -> (base: URL, parent: URL, token: String) {
        let suffix = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        let base = runTestTemporaryDirectory()
        let parent = base.appendingPathComponent("serpy-xctest-session.\(suffix)")
        let token = UUID().uuidString
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: false)
        try token.write(
            to: parent.appendingPathComponent(".serpy-xctest-run-owner"),
            atomically: true,
            encoding: .utf8
        )
        return (base, parent, token)
    }

    private func verifiedCloudEnvironment() -> [String: String] {
        [
            "CI": "TRUE",
            "CI_XCODE_CLOUD": "TRUE",
            "CI_WORKFLOW": "golden-ui-tests",
            "CI_XCODE_PROJECT": "GuideCompanion",
            "CI_XCODE_SCHEME": "GuideCompanion",
            "CI_XCODEBUILD_ACTION": "test-without-building",
            "CI_BUILD_ID": "fixture-build-id",
        ]
    }

    private func assertCloudProvisioningCleanup(
        fault: UITestProvisioningFault,
        suffix: String
    ) throws {
        let base = runTestTemporaryDirectory()
        let parent = base.appendingPathComponent("serpy-xctest-session.\(suffix)")
        let unrelated = base
            .appendingPathComponent("serpy-unrelated-\(UUID().uuidString)")
        try "keep".write(to: unrelated, atomically: true, encoding: .utf8)
        defer {
            try? FileManager.default.removeItem(at: parent)
            try? FileManager.default.removeItem(at: unrelated)
        }

        #expect(throws: UITestSessionRootError.injectedProvisioningFailure) {
            try UITestRunSessionProvisioner.provision(
                environment: verifiedCloudEnvironment(),
                temporaryDirectory: base,
                fault: fault,
                identifiers: UITestProvisioningIdentifiers(
                    runToken: UUID().uuidString,
                    sessionID: UUID().uuidString,
                    parentSuffix: suffix
                )
            )
        }
        #expect(!FileManager.default.fileExists(atPath: parent.path))
        #expect(FileManager.default.fileExists(atPath: unrelated.path))
        #expect(try String(contentsOf: unrelated, encoding: .utf8) == "keep")
    }
}

private final class CompositionFixtureAdapter: DeterministicUITestAdapter {}
