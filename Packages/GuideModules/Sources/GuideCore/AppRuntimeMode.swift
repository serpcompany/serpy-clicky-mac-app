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
              let rawRoot = environment["SERPY_TEST_ROOT"],
              let rawParent = environment["SERPY_TEST_PARENT"] else {
            throw UITestSessionRootError.invalidIdentity
        }
        let supplied = URL(fileURLWithPath: rawRoot).standardizedFileURL
        let canonicalRoot = supplied.resolvingSymlinksInPath()
        let suppliedParent = URL(fileURLWithPath: rawParent).standardizedFileURL
        let canonicalParent = suppliedParent.resolvingSymlinksInPath()
        let systemTemporaryDirectory = FileManager.default.temporaryDirectory
            .standardizedFileURL
            .resolvingSymlinksInPath()
        guard canonicalRoot.lastPathComponent == "serpy-real-ui-\(sessionID)",
              canonicalRoot.deletingLastPathComponent() == canonicalParent,
              canonicalParent == systemTemporaryDirectory,
              supplied.path == canonicalRoot.path,
              suppliedParent.path == canonicalParent.path,
              (try? supplied.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) != true,
              (try? suppliedParent.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) != true else {
            throw UITestSessionRootError.invalidLocation
        }
        let ownerURL = canonicalRoot.appendingPathComponent(".serpy-real-ui-owner")
        let parentOwnerURL = canonicalParent.appendingPathComponent(".serpy-real-ui-parent-\(sessionID)")
        guard let owner = try? String(contentsOf: ownerURL, encoding: .utf8), owner == sessionID,
              let parentOwner = try? String(contentsOf: parentOwnerURL, encoding: .utf8),
              parentOwner == sessionID else {
            throw UITestSessionRootError.missingOwnership
        }
        return canonicalRoot
    }
}

public enum RuntimeAdapterRole: String, CaseIterable, Hashable, Sendable {
    case dictationSession
    case guideTranscription
    case guideSpeech
    case permissions
    case textInsertion
    case screenCapture
    case guidePlanGenerator
    case localGuidanceProvider
    case cloudGuidanceProvider
    case credentialStore
    case credentialVerifier
    case verificationSleeper
    case diagnosticReporter
    case transcriptStore
    case preferences
    case clipboard
    case globalShortcuts
}

public enum RuntimeAdapterKind: String, Equatable, Sendable {
    case production
    case deterministic
}

/// Only deterministic adapters owned by the isolated UI-test composition may
/// conform. Requiring the constructed value prevents a production adapter from
/// being relabeled as deterministic in an audit dictionary.
public protocol DeterministicUITestAdapter {}

public struct RuntimeAdapterIdentity: Hashable, @unchecked Sendable {
    public let objectIdentifier: ObjectIdentifier
    public let typeName: String

    public init(_ type: Any.Type) {
        objectIdentifier = ObjectIdentifier(type)
        typeName = String(reflecting: type)
    }
}

public struct RuntimeCompositionAudit: Equatable, Sendable {
    public let adapters: [RuntimeAdapterRole: RuntimeAdapterKind]
    public let identities: [RuntimeAdapterRole: RuntimeAdapterIdentity]

    private init(
        adapters: [RuntimeAdapterRole: RuntimeAdapterKind],
        identities: [RuntimeAdapterRole: RuntimeAdapterIdentity] = [:]
    ) {
        self.adapters = adapters
        self.identities = identities
    }

    public static let production = RuntimeCompositionAudit(
        adapters: Dictionary(uniqueKeysWithValues: RuntimeAdapterRole.allCases.map { ($0, .production) })
    )

    public static func deterministic(
        _ constructedAdapters: [RuntimeAdapterRole: any DeterministicUITestAdapter]
    ) -> RuntimeCompositionAudit {
        RuntimeCompositionAudit(
            adapters: Dictionary(uniqueKeysWithValues: constructedAdapters.keys.map { ($0, .deterministic) }),
            identities: constructedAdapters.mapValues { RuntimeAdapterIdentity(type(of: $0)) }
        )
    }

    public func isValid(for mode: AppRuntimeMode) -> Bool {
        switch mode {
        case .production:
            adapters == Self.production.adapters
        case .uiTest:
            Set(adapters.keys) == Set(RuntimeAdapterRole.allCases)
                && adapters.values.allSatisfy { $0 == .deterministic }
                && Set(identities.keys) == Set(RuntimeAdapterRole.allCases)
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
