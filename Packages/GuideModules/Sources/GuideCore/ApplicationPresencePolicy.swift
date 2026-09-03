public enum ApplicationLifetimeState: Equatable, Sendable {
    case running(settingsVisible: Bool)
    case terminating
}

public enum ApplicationPresence: Equatable, Sendable {
    case regular
    case prohibited
}

/// Product policy for the app's lifetime presence. Settings visibility is
/// deliberately input-only evidence: closing a window never turns SERPy into
/// a hidden accessory application.
public struct ApplicationPresencePolicy: Sendable {
    public init() {}

    public func presence(for state: ApplicationLifetimeState) -> ApplicationPresence {
        switch state {
        case .running:
            .regular
        case .terminating:
            .prohibited
        }
    }
}
