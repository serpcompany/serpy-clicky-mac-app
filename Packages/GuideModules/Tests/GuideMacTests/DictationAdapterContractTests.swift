import GuideCore
@testable import GuideMac
import Testing

@MainActor
@Suite("External Dictation adapter contracts")
struct DictationAdapterContractTests {
    @Test("production adapters satisfy the provider-neutral Dictation seams")
    func productionConformancesAreExplicit() {
        requireSession(DurableDictationSession())
        requireTargetReader(TextInsertionService())
        requireInserter(TextInsertionService())
        requireHistory(TranscriptHistoryStore())
        requireCapture(YapAudioCaptureService())
        requireStreaming(ChunkedSFSpeechTranscriber())
    }

    private func requireSession(_ value: any DictationSessioning) {}
    private func requireTargetReader<T: FocusedTextTargetReading>(_ value: T) {}
    private func requireInserter<T: TextInserting>(_ value: T) {}
    private func requireHistory(_ value: any LastDictationStoring) {}
    private func requireCapture(_ value: any AudioCapturing) {}
    private func requireStreaming(_ value: any StreamingTranscriber) {}
}
