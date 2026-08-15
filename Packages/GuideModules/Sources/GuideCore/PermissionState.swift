import Foundation

public enum GuidePermission: String, CaseIterable, Codable, Equatable, Sendable {
    case microphone
    case speechRecognition
    case accessibility
    case screenRecording
}

public enum PermissionState: Equatable, Sendable {
    case unknown
    case explained
    case requesting
    case granted
    case denied
    case unavailable(reason: String)

    public var isGranted: Bool {
        self == .granted
    }

    public var displayName: String {
        switch self {
        case .unknown: "Not requested"
        case .explained: "Ready to request"
        case .requesting: "Requesting…"
        case .granted: "Granted"
        case .denied: "Denied"
        case .unavailable(let reason): reason
        }
    }
}

public struct PermissionStateMachine: Equatable, Sendable {
    public private(set) var state: PermissionState

    public init(state: PermissionState = .unknown) {
        self.state = state
    }

    public mutating func explain() {
        guard state == .unknown || state == .denied else { return }
        state = .explained
    }

    public mutating func beginRequest() throws {
        guard state == .explained else {
            throw GuideFailure(
                stage: .permission,
                message: "Permission must be explained before it is requested.",
                recovery: "Show the permission explanation first."
            )
        }
        state = .requesting
    }

    public mutating func resolve(granted: Bool) {
        guard state == .requesting else { return }
        state = granted ? .granted : .denied
    }

    public mutating func synchronize(granted: Bool) {
        if granted {
            state = .granted
        } else if state == .granted || state == .requesting {
            state = .denied
        }
    }

    public mutating func markUnavailable(_ reason: String) {
        state = .unavailable(reason: reason)
    }
}
