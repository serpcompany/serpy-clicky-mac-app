import Foundation
import Darwin

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
    case injectedProvisioningFailure
    case provisioningCleanupFailed
}

public enum UITestRunParentProvisioning: Equatable, Sendable {
    case boundedWrapper(runToken: String)
    case verifiedXcodeCloud
}

public enum UITestRunParentPolicy {
    public static func resolve(environment: [String: String]) throws -> UITestRunParentProvisioning {
        if let token = environment["SERPY_XCUI_RUN_TOKEN"],
           UUID(uuidString: token) != nil {
            return .boundedWrapper(runToken: token)
        }
        guard environment["CI"] == "TRUE",
              environment["CI_XCODE_CLOUD"] == "TRUE",
              environment["CI_WORKFLOW"] == "golden-ui-tests",
              environment["CI_XCODE_PROJECT"] == "GuideCompanion.xcodeproj",
              environment["CI_XCODE_SCHEME"] == "GuideCompanion",
              environment["CI_XCODEBUILD_ACTION"] == "test-without-building",
              environment["CI_BUILD_ID"]?.isEmpty == false else {
            throw UITestSessionRootError.invalidIdentity
        }
        return .verifiedXcodeCloud
    }
}

public enum UITestProvisioningFault: Equatable, Sendable {
    case none
    case afterParentCreation
    case afterSessionCreation
    case afterSessionTokenWrite
}

public struct UITestRunSession: Sendable {
    public let temporaryRoot: URL
    public let parent: URL
    public let root: URL
    public let runToken: String
    public let sessionID: String

    public func remove(fileManager: FileManager = .default) throws {
        try fileManager.removeItem(at: parent)
    }
}

public struct UITestProvisioningIdentifiers: Sendable {
    public let runToken: String?
    public let sessionID: String?
    public let parentSuffix: String?

    public init(runToken: String? = nil, sessionID: String? = nil, parentSuffix: String? = nil) {
        self.runToken = runToken
        self.sessionID = sessionID
        self.parentSuffix = parentSuffix
    }
}

public enum UITestRunSessionProvisioner {
    public static func provision(
        environment: [String: String],
        temporaryDirectory: URL = FileManager.default.temporaryDirectory,
        fileManager: FileManager = .default,
        fault: UITestProvisioningFault = .none,
        identifiers: UITestProvisioningIdentifiers = .init()
    ) throws -> UITestRunSession {
        let provisioning = try UITestRunParentPolicy.resolve(environment: environment)
        let runToken: String
        switch provisioning {
        case let .boundedWrapper(suppliedRunToken):
            runToken = suppliedRunToken
        case .verifiedXcodeCloud:
            runToken = identifiers.runToken ?? UUID().uuidString
        }

        guard let temporaryRoot = canonicalExistingURL(temporaryDirectory.path) else {
            throw UITestSessionRootError.invalidLocation
        }
        let suffix = identifiers.parentSuffix ?? runToken.replacingOccurrences(of: "-", with: "")
        let parent = temporaryRoot.appendingPathComponent("serpy-xctest-session.\(suffix)")
        let sessionID = identifiers.sessionID ?? UUID().uuidString
        let root = parent.appendingPathComponent("serpy-real-ui-\(sessionID)")
        do {
            try fileManager.createDirectory(at: parent, withIntermediateDirectories: false)
            if fault == .afterParentCreation {
                throw UITestSessionRootError.injectedProvisioningFailure
            }
            try runToken.write(
                to: parent.appendingPathComponent(".serpy-xctest-run-owner"),
                atomically: true,
                encoding: .utf8
            )
            try fileManager.createDirectory(at: root, withIntermediateDirectories: false)
            if fault == .afterSessionCreation {
                throw UITestSessionRootError.injectedProvisioningFailure
            }
            try sessionID.write(
                to: root.appendingPathComponent(".serpy-real-ui-owner"),
                atomically: true,
                encoding: .utf8
            )
            if fault == .afterSessionTokenWrite {
                throw UITestSessionRootError.injectedProvisioningFailure
            }
            return UITestRunSession(
                temporaryRoot: temporaryRoot,
                parent: parent,
                root: root,
                runToken: runToken,
                sessionID: sessionID
            )
        } catch {
            if fileManager.fileExists(atPath: parent.path) {
                do { try fileManager.removeItem(at: parent) }
                catch { throw UITestSessionRootError.provisioningCleanupFailed }
            }
            throw error
        }
    }

    private static func canonicalExistingURL(_ path: String) -> URL? {
        guard let resolved = Darwin.realpath(path, nil) else { return nil }
        defer { Darwin.free(resolved) }
        return URL(fileURLWithPath: String(cString: resolved), isDirectory: true)
    }
}

