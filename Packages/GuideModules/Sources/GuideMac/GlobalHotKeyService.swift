import AppKit
import Carbon
import CoreGraphics
import Foundation

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

@MainActor
public final class GlobalHotKeyService {
    public typealias Handler = @MainActor @Sendable () -> Void

    private let pressed: Handler
    private let released: Handler
    private let cancelled: Handler
    private let configuration: GlobalHotKeyConfiguration
    private let eventPolicy = GlobalHotKeyEventPolicy()
    private var eventTap: CFMachPort?
    private var eventTapSource: CFRunLoopSource?
    private var pressState = GlobalHotKeyPressState()
    private var deliveredIsPressed = false

    public init(
        configuration: GlobalHotKeyConfiguration = .dictation,
        pressed: @escaping Handler,
        released: @escaping Handler,
        cancelled: @escaping Handler = {}
    ) {
        self.configuration = configuration
        self.pressed = pressed
        self.released = released
        self.cancelled = cancelled
    }

    public func start() throws {
        guard eventTap == nil else { return }
        let userData = Unmanaged.passUnretained(self).toOpaque()
        let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: guideKeyboardEventTapHandler,
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
        pressState.reset()
        deliveredIsPressed = false
    }

    fileprivate func handle(_ event: KeyboardEventSnapshot) {
        if event.isKeyDown, event.keyCode == UInt16(kVK_Escape) {
            cancelled()
            return
        }
        guard let transition = pressState.consume(event, configuration: configuration) else { return }
        deliver(transition)
    }

    nonisolated fileprivate func shouldConsume(_ event: KeyboardEventSnapshot) -> Bool {
        eventPolicy.shouldConsume(event, configuration: configuration)
    }

    private func deliver(_ transition: GlobalHotKeyTransition) {
        switch transition {
        case .pressed:
            guard !deliveredIsPressed else { return }
            deliveredIsPressed = true
            pressed()
        case .released:
            guard deliveredIsPressed else { return }
            deliveredIsPressed = false
            released()
        }
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

private func guideKeyboardEventTapHandler(
    _ proxy: CGEventTapProxy,
    _ type: CGEventType,
    _ event: CGEvent,
    _ userData: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard (type == .keyDown || type == .keyUp), let userData else {
        return Unmanaged.passUnretained(event)
    }

    var modifierFlags: UInt = 0
    if event.flags.contains(.maskControl) { modifierFlags |= NSEvent.ModifierFlags.control.rawValue }
    if event.flags.contains(.maskAlternate) { modifierFlags |= NSEvent.ModifierFlags.option.rawValue }
    if event.flags.contains(.maskCommand) { modifierFlags |= NSEvent.ModifierFlags.command.rawValue }
    if event.flags.contains(.maskShift) { modifierFlags |= NSEvent.ModifierFlags.shift.rawValue }

    let snapshot = KeyboardEventSnapshot(
        keyCode: UInt16(event.getIntegerValueField(.keyboardEventKeycode)),
        modifierFlags: modifierFlags,
        isKeyDown: type == .keyDown
    )
    let service = Unmanaged<GlobalHotKeyService>.fromOpaque(userData).takeUnretainedValue()
    let shouldConsume = service.shouldConsume(snapshot)
    Task { @MainActor in
        service.handle(snapshot)
    }
    return shouldConsume ? nil : Unmanaged.passUnretained(event)
}
