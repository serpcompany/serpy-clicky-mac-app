public struct GlobalShortcutModifiers: OptionSet, Codable, Equatable, Hashable, Sendable {
    public let rawValue: UInt8

    public init(rawValue: UInt8) { self.rawValue = rawValue }

    public static let control = GlobalShortcutModifiers(rawValue: 1 << 0)
    public static let option = GlobalShortcutModifiers(rawValue: 1 << 1)
    public static let shift = GlobalShortcutModifiers(rawValue: 1 << 2)
    public static let command = GlobalShortcutModifiers(rawValue: 1 << 3)
}

public struct GlobalHotKeyConfiguration: Codable, Equatable, Sendable {
    public let keyCode: UInt16
    public let modifiers: GlobalShortcutModifiers
    public let displayName: String

    public init(keyCode: UInt16, modifiers: GlobalShortcutModifiers, displayName: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.displayName = displayName
    }

    public static let dictation = GlobalHotKeyConfiguration(
        keyCode: 49,
        modifiers: .option,
        displayName: "⌥Space"
    )
}

public struct GlobalModifierChordConfiguration: Codable, Equatable, Hashable, Sendable, Identifiable {
    public let modifiers: GlobalShortcutModifiers
    public let displayName: String

    public var id: GlobalShortcutModifiers { modifiers }

    public init(modifiers: GlobalShortcutModifiers, displayName: String) {
        self.modifiers = modifiers
        self.displayName = displayName
    }

    public static let guideDefault = GlobalModifierChordConfiguration(
        modifiers: [.control, .option],
        displayName: "Control–Option"
    )

    public static let guideChoices: [GlobalModifierChordConfiguration] = [
        guideDefault,
        .init(modifiers: [.control, .command], displayName: "Control–Command"),
        .init(modifiers: [.option, .command], displayName: "Option–Command")
    ]
}

public struct GlobalShortcutConfigurationSet: Equatable, Sendable {
    public let dictation: GlobalHotKeyConfiguration
    public let guide: GlobalModifierChordConfiguration

    public init(
        dictation: GlobalHotKeyConfiguration,
        guide: GlobalModifierChordConfiguration
    ) {
        self.dictation = dictation
        self.guide = guide
    }
}

public enum GlobalHotKeyTransition: Equatable, Sendable {
    case pressed
    case released
}

public enum GlobalShortcutEventKind: Equatable, Sendable {
    case keyDown
    case keyUp
    case flagsChanged
}

public struct GlobalShortcutEventSnapshot: Equatable, Sendable {
    public let keyCode: UInt16
    public let modifiers: GlobalShortcutModifiers
    public let kind: GlobalShortcutEventKind

    public init(
        keyCode: UInt16,
        modifiers: GlobalShortcutModifiers,
        kind: GlobalShortcutEventKind
    ) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.kind = kind
    }
}

public enum GlobalShortcutGesture: Equatable, Sendable {
    case key(GlobalHotKeyConfiguration)
    case modifierChord(GlobalModifierChordConfiguration)

    fileprivate var modifiers: GlobalShortcutModifiers {
        switch self {
        case let .key(configuration): configuration.modifiers
        case let .modifierChord(configuration): configuration.modifiers
        }
    }
}

public enum GlobalShortcutID: String, Equatable, Hashable, Sendable {
    case dictation
    case guide
}

public struct GlobalShortcutBinding: Equatable, Sendable {
    public let id: GlobalShortcutID
    public let gesture: GlobalShortcutGesture

    public init(id: GlobalShortcutID, gesture: GlobalShortcutGesture) {
        self.id = id
        self.gesture = gesture
    }
}

public struct GlobalShortcutDelivery: Equatable, Sendable {
    public let id: GlobalShortcutID
    public let transition: GlobalHotKeyTransition

    public init(id: GlobalShortcutID, transition: GlobalHotKeyTransition) {
        self.id = id
        self.transition = transition
    }
}

@MainActor
public struct GlobalShortcutCallbacks {
    public let dictationPressed: @MainActor @Sendable () -> Void
    public let dictationReleased: @MainActor @Sendable () -> Void
    public let guidePressed: @MainActor @Sendable () -> Void
    public let guideReleased: @MainActor @Sendable () -> Void
    public let cancelled: @MainActor @Sendable () -> Void

    public init(
        dictationPressed: @escaping @MainActor @Sendable () -> Void,
        dictationReleased: @escaping @MainActor @Sendable () -> Void,
        guidePressed: @escaping @MainActor @Sendable () -> Void,
        guideReleased: @escaping @MainActor @Sendable () -> Void,
        cancelled: @escaping @MainActor @Sendable () -> Void
    ) {
        self.dictationPressed = dictationPressed
        self.dictationReleased = dictationReleased
        self.guidePressed = guidePressed
        self.guideReleased = guideReleased
        self.cancelled = cancelled
    }
}

public struct GlobalShortcutRouteResult: Equatable, Sendable {
    public let deliveries: [GlobalShortcutDelivery]
    public let shouldConsume: Bool

    public init(deliveries: [GlobalShortcutDelivery], shouldConsume: Bool) {
        self.deliveries = deliveries
        self.shouldConsume = shouldConsume
    }
}

public struct GlobalShortcutEventRouter: Sendable {
    private let bindings: [GlobalShortcutBinding]
    private var pressedBindingIDs: Set<GlobalShortcutID> = []

    public init(bindings: [GlobalShortcutBinding]) {
        self.bindings = bindings
    }

    public mutating func route(_ event: GlobalShortcutEventSnapshot) -> GlobalShortcutRouteResult {
        var deliveries: [GlobalShortcutDelivery] = []
        var shouldConsume = false

        for binding in bindings {
            switch binding.gesture {
            case let .key(configuration):
                guard event.kind == .keyDown || event.kind == .keyUp,
                      event.keyCode == configuration.keyCode
                else { continue }
                let isDown = event.kind == .keyDown
                if isDown,
                   event.modifiers == configuration.modifiers,
                   pressedBindingIDs.insert(binding.id).inserted {
                    deliveries.append(.init(id: binding.id, transition: .pressed))
                } else if !isDown, pressedBindingIDs.remove(binding.id) != nil {
                    deliveries.append(.init(id: binding.id, transition: .released))
                }
                if event.modifiers == configuration.modifiers || pressedBindingIDs.contains(binding.id) {
                    shouldConsume = true
                }

            case .modifierChord:
                guard event.kind == .flagsChanged else { continue }
                let isDown = event.modifiers == binding.gesture.modifiers
                if isDown, pressedBindingIDs.insert(binding.id).inserted {
                    deliveries.append(.init(id: binding.id, transition: .pressed))
                } else if !isDown, pressedBindingIDs.remove(binding.id) != nil {
                    deliveries.append(.init(id: binding.id, transition: .released))
                }
            }
        }

        return .init(deliveries: deliveries, shouldConsume: shouldConsume)
    }

    public mutating func reset() {
        pressedBindingIDs.removeAll(keepingCapacity: false)
    }
}
