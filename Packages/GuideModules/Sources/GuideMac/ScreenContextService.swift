import AppKit
import Foundation
import GuideCore
import ScreenCaptureKit
import Vision

public final class VisionScreenTextRecognizer: @unchecked Sendable {
    typealias Perform = @Sendable (CGImage) throws -> [ScreenTextBlock]

    private let queue = DispatchQueue(label: "com.serpcompany.serpy.vision-ocr", qos: .userInitiated)
    private let perform: Perform

    public init() {
        perform = Self.performVisionRecognition
    }

    init(perform: @escaping Perform) {
        self.perform = perform
    }

    public func recognizeText(in image: CGImage) async throws -> [ScreenTextBlock] {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [perform] in
                do {
                    continuation.resume(returning: try perform(image))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func performVisionRecognition(_ image: CGImage) throws -> [ScreenTextBlock] {
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

public final class ScreenContextService: GuideTurnContextCapturing, @unchecked Sendable {
    @MainActor private var preferredApplicationPID: pid_t?
    private let targetPolicy = ScreenContextTargetPolicy()
    private let exactTargetPolicy = ExactWindowTargetPolicy()
    private let recognizer: VisionScreenTextRecognizer

    public init(recognizer: VisionScreenTextRecognizer = VisionScreenTextRecognizer()) {
        self.recognizer = recognizer
    }

    @MainActor
    public func rememberFrontmostApplication() {
        let ownPID = ProcessInfo.processInfo.processIdentifier
        guard let frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier,
              frontPID != ownPID
        else { return }
        preferredApplicationPID = frontPID
    }

    @MainActor
    public func snapshotTarget() throws -> GuideWindowTarget {
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        guard let targetPID = targetPolicy.targetProcessIdentifier(
            remembered: preferredApplicationPID,
            frontmost: frontPID,
            own: ownPID
        ) else {
            throw missingTargetFailure
        }
        let locked = try exactTargetPolicy.lockTarget(
            frontToBack: Self.onScreenWindowTargets(excluding: ownPID),
            processIdentifier: targetPID
        )
        preferredApplicationPID = locked.processIdentifier
        return locked
    }

    public func capture(_ target: GuideWindowTarget) async throws -> ScreenContext {
        try Task.checkCancellation()
        let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
        let availableTargets = content.windows.compactMap { window -> GuideWindowTarget? in
            guard let processIdentifier = window.owningApplication?.processID else { return nil }
            return GuideWindowTarget(
                processIdentifier: processIdentifier,
                windowIdentifier: window.windowID,
                applicationName: window.owningApplication?.applicationName ?? "Current app",
                windowTitle: window.title ?? "Untitled window",
                frame: window.frame
            )
        }
        let resolvedTarget = try exactTargetPolicy.resolveExactTarget(
            target,
            available: availableTargets
        )
        guard let exactWindow = content.windows.first(where: {
            $0.owningApplication?.processID == resolvedTarget.processIdentifier &&
                $0.windowID == resolvedTarget.windowIdentifier
        }) else { throw missingTargetFailure }

        let filter = SCContentFilter(desktopIndependentWindow: exactWindow)
        let configuration = SCStreamConfiguration()
        configuration.width = max(1, Int(target.frame.width * 2))
        configuration.height = max(1, Int(target.frame.height * 2))
        configuration.showsCursor = false
        let image = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: configuration
        )
        try Task.checkCancellation()
        let blocks = try await recognizer.recognizeText(in: image)
        try Task.checkCancellation()

        return ScreenContext(
            applicationName: target.applicationName,
            windowTitle: target.windowTitle,
            windowFrame: target.frame,
            textBlocks: blocks
        )
    }

    private static func onScreenWindowTargets(excluding ownPID: pid_t) -> [GuideWindowTarget] {
        guard let rawWindows = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else { return [] }

        return rawWindows.compactMap { info in
            guard let pidNumber = info[kCGWindowOwnerPID as String] as? NSNumber,
                  let windowNumber = info[kCGWindowNumber as String] as? NSNumber,
                  let layerNumber = info[kCGWindowLayer as String] as? NSNumber,
                  layerNumber.intValue == 0,
                  pidNumber.int32Value != ownPID,
                  let bounds = info[kCGWindowBounds as String] as? NSDictionary,
                  let frame = CGRect(dictionaryRepresentation: bounds)
            else { return nil }

            return GuideWindowTarget(
                processIdentifier: pidNumber.int32Value,
                windowIdentifier: windowNumber.uint32Value,
                applicationName: info[kCGWindowOwnerName as String] as? String ?? "Current app",
                windowTitle: info[kCGWindowName as String] as? String ?? "Untitled window",
                frame: frame
            )
        }
    }

    private var missingTargetFailure: GuideFailure {
        GuideFailure(
            stage: .capture,
            message: "The window selected when the guide started is no longer available.",
            recovery: "Bring that exact window forward and start the voice guide again."
        )
    }
}
