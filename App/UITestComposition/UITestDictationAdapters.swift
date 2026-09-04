import AppKit
import Foundation
import GuideCore
import GuideMac
import GuideUI

@MainActor
final class UITestClipboardService: AppClipboardServicing, DeterministicUITestAdapter {
    private let receiptURL: URL
    init(sessionRoot: URL) { receiptURL = sessionRoot.appendingPathComponent("clipboard.fixture") }
    func copy(_ text: String) -> Bool {
        do {
            try text.write(to: receiptURL, atomically: true, encoding: .utf8)
            return true
        } catch {
            return false
        }
    }
}

final class UITestPreferences: AppPreferences, DeterministicUITestAdapter {
    private var values: [String: Any] = [:]
    func set(_ value: Any?, forKey defaultName: String) { values[defaultName] = value }
    func string(forKey defaultName: String) -> String? { values[defaultName] as? String }
    func bool(forKey defaultName: String) -> Bool { values[defaultName] as? Bool ?? false }
    func data(forKey defaultName: String) -> Data? { values[defaultName] as? Data }
    func object(forKey defaultName: String) -> Any? { values[defaultName] }
}

@MainActor
final class UITestPermissionService: AppPermissionServicing, DeterministicUITestAdapter {
    private var microphone: PermissionState
    private let denyMicrophone: Bool
    private let stateURL: URL

    init(denyMicrophone: Bool, sessionRoot: URL) {
        self.denyMicrophone = denyMicrophone
        stateURL = sessionRoot.appendingPathComponent("permission-denied.fixture")
        microphone = FileManager.default.fileExists(atPath: stateURL.path)
            ? .denied
            : (denyMicrophone ? .unknown : .granted)
    }

    func snapshot() -> PermissionSnapshot {
        PermissionSnapshot(microphone: microphone, speechRecognition: .granted, accessibility: .granted, screenRecording: .granted)
    }
    func requestMicrophone() async -> Bool {
        microphone = denyMicrophone ? .denied : .granted
        if denyMicrophone {
            do { try Data().write(to: stateURL, options: .atomic) }
            catch { preconditionFailure("permission fixture state could not be persisted") }
        }
        return microphone == .granted
    }
    func requestSpeechRecognition() async -> Bool { true }
    func requestAccessibility() -> Bool { true }
    func requestScreenRecording() -> Bool { true }
    func openSystemSettings(for permission: GuidePermission) {}
}

@MainActor
final class UITestTextInsertionService: AppTextInsertionServicing, DeterministicUITestAdapter {
    private let receiptURL: URL
    private let block: Bool
    init(sessionRoot: URL, block: Bool) {
        receiptURL = sessionRoot.appendingPathComponent("insertion.fixture")
        self.block = block
    }
    func captureFocusedTarget() throws -> FocusedTextTarget {
        FocusedTextTarget(
            processIdentifier: ProcessInfo.processInfo.processIdentifier,
            element: nil,
            bundleIdentifier: "fixture.target"
        )
    }
    func insert(_ text: String, into target: FocusedTextTarget) async throws -> TextInsertionMethod {
        if block { try await Task.sleep(for: .seconds(3_600)) }
        try text.write(to: receiptURL, atomically: true, encoding: .utf8)
        return .accessibility
    }
    func cancel() -> Bool { true }
}

@MainActor
final class UITestDictationSession: DictationSessioning, DeterministicUITestAdapter {
    var onPartial: (@MainActor @Sendable (String) -> Void)?
    var isOnDeviceAvailable: Bool { true }
    var availabilityDescription: String { "Deterministic local speech fixture" }
    private let blockStop: Bool
    init(blockStop: Bool) { self.blockStop = blockStop }
    func start(retainAudioInHistory: Bool) async throws { onPartial?("alpha beta") }
    func stop() async throws -> SpeechTranscriptionResult {
        if blockStop { try await Task.sleep(for: .seconds(3_600)) }
        return .init(transcript: "alpha beta", temporaryAudioURL: nil)
    }
    func cancel() throws {}
    func discardTemporaryAudio(at url: URL) throws {}
}

actor UITestHistoryStore: AppTranscriptHistoryServicing, DeterministicUITestAdapter {
    private var entries: [TranscriptHistoryEntry]
    private let storeURL: URL

    init(arguments: [String], sessionRoot: URL) {
        storeURL = sessionRoot.appendingPathComponent("transcript-history.fixture.json")
        if let data = try? Data(contentsOf: storeURL),
           let persisted = try? JSONDecoder().decode([TranscriptHistoryEntry].self, from: data) {
            entries = persisted
            return
        }
        guard let raw = arguments.first(where: { $0.hasPrefix("--recovery-variant=") })?
            .replacingOccurrences(of: "--recovery-variant=", with: ""),
              let state = TranscriptDeliveryState(rawValue: raw == "interrupted" ? "pending" : raw)
        else {
            entries = []
            return
        }
        entries = [TranscriptHistoryEntry(
            text: "Recovered fixture dictation",
            targetBundleIdentifier: "fixture.target",
            deliveryState: state,
            retainedInHistory: false,
            expiresAt: .distantFuture
        )]
        Self.persist(entries, to: storeURL)
    }
    func load() -> [TranscriptHistoryEntry] { entries }
    func preserve(text: String, targetBundleIdentifier: String?, temporaryAudioURL: URL?, retainInHistory: Bool) -> TranscriptHistoryEntry {
        let entry = TranscriptHistoryEntry(text: text, targetBundleIdentifier: targetBundleIdentifier, retainedInHistory: retainInHistory, expiresAt: .distantFuture)
        entries = [entry]
        Self.persist(entries, to: storeURL)
        return entry
    }
    func updateDelivery(id: UUID, state: TranscriptDeliveryState, method: String?, targetBundleIdentifier: String?) -> [TranscriptHistoryEntry] {
        if let index = entries.firstIndex(where: { $0.id == id }) {
            entries[index].deliveryState = state
            entries[index].deliveryMethod = method
        }
        Self.persist(entries, to: storeURL)
        return entries
    }
    func delete(id: UUID) -> [TranscriptHistoryEntry] {
        entries.removeAll { $0.id == id }
        Self.persist(entries, to: storeURL)
        return entries
    }
    func clear() {
        entries = []
        Self.persist(entries, to: storeURL)
    }

    private nonisolated static func persist(_ entries: [TranscriptHistoryEntry], to storeURL: URL) {
        guard let data = try? JSONEncoder().encode(entries) else {
            preconditionFailure("transcript history fixture could not be encoded")
        }
        do { try data.write(to: storeURL, options: .atomic) }
        catch { preconditionFailure("transcript history fixture could not be persisted") }
    }
}
