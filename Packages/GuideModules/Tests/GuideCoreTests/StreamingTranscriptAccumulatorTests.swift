import GuideCore
import Testing

@Suite("Durable streaming transcript accumulation")
struct StreamingTranscriptAccumulatorTests {
    @Test("multi-minute finalized segments keep every sentinel exactly once and in order")
    func multiMinuteSegmentsPreservePrefixAcrossRecognitionBoundary() {
        var transcript = StreamingTranscriptAccumulator()

        transcript.receive(.volatile("BEGIN alpha"))
        transcript.receive(.finalized("BEGIN alpha "))
        transcript.receive(.volatile("BEFORE-60 beta"))
        transcript.receive(.finalized("BEFORE-60 beta "))
        transcript.receive(.volatile("AFTER-60 gamma"))
        transcript.receive(.finalized("AFTER-60 gamma "))
        transcript.receive(.finalized("MIDDLE delta "))
        transcript.receive(.volatile("END omega"))
        transcript.receive(.finalized("END omega"))

        let expected = "BEGIN alpha BEFORE-60 beta AFTER-60 gamma MIDDLE delta END omega"
        #expect(transcript.completeText == expected)

        var searchStart = expected.startIndex
        for sentinel in ["BEGIN", "BEFORE-60", "AFTER-60", "MIDDLE", "END"] {
            #expect(expected.components(separatedBy: sentinel).count - 1 == 1)
            let match = expected.range(of: sentinel, range: searchStart..<expected.endIndex)
            #expect(match != nil)
            if let match {
                searchStart = match.upperBound
            }
        }
    }

    @Test("volatile replacement never overwrites the finalized prefix")
    func volatileTextCannotReplaceCommittedText() {
        var transcript = StreamingTranscriptAccumulator()

        transcript.receive(.finalized("BEGIN committed "))
        transcript.receive(.volatile("draft one"))
        #expect(transcript.visibleText == "BEGIN committed draft one")

        transcript.receive(.volatile("draft two"))
        #expect(transcript.visibleText == "BEGIN committed draft two")
        #expect(transcript.completeText == "BEGIN committed")
    }
}
