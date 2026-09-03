import AppKit
import Foundation
import GuideCore
import ScreenCaptureKit
import Vision

private func lockedDisplayIdentifier(for frame: CGRect) -> UInt32? {
    var displayCount: UInt32 = 0
    guard CGGetDisplaysWithRect(frame, 0, nil, &displayCount) == .success,
          displayCount > 0 else { return nil }
    var displays = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
    guard CGGetDisplaysWithRect(frame, displayCount, &displays, &displayCount) == .success else { return nil }
    return displays.prefix(Int(displayCount)).max { first, second in
        let firstIntersection = CGDisplayBounds(first).intersection(frame)
        let secondIntersection = CGDisplayBounds(second).intersection(frame)
        return firstIntersection.width * firstIntersection.height
            < secondIntersection.width * secondIntersection.height
    }
}

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

public struct ScreenCaptureKitWindowSnapshot: Equatable, Sendable {
    public let processIdentifier: Int32
    public let windowIdentifier: UInt32
    public let applicationName: String
    public let windowTitle: String
    public let frame: CGRect
    public let displayIdentifier: UInt32?

    public init(processIdentifier: Int32, windowIdentifier: UInt32, applicationName: String, windowTitle: String, frame: CGRect, displayIdentifier: UInt32? = nil) {
        self.processIdentifier = processIdentifier
        self.windowIdentifier = windowIdentifier
        self.applicationName = applicationName
        self.windowTitle = windowTitle
        self.frame = frame
        self.displayIdentifier = displayIdentifier
    }
}

public struct ScreenCaptureKitCaptureRequest: Equatable, Sendable {
    public let processIdentifier: Int32
    public let windowIdentifier: UInt32
    public let pixelWidth: Int
    public let pixelHeight: Int
    public let showsCursor: Bool

    public init(processIdentifier: Int32, windowIdentifier: UInt32, pixelWidth: Int, pixelHeight: Int, showsCursor: Bool) {
        self.processIdentifier = processIdentifier
        self.windowIdentifier = windowIdentifier
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.showsCursor = showsCursor
    }
}

public protocol ScreenCaptureKitFacading: Sendable {
    func windowSnapshots() async throws -> [ScreenCaptureKitWindowSnapshot]
    func capturePNG(_ request: ScreenCaptureKitCaptureRequest) async throws -> Data
}

public struct ScreenCaptureKitPNGEncoder: Sendable {
    public init() {}

    public func encode(_ image: CGImage) throws -> Data {
        guard let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
            throw GuideFailure(stage: .capture, message: "The captured window image could not be encoded.", recovery: "Bring that exact window forward and try again.")
        }
        return data
    }
}

public actor SystemScreenCaptureKitFacade: ScreenCaptureKitFacading {
    private var windowsByID: [UInt32: SCWindow] = [:]
    private let encoder = ScreenCaptureKitPNGEncoder()

    public init() {}

    public func windowSnapshots() async throws -> [ScreenCaptureKitWindowSnapshot] {
        let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
        windowsByID = Dictionary(uniqueKeysWithValues: content.windows.map { ($0.windowID, $0) })
        return content.windows.compactMap { window in
            guard let pid = window.owningApplication?.processID else { return nil }
            return ScreenCaptureKitWindowSnapshot(
                processIdentifier: pid,
                windowIdentifier: window.windowID,
                applicationName: window.owningApplication?.applicationName ?? "Current app",
                windowTitle: window.title ?? "Untitled window",
                frame: window.frame,
                displayIdentifier: lockedDisplayIdentifier(for: window.frame)
            )
        }
    }

    public func capturePNG(_ request: ScreenCaptureKitCaptureRequest) async throws -> Data {
        guard let window = windowsByID[request.windowIdentifier],
              window.owningApplication?.processID == request.processIdentifier else {
            throw GuideFailure(stage: .capture, message: "The exact ScreenCaptureKit window is no longer available.", recovery: "Bring that exact window forward and start again.")
        }
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let configuration = SCStreamConfiguration()
        configuration.width = request.pixelWidth
        configuration.height = request.pixelHeight
        configuration.showsCursor = request.showsCursor
        let image = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: configuration
        )
        return try encoder.encode(image)
    }
}

public actor ScreenCaptureKitWindowProvider: ScreenWindowCaptureProviding {
    private let facade: any ScreenCaptureKitFacading
    private var snapshotsByID: [UInt32: ScreenCaptureKitWindowSnapshot] = [:]

    public init(facade: any ScreenCaptureKitFacading = SystemScreenCaptureKitFacade()) {
        self.facade = facade
    }

    public func availableWindows() async throws -> [GuideWindowTarget] {
        let snapshots = try await facade.windowSnapshots()
        snapshotsByID = Dictionary(uniqueKeysWithValues: snapshots.map { ($0.windowIdentifier, $0) })
        return snapshots.map { GuideWindowTarget(
            processIdentifier: $0.processIdentifier,
            windowIdentifier: $0.windowIdentifier,
            applicationName: $0.applicationName,
            windowTitle: $0.windowTitle,
            frame: $0.frame,
            displayIdentifier: $0.displayIdentifier
        ) }
    }

    public func captureWindow(_ target: GuideWindowTarget) async throws -> ScreenRaster {
        guard let snapshot = snapshotsByID[target.windowIdentifier], snapshot.processIdentifier == target.processIdentifier else {
            throw GuideFailure(stage: .capture, message: "The window selected when the guide started is no longer available.", recovery: "Bring that exact window forward and start the voice guide again.")
        }
        let request = ScreenCaptureKitCaptureRequest(
            processIdentifier: target.processIdentifier,
            windowIdentifier: target.windowIdentifier,
            pixelWidth: max(1, Int(target.frame.width * 2)),
            pixelHeight: max(1, Int(target.frame.height * 2)),
            showsCursor: false
        )
        do {
            let png = try await facade.capturePNG(request)
            guard !png.isEmpty, NSBitmapImageRep(data: png) != nil else {
                throw GuideFailure(stage: .capture, message: "The selected window did not produce a readable PNG.", recovery: "Bring that exact window forward and try again.")
            }
            return ScreenRaster(
                encodedImage: png,
                pixelWidth: request.pixelWidth,
                pixelHeight: request.pixelHeight
            )
        } catch let failure as GuideFailure {
            throw failure
        } catch {
            throw GuideFailure(stage: .capture, message: "ScreenCaptureKit could not capture the selected window. \(error.localizedDescription)", recovery: "Verify Screen Recording permission, bring that exact window forward, and try again.")
        }
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
            textBlocks: blocks,
            raster: raster.guideRaster
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
                frame: frame,
                displayIdentifier: lockedDisplayIdentifier(for: frame)
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
