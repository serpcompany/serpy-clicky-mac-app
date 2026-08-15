import AppKit
import Carbon
import GuideMac
import Testing

@Suite("Global hotkey event delivery")
struct GlobalHotKeyPressStateTests {
    private let configuration = GlobalHotKeyConfiguration.dictation

    @Test("matching global key down and up produce one press cycle")
    func matchingCycle() {
        var state = GlobalHotKeyPressState()

        #expect(state.consume(keyDown(), configuration: configuration) == .pressed)
        #expect(state.consume(keyDown(), configuration: configuration) == nil)
        #expect(state.consume(keyUp(), configuration: configuration) == .released)
        #expect(state.consume(keyUp(), configuration: configuration) == nil)
    }

    @Test("unrelated keys and modifier combinations are ignored")
    func ignoresUnrelatedEvents() {
        var state = GlobalHotKeyPressState()
        let wrongKey = KeyboardEventSnapshot(
            keyCode: UInt16(kVK_ANSI_F),
            modifierFlags: configuration.cocoaModifiers,
            isKeyDown: true
        )
        let wrongModifiers = KeyboardEventSnapshot(
            keyCode: UInt16(configuration.keyCode),
            modifierFlags: NSEvent.ModifierFlags.command.rawValue,
            isKeyDown: true
        )

        #expect(state.consume(wrongKey, configuration: configuration) == nil)
        #expect(state.consume(wrongModifiers, configuration: configuration) == nil)
    }

    @Test("key release completes an active press even after modifiers lift")
    func releaseAfterModifiersLift() {
        var state = GlobalHotKeyPressState()

        #expect(state.consume(keyDown(), configuration: configuration) == .pressed)
        let keyUpWithoutModifiers = KeyboardEventSnapshot(
            keyCode: UInt16(configuration.keyCode),
            modifierFlags: 0,
            isKeyDown: false
        )
        #expect(state.consume(keyUpWithoutModifiers, configuration: configuration) == .released)
    }

    private func keyDown() -> KeyboardEventSnapshot {
        KeyboardEventSnapshot(
            keyCode: UInt16(configuration.keyCode),
            modifierFlags: configuration.cocoaModifiers,
            isKeyDown: true
        )
    }

    private func keyUp() -> KeyboardEventSnapshot {
        KeyboardEventSnapshot(
            keyCode: UInt16(configuration.keyCode),
            modifierFlags: configuration.cocoaModifiers,
            isKeyDown: false
        )
    }
}
