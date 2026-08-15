import Foundation

public enum CompanionBlocker: Equatable, Sendable {
    case permission(String)
    case displayUnavailable
}

public enum CompanionVisibility: Equatable, Sendable {
    case disabled
    case blocked(CompanionBlocker)
    case visible
    case temporarilyHidden(reason: String)
}

public struct CompanionStateMachine: Equatable, Sendable {
    public private(set) var isEnabled: Bool
    public private(set) var visibility: CompanionVisibility

    public init(isEnabled: Bool = false) {
        self.isEnabled = isEnabled
        self.visibility = isEnabled ? .visible : .disabled
    }

    public mutating func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        visibility = enabled ? .visible : .disabled
    }

    public mutating func block(_ blocker: CompanionBlocker) {
        guard isEnabled else { return }
        visibility = .blocked(blocker)
    }

    public mutating func temporarilyHide(reason: String) {
        guard isEnabled, visibility == .visible else { return }
        visibility = .temporarilyHidden(reason: reason)
    }

    public mutating func clearBlockerOrTemporaryHide() {
        guard isEnabled else {
            visibility = .disabled
            return
        }
        visibility = .visible
    }
}

