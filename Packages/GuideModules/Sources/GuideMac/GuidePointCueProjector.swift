import AppKit
import CoreGraphics
import GuideCore

public struct GuideDisplayMapping: Equatable, Sendable {
    public let quartzFrame: CGRect
    public let appKitFrame: CGRect

    public init(quartzFrame: CGRect, appKitFrame: CGRect) {
        self.quartzFrame = quartzFrame
        self.appKitFrame = appKitFrame
    }
}

public struct GuidePointCueProjector: Sendable {
    public init() {}

    public func appKitPoint(
        for cue: GuidePointCue,
        displays: [GuideDisplayMapping]
    ) -> CGPoint? {
        let normalized = cue.normalizedPoint
        guard (0...1).contains(normalized.x), (0...1).contains(normalized.y) else { return nil }

        // CGWindow frames use Quartz's top-left-oriented desktop coordinates.
        // Provider points are top-left normalized within the captured image.
        let quartzPoint = CGPoint(
            x: cue.target.frame.minX + normalized.x * cue.target.frame.width,
            y: cue.target.frame.minY + normalized.y * cue.target.frame.height
        )
        guard let display = displays.first(where: { $0.quartzFrame.contains(quartzPoint) }) else {
            return nil
        }
        return CGPoint(
            x: display.appKitFrame.minX + quartzPoint.x - display.quartzFrame.minX,
            y: display.appKitFrame.maxY - (quartzPoint.y - display.quartzFrame.minY)
        )
    }

    @MainActor
    public func appKitPoint(for cue: GuidePointCue) -> CGPoint? {
        appKitPoint(for: cue, displays: Self.systemDisplayMappings())
    }

    @MainActor
    public static func systemDisplayMappings() -> [GuideDisplayMapping] {
        NSScreen.screens.compactMap { screen in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                return nil
            }
            return GuideDisplayMapping(
                quartzFrame: CGDisplayBounds(CGDirectDisplayID(number.uint32Value)),
                appKitFrame: screen.frame
            )
        }
    }
}
