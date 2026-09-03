import AppKit
import Foundation
import GuideCore
import ScreenCaptureKit
import Vision

public final class VisionScreenTextRecognizer: ScreenTextRecognizing, @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.serpcompany.serpy.vision-ocr", qos: .userInitiated)

    public init() {}

    public func recognizeText(in raster: ScreenRaster) async throws -> [ScreenTextBlock] {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    continuation.resume(returning: try Self.performVisionRecognition(raster.encodedImage))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func performVisionRecognition(_ imageData: Data) throws -> [ScreenTextBlock] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = true
        let handler = VNImageRequestHandler(data: imageData)
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

public actor ScreenCaptureKitWindowProvider: ScreenWindowCaptureProviding {
    private var windowsByID: [UInt32: SCWindow] = [:]

    public init() {}

    public func availableWindows() async throws -> [GuideWindowTarget] {
        let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
        windowsByID = Dictionary(uniqueKeysWithValues: content.windows.map { ($0.windowID, $0) })
        return content.windows.compactMap(Self.descriptor)
    }

    public func captureWindow(_ target: GuideWindowTarget) async throws -> ScreenRaster {
        guard let window = windowsByID[target.windowIdentifier],
              window.owningApplication?.processID == target.processIdentifier
        else {
            throw GuideFailure(
                stage: .capture,
                message: "The window selected when the guide started is no longer available.",
                recovery: "Bring that exact window forward and start the voice guide again."
            )
        }
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let configuration = SCStreamConfiguration()
        configuration.width = max(1, Int(target.frame.width * 2))
        configuration.height = max(1, Int(target.frame.height * 2))
        configuration.showsCursor = false
        let image = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: configuration
        )
        guard let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
            throw GuideFailure(
                stage: .capture,
                message: "The selected window image could not be prepared for local reading.",
                recovery: "Bring that exact window forward and try again."
            )
        }
        return ScreenRaster(encodedImage: data)
    }

    private static func descriptor(_ window: SCWindow) -> GuideWindowTarget? {
        guard let processIdentifier = window.owningApplication?.processID else { return nil }
        return GuideWindowTarget(
            processIdentifier: processIdentifier,
            windowIdentifier: window.windowID,
            applicationName: window.owningApplication?.applicationName ?? "Current app",
            windowTitle: window.title ?? "Untitled window",
            frame: window.frame
        )
    }
}

public final class ScreenContextService: GuideTurnContextCapturing, @unchecked Sendable {
    @MainActor private var preferredApplicationPID: pid_t?
    private let targetPolicy = ScreenContextTargetPolicy()
    private let exactTargetPolicy = ExactWindowTargetPolicy()
    private let windowProvider: any ScreenWindowCaptureProviding
    private let recognizer: any ScreenTextRecognizing

    public init(
        windowProvider: any ScreenWindowCaptureProviding = ScreenCaptureKitWindowProvider(),
        recognizer: any ScreenTextRecognizing = VisionScreenTextRecognizer()
    ) {
        self.windowProvider = windowProvider
        self.recognizer = recognizer
    }

    @MainActor
    public func rememberFrontmostApplication() {
        let ownPID = ProcessInfo.processInfo.processIdentifier
        guard let frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier,
              frontPID != ownPID else { return }
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
        ) else { throw missingTargetFailure }
        let locked = try exactTargetPolicy.lockTarget(
            frontToBack: Self.onScreenWindowTargets(excluding: ownPID),
            processIdentifier: targetPID
        )
        preferredApplicationPID = locked.processIdentifier
        return locked
    }

    public func capture(_ target: GuideWindowTarget) async throws -> ScreenContext {
        try Task.checkCancellation()
        let availableTargets = try await windowProvider.availableWindows()
        let resolvedTarget = try exactTargetPolicy.resolveExactTarget(target, available: availableTargets)
        let raster = try await windowProvider.captureWindow(resolvedTarget)
        try Task.checkCancellation()
        let blocks = try await recognizer.recognizeText(in: raster)
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
            guard let pid = info[kCGWindowOwnerPID as String] as? NSNumber,
                  let windowID = info[kCGWindowNumber as String] as? NSNumber,
                  let layer = info[kCGWindowLayer as String] as? NSNumber,
                  layer.intValue == 0,
                  pid.int32Value != ownPID,
                  let bounds = info[kCGWindowBounds as String] as? NSDictionary,
                  let frame = CGRect(dictionaryRepresentation: bounds)
            else { return nil }
            return GuideWindowTarget(
                processIdentifier: pid.int32Value,
                windowIdentifier: windowID.uint32Value,
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
