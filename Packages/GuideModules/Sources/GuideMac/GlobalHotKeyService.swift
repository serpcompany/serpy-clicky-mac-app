import AppKit
import Carbon
import Foundation

public struct GlobalHotKeyConfiguration: Equatable, Sendable {
    public let keyCode: UInt32
    public let modifiers: UInt32
    public let displayName: String

    public var cocoaModifiers: UInt {
        var result: UInt = 0
        if modifiers & UInt32(controlKey) != 0 {
            result |= NSEvent.ModifierFlags.control.rawValue
        }
        if modifiers & UInt32(optionKey) != 0 {
            result |= NSEvent.ModifierFlags.option.rawValue
        }
        if modifiers & UInt32(cmdKey) != 0 {
            result |= NSEvent.ModifierFlags.command.rawValue
        }
        if modifiers & UInt32(shiftKey) != 0 {
            result |= NSEvent.ModifierFlags.shift.rawValue
        }
        return result
    }

    public init(keyCode: UInt32, modifiers: UInt32, displayName: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.displayName = displayName
    }

    public static let dictation = GlobalHotKeyConfiguration(
        keyCode: UInt32(kVK_ANSI_D),
        modifiers: UInt32(controlKey | optionKey),
        displayName: "Control–Option–D"
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

@MainActor
public final class GlobalHotKeyService {
    public typealias Handler = @MainActor @Sendable () -> Void

    private let pressed: Handler
    private let released: Handler
    private let configuration: GlobalHotKeyConfiguration
    private let identifier: EventHotKeyID
    private var eventHandler: EventHandlerRef?
    private var hotKey: EventHotKeyRef?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var pressState = GlobalHotKeyPressState()
    private var deliveredIsPressed = false

    public init(
        configuration: GlobalHotKeyConfiguration = .dictation,
        identifier: UInt32 = 1,
        pressed: @escaping Handler,
        released: @escaping Handler
    ) {
        self.configuration = configuration
        self.identifier = EventHotKeyID(signature: 0x47554350, id: identifier) // GUCP
        self.pressed = pressed
        self.released = released
    }

    public func start() throws {
        guard hotKey == nil else { return }

        var eventTypes = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
        ]

        let userData = Unmanaged.passUnretained(self).toOpaque()
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            guideHotKeyEventHandler,
            eventTypes.count,
            &eventTypes,
            userData,
            &eventHandler
        )
        guard installStatus == noErr else {
            throw HotKeyError.installFailed(installStatus)
        }

        let registerStatus = RegisterEventHotKey(
            configuration.keyCode,
            configuration.modifiers,
            identifier,
            GetApplicationEventTarget(),
            0,
            &hotKey
        )
        guard registerStatus == noErr else {
            stop()
            throw HotKeyError.registrationFailed(registerStatus)
        }

        let sink = MainActorCallbackBridge.make { [weak self] event in
            self?.handle(event)
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.keyDown, .keyUp],
            handler: KeyboardMonitorBridge.makeObserver(sink)
        )
        localMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.keyDown, .keyUp],
            handler: KeyboardMonitorBridge.makeLocalObserver(sink)
        )
        guard globalMonitor != nil, localMonitor != nil else {
            stop()
            throw HotKeyError.monitorInstallationFailed
        }
    }

    public func stop() {
        if let hotKey {
            UnregisterEventHotKey(hotKey)
            self.hotKey = nil
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
        pressState.reset()
        deliveredIsPressed = false
    }

    fileprivate func handle(kind: UInt32, signature: OSType, identifier receivedID: UInt32) {
        guard signature == identifier.signature, receivedID == identifier.id else { return }
        switch kind {
        case UInt32(kEventHotKeyPressed): deliver(.pressed)
        case UInt32(kEventHotKeyReleased): deliver(.released)
        default: break
        }
    }

    fileprivate func handle(_ event: KeyboardEventSnapshot) {
        guard let transition = pressState.consume(event, configuration: configuration) else { return }
        deliver(transition)
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
    case installFailed(OSStatus)
    case registrationFailed(OSStatus)
    case monitorInstallationFailed

    public var errorDescription: String? {
        switch self {
        case .installFailed(let status):
            "Could not install the global shortcut handler (\(status))."
        case .registrationFailed(let status):
            "The global shortcut is unavailable (\(status))."
        case .monitorInstallationFailed:
            "Could not install the global keyboard monitor."
        }
    }
}

private enum KeyboardMonitorBridge {
    nonisolated static func makeObserver(
        _ sink: @escaping @Sendable (KeyboardEventSnapshot) -> Void
    ) -> (NSEvent) -> Void {
        { event in
            sink(snapshot(event))
        }
    }

    nonisolated static func makeLocalObserver(
        _ sink: @escaping @Sendable (KeyboardEventSnapshot) -> Void
    ) -> (NSEvent) -> NSEvent? {
        { event in
            sink(snapshot(event))
            return event
        }
    }

    private nonisolated static func snapshot(_ event: NSEvent) -> KeyboardEventSnapshot {
        KeyboardEventSnapshot(
            keyCode: event.keyCode,
            modifierFlags: event.modifierFlags.rawValue,
            isKeyDown: event.type == .keyDown
        )
    }
}

private func guideHotKeyEventHandler(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event, let userData else { return OSStatus(eventNotHandledErr) }
    let kind = GetEventKind(event)
    let service = Unmanaged<GlobalHotKeyService>.fromOpaque(userData).takeUnretainedValue()
    var received = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &received
    )
    guard status == noErr else { return status }
    let signature = received.signature
    let identifier = received.id
    Task { @MainActor in
        service.handle(kind: kind, signature: signature, identifier: identifier)
    }
    return noErr
}
