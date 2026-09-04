@preconcurrency import AVFoundation
import Foundation
import GuideCore

public protocol AudioCheckpointSink: AnyObject, Sendable {
    func append(_ buffer: AVAudioPCMBuffer) throws
    func finish() throws -> URL?
    func cancel() throws
}

/// Writes every captured buffer through an injected recovery sink. The first
/// write failure becomes a stable storage failure and completion is rejected.
public final class RecoverableAudioCheckpointWriter: @unchecked Sendable {
    private let lock = NSLock()
    private let sink: any AudioCheckpointSink
    private var failure: GuideFailure?

    public init(sink: any AudioCheckpointSink) {
        self.sink = sink
    }

    public convenience init(directoryURL: URL) throws {
        try self.init(sink: AudioFileCheckpointSink(directoryURL: directoryURL))
    }

    convenience init(fileManager: FileManager = .default) throws {
        try self.init(directoryURL: Self.defaultRecoveryDirectory(fileManager: fileManager))
    }

    public static func defaultRecoveryDirectory(fileManager: FileManager = .default) -> URL {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "SERPy/RecoveryAudio", directoryHint: .isDirectory)
    }

    public static func recoverableAudioURLs(
        in directoryURL: URL,
        fileManager: FileManager = .default
    ) throws -> [URL] {
        guard fileManager.fileExists(atPath: directoryURL.path) else { return [] }
        return try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        )
            .filter { $0.lastPathComponent.hasPrefix("active-") && $0.pathExtension == "caf" }
            .sorted { lhs, rhs in
                let left = try? lhs.resourceValues(forKeys: [.creationDateKey]).creationDate
                let right = try? rhs.resourceValues(forKeys: [.creationDateKey]).creationDate
                return (left ?? .distantPast) < (right ?? .distantPast)
            }
    }

    public func append(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        defer { lock.unlock() }
        guard failure == nil else { return }
        do {
            try sink.append(buffer)
        } catch {
            failure = GuideFailure(
                stage: .storage,
                message: "Active Dictation audio could not be checkpointed.",
                recovery: "Dictation stopped before unsafe completion. Check available disk space and try again."
            )
        }
    }

    public func finish() throws -> URL? {
        lock.lock()
        defer { lock.unlock() }
        if let failure { throw failure }
        return try sink.finish()
    }

    public func cancel() throws {
        lock.lock()
        defer { lock.unlock() }
        try sink.cancel()
    }
}

/// Copies audio into a bounded memory queue on the real-time callback and
/// performs ordered file writes on a dedicated serial executor.
public final class SerializedAudioCheckpointWriter: @unchecked Sendable {
    private final class SendableBuffer: @unchecked Sendable {
        let value: AVAudioPCMBuffer
        init(_ value: AVAudioPCMBuffer) { self.value = value }
    }

    private let writer: RecoverableAudioCheckpointWriter
    private let maximumPendingBuffers: Int
    private let queue = DispatchQueue(label: "com.serpcompany.serpy.audio-checkpoints")
    private let lock = NSLock()
    private var pendingBuffers = 0
    private var failure: GuideFailure?
    private var acceptingBuffers = true

    public init(
        writer: RecoverableAudioCheckpointWriter,
        maximumPendingBuffers: Int = 512
    ) {
        self.writer = writer
        self.maximumPendingBuffers = max(1, maximumPendingBuffers)
    }

    /// Returns without waiting for disk IO. False records a terminal overflow
    /// failure; completion can no longer return a truncated success.
    @discardableResult
    public func enqueue(_ buffer: AVAudioPCMBuffer) -> Bool {
        guard let copied = Self.copy(buffer) else {
            recordFailure(
                message: "A captured audio buffer could not be copied for recovery.",
                recovery: "Dictation stopped before unsafe completion. Try again after freeing memory."
            )
            return false
        }
        let sendable = SendableBuffer(copied)
        lock.lock()
        guard acceptingBuffers, failure == nil, pendingBuffers < maximumPendingBuffers else {
            if acceptingBuffers, failure == nil {
                failure = GuideFailure(
                    stage: .storage,
                    message: "The recoverable audio checkpoint queue overflowed.",
                    recovery: "Dictation stopped before unsafe completion. Free disk or memory and try again."
                )
            }
            lock.unlock()
            return false
        }
        pendingBuffers += 1
        queue.async { [writer, weak self] in
            writer.append(sendable.value)
            guard let self else { return }
            self.lock.withLock { self.pendingBuffers -= 1 }
        }
        lock.unlock()
        return true
    }

    public func finish() throws -> URL? {
        lock.withLock { acceptingBuffers = false }
        queue.sync {}
        if let failure = lock.withLock({ failure }) { throw failure }
        return try writer.finish()
    }

    public func cancel() throws {
        lock.withLock { acceptingBuffers = false }
        queue.sync {}
        try writer.cancel()
    }

    private func recordFailure(message: String, recovery: String) {
        lock.withLock {
            if failure == nil {
                failure = GuideFailure(stage: .storage, message: message, recovery: recovery)
            }
        }
    }

    private static func copy(_ source: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let copy = AVAudioPCMBuffer(
            pcmFormat: source.format,
            frameCapacity: source.frameLength
        ) else { return nil }
        copy.frameLength = source.frameLength
        let sourceBuffers = UnsafeMutableAudioBufferListPointer(source.mutableAudioBufferList)
        let destinationBuffers = UnsafeMutableAudioBufferListPointer(copy.mutableAudioBufferList)
        guard sourceBuffers.count == destinationBuffers.count else { return nil }
        for index in sourceBuffers.indices {
            guard let sourceData = sourceBuffers[index].mData,
                  let destinationData = destinationBuffers[index].mData else { return nil }
            let byteCount = Int(sourceBuffers[index].mDataByteSize)
            memcpy(destinationData, sourceData, byteCount)
            destinationBuffers[index].mDataByteSize = sourceBuffers[index].mDataByteSize
        }
        return copy
    }
}

private final class AudioFileCheckpointSink: AudioCheckpointSink, @unchecked Sendable {
    private let url: URL
    private var file: AVAudioFile?

    init(directoryURL: URL, fileManager: FileManager = .default) throws {
        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directoryURL.path)
        var directoryValues = URLResourceValues()
        directoryValues.isExcludedFromBackup = true
        var mutableDirectory = directoryURL
        try mutableDirectory.setResourceValues(directoryValues)
        url = directoryURL.appending(path: "active-\(UUID().uuidString).caf")
    }

    func append(_ buffer: AVAudioPCMBuffer) throws {
        if file == nil {
            file = try AVAudioFile(forWriting: url, settings: buffer.format.settings)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            var mutableURL = url
            try mutableURL.setResourceValues(values)
        }
        try file?.write(from: buffer)
    }

    func finish() throws -> URL? {
        file = nil
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func cancel() throws {
        file = nil
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }
}
