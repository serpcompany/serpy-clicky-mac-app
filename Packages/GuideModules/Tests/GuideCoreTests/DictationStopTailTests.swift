import GuideCore
import Testing

@MainActor
@Suite("Cancellable final-word stop tail")
struct DictationStopTailTests {
    @Test("uses the donor duration and cancellation terminates the wait")
    func boundedTailIsCancellable() async {
        let tail = DictationStopTail()
        let wait = Task { try await tail.wait() }
        await Task.yield()

        #expect(tail.duration == .milliseconds(250))
        tail.cancel()

        await #expect(throws: CancellationError.self) {
            try await wait.value
        }
    }
}
