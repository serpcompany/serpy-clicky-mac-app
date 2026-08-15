import GuideCore
import Testing

@Suite("Toggle dictation activation")
struct DictationActivationPolicyTests {
    private let policy = DictationActivationPolicy()

    @Test("shortcut starts an idle dictation and stops a recording dictation")
    func shortcutTogglesRecording() {
        #expect(policy.shortcutAction(for: .idle) == .start)
        #expect(policy.shortcutAction(for: .recording) == .finish)
    }

    @Test("shortcut cannot interrupt transitional work")
    func shortcutIgnoresTransitionalPhases() {
        #expect(policy.shortcutAction(for: .preparing) == .none)
        #expect(policy.shortcutAction(for: .transcribing) == .none)
        #expect(policy.shortcutAction(for: .inserting) == .none)
    }

    @Test("escape cancels only an active dictation")
    func escapeCancelsActiveDictation() {
        #expect(policy.escapeAction(for: .recording) == .cancel)
        #expect(policy.escapeAction(for: .preparing) == .cancel)
        #expect(policy.escapeAction(for: .idle) == .none)
        #expect(policy.escapeAction(for: .succeeded) == .none)
    }
}
