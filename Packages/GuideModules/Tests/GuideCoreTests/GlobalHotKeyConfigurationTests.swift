import Carbon
import GuideMac
import Testing

@Suite("Global dictation shortcut")
struct GlobalHotKeyConfigurationTests {
    @Test("default matches the SERPy toggle shortcut")
    func defaultMatchesSERPyToggleShortcut() {
        let shortcut = GlobalHotKeyConfiguration.dictation
        #expect(shortcut.keyCode == UInt32(kVK_Space))
        #expect(shortcut.modifiers == UInt32(optionKey))
        #expect(shortcut.displayName == "⌥Space")
    }

    @Test("configuration survives persistence")
    func configurationRoundTripsThroughJSON() throws {
        let original = GlobalHotKeyConfiguration(
            keyCode: UInt32(kVK_ANSI_J),
            modifiers: UInt32(controlKey | optionKey),
            displayName: "⌃⌥J"
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(GlobalHotKeyConfiguration.self, from: data)

        #expect(decoded == original)
    }
}
