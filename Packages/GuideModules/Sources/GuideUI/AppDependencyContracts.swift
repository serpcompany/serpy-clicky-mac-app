import AppKit
import Foundation
import GuideCore
import GuideMac

public protocol AppPreferences: AnyObject {
    func set(_ value: Any?, forKey defaultName: String)
    func string(forKey defaultName: String) -> String?
    func bool(forKey defaultName: String) -> Bool
    func data(forKey defaultName: String) -> Data?
    func object(forKey defaultName: String) -> Any?
}

extension UserDefaults: AppPreferences {}

@MainActor
public protocol AppClipboardServicing: AnyObject {
    func copy(_ text: String) -> Bool
}

@MainActor
public final class SystemAppClipboardService: AppClipboardServicing {
    public init() {}
    public func copy(_ text: String) -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.setString(text, forType: .string)
    }
}

@MainActor
public protocol AppPermissionServicing: AnyObject {
    func snapshot() -> PermissionSnapshot
    func requestMicrophone() async -> Bool
    func requestSpeechRecognition() async -> Bool
    func requestAccessibility() -> Bool
    func requestScreenRecording() -> Bool
    func openSystemSettings(for permission: GuidePermission)
}

extension PermissionService: AppPermissionServicing {}

@MainActor
public protocol AppTextInsertionServicing: FocusedTextTargetReading, TextInserting
where FocusedTarget == FocusedTextTarget {}

extension TextInsertionService: AppTextInsertionServicing {}

public protocol AppTranscriptHistoryServicing: LastDictationStoring {
    func delete(id: UUID) async throws -> [TranscriptHistoryEntry]
    func clear() async throws
}

extension TranscriptHistoryStore: AppTranscriptHistoryServicing {}

public protocol AppScreenContextServicing: GuideTurnContextCapturing {
    @MainActor func rememberFrontmostApplication()
}

extension ScreenContextService: AppScreenContextServicing {}

@MainActor
public protocol AppGuideTranscribing: GuideTurnTranscribing {
    var isOnDeviceAvailable: Bool { get }
}

extension AppleSpeechGuideTurnTranscriber: AppGuideTranscribing {
}
