import AppKit
import Carbon
import GuideCore
import SwiftUI

struct ShortcutRecorderView: NSViewRepresentable {
    let configuration: GlobalHotKeyConfiguration
    let onChange: @MainActor (GlobalHotKeyConfiguration) -> Void

    func makeNSView(context: Context) -> ShortcutRecorderButton {
        let button = ShortcutRecorderButton()
        button.bezelStyle = .rounded
        button.setButtonType(.momentaryPushIn)
        button.onChange = onChange
        button.update(configuration: configuration)
        return button
    }

    func updateNSView(_ button: ShortcutRecorderButton, context: Context) {
        button.onChange = onChange
        button.update(configuration: configuration)
    }
}

@MainActor
final class ShortcutRecorderButton: NSButton {
    var onChange: ((GlobalHotKeyConfiguration) -> Void)?
    private var configuration = GlobalHotKeyConfiguration.dictation
    private var isRecording = false

    override var acceptsFirstResponder: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        target = self
        action = #selector(beginRecording)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        target = self
        action = #selector(beginRecording)
    }

    func update(configuration: GlobalHotKeyConfiguration) {
        self.configuration = configuration
        if !isRecording {
            title = configuration.displayName
        }
    }

    @objc private func beginRecording() {
        isRecording = true
        title = "Press shortcut…"
        window?.makeFirstResponder(self)
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        title = configuration.displayName
        return super.resignFirstResponder()
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording, !event.isARepeat else {
            super.keyDown(with: event)
            return
        }
        if event.keyCode == UInt16(kVK_Escape) {
            isRecording = false
            title = configuration.displayName
            window?.makeFirstResponder(nil)
            return
        }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var shortcutModifiers: GlobalShortcutModifiers = []
        var modifierSymbols = ""
        if flags.contains(.control) {
            shortcutModifiers.insert(.control)
            modifierSymbols += "⌃"
        }
        if flags.contains(.option) {
            shortcutModifiers.insert(.option)
            modifierSymbols += "⌥"
        }
        if flags.contains(.shift) {
            shortcutModifiers.insert(.shift)
            modifierSymbols += "⇧"
        }
        if flags.contains(.command) {
            shortcutModifiers.insert(.command)
            modifierSymbols += "⌘"
        }
        guard !shortcutModifiers.isEmpty else {
            NSSound.beep()
            title = "Include a modifier"
            return
        }

        let keyName = Self.keyName(for: event)
        let updated = GlobalHotKeyConfiguration(
            keyCode: event.keyCode,
            modifiers: shortcutModifiers,
            displayName: modifierSymbols + keyName
        )
        configuration = updated
        isRecording = false
        title = updated.displayName
        window?.makeFirstResponder(nil)
        onChange?(updated)
    }

    private static func keyName(for event: NSEvent) -> String {
        switch Int(event.keyCode) {
        case kVK_Space: "Space"
        case kVK_Return: "Return"
        case kVK_Tab: "Tab"
        case kVK_Delete: "Delete"
        case kVK_ForwardDelete: "Forward Delete"
        case kVK_LeftArrow: "←"
        case kVK_RightArrow: "→"
        case kVK_UpArrow: "↑"
        case kVK_DownArrow: "↓"
        default: event.charactersIgnoringModifiers?.uppercased() ?? "Key \(event.keyCode)"
        }
    }
}
