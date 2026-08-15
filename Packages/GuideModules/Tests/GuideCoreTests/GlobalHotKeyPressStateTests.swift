import AppKit
import Carbon
import GuideMac
import Testing

@Suite("Global hotkey event delivery")
struct GlobalHotKeyPressStateTests {
    private let configuration = GlobalHotKeyConfiguration.dictation

    @Test("one physical key cycle produces one press and one release")
    func matchingCycle() {
        var state = GlobalHotKeyPressState()

        #expect(state.consume(keyDown(), configuration: configuration) == .pressed)
        #expect(state.consume(keyDown(), configuration: configuration) == nil)
        #expect(state.consume(keyUp(), configuration: configuration) == .released)
        #expect(state.consume(keyUp(), configuration: configuration) == nil)
    }

    @Test("release completes the cycle after the modifier is lifted")
    func releaseAfterModifierLift() {
        var state = GlobalHotKeyPressState()
        #expect(state.consume(keyDown(), configuration: configuration) == .pressed)
        #expect(state.consume(
            KeyboardEventSnapshot(
                keyCode: UInt16(configuration.keyCode),
                modifierFlags: 0,
                isKeyDown: false
            ),
            configuration: configuration
        ) == .released)
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
