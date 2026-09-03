import CoreGraphics

public struct GuideAmbientPanelLayoutPolicy: Sendable {
    public init() {}

    public func frame(
        visibleFrame: CGRect,
        contentSize: CGSize,
        margin: CGFloat = 8
    ) -> CGRect {
        let safeFrame = visibleFrame.insetBy(dx: margin, dy: margin)
        let size = CGSize(
            width: min(contentSize.width, safeFrame.width),
            height: min(contentSize.height, safeFrame.height)
        )
        return CGRect(
            x: safeFrame.midX - size.width / 2,
            y: safeFrame.maxY - size.height,
            width: size.width,
            height: size.height
        )
    }
}

public enum CompanionResponseInteractionMode: Equatable, Sendable {
    case clickThrough
    case scrollableVisibleControl
}

public enum GuideSurface: Equatable, Sendable {
    case status
    case answer
    case pointCue
}

/// Guide surfaces explain and point; they never become controls over the work
/// surface. Overflow remains readable through truncation/transcript review.
public struct GuideSurfaceInteractionPolicy: Sendable {
    public init() {}

    public func mode(
        for surface: GuideSurface,
        contentOverflows: Bool
    ) -> CompanionResponseInteractionMode {
        _ = surface
        _ = contentOverflows
        return .clickThrough
    }
}

public struct CompanionResponseInteractionPolicy: Sendable {
    public init() {}

    public func mode(
        measuredContentHeight: CGFloat,
        maximumPanelHeight: CGFloat
    ) -> CompanionResponseInteractionMode {
        measuredContentHeight > maximumPanelHeight
            ? .scrollableVisibleControl
            : .clickThrough
    }

    public func maximumNonOverlappingHeight(
        visibleFrame: CGRect,
        avoidedFrame: CGRect,
        margin: CGFloat = 8,
        gap: CGFloat = 14
    ) -> CGFloat {
        let safeFrame = visibleFrame.insetBy(dx: margin, dy: margin)
        let below = avoidedFrame.minY - gap - safeFrame.minY
        let above = safeFrame.maxY - avoidedFrame.maxY - gap
        return max(0, below, above)
    }
}

public struct CompanionResponseSizing: Equatable, Sendable {
    public let size: CGSize
    public let interactionMode: CompanionResponseInteractionMode

    public init(size: CGSize, interactionMode: CompanionResponseInteractionMode) {
        self.size = size
        self.interactionMode = interactionMode
    }
}

public struct CompanionResponseSizingPolicy: Sendable {
    private let interaction = CompanionResponseInteractionPolicy()

    public init() {}

    public func resolve(
        width: CGFloat,
        measuredContentHeight: CGFloat,
        maximumPanelHeight: CGFloat,
        minimumPanelHeight: CGFloat
    ) -> CompanionResponseSizing {
        let mode = interaction.mode(
            measuredContentHeight: measuredContentHeight,
            maximumPanelHeight: maximumPanelHeight
        )
        return CompanionResponseSizing(
            size: CGSize(
                width: width,
                height: min(max(minimumPanelHeight, measuredContentHeight), maximumPanelHeight)
            ),
            interactionMode: mode
        )
    }
}

public struct CompanionResponseAnchorPolicy: Sendable {
    public init() {}

    public func frame(
        current: CGRect?,
        proposed: CGRect,
        responseIsVisible: Bool,
        visibleFrame: CGRect? = nil,
        avoiding avoidedFrame: CGRect? = nil
    ) -> CGRect {
        if responseIsVisible, let current {
            let anchored = CGRect(origin: current.origin, size: proposed.size)
            let staysVisible = visibleFrame.map { $0.insetBy(dx: 8, dy: 8).contains(anchored) } ?? true
            let avoidsStatus = avoidedFrame.map { !anchored.intersects($0) } ?? true
            if staysVisible, avoidsStatus { return anchored }
        }
        return proposed
    }
}

public struct CompanionResponseLayoutPolicy: Sendable {
    public init() {}

    public func frame(
        pointer: CGPoint,
        visibleFrame: CGRect,
        contentSize: CGSize,
        avoiding avoidedFrame: CGRect? = nil
    ) -> CGRect {
        let margin: CGFloat = 8
        let gap: CGFloat = 14
        let safeFrame = visibleFrame.insetBy(dx: margin, dy: margin)

        if let avoidedFrame {
            let candidates = [
                CGRect(
                    x: avoidedFrame.maxX + gap,
                    y: avoidedFrame.midY - contentSize.height / 2,
                    width: contentSize.width,
                    height: contentSize.height
                ),
                CGRect(
                    x: avoidedFrame.minX - gap - contentSize.width,
                    y: avoidedFrame.midY - contentSize.height / 2,
                    width: contentSize.width,
                    height: contentSize.height
                ),
                CGRect(
                    x: avoidedFrame.midX - contentSize.width / 2,
                    y: avoidedFrame.minY - gap - contentSize.height,
                    width: contentSize.width,
                    height: contentSize.height
                ),
                CGRect(
                    x: avoidedFrame.midX - contentSize.width / 2,
                    y: avoidedFrame.maxY + gap,
                    width: contentSize.width,
                    height: contentSize.height
                )
            ]

            if let fittingCandidate = candidates.first(where: {
                safeFrame.contains($0) && !$0.intersects(avoidedFrame)
            }) {
                return fittingCandidate
            }

            let clampedCandidates = candidates.map { candidate in
                CGRect(
                    x: min(max(candidate.minX, safeFrame.minX), safeFrame.maxX - contentSize.width),
                    y: min(max(candidate.minY, safeFrame.minY), safeFrame.maxY - contentSize.height),
                    width: contentSize.width,
                    height: contentSize.height
                )
            }
            if let nonOverlappingCandidate = clampedCandidates.first(where: {
                !$0.intersects(avoidedFrame)
            }) {
                return nonOverlappingCandidate
            }
            return clampedCandidates.min(by: {
                intersectionArea($0, avoidedFrame) < intersectionArea($1, avoidedFrame)
            }) ?? CGRect(origin: safeFrame.origin, size: contentSize)
        }

        var originX = pointer.x + gap
        if originX + contentSize.width > safeFrame.maxX {
            originX = pointer.x - gap - contentSize.width
        }

        var originY = pointer.y - gap - contentSize.height
        if originY < safeFrame.minY {
            originY = pointer.y + gap
        }

        originX = min(max(originX, safeFrame.minX), safeFrame.maxX - contentSize.width)
        originY = min(max(originY, safeFrame.minY), safeFrame.maxY - contentSize.height)
        return CGRect(origin: CGPoint(x: originX, y: originY), size: contentSize)
    }

    private func intersectionArea(_ first: CGRect, _ second: CGRect) -> CGFloat {
        let intersection = first.intersection(second)
        guard !intersection.isNull else { return 0 }
        return intersection.width * intersection.height
    }
}
