import Foundation
import GuideCore
import GuideMac
import Testing

@Suite("Temporary speech audio cleanup")
struct TemporaryAudioCleanupTests {
    @Test("deletion failure preserves a staged actionable recovery")
    func deletionFailureIsStructured() {
        let url = URL(fileURLWithPath: "/synthetic/audio.caf")
        do {
            try TemporaryAudioCleanup.discard(url) { _ in throw DeleteFailure() }
            Issue.record("Expected deletion failure")
        } catch let failure as GuideFailure {
            #expect(failure.stage == .storage)
            #expect(failure.message.contains("deleted"))
            #expect(!failure.recovery.isEmpty)
        } catch {
            Issue.record("Expected GuideFailure, received \(error)")
        }
    }
}

private struct DeleteFailure: Error {}
