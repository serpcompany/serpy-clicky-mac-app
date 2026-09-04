import Foundation

public enum AppRuntimeCapability: String, Hashable, Sendable {
    case actualAppLifecycle
    case deterministicExternalAdapters
    case ephemeralStorage
    case globalShortcuts
    case clipboard
    case microphone
    case networkProvider
    case permissionRequests
    case persistentUserData
    case productionKeychain
    case screenRecording
    case sentryTransport
}

public enum UITestSessionRootError: Error, Equatable, Sendable {
    case invalidIdentity
    case invalidLocation
    case missingOwnership
}

public enum UITestSessionRootPolicy {
    public static func validate(environment: [String: String]) throws -> URL {
        guard let sessionID = environment["SERPY_TEST_SESSION_ID"],
              UUID(uuidString: sessionID) != nil,
              let rawRoot = environment["SERPY_TEST_ROOT"] else {
            throw UITestSessionRootError.invalidIdentity
        }
        let supplied = URL(fileURLWithPath: rawRoot).standardizedFileURL
        let parentPath = supplied.deletingLastPathComponent().path
        let isDarwinTemp = supplied.deletingLastPathComponent().lastPathComponent == "T"
            && (parentPath.hasPrefix("/var/folders/") || parentPath.hasPrefix("/private/var/folders/"))
        let runnerSuffix = "/Library/Containers/com.serpcompany.guidecompanion.internal.uitests.xctrunner/Data/tmp"
        guard supplied.lastPathComponent == "serpy-real-ui-\(sessionID)",
              isDarwinTemp || parentPath.hasSuffix(runnerSuffix),
              (try? supplied.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) != true else {
            throw UITestSessionRootError.invalidLocation
        }
        let ownerURL = supplied.appendingPathComponent(".serpy-real-ui-owner")
        guard let owner = try? String(contentsOf: ownerURL, encoding: .utf8), owner == sessionID else {
            throw UITestSessionRootError.missingOwnership
        }
        return supplied
    }
}

public enum RuntimeAdapterRole: String, CaseIterable, Hashable, Sendable {
    case audioAndSpeech
    case permissions
    case textInsertion
    case screenCapture
    case guidanceProvider
    case credentialStore
    case diagnosticReporter
    case transcriptStore
    case preferences
    case globalShortcuts
}

public enum RuntimeAdapterKind: String, Equatable, Sendable {
    case production
    case deterministic
}

public struct RuntimeCompositionAudit: Equatable, Sendable {
    public let adapters: [RuntimeAdapterRole: RuntimeAdapterKind]

    public init(adapters: [RuntimeAdapterRole: RuntimeAdapterKind]) {
        self.adapters = adapters
    }

    public static let production = RuntimeCompositionAudit(
        adapters: Dictionary(uniqueKeysWithValues: RuntimeAdapterRole.allCases.map { ($0, .production) })
    )

    public func isValid(for mode: AppRuntimeMode) -> Bool {
        switch mode {
        case .production:
            adapters == Self.production.adapters
        case .uiTest:
            Set(adapters.keys) == Set(RuntimeAdapterRole.allCases)
                && adapters.values.allSatisfy { $0 == .deterministic }
        }
    }
}

public enum AppRuntimeMode: Equatable, Sendable {
    case production
    case uiTest

    public static func resolve(arguments: [String]) -> Self {
        arguments.contains("--ui-testing") ? .uiTest : .production
    }

    public var capabilities: Set<AppRuntimeCapability> {
        switch self {
        case .production:
            [
                .actualAppLifecycle, .globalShortcuts, .microphone,
                .networkProvider, .permissionRequests, .persistentUserData,
                .productionKeychain, .screenRecording, .sentryTransport,
            ]
        case .uiTest:
            [.actualAppLifecycle, .deterministicExternalAdapters, .ephemeralStorage]
        }
    }
}
