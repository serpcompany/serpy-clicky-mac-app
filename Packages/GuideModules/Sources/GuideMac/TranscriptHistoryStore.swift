import Foundation
import GuideCore

private struct TranscriptHistoryDocument: Codable, Equatable, Sendable {
    var schemaVersion = 1
    var entries: [TranscriptHistoryEntry]
}

public actor TranscriptHistoryStore {
    public static let defaultMaximumEntries = 25
    public static let defaultRetentionInterval: TimeInterval = 30 * 24 * 60 * 60
    public static let recoveryRetentionInterval: TimeInterval = 24 * 60 * 60
    public static let confirmedRecoveryInterval: TimeInterval = 10 * 60

    private let fileURL: URL
    private let audioDirectoryURL: URL
    private let maximumEntries: Int
    private let retentionInterval: TimeInterval
    private let now: @Sendable () -> Date
    private let fileManager: FileManager

    public init(
        fileURL: URL = TranscriptHistoryStore.defaultFileURL(),
        maximumEntries: Int = TranscriptHistoryStore.defaultMaximumEntries,
        retentionInterval: TimeInterval = TranscriptHistoryStore.defaultRetentionInterval,
        now: @escaping @Sendable () -> Date = { .now },
        fileManager: FileManager = .default
    ) {
        self.fileURL = fileURL
        audioDirectoryURL = fileURL.deletingLastPathComponent().appending(path: "Audio", directoryHint: .isDirectory)
        self.maximumEntries = max(1, maximumEntries)
        self.retentionInterval = max(60, retentionInterval)
        self.now = now
        self.fileManager = fileManager
    }

    public static func defaultFileURL(fileManager: FileManager = .default) -> URL {
        let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return applicationSupport
            .appending(path: "Guide Companion", directoryHint: .isDirectory)
            .appending(path: "History", directoryHint: .isDirectory)
            .appending(path: "transcripts.json", directoryHint: .notDirectory)
    }

    public func load() throws -> [TranscriptHistoryEntry] {
        var document = try loadDocument()
        let originalEntries = document.entries
        document.entries = retainedEntries(from: document.entries)
        if document.entries != originalEntries {
            try write(document)
        }
        try removeOrphanedAudio(referencedBy: document.entries)
        return document.entries
    }

    @discardableResult
    public func preserve(
        text: String,
        targetBundleIdentifier: String?,
        temporaryAudioURL: URL? = nil,
        retainInHistory: Bool = false
    ) throws -> TranscriptHistoryEntry {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            throw CocoaError(.fileWriteInapplicableStringEncoding)
        }

        var document = try loadDocument()
        let createdAt = now()
        var entry = TranscriptHistoryEntry(
            createdAt: createdAt,
            text: cleaned,
            targetBundleIdentifier: targetBundleIdentifier,
            retainedInHistory: retainInHistory,
            expiresAt: createdAt.addingTimeInterval(
                retainInHistory ? retentionInterval : Self.recoveryRetentionInterval
            )
        )
        if let temporaryAudioURL {
            entry.audioFilename = try archiveAudio(from: temporaryAudioURL, id: entry.id)
        }
        if !retainInHistory {
            document.entries = []
        }
        document.entries.insert(entry, at: 0)
        document.entries = retainedEntries(from: document.entries)
        try write(document)
        try removeOrphanedAudio(referencedBy: document.entries)
        return entry
    }

    public func updateDelivery(
        id: UUID,
        state: TranscriptDeliveryState,
        method: String?,
        targetBundleIdentifier: String? = nil
    ) throws -> [TranscriptHistoryEntry] {
        var document = try loadDocument()
        guard let index = document.entries.firstIndex(where: { $0.id == id }) else {
            return retainedEntries(from: document.entries)
        }
        document.entries[index].deliveryState = state
        document.entries[index].deliveryMethod = method
        if let targetBundleIdentifier {
            document.entries[index].targetBundleIdentifier = targetBundleIdentifier
        }
        if !document.entries[index].retainedInHistory {
            let interval = state == .confirmed
                ? Self.confirmedRecoveryInterval
                : Self.recoveryRetentionInterval
            document.entries[index].expiresAt = now().addingTimeInterval(interval)
        }
        document.entries = retainedEntries(from: document.entries)
        try write(document)
        return document.entries
    }

    public func delete(id: UUID) throws -> [TranscriptHistoryEntry] {
        var document = try loadDocument()
        let removed = document.entries.first(where: { $0.id == id })
        document.entries.removeAll(where: { $0.id == id })
        try write(document)
        if let audioFilename = removed?.audioFilename {
            try? fileManager.removeItem(at: audioDirectoryURL.appending(path: audioFilename))
        }
        return document.entries
    }

    public func clear() throws {
        try write(TranscriptHistoryDocument(entries: []))
        if fileManager.fileExists(atPath: audioDirectoryURL.path) {
            try fileManager.removeItem(at: audioDirectoryURL)
        }
    }

    private func loadDocument() throws -> TranscriptHistoryDocument {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return TranscriptHistoryDocument(entries: [])
        }
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(TranscriptHistoryDocument.self, from: data)
    }

    private func retainedEntries(from entries: [TranscriptHistoryEntry]) -> [TranscriptHistoryEntry] {
        return entries
            .filter { $0.expiresAt > now() }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(maximumEntries)
            .map { $0 }
    }

    private func write(_ document: TranscriptHistoryDocument) throws {
        let directory = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var directoryURL = directory
        try? directoryURL.setResourceValues(values)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(document)
        try data.write(to: fileURL, options: .atomic)
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
        var fileValues = URLResourceValues()
        fileValues.isExcludedFromBackup = true
        var mutableFileURL = fileURL
        try? mutableFileURL.setResourceValues(fileValues)
    }

    private func archiveAudio(from temporaryURL: URL, id: UUID) throws -> String {
        try fileManager.createDirectory(
            at: audioDirectoryURL,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        let filename = "\(id.uuidString).wav"
        let destination = audioDirectoryURL.appending(path: filename)
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.moveItem(at: temporaryURL, to: destination)
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: destination.path)
        return filename
    }

    private func removeOrphanedAudio(referencedBy entries: [TranscriptHistoryEntry]) throws {
        guard fileManager.fileExists(atPath: audioDirectoryURL.path) else { return }
        let referenced = Set(entries.compactMap(\.audioFilename))
        for url in try fileManager.contentsOfDirectory(
            at: audioDirectoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) where !referenced.contains(url.lastPathComponent) {
            try? fileManager.removeItem(at: url)
        }
    }
}
