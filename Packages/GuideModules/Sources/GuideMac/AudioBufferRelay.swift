@preconcurrency import AVFoundation
import Foundation

/// Bounded early-buffer relay copied from Yap. Capture can start before the
/// local transcriber is ready without losing the opening words.
final class AudioBufferRelay: @unchecked Sendable {
    private let lock = NSLock()
    private var pending: [AVAudioPCMBuffer] = []
    private var sink: (@Sendable (AVAudioPCMBuffer) -> Void)?
    private let maximumPending = 250

    func receive(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        if let sink {
            lock.unlock()
            sink(buffer)
            return
        }
        if pending.count < maximumPending { pending.append(buffer) }
        lock.unlock()
    }

    func attach(_ sink: @escaping @Sendable (AVAudioPCMBuffer) -> Void) {
        lock.lock()
        let buffered = pending
        pending.removeAll()
        self.sink = sink
        lock.unlock()
        for buffer in buffered { sink(buffer) }
    }

    func reset() {
        lock.lock()
        sink = nil
        pending.removeAll()
        lock.unlock()
    }
}
