import CoreGraphics
import GuideCore
import GuideMac
import Testing

@Suite("CGEvent shortcut adapter")
struct GlobalShortcutEventAdapterTests {
    @Test("platform keyboard event becomes a provider-neutral router snapshot")
    func convertsKeyboardEvent() throws {
        let source = try #require(CGEventSource(stateID: .privateState))
        let event = try #require(CGEvent(
            keyboardEventSource: source,
            virtualKey: 49,
            keyDown: true
        ))
        event.flags = [.maskAlternate]

        let snapshot = GlobalShortcutEventAdapter().snapshot(type: .keyDown, event: event)

        #expect(snapshot == .init(
            keyCode: 49,
            modifiers: .option,
            kind: .keyDown
        ))
    }
}
