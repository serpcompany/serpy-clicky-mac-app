import AppKit
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

    @Test("cancellation immediately before the paste commit posts no event")
    func cancellationWinsBeforeIrreversiblePasteCommit() async throws {
        let pasteboard = NSPasteboard(name: .init("serpy-linearizable-paste-\(UUID().uuidString)"))
        pasteboard.clearContents()
        pasteboard.setString("original", forType: .string)
        let dispatcher = CancellingPasteDispatcher()
        let service = TextInsertionService(
            pasteboard: pasteboard,
            frontmostProcessIdentifier: { 42 },
            pasteDispatcher: dispatcher,
            postPasteDelay: {}
        )
        dispatcher.service = service
        let target = FocusedTextTarget(
            processIdentifier: 42,
            element: nil,
            bundleIdentifier: "com.example.target"
        )

        await #expect(throws: CancellationError.self) {
            _ = try await service.insert("must not post", into: target)
        }

        #expect(dispatcher.postedEvents == 0)
        #expect(pasteboard.string(forType: .string) == "original")
    }

    private func requireSession(_ value: any DictationSessioning) {}
    private func requireTargetReader<T: FocusedTextTargetReading>(_ value: T) {}
    private func requireInserter<T: TextInserting>(_ value: T) {}
    private func requireHistory(_ value: any LastDictationStoring) {}
    private func requireCapture(_ value: any AudioCapturing) {}
    private func requireStreaming(_ value: any StreamingTranscriber) {}
}

@MainActor
private final class CancellingPasteDispatcher: PasteEventDispatching {
    weak var service: TextInsertionService?
    private(set) var postedEvents = 0

    func commitPaste(ifAllowed: () -> Bool) throws -> Bool {
        #expect(service?.cancel() == true)
        guard ifAllowed() else { return false }
        postedEvents += 1
        return true
    }
}
