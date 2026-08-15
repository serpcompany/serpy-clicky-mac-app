import Foundation
import GuideMac
import Testing

@Suite("Accessibility text value replacement")
struct TextValueReplacementTests {
    @Test("replaces the selected UTF-16 range and advances the caret")
    func replacesSelection() throws {
        let result = try TextValueReplacement.inserting(
            "swift",
            into: "hello world",
            selectedRange: CFRange(location: 6, length: 5)
        )

        #expect(result.value == "hello swift")
        #expect(result.caret.location == 11)
        #expect(result.caret.length == 0)
    }

    @Test("rejects an out-of-bounds selection")
    func rejectsInvalidSelection() {
        #expect(throws: TextValueReplacement.Error.invalidRange) {
            try TextValueReplacement.inserting(
                "x",
                into: "abc",
                selectedRange: CFRange(location: 20, length: 0)
            )
        }
    }
}
