import Carbon
import CoreGraphics
import Foundation

public struct GlobalHotKeyConfiguration: Codable, Equatable, Sendable {
    public let keyCode: UInt32
    public let modifiers: UInt32
    public let displayName: String

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
    public let isKeyDown: Bool

    public init(keyCode: UInt16, isKeyDown: Bool) {
        self.keyCode = keyCode
        self.isKeyDown = isKeyDown
    }
}

private enum GlobalHotKeyTransition: Equatable, Sendable {
    case pressed
    case released
}

@MainActor
public final class GlobalHotKeyService {
    public typealias Handler = @MainActor @Sendable () -> Void

    private let pressed: Handler
    private let released: Handler
    private let cancelled: Handler
    private let configuration: GlobalHotKeyConfiguration
    private let identifier: EventHotKeyID
    private var eventHandler: EventHandlerRef?
    private var hotKey: EventHotKeyRef?
    private var eventTap: CFMachPort?
    private var eventTapSource: CFRunLoopSource?
    private var deliveredIsPressed = false

    public init(
        configuration: GlobalHotKeyConfiguration = .dictation,
        identifier: UInt32 = 1,
        pressed: @escaping Handler,
        released: @escaping Handler,
        cancelled: @escaping Handler = {}
    ) {
        self.configuration = configuration
        self.identifier = EventHotKeyID(signature: 0x47554350, id: identifier) // GUCP
        self.pressed = pressed
        self.released = released
        self.cancelled = cancelled
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

        let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
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
        if let hotKey {
            UnregisterEventHotKey(hotKey)
            self.hotKey = nil
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
        if let eventTapSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), eventTapSource, .commonModes)
            CFRunLoopSourceInvalidate(eventTapSource)
            self.eventTapSource = nil
        }
        if let eventTap {
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
        }
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
        if event.isKeyDown, event.keyCode == UInt16(kVK_Escape) {
            cancelled()
        }
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
    case eventTapInstallationFailed

    public var errorDescription: String? {
        switch self {
        case .installFailed(let status):
            "Could not install the global shortcut handler (\(status))."
        case .registrationFailed(let status):
            "The global shortcut is unavailable (\(status))."
        case .eventTapInstallationFailed:
            "Could not install the global keyboard event tap."
        }
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

private func guideKeyboardEventTapHandler(
    _ proxy: CGEventTapProxy,
    _ type: CGEventType,
    _ event: CGEvent,
    _ userData: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard (type == .keyDown || type == .keyUp), let userData else {
        return Unmanaged.passUnretained(event)
    }

    let snapshot = KeyboardEventSnapshot(
        keyCode: UInt16(event.getIntegerValueField(.keyboardEventKeycode)),
        isKeyDown: type == .keyDown
    )
    let service = Unmanaged<GlobalHotKeyService>.fromOpaque(userData).takeUnretainedValue()
    Task { @MainActor in
        service.handle(snapshot)
    }
    return Unmanaged.passUnretained(event)
}
