import Foundation
import GuideCore
import Testing

@Suite("Global dictation shortcut")
struct GlobalHotKeyConfigurationTests {
    @Test("default matches the SERPy toggle shortcut")
    func defaultMatchesSERPyToggleShortcut() {
        let shortcut = GlobalHotKeyConfiguration.dictation
        #expect(shortcut.keyCode == 49)
        #expect(shortcut.modifiers == .option)
        #expect(shortcut.displayName == "⌥Space")
    }

    @Test("configuration survives persistence")
    func configurationRoundTripsThroughJSON() throws {
        let original = GlobalHotKeyConfiguration(
            keyCode: 38,
            modifiers: [.control, .option],
            displayName: "⌃⌥J"
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(GlobalHotKeyConfiguration.self, from: data)

        #expect(decoded == original)
    }

    @Test("held Guide chord survives persistence and exposes safe choices")
    func guideChordRoundTripsThroughJSON() throws {
        let original = GlobalModifierChordConfiguration.guideDefault
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(GlobalModifierChordConfiguration.self, from: data)

        #expect(decoded == original)
        #expect(GlobalModifierChordConfiguration.guideChoices.contains(original))
        #expect(original.displayName == "Control–Option")
    }

    @Test("Guide chord cannot shadow the modifiers of a keyed dictation shortcut")
    func overlappingGuideAndDictationAreRejected() {
        let configuration = GlobalShortcutConfigurationSet(
            dictation: .init(
                keyCode: 5,
                modifiers: [.control, .option],
                displayName: "⌃⌥G"
            ),
            guide: .guideDefault
        )

        #expect(configuration.hasGestureConflict)
        #expect(!GlobalShortcutConfigurationSet(
            dictation: .dictation,
            guide: .guideDefault
        ).hasGestureConflict)
    }
}
