import AppKit
import ApplicationServices
import AVFoundation
import CoreGraphics
import Foundation
import GuideCore
import Speech

public struct PermissionSnapshot: Equatable, Sendable {
    public let microphone: PermissionState
    public let speechRecognition: PermissionState
    public let accessibility: PermissionState
    public let screenRecording: PermissionState

    public init(
        microphone: PermissionState,
        speechRecognition: PermissionState,
        accessibility: PermissionState,
        screenRecording: PermissionState
    ) {
        self.microphone = microphone
        self.speechRecognition = speechRecognition
        self.accessibility = accessibility
        self.screenRecording = screenRecording
    }

    public var dictationReady: Bool {
        microphone.isGranted && speechRecognition.isGranted && accessibility.isGranted
    }
}

@MainActor
public final class PermissionService {
    public init() {}

    public func snapshot() -> PermissionSnapshot {
        PermissionSnapshot(
            microphone: microphoneState,
            speechRecognition: speechRecognitionState,
            accessibility: AXIsProcessTrusted() ? .granted : .unknown,
            screenRecording: CGPreflightScreenCaptureAccess() ? .granted : .unknown
        )
    }

    public func requestMicrophone() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .audio)
    }

    public func requestSpeechRecognition() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    @discardableResult
    public func requestAccessibility() -> Bool {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    @discardableResult
    public func requestScreenRecording() -> Bool {
        CGRequestScreenCaptureAccess()
    }

    public func openSystemSettings(for permission: GuidePermission) {
        let destination: String
        switch permission {
        case .microphone:
            destination = "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
        case .speechRecognition:
            destination = "x-apple.systempreferences:com.apple.preference.security?Privacy_SpeechRecognition"
        case .accessibility:
            destination = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        case .screenRecording:
            destination = "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        }
        guard let url = URL(string: destination) else { return }
        NSWorkspace.shared.open(url)
    }

    private var microphoneState: PermissionState {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: .granted
        case .denied, .restricted: .denied
        case .notDetermined: .unknown
        @unknown default: .unavailable(reason: "Unknown microphone authorization state.")
        }
    }

    private var speechRecognitionState: PermissionState {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized: .granted
        case .denied, .restricted: .denied
        case .notDetermined: .unknown
        @unknown default: .unavailable(reason: "Unknown speech-recognition authorization state.")
        }
    }
}
