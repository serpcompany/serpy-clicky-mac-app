import AppKit
import CoreGraphics
import GuideCore

public struct GuideDisplayMapping: Equatable, Sendable {
    public let displayIdentifier: UInt32?
    public let quartzFrame: CGRect
    public let appKitFrame: CGRect

    public init(displayIdentifier: UInt32? = nil, quartzFrame: CGRect, appKitFrame: CGRect) {
        self.displayIdentifier = displayIdentifier
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
        let lockedDisplays = cue.target.displayIdentifier.map { identifier in
            displays.filter { $0.displayIdentifier == identifier }
        } ?? displays
        guard let display = lockedDisplays.first(where: { $0.quartzFrame.contains(quartzPoint) }) else {
            return nil
        }
        return CGPoint(
            x: display.appKitFrame.minX + quartzPoint.x - display.quartzFrame.minX,
            y: display.appKitFrame.maxY - (quartzPoint.y - display.quartzFrame.minY)
        )
    }

    public func panelFrame(
        for cue: GuidePointCue,
        panelSize: CGSize,
        displays: [GuideDisplayMapping]
    ) -> CGRect? {
        guard let point = appKitPoint(for: cue, displays: displays) else { return nil }
        let lockedDisplays = cue.target.displayIdentifier.map { identifier in
            displays.filter { $0.displayIdentifier == identifier }
        } ?? displays
        guard let display = lockedDisplays.first(where: { $0.quartzFrame.intersects(cue.target.frame) }) else {
            return nil
        }
        let targetFrame = CGRect(
            x: display.appKitFrame.minX + cue.target.frame.minX - display.quartzFrame.minX,
            y: display.appKitFrame.maxY - (cue.target.frame.maxY - display.quartzFrame.minY),
            width: cue.target.frame.width,
            height: cue.target.frame.height
        )
        let size = CGSize(
            width: min(panelSize.width, targetFrame.width),
            height: min(panelSize.height, targetFrame.height)
        )
        return CGRect(
            x: min(max(point.x - size.width / 2, targetFrame.minX), targetFrame.maxX - size.width),
            y: min(max(point.y - size.height / 2, targetFrame.minY), targetFrame.maxY - size.height),
            width: size.width,
            height: size.height
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
                displayIdentifier: number.uint32Value,
                quartzFrame: CGDisplayBounds(CGDirectDisplayID(number.uint32Value)),
                appKitFrame: screen.frame
            )
        }
    }
}
