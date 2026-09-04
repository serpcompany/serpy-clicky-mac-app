import AppKit
import GuideCore
@testable import GuideMac
import Testing

@MainActor
@Suite("Pasteboard snapshot")
struct PasteboardSnapshotTests {
    @Test("only observable delivery methods are confirmed")
    func deliveryConfirmationIsConservative() {
        #expect(TextInsertionMethod.accessibility.isConfirmed)
        #expect(TextInsertionMethod.accessibilityValue.isConfirmed)
        #expect(TextInsertionMethod.paste.isConfirmed)
        #expect(!TextInsertionMethod.pasteUnconfirmed.isConfirmed)
    }

    @Test("restores all items and representations while it owns the pasteboard")
    func restoresAllRepresentations() throws {
        let pasteboard = NSPasteboard(name: .init("GuideCompanionTests-\(UUID().uuidString)"))
        let first = NSPasteboardItem()
        first.setString("plain", forType: .string)
        first.setData(Data([0x01, 0x02]), forType: .init("com.example.binary"))
        let second = NSPasteboardItem()
        second.setString("second", forType: .string)
        pasteboard.clearContents()
        pasteboard.writeObjects([first, second])
        let snapshot = PasteboardSnapshot(pasteboard: pasteboard)

        pasteboard.clearContents()
        pasteboard.setString("temporary transcript", forType: .string)
        let ownedChangeCount = pasteboard.changeCount

        #expect(snapshot.restoreIfUnchanged(to: pasteboard, expectedChangeCount: ownedChangeCount))
        #expect(pasteboard.pasteboardItems?.count == 2)
        #expect(pasteboard.pasteboardItems?.first?.string(forType: .string) == "plain")
        #expect(pasteboard.pasteboardItems?.first?.data(forType: .init("com.example.binary")) == Data([0x01, 0x02]))
        #expect(pasteboard.pasteboardItems?.last?.string(forType: .string) == "second")
    }

    @Test("never overwrites a newer user clipboard change")
    func preservesNewerClipboard() {
        let pasteboard = NSPasteboard(name: .init("GuideCompanionTests-\(UUID().uuidString)"))
        pasteboard.clearContents()
        pasteboard.setString("original", forType: .string)
        let snapshot = PasteboardSnapshot(pasteboard: pasteboard)

        pasteboard.clearContents()
        pasteboard.setString("temporary transcript", forType: .string)
        let ownedChangeCount = pasteboard.changeCount
        pasteboard.clearContents()
        pasteboard.setString("new user copy", forType: .string)

        #expect(!snapshot.restoreIfUnchanged(to: pasteboard, expectedChangeCount: ownedChangeCount))
        #expect(pasteboard.string(forType: .string) == "new user copy")
    }
}
