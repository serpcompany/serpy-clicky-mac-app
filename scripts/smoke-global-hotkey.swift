#!/usr/bin/env swift

import AppKit
import Carbon
import CoreGraphics
import Foundation

let expectedFrontmostBundle = "com.apple.TextEdit"
let frontmostBundle = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "none"

guard frontmostBundle == expectedFrontmostBundle else {
    FileHandle.standardError.write(
        Data("FAIL: expected TextEdit frontmost; found \(frontmostBundle)\n".utf8)
    )
    exit(2)
}

guard let source = CGEventSource(stateID: .combinedSessionState),
      let keyDown = CGEvent(
        keyboardEventSource: source,
        virtualKey: CGKeyCode(kVK_ANSI_D),
        keyDown: true
      ),
      let keyUp = CGEvent(
        keyboardEventSource: source,
        virtualKey: CGKeyCode(kVK_ANSI_D),
        keyDown: false
      ) else {
    FileHandle.standardError.write(Data("FAIL: could not construct key events\n".utf8))
    exit(3)
}

let modifiers: CGEventFlags = [.maskControl, .maskAlternate]
keyDown.flags = modifiers
keyUp.flags = modifiers
keyDown.post(tap: .cghidEventTap)
Thread.sleep(forTimeInterval: 0.6)
keyUp.post(tap: .cghidEventTap)

print("Posted Control-Option-D with TextEdit verified frontmost")
