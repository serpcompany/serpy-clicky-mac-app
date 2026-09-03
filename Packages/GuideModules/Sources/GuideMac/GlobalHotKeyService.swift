import AppKit
import Carbon
import CoreGraphics
import Foundation
import GuideCore

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
        var modifiers: GlobalShortcutModifiers = []
        if event.flags.contains(.maskControl) { modifiers.insert(.control) }
        if event.flags.contains(.maskAlternate) { modifiers.insert(.option) }
        if event.flags.contains(.maskCommand) { modifiers.insert(.command) }
        if event.flags.contains(.maskShift) { modifiers.insert(.shift) }
        return .init(
            keyCode: UInt16(event.getIntegerValueField(.keyboardEventKeycode)),
            modifiers: modifiers,
            kind: kind
        )
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
    private var queuedDeliveryTask: Task<Void, Never>?

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
        queuedDeliveryTask?.cancel()
        queuedDeliveryTask = nil
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
            enqueue(.cancelled)
            return false
        }
        let result = router.route(event)
        for delivery in result.deliveries {
            enqueue(.delivery(delivery))
        }
        return result.shouldConsume
    }

    fileprivate func reenableAfterSystemDisable() {
        guard let eventTap else { return }
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    private enum QueuedCallback: Sendable {
        case delivery(GlobalShortcutDelivery)
        case cancelled
    }

    private func enqueue(_ callback: QueuedCallback) {
        let previous = queuedDeliveryTask
        queuedDeliveryTask = Task { @MainActor [weak self] in
            _ = await previous?.result
            guard !Task.isCancelled, let self else { return }
            switch callback {
            case let .delivery(delivery): delivered(delivery)
            case .cancelled: cancelled()
            }
        }
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
