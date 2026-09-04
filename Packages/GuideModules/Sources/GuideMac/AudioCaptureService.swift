@preconcurrency import AVFoundation
import Foundation
import GuideCore

public protocol AudioCapturing: AnyObject, Sendable {
    var onBuffer: (@Sendable (AVAudioPCMBuffer) -> Void)? { get set }
    var onFailure: (@Sendable (GuideFailure) -> Void)? { get set }
    var isRunning: Bool { get }
    func start() throws
    func stop()
}

/// Fresh-engine capture adapted from Yap so an input-device change cannot
/// leave a stale format on a reused AVAudioEngine graph.
final class YapAudioCaptureService: AudioCapturing, @unchecked Sendable {
    var onBuffer: (@Sendable (AVAudioPCMBuffer) -> Void)?
    var onFailure: (@Sendable (GuideFailure) -> Void)?
    private var engine = AVAudioEngine()
    private(set) var isRunning = false
    private var configObserver: NSObjectProtocol?
    private var handlingConfigChange = false

    func start() throws {
        try restart()
        isRunning = true
    }

    func stop() {
        removeObserver()
        guard isRunning else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRunning = false
    }

    private func restart() throws {
        removeObserver()
        engine.stop()
        engine = AVAudioEngine()
        let input = engine.inputNode
        input.removeTap(onBus: 0)
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw recordingFailure(
                "The selected microphone has no usable audio format.",
                recovery: "Reconnect or choose another input device and try again."
            )
        }
        input.installTap(onBus: 0, bufferSize: 2_048, format: format) { [weak self] buffer, _ in
            self?.onBuffer?(buffer)
        }
        addObserver()
        engine.prepare()
        do {
            try engine.start()
        } catch {
            removeObserver()
            input.removeTap(onBus: 0)
            throw recordingFailure(
                "The microphone could not start.",
                recovery: "Check the input device and try again."
            )
        }
    }

    private func addObserver() {
        configObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { [weak self] _ in self?.handleConfigurationChange() }
    }

    private func removeObserver() {
        guard let configObserver else { return }
        NotificationCenter.default.removeObserver(configObserver)
        self.configObserver = nil
    }

    private func handleConfigurationChange() {
        guard isRunning, !handlingConfigChange else { return }
        handlingConfigChange = true
        defer { handlingConfigChange = false }
        do {
            try restart()
        } catch let failure as GuideFailure {
            stop()
            onFailure?(failure)
        } catch {
            stop()
            onFailure?(recordingFailure(
                "The microphone stopped after its input device changed.",
                recovery: "Reconnect the microphone and start Dictation again."
            ))
        }
    }

    private func recordingFailure(_ message: String, recovery: String) -> GuideFailure {
        GuideFailure(stage: .recording, message: message, recovery: recovery)
    }
}
