public enum AppRuntimeCapability: String, Hashable, Sendable {
    case actualAppLifecycle
    case deterministicExternalAdapters
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
