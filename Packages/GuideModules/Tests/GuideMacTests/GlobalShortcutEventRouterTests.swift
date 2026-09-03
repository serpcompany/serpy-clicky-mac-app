import AppKit
import Carbon
import GuideMac
import Testing

@Suite("Global shortcut event router")
struct GlobalShortcutEventRouterTests {
    @Test("held Guide chord coexists with dictation and never leaks a trigger key")
    func heldGuideChordAndDictationCoexist() {
        var router = GlobalShortcutEventRouter(
            bindings: [
                .init(id: .dictation, gesture: .key(.dictation)),
                .init(
                    id: .guide,
                    gesture: .modifierChord(
                        modifiers: UInt32(controlKey | optionKey),
                        displayName: "⌃⌥"
                    )
                )
            ]
        )

        let guideDown = router.route(.init(
            keyCode: UInt16(kVK_Option),
            modifierFlags: NSEvent.ModifierFlags([.control, .option]).rawValue,
            kind: .flagsChanged
        ))
        #expect(guideDown.deliveries == [.init(id: .guide, transition: .pressed)])
        #expect(!guideDown.shouldConsume)

        let guideUp = router.route(.init(
            keyCode: UInt16(kVK_Option),
            modifierFlags: NSEvent.ModifierFlags.control.rawValue,
            kind: .flagsChanged
        ))
        #expect(guideUp.deliveries == [.init(id: .guide, transition: .released)])
        #expect(!guideUp.shouldConsume)

        let dictationDown = router.route(.init(
            keyCode: UInt16(kVK_Space),
            modifierFlags: NSEvent.ModifierFlags.option.rawValue,
            kind: .keyDown
        ))
        #expect(dictationDown.deliveries == [.init(id: .dictation, transition: .pressed)])
        #expect(dictationDown.shouldConsume)

        let dictationUp = router.route(.init(
            keyCode: UInt16(kVK_Space),
            modifierFlags: NSEvent.ModifierFlags.option.rawValue,
            kind: .keyUp
        ))
        #expect(dictationUp.deliveries == [.init(id: .dictation, transition: .released)])
        #expect(dictationUp.shouldConsume)
    }
}
