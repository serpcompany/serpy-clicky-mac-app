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
}

public enum GoldenHostRuntimeContract {
    public static func resolve(arguments: [String]) throws -> AppRuntimeMode {
        guard arguments.contains("--ui-testing") else {
            throw GoldenHostRuntimeError.uiTestingArgumentRequired
        }
        return .uiTest
    }
}
