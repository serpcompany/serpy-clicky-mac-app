import AppKit
import Foundation
import GuideCore
import ScreenCaptureKit
import Vision

@MainActor
public final class ScreenContextService {
    public init() {}

    public func captureFrontmostContext() async throws -> ScreenContext {
        let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let candidates = content.windows.filter { window in
            window.isOnScreen && window.owningApplication?.processID != ownPID && window.frame.width > 160 && window.frame.height > 100
        }
        guard let window = candidates.first(where: { $0.owningApplication?.processID == frontPID }) ?? candidates.first else {
            throw GuideFailure(
                stage: .capture,
                message: "No readable app window is available.",
                recovery: "Open the app you want help with, then try Guide Current Screen again."
            )
        }

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
