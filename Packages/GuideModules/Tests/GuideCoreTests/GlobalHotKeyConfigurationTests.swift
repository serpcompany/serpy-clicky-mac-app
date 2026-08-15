import Carbon
import GuideMac
import Testing

@Suite("Global dictation shortcut")
struct GlobalHotKeyConfigurationTests {
    @Test("default avoids macOS input-source shortcuts")
    func defaultAvoidsInputSourceShortcuts() {
        let shortcut = GlobalHotKeyConfiguration.dictation
        let inputSourceShortcuts: Set<Shortcut> = [
            Shortcut(keyCode: UInt32(kVK_Space), modifiers: UInt32(controlKey)),
            Shortcut(keyCode: UInt32(kVK_Space), modifiers: UInt32(controlKey | optionKey))
        ]

        #expect(!inputSourceShortcuts.contains(
            Shortcut(keyCode: shortcut.keyCode, modifiers: shortcut.modifiers)
        ))
    }
}

private struct Shortcut: Hashable {
    let keyCode: UInt32
    let modifiers: UInt32
}
