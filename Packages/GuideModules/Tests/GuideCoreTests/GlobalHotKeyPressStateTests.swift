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

    @Test("configured chord is consumed without consuming ordinary typing")
    func consumesOnlyConfiguredChord() {
        let policy = GlobalHotKeyEventPolicy()
        #expect(policy.shouldConsume(keyDown(), configuration: configuration))
        #expect(policy.shouldConsume(
            KeyboardEventSnapshot(
                keyCode: UInt16(configuration.keyCode),
                modifierFlags: 0,
                isKeyDown: false
            ),
            configuration: configuration
        ))
        #expect(!policy.shouldConsume(
            KeyboardEventSnapshot(
                keyCode: UInt16(kVK_ANSI_A),
                modifierFlags: 0,
                isKeyDown: true
            ),
            configuration: configuration
        ))
        #expect(!policy.shouldConsume(
            KeyboardEventSnapshot(
                keyCode: UInt16(kVK_Space),
                modifierFlags: 0,
                isKeyDown: true
            ),
            configuration: configuration
        ))
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
