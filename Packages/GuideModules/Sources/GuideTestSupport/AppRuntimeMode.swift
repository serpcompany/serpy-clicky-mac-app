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
    case production
    case uiTest

    public static func resolve(arguments: [String]) -> Self {
        arguments.contains("--ui-testing") ? .uiTest : .production
    }

    public var capabilities: Set<AppRuntimeCapability> {
        switch self {
        case .production:
            return [
                .globalShortcuts,
                .microphone,
                .networkProvider,
                .permissionRequests,
                .persistentUserData,
                .productionKeychain,
                .screenRecording,
                .sentryTransport,
            ]
        case .uiTest:
            return [.deterministicFixtures, .ephemeralStorage]
        }
    }
}
