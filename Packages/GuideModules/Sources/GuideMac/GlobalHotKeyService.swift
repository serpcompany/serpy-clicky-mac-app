import AppKit
import Carbon
import CoreGraphics
import Foundation
import GuideCore

public struct GlobalHotKeyConfiguration: Codable, Equatable, Sendable {
    public let keyCode: UInt32
    public let modifiers: UInt32
    public let displayName: String

    public var cocoaModifiers: UInt {
        var result: UInt = 0
        if modifiers & UInt32(controlKey) != 0 { result |= NSEvent.ModifierFlags.control.rawValue }
        if modifiers & UInt32(optionKey) != 0 { result |= NSEvent.ModifierFlags.option.rawValue }
        if modifiers & UInt32(cmdKey) != 0 { result |= NSEvent.ModifierFlags.command.rawValue }
        if modifiers & UInt32(shiftKey) != 0 { result |= NSEvent.ModifierFlags.shift.rawValue }
        return result
    }

    public init(keyCode: UInt32, modifiers: UInt32, displayName: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.displayName = displayName
    }

    public static let dictation = GlobalHotKeyConfiguration(
        keyCode: UInt32(kVK_Space),
        modifiers: UInt32(optionKey),
        displayName: "⌥Space"
    )
}

public struct GlobalModifierChordConfiguration: Codable, Equatable, Hashable, Sendable, Identifiable {
    public let modifiers: UInt32
    public let displayName: String

    public var id: UInt32 { modifiers }

    public init(modifiers: UInt32, displayName: String) {
        self.modifiers = modifiers
        self.displayName = displayName
    }

    public static let guideDefault = GlobalModifierChordConfiguration(
        modifiers: UInt32(controlKey | optionKey),
        displayName: "Control–Option"
    )

    public static let guideChoices: [GlobalModifierChordConfiguration] = [
        guideDefault,
        .init(modifiers: UInt32(controlKey | cmdKey), displayName: "Control–Command"),
        .init(modifiers: UInt32(optionKey | cmdKey), displayName: "Option–Command")
    ]
}

public struct KeyboardEventSnapshot: Sendable {
    public let keyCode: UInt16
    public let modifierFlags: UInt
    public let isKeyDown: Bool

    public init(keyCode: UInt16, modifierFlags: UInt, isKeyDown: Bool) {
        self.keyCode = keyCode
        self.modifierFlags = modifierFlags
        self.isKeyDown = isKeyDown
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
    public let modifierFlags: UInt
    public let kind: GlobalShortcutEventKind

    public init(keyCode: UInt16, modifierFlags: UInt, kind: GlobalShortcutEventKind) {
        self.keyCode = keyCode
        self.modifierFlags = modifierFlags
        self.kind = kind
    }
}

public struct GlobalShortcutEventAdapter: Sendable {
    public init() {}

    public func snapshot(
        type: CGEventType,
        event: CGEvent
    ) -> GlobalShortcutEventSnapshot? {
        let kind: GlobalShortcutEventKind
        switch type {
        case .keyDown: kind = .keyDown
        case .keyUp: kind = .keyUp
        case .flagsChanged: kind = .flagsChanged
        default: return nil
        }
        var modifierFlags: UInt = 0
        if event.flags.contains(.maskControl) { modifierFlags |= NSEvent.ModifierFlags.control.rawValue }
        if event.flags.contains(.maskAlternate) { modifierFlags |= NSEvent.ModifierFlags.option.rawValue }
        if event.flags.contains(.maskCommand) { modifierFlags |= NSEvent.ModifierFlags.command.rawValue }
        if event.flags.contains(.maskShift) { modifierFlags |= NSEvent.ModifierFlags.shift.rawValue }
        return .init(
            keyCode: UInt16(event.getIntegerValueField(.keyboardEventKeycode)),
            modifierFlags: modifierFlags,
            kind: kind
        )
    }
}

public enum GlobalShortcutGesture: Equatable, Sendable {
    case key(GlobalHotKeyConfiguration)
    case modifierChord(modifiers: UInt32, displayName: String)

