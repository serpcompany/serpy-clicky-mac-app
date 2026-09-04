import GuideCore
import Testing

@Suite("Overlapping transcript reconciliation")
struct TranscriptOverlapReconcilerTests {
    @Test("largest matching word boundary appears exactly once")
    func removesOnlyTheDuplicatedBoundaryPrefix() {
        let reconciler = TranscriptOverlapReconciler()
        let result = reconciler.appending(
            "BEGIN alpha boundary phrase",
            next: "boundary phrase AFTER omega"
        )

        #expect(result == "BEGIN alpha boundary phrase AFTER omega")
        #expect(result.components(separatedBy: "boundary phrase").count - 1 == 1)
    }
}
