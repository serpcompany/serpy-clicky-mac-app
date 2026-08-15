public enum DictationActivationAction: Equatable, Sendable {
    case start
    case finish
    case cancel
    case none
}

public struct DictationActivationPolicy: Sendable {
    public init() {}

    public func shortcutAction(for phase: DictationPhase) -> DictationActivationAction {
        switch phase {
        case .idle, .succeeded, .cancelled, .failed:
            .start
        case .recording:
            .finish
        case .preparing, .transcribing, .inserting:
            .none
        }
    }

    public func escapeAction(for phase: DictationPhase) -> DictationActivationAction {
        phase.isActive ? .cancel : .none
    }
}
