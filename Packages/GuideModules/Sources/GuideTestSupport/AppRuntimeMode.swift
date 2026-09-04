public enum AppRuntimeCapability: String, CaseIterable, Hashable, Sendable {
    case deterministicFixtures
    case ephemeralStorage
    case globalShortcuts
    case microphone
    case networkProvider
    case permissionRequests
    case persistentUserData
    case productionKeychain
    case screenRecording
    case sentryTransport
}

public enum AppRuntimeMode: Equatable, Sendable {
    case uiTest

    public var capabilities: Set<AppRuntimeCapability> {
        [.deterministicFixtures, .ephemeralStorage]
    }
}

public enum GoldenHostRuntimeError: Error, Equatable, Sendable {
    case uiTestingArgumentRequired
    case invalidSessionIdentifier
    case invalidSessionRoot
}

public enum GoldenTestSessionContract {
    public static func resolveRoot(
        environment: [String: String],
        temporaryDirectory: URL
    ) throws -> URL {
        guard let sessionID = environment["SERPY_TEST_SESSION_ID"],
              UUID(uuidString: sessionID) != nil else {
            throw GoldenHostRuntimeError.invalidSessionIdentifier
        }
        guard let rawRoot = environment["SERPY_TEST_ROOT"] else {
            throw GoldenHostRuntimeError.invalidSessionRoot
        }
        let supplied = URL(fileURLWithPath: rawRoot)
        let canonicalTemp = temporaryDirectory.standardizedFileURL.resolvingSymlinksInPath()
        let canonicalRoot = supplied.standardizedFileURL.resolvingSymlinksInPath()
        guard canonicalRoot.deletingLastPathComponent() == canonicalTemp,
              canonicalRoot.lastPathComponent == "serpy-golden-\(sessionID)",
              supplied.standardizedFileURL.path == canonicalRoot.path else {
            throw GoldenHostRuntimeError.invalidSessionRoot
        }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: canonicalRoot.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw GoldenHostRuntimeError.invalidSessionRoot
        }
        return canonicalRoot
    }
}

public enum GoldenHostRuntimeContract {
    public static func resolve(arguments: [String]) throws -> AppRuntimeMode {
        guard arguments.contains("--ui-testing") else {
            throw GoldenHostRuntimeError.uiTestingArgumentRequired
        }
        return .uiTest
    }
}
import Foundation
