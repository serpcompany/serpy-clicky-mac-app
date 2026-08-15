import Carbon
import Foundation

public struct GlobalHotKeyConfiguration: Equatable, Sendable {
    public let keyCode: UInt32
    public let modifiers: UInt32
    public let displayName: String

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

@MainActor
public final class GlobalHotKeyService {
    public typealias Handler = @MainActor @Sendable () -> Void

    private let pressed: Handler
    private let released: Handler
    private let keyCode: UInt32
    private let modifiers: UInt32
    private let identifier: EventHotKeyID
    private var eventHandler: EventHandlerRef?
    private var hotKey: EventHotKeyRef?

    public init(
        configuration: GlobalHotKeyConfiguration = .dictation,
        identifier: UInt32 = 1,
        pressed: @escaping Handler,
        released: @escaping Handler
    ) {
        self.keyCode = configuration.keyCode
        self.modifiers = configuration.modifiers
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
            keyCode,
            modifiers,
            identifier,
            GetApplicationEventTarget(),
            0,
            &hotKey
        )
        guard registerStatus == noErr else {
            stop()
            throw HotKeyError.registrationFailed(registerStatus)
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
    }

    fileprivate func handle(kind: UInt32, signature: OSType, identifier receivedID: UInt32) {
        guard signature == identifier.signature, receivedID == identifier.id else { return }
        switch kind {
        case UInt32(kEventHotKeyPressed): pressed()
        case UInt32(kEventHotKeyReleased): released()
        default: break
        }
    }

}

public enum HotKeyError: LocalizedError {
    case installFailed(OSStatus)
    case registrationFailed(OSStatus)

    public var errorDescription: String? {
        switch self {
        case .installFailed(let status):
            "Could not install the global shortcut handler (\(status))."
        case .registrationFailed(let status):
            "The global shortcut is unavailable (\(status))."
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