    fileprivate var cocoaModifiers: UInt {
        let carbonModifiers: UInt32 = switch self {
        case let .key(configuration): configuration.modifiers
        case let .modifierChord(modifiers, _): modifiers
        }
        var result: UInt = 0
        if carbonModifiers & UInt32(controlKey) != 0 { result |= NSEvent.ModifierFlags.control.rawValue }
        if carbonModifiers & UInt32(optionKey) != 0 { result |= NSEvent.ModifierFlags.option.rawValue }
        if carbonModifiers & UInt32(cmdKey) != 0 { result |= NSEvent.ModifierFlags.command.rawValue }
        if carbonModifiers & UInt32(shiftKey) != 0 { result |= NSEvent.ModifierFlags.shift.rawValue }
        return result
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

public struct GlobalShortcutRouteResult: Equatable, Sendable {
    public let deliveries: [GlobalShortcutDelivery]
    public let shouldConsume: Bool

    public init(deliveries: [GlobalShortcutDelivery], shouldConsume: Bool) {
        self.deliveries = deliveries
        self.shouldConsume = shouldConsume
    }
}

/// Pure event-routing seam shared by the installed event tap and deterministic
/// contract tests. A single router owns every shortcut so registrations cannot
/// silently diverge across multiple taps.
public struct GlobalShortcutEventRouter: Sendable {
    private let bindings: [GlobalShortcutBinding]
    private var pressedBindingIDs: Set<GlobalShortcutID> = []

    public init(bindings: [GlobalShortcutBinding]) {
        self.bindings = bindings
    }

    public mutating func route(_ event: GlobalShortcutEventSnapshot) -> GlobalShortcutRouteResult {
        let significantMask = NSEvent.ModifierFlags.deviceIndependentFlagsMask.rawValue
        let significantFlags = event.modifierFlags & significantMask
        var deliveries: [GlobalShortcutDelivery] = []
        var shouldConsume = false

        for binding in bindings {
            switch binding.gesture {
            case let .key(configuration):
                guard event.kind == .keyDown || event.kind == .keyUp,
                      event.keyCode == UInt16(configuration.keyCode)
                else { continue }
                let isDown = event.kind == .keyDown
                if isDown,
                   significantFlags == configuration.cocoaModifiers,
                   pressedBindingIDs.insert(binding.id).inserted {
                    deliveries.append(.init(id: binding.id, transition: .pressed))
                } else if !isDown, pressedBindingIDs.remove(binding.id) != nil {
                    deliveries.append(.init(id: binding.id, transition: .released))
                }
                if significantFlags == configuration.cocoaModifiers || pressedBindingIDs.contains(binding.id) {
                    shouldConsume = true
                }

            case .modifierChord:
                guard event.kind == .flagsChanged else { continue }
                let isDown = significantFlags == binding.gesture.cocoaModifiers
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

public struct GlobalHotKeyPressState: Sendable {
    private var isPressed = false

    public init() {}

    public mutating func consume(
        _ event: KeyboardEventSnapshot,
        configuration: GlobalHotKeyConfiguration
    ) -> GlobalHotKeyTransition? {
        guard event.keyCode == UInt16(configuration.keyCode) else { return nil }
        if event.isKeyDown {
            let significantMask = NSEvent.ModifierFlags.deviceIndependentFlagsMask.rawValue
            guard event.modifierFlags & significantMask == configuration.cocoaModifiers,
                  !isPressed else { return nil }
            isPressed = true
            return .pressed
        }
        guard isPressed else { return nil }
        isPressed = false
        return .released
    }

    public mutating func reset() {
        isPressed = false
    }
}

public struct GlobalHotKeyEventPolicy: Sendable {
    public init() {}

    public func shouldConsume(
        _ event: KeyboardEventSnapshot,
        configuration: GlobalHotKeyConfiguration
    ) -> Bool {
        guard event.keyCode == UInt16(configuration.keyCode) else { return false }
        let significantMask = NSEvent.ModifierFlags.deviceIndependentFlagsMask.rawValue
        return event.modifierFlags & significantMask == configuration.cocoaModifiers
    }
}

public enum HotKeyError: LocalizedError {
    case eventTapInstallationFailed

    public var errorDescription: String? {
        switch self {
        case .eventTapInstallationFailed:
            "Could not install the global keyboard event tap."
        }
    }
}

@MainActor
public final class GlobalShortcutService: GlobalShortcutMonitoring {
    public typealias DeliveryHandler = @MainActor @Sendable (GlobalShortcutDelivery) -> Void
    public typealias CancellationHandler = @MainActor @Sendable () -> Void

    private let delivered: DeliveryHandler
    private let cancelled: CancellationHandler
    private var router: GlobalShortcutEventRouter
    private var eventTap: CFMachPort?
    private var eventTapSource: CFRunLoopSource?

    public init(
        bindings: [GlobalShortcutBinding],
        delivered: @escaping DeliveryHandler,
        cancelled: @escaping CancellationHandler
    ) {
        router = GlobalShortcutEventRouter(bindings: bindings)
        self.delivered = delivered
        self.cancelled = cancelled
    }

    public func start() throws {
        guard eventTap == nil else { return }
        let userData = Unmanaged.passUnretained(self).toOpaque()
        let eventMask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: globalShortcutEventTapHandler,
            userInfo: userData
        )
        guard let eventTap else {
            stop()
            throw HotKeyError.eventTapInstallationFailed
        }
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        eventTapSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    public func stop() {
        if let eventTapSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), eventTapSource, .commonModes)
            CFRunLoopSourceInvalidate(eventTapSource)
            self.eventTapSource = nil
        }
        if let eventTap {
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
        }
        router.reset()
    }

    fileprivate func route(_ event: GlobalShortcutEventSnapshot) -> Bool {
        if event.kind == .keyDown, event.keyCode == UInt16(kVK_Escape) {
            Task { @MainActor [cancelled] in cancelled() }
            return false
        }
        let result = router.route(event)
        if !result.deliveries.isEmpty {
            Task { @MainActor [delivered, deliveries = result.deliveries] in
                for delivery in deliveries { delivered(delivery) }
            }
        }
        return result.shouldConsume
    }

    fileprivate func reenableAfterSystemDisable() {
        guard let eventTap else { return }
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }
}

private func globalShortcutEventTapHandler(
    _ proxy: CGEventTapProxy,
    _ type: CGEventType,
    _ event: CGEvent,
    _ userData: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userData else { return Unmanaged.passUnretained(event) }
    let service = Unmanaged<GlobalShortcutService>.fromOpaque(userData).takeUnretainedValue()
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        MainActor.assumeIsolated { service.reenableAfterSystemDisable() }
        return Unmanaged.passUnretained(event)
    }
    guard let snapshot = GlobalShortcutEventAdapter().snapshot(type: type, event: event) else {
        return Unmanaged.passUnretained(event)
    }
    let shouldConsume = MainActor.assumeIsolated { service.route(snapshot) }
    return shouldConsume ? nil : Unmanaged.passUnretained(event)
}
