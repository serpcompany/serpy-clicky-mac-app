import Foundation
import Testing
@testable import GuideTestSupport

@Suite("Golden runtime composition")
struct GoldenRuntimeCompositionTests {
    @Test("GT-UF00-001 UI runtime is selected before composition")
    func uiRuntimeSelection() throws {
        let runtime = try GoldenHostRuntimeContract.resolve(arguments: ["serpy", "--ui-testing"])

        #expect(runtime == .uiTest)
        #expect(runtime.capabilities == [.deterministicFixtures, .ephemeralStorage])
    }

    @Test("GT-UF00-004 Golden host refuses to compose without UI runtime")
    func goldenHostRefusesProductionRuntime() {
        #expect(throws: GoldenHostRuntimeError.uiTestingArgumentRequired) {
            try GoldenHostRuntimeContract.resolve(arguments: ["serpy"])
        }
    }

    @Test("GT-UF00-005 Golden session root is exact and rejects traversal or unrelated roots")
    func goldenSessionRootValidation() throws {
        let fileManager = FileManager.default
        let temporary = fileManager.temporaryDirectory.resolvingSymlinksInPath()
        let sessionID = UUID().uuidString
        let valid = temporary.appendingPathComponent("serpy-golden-\(sessionID)")
        try fileManager.createDirectory(at: valid, withIntermediateDirectories: false)
        defer { try? fileManager.removeItem(at: valid) }
        let environment = ["SERPY_TEST_SESSION_ID": sessionID, "SERPY_TEST_ROOT": valid.path]
        #expect(try GoldenTestSessionContract.resolveRoot(
            environment: environment,
            temporaryDirectory: temporary
        ).path == valid.path)

        #expect(throws: GoldenHostRuntimeError.invalidSessionRoot) {
            try GoldenTestSessionContract.resolveRoot(
                environment: [
                    "SERPY_TEST_SESSION_ID": sessionID,
                    "SERPY_TEST_ROOT": valid.appendingPathComponent("../../outside").path,
                ],
                temporaryDirectory: temporary
            )
        }
        #expect(throws: GoldenHostRuntimeError.invalidSessionRoot) {
            try GoldenTestSessionContract.resolveRoot(
                environment: [
                    "SERPY_TEST_SESSION_ID": sessionID,
                    "SERPY_TEST_ROOT": temporary.appendingPathComponent("unrelated").path,
                ],
                temporaryDirectory: temporary
            )
        }
    }

    @Test("GT-UF00-006 Golden session root rejects symlinks")
    func goldenSessionRootRejectsSymlink() throws {
        let fileManager = FileManager.default
        let temporary = fileManager.temporaryDirectory.resolvingSymlinksInPath()
        let sessionID = UUID().uuidString
        let destination = temporary.appendingPathComponent("serpy-golden-destination-\(sessionID)")
        let link = temporary.appendingPathComponent("serpy-golden-\(sessionID)")
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: false)
        try fileManager.createSymbolicLink(at: link, withDestinationURL: destination)
        defer {
            try? fileManager.removeItem(at: link)
            try? fileManager.removeItem(at: destination)
        }
        #expect(throws: GoldenHostRuntimeError.invalidSessionRoot) {
            try GoldenTestSessionContract.resolveRoot(
                environment: ["SERPY_TEST_SESSION_ID": sessionID, "SERPY_TEST_ROOT": link.path],
                temporaryDirectory: temporary
            )
        }
    }

    @Test("GT-UF00-002 UI runtime rejects production capabilities")
    func uiRuntimeRejectsProductionCapabilities() {
        let forbidden: Set<AppRuntimeCapability> = [
            .microphone,
            .permissionRequests,
            .productionKeychain,
            .persistentUserData,
            .screenRecording,
            .sentryTransport,
            .networkProvider,
            .globalShortcuts,
        ]

        #expect(AppRuntimeMode.uiTest.capabilities.isDisjoint(with: forbidden))
    }

}
