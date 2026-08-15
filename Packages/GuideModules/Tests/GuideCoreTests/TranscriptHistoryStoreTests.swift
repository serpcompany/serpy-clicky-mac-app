import Foundation
import GuideCore
import GuideMac
import Testing

@Suite("Transcript history store")
struct TranscriptHistoryStoreTests {
    @Test("persists before delivery and survives a new store instance")
    func persistsAcrossInstances() async throws {
        let fixture = try Fixture()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let firstStore = fixture.store(now: now)
        let entry = try await firstStore.preserve(
            text: "Never make me say this twice",
            targetBundleIdentifier: "com.example.editor",
            retainInHistory: true
        )

        #expect(entry.deliveryState == .pending)
        let reloaded = try await fixture.store(now: now).load()
        #expect(reloaded == [entry])
        #expect(fixture.filePermissions == 0o600)
    }

    @Test("tracks confirmed, unconfirmed, and failed delivery without losing text")
    func updatesDelivery() async throws {
        let fixture = try Fixture()
        let store = fixture.store()
        let entry = try await store.preserve(text: "recover me", targetBundleIdentifier: nil)

        let updated = try await store.updateDelivery(
            id: entry.id,
            state: .failed,
            method: "paste"
        )

        #expect(updated.first?.text == "recover me")
        #expect(updated.first?.deliveryState == .failed)
        #expect(updated.first?.deliveryMethod == "paste")
    }

    @Test("bounds history by age and count")
    func prunesHistory() async throws {
        let fixture = try Fixture()
        var current = Date(timeIntervalSince1970: 1_800_000_000)
        let clock = LockedClock { current }
        let store = TranscriptHistoryStore(
            fileURL: fixture.fileURL,
            maximumEntries: 2,
            retentionInterval: 100,
            now: { clock.value }
        )

        _ = try await store.preserve(text: "first", targetBundleIdentifier: nil, retainInHistory: true)
        current.addTimeInterval(10)
        clock.set(current)
        _ = try await store.preserve(text: "second", targetBundleIdentifier: nil, retainInHistory: true)
        current.addTimeInterval(10)
        clock.set(current)
        _ = try await store.preserve(text: "third", targetBundleIdentifier: nil, retainInHistory: true)
        #expect(try await store.load().map(\.text) == ["third", "second"])

        current.addTimeInterval(200)
        clock.set(current)
        #expect(try await store.load().isEmpty)
    }

    @Test("archives optional audio and removes it with its entry")
    func archivesAndDeletesAudio() async throws {
        let fixture = try Fixture()
        let temporaryAudio = fixture.directory.appending(path: "capture.wav")
        try Data("audio fixture".utf8).write(to: temporaryAudio)
        let store = fixture.store()

        let entry = try await store.preserve(
            text: "audio is opt in",
            targetBundleIdentifier: nil,
            temporaryAudioURL: temporaryAudio
        )
        let audioFilename = try #require(entry.audioFilename)
        let audioURL = fixture.fileURL.deletingLastPathComponent()
            .appending(path: "Audio")
            .appending(path: audioFilename)
        #expect(FileManager.default.fileExists(atPath: audioURL.path))
        #expect(!FileManager.default.fileExists(atPath: temporaryAudio.path))

        _ = try await store.delete(id: entry.id)
        #expect(!FileManager.default.fileExists(atPath: audioURL.path))
    }

    @Test("clear removes transcript and audio history")
    func clearsEverything() async throws {
        let fixture = try Fixture()
        let store = fixture.store()
        _ = try await store.preserve(text: "temporary", targetBundleIdentifier: nil)

        try await store.clear()

        #expect(try await store.load().isEmpty)
    }

    @Test("default recovery keeps one item and shortens confirmed retention")
    func boundsDefaultRecovery() async throws {
        let fixture = try Fixture()
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let clock = LockedClock { base }
        let store = TranscriptHistoryStore(fileURL: fixture.fileURL, now: { clock.value })

        _ = try await store.preserve(text: "older", targetBundleIdentifier: nil)
        let latest = try await store.preserve(text: "latest", targetBundleIdentifier: nil)
        #expect(try await store.load().map(\.text) == ["latest"])

        _ = try await store.updateDelivery(id: latest.id, state: .confirmed, method: "paste")
        clock.set(base.addingTimeInterval(TranscriptHistoryStore.confirmedRecoveryInterval + 1))
        #expect(try await store.load().isEmpty)
    }

    @Test("unconfirmed recovery remains available for one day")
    func retainsUnconfirmedRecoveryForOneDay() async throws {
        let fixture = try Fixture()
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let clock = LockedClock { base }
        let store = TranscriptHistoryStore(fileURL: fixture.fileURL, now: { clock.value })

        let entry = try await store.preserve(text: "verify this paste", targetBundleIdentifier: nil)
        _ = try await store.updateDelivery(id: entry.id, state: .unconfirmed, method: "pasteUnconfirmed")

        clock.set(base.addingTimeInterval(TranscriptHistoryStore.recoveryRetentionInterval - 1))
        #expect(try await store.load().map(\.text) == ["verify this paste"])

        clock.set(base.addingTimeInterval(TranscriptHistoryStore.recoveryRetentionInterval + 1))
        #expect(try await store.load().isEmpty)
    }
}

private final class LockedClock: @unchecked Sendable {
    private let lock = NSLock()
    private var read: () -> Date

    init(_ read: @escaping () -> Date) {
        self.read = read
    }

    var value: Date {
        lock.withLock { read() }
    }

    func set(_ date: Date) {
        lock.withLock { read = { date } }
    }
}

private struct Fixture {
    let directory: URL
    let fileURL: URL

    init() throws {
        directory = FileManager.default.temporaryDirectory
            .appending(path: "GuideCompanionHistoryTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appending(path: "History/transcripts.json")
    }

    func store(now: Date = Date(timeIntervalSince1970: 1_800_000_000)) -> TranscriptHistoryStore {
        TranscriptHistoryStore(fileURL: fileURL, now: { now })
    }

    var filePermissions: Int {
        let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
        return (attributes?[.posixPermissions] as? NSNumber)?.intValue ?? 0
    }
}
