import AppKit
import Foundation
import GuideCore
import ScreenCaptureKit
import Vision

@MainActor
public final class ScreenContextService {
    private var preferredApplicationPID: pid_t?
    private let targetPolicy = ScreenContextTargetPolicy()

    public init() {}

    public func rememberFrontmostApplication() {
        let ownPID = ProcessInfo.processInfo.processIdentifier
        guard let frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier,
              frontPID != ownPID
        else { return }
        preferredApplicationPID = frontPID
    }

    public func captureFrontmostContext() async throws -> ScreenContext {
        let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let targetPID = targetPolicy.targetProcessIdentifier(
            remembered: preferredApplicationPID,
            frontmost: frontPID,
            own: ownPID
        )
        let candidates = content.windows.filter { window in
            window.isOnScreen && window.owningApplication?.processID != ownPID && window.frame.width > 160 && window.frame.height > 100
        }
        let window = targetPID.flatMap { targetPID in
            candidates.first(where: { $0.owningApplication?.processID == targetPID })
        }
        guard let window else {
            throw GuideFailure(
                stage: .capture,
                message: "The app selected when the guide started no longer has a readable window.",
                recovery: "Bring that app's window forward and start the voice guide again."
            )
        }
        preferredApplicationPID = window.owningApplication?.processID

        let filter = SCContentFilter(desktopIndependentWindow: window)
        let configuration = SCStreamConfiguration()
        configuration.width = max(1, Int(window.frame.width * 2))
        configuration.height = max(1, Int(window.frame.height * 2))
        configuration.showsCursor = false
        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
        let blocks = try recognizeText(in: image)

        return ScreenContext(
            applicationName: window.owningApplication?.applicationName ?? "Current app",
            windowTitle: window.title ?? "Untitled window",
            windowFrame: window.frame,
            textBlocks: blocks
        )
    }

    private func recognizeText(in image: CGImage) throws -> [ScreenTextBlock] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = true
        let handler = VNImageRequestHandler(cgImage: image)
        try handler.perform([request])
        return (request.results ?? []).compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            return ScreenTextBlock(
                text: candidate.string,
                normalizedBounds: observation.boundingBox,
                confidence: candidate.confidence
            )
        }
    }
}
