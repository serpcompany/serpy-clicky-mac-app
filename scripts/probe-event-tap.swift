#!/usr/bin/env swift

import Carbon
import CoreGraphics
import Foundation

let callback: CGEventTapCallBack = { _, type, event, _ in
    guard type == .keyDown || type == .keyUp else {
        return Unmanaged.passUnretained(event)
    }
    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    guard keyCode == Int64(kVK_ANSI_D) else {
        return Unmanaged.passUnretained(event)
    }
    print("observed type=\(type.rawValue) keyCode=\(keyCode) flags=\(event.flags.rawValue)")
    return Unmanaged.passUnretained(event)
}

let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
guard let tap = CGEvent.tapCreate(
    tap: .cgSessionEventTap,
    place: .headInsertEventTap,
    options: .listenOnly,
    eventsOfInterest: CGEventMask(mask),
    callback: callback,
    userInfo: nil
) else {
    FileHandle.standardError.write(Data("FAIL: could not create event tap\n".utf8))
    exit(2)
}

let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
CGEvent.tapEnable(tap: tap, enable: true)

DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) {
    guard let eventSource = CGEventSource(stateID: .combinedSessionState),
          let keyDown = CGEvent(
            keyboardEventSource: eventSource,
            virtualKey: CGKeyCode(kVK_ANSI_D),
            keyDown: true
          ),
          let keyUp = CGEvent(
            keyboardEventSource: eventSource,
            virtualKey: CGKeyCode(kVK_ANSI_D),
            keyDown: false
          ) else { return }
    keyDown.flags = [.maskControl, .maskAlternate]
    keyUp.flags = [.maskControl, .maskAlternate]
    keyDown.post(tap: .cghidEventTap)
    Thread.sleep(forTimeInterval: 0.2)
    keyUp.post(tap: .cghidEventTap)
}

RunLoop.current.run(until: Date().addingTimeInterval(1.5))
