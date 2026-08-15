import GuideCore
import Testing

@Suite("Ephemeral transcript recovery")
struct EphemeralTranscriptRecoveryTests {
    @Test("completed transcript remains available until explicitly cleared")
    func preservesUntilCleared() {
        var recovery = EphemeralTranscriptRecovery()

        recovery.preserve("Do not make me say this twice")
        #expect(recovery.transcript == "Do not make me say this twice")
        #expect(recovery.isAvailable)

        recovery.clear()
        #expect(recovery.transcript == nil)
        #expect(!recovery.isAvailable)
    }

    @Test("empty results never overwrite a recoverable transcript")
    func ignoresEmptyResults() {
        var recovery = EphemeralTranscriptRecovery(transcript: "keep me")

        recovery.preserve("")

        #expect(recovery.transcript == "keep me")
    }
}