public enum UITestSessionRootPolicy {
    public static func validate(
        environment: [String: String],
        allowedTemporaryRoots: [URL]? = nil
    ) throws -> URL {
        guard let sessionID = environment["SERPY_TEST_SESSION_ID"],
              UUID(uuidString: sessionID) != nil,
              let runToken = environment["SERPY_XCUI_RUN_TOKEN"],
              UUID(uuidString: runToken) != nil,
              let rawRoot = environment["SERPY_TEST_ROOT"],
              let rawParent = environment["SERPY_TEST_PARENT"],
              let rawTemporaryRoot = environment["SERPY_TEST_TEMP_ROOT"] else {
            throw UITestSessionRootError.invalidIdentity
        }
        let supplied = URL(fileURLWithPath: rawRoot)
        let suppliedParent = URL(fileURLWithPath: rawParent)
        let suppliedTemporaryRoot = URL(fileURLWithPath: rawTemporaryRoot)
        guard let canonicalRoot = canonicalExistingURL(rawRoot),
              let canonicalParent = canonicalExistingURL(rawParent),
              let canonicalTemporaryRoot = canonicalExistingURL(rawTemporaryRoot) else {
            throw UITestSessionRootError.invalidLocation
        }
        let parentName = canonicalParent.lastPathComponent
        let parentSuffix = parentName.dropFirst("serpy-xctest-session.".count)
        let temporaryRootIsAllowed = if let allowedTemporaryRoots {
            allowedTemporaryRoots.contains(where: { $0.path == canonicalTemporaryRoot.path })
        } else {
            isRecognizedSystemTemporaryRoot(canonicalTemporaryRoot)
        }
        guard canonicalRoot.lastPathComponent == "serpy-real-ui-\(sessionID)",
              canonicalRoot.deletingLastPathComponent() == canonicalParent,
              canonicalParent.deletingLastPathComponent() == canonicalTemporaryRoot,
              temporaryRootIsAllowed,
              parentName.hasPrefix("serpy-xctest-session."),
              !parentSuffix.isEmpty,
              parentSuffix.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }),
              supplied.path == canonicalRoot.path,
              suppliedParent.path == canonicalParent.path,
              suppliedTemporaryRoot.path == canonicalTemporaryRoot.path,
              (try? supplied.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) != true,
              (try? suppliedParent.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) != true,
              (try? suppliedTemporaryRoot.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) != true else {
            throw UITestSessionRootError.invalidLocation
        }
        let ownerURL = canonicalRoot.appendingPathComponent(".serpy-real-ui-owner")
        let parentOwnerURL = canonicalParent.appendingPathComponent(".serpy-xctest-run-owner")
        guard let owner = try? String(contentsOf: ownerURL, encoding: .utf8), owner == sessionID,
              let parentOwner = try? String(contentsOf: parentOwnerURL, encoding: .utf8),
              parentOwner == runToken else {
            throw UITestSessionRootError.missingOwnership
        }
        return canonicalRoot
    }

    private static func canonicalExistingURL(_ path: String) -> URL? {
        guard let resolved = Darwin.realpath(path, nil) else { return nil }
        defer { Darwin.free(resolved) }
        return URL(fileURLWithPath: String(cString: resolved))
    }

    private static func isRecognizedSystemTemporaryRoot(_ root: URL) -> Bool {
        var buffer = [CChar](repeating: 0, count: Int(PATH_MAX))
        if confstr(_CS_DARWIN_USER_TEMP_DIR, &buffer, buffer.count) > 0 {
            let bytes = buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
            if let canonical = canonicalExistingURL(String(decoding: bytes, as: UTF8.self)),
               canonical.path == root.path {
                return true
            }
        }
        let home = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        return [
            "com.serpcompany.guidecompanion.internal.uitests",
            "com.serpcompany.guidecompanion.internal.uitests.xctrunner",
        ].contains { container in
            home.appendingPathComponent("Library/Containers/\(container)/Data/tmp", isDirectory: true).path
                == root.path
        }
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
    public let deterministicAllowlist: [RuntimeAdapterRole: RuntimeAdapterIdentity]

    private init(
        adapters: [RuntimeAdapterRole: RuntimeAdapterKind],
        identities: [RuntimeAdapterRole: RuntimeAdapterIdentity] = [:],
        deterministicAllowlist: [RuntimeAdapterRole: RuntimeAdapterIdentity] = [:]
    ) {
        self.adapters = adapters
        self.identities = identities
        self.deterministicAllowlist = deterministicAllowlist
    }

    public static let production = RuntimeCompositionAudit(
        adapters: Dictionary(uniqueKeysWithValues: RuntimeAdapterRole.allCases.map { ($0, .production) })
    )

    public static func deterministic(
        _ constructedAdapters: [RuntimeAdapterRole: any DeterministicUITestAdapter],
        allowlist: [RuntimeAdapterRole: RuntimeAdapterIdentity]
    ) -> RuntimeCompositionAudit {
        RuntimeCompositionAudit(
            adapters: Dictionary(uniqueKeysWithValues: constructedAdapters.keys.map { ($0, .deterministic) }),
            identities: constructedAdapters.mapValues { RuntimeAdapterIdentity(type(of: $0)) },
            deterministicAllowlist: allowlist
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
                && identities == deterministicAllowlist
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
