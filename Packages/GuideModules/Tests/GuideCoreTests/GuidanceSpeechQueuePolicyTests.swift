import GuideCore
import Testing

@Suite("Guidance speech queue")
struct GuidanceSpeechQueuePolicyTests {
    @Test("provider order is sanitized and each sentence is queued once")
    func orderedSanitizedDeduplication() {
        var policy = GuidanceSpeechQueuePolicy()

        #expect(policy.accept("“Open File.”") == "Open File.")
        #expect(policy.accept("Open File.") == nil)
        #expect(policy.accept(#"{"answer":"must not expose syntax"}"#) == nil)
        #expect(policy.accept("Choose New Window.") == "Choose New Window.")
        #expect(policy.accept("Then continue.") == "Then continue.")
    }

    @Test("cancellation rejects pending and late speech idempotently")
    func cancellationIsTerminal() {
        var policy = GuidanceSpeechQueuePolicy()
        policy.cancel()
        policy.cancel()

        #expect(policy.accept("must not be spoken") == nil)
    }
}
