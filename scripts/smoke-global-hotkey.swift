#!/usr/bin/env swift

import AppKit
import Carbon
import CoreGraphics
import Foundation

func argument(after flag: String) -> String? {
    guard let index = CommandLine.arguments.firstIndex(of: flag),
          CommandLine.arguments.indices.contains(index + 1) else { return nil }
    return CommandLine.arguments[index + 1]
}

let expectedFrontmostBundle = argument(after: "--bundle") ?? "com.apple.TextEdit"
let spokenPhrase = argument(after: "--phrase") ?? "SERPy dictation test"
let startupDelay = Double(argument(after: "--delay") ?? "0") ?? 0
if startupDelay > 0 {
    Thread.sleep(forTimeInterval: startupDelay)
}
let frontmostBundle = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "none"

guard frontmostBundle == expectedFrontmostBundle else {
    FileHandle.standardError.write(
        Data("FAIL: expected \(expectedFrontmostBundle) frontmost; found \(frontmostBundle)\n".utf8)
    )
    exit(2)
}

guard let source = CGEventSource(stateID: .combinedSessionState),
      let keyDown = CGEvent(
        keyboardEventSource: source,
        virtualKey: CGKeyCode(kVK_Space),
        keyDown: true
      ),
      let keyUp = CGEvent(
        keyboardEventSource: source,
        virtualKey: CGKeyCode(kVK_Space),
        keyDown: false
      ) else {
    FileHandle.standardError.write(Data("FAIL: could not construct key events\n".utf8))
    exit(3)
}

let modifiers: CGEventFlags = [.maskAlternate]
keyDown.flags = modifiers
keyUp.flags = modifiers
keyDown.post(tap: .cghidEventTap)
keyUp.post(tap: .cghidEventTap)

if CommandLine.arguments.contains("--speak") {
    Thread.sleep(forTimeInterval: 0.7)
    let speaker = Process()
    speaker.executableURL = URL(fileURLWithPath: "/usr/bin/say")
    speaker.arguments = [spokenPhrase]
    try speaker.run()
    speaker.waitUntilExit()
    Thread.sleep(forTimeInterval: 1.0)
} else {
    Thread.sleep(forTimeInterval: 0.6)
}

keyDown.post(tap: .cghidEventTap)
keyUp.post(tap: .cghidEventTap)

print("Toggled Option-Space twice with \(expectedFrontmostBundle) verified frontmost")
