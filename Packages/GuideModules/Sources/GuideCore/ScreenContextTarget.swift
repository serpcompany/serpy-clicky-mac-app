public struct ScreenContextTargetPolicy: Sendable {
    public init() {}

    public func targetProcessIdentifier(
        remembered: Int32?,
        frontmost: Int32?,
        own: Int32
    ) -> Int32? {
        if let remembered, remembered != own {
            return remembered
        }
        if let frontmost, frontmost != own {
            return frontmost
        }
        return nil
    }
}

public struct ExactWindowTargetPolicy: Sendable {
    public init() {}

    public func lockTarget(
        frontToBack candidates: [GuideWindowTarget],
        processIdentifier: Int32
    ) throws -> GuideWindowTarget {
        guard let target = candidates.first(where: {
            $0.processIdentifier == processIdentifier && $0.frame.width > 160 && $0.frame.height > 100
        }) else {
            throw missingTargetFailure
        }
        return target
    }

    public func resolveExactTarget(
        _ locked: GuideWindowTarget,
        available candidates: [GuideWindowTarget]
    ) throws -> GuideWindowTarget {
        guard let exact = candidates.first(where: {
            $0.processIdentifier == locked.processIdentifier &&
                $0.windowIdentifier == locked.windowIdentifier
        }) else {
            throw missingTargetFailure
        }
        return exact
    }

    private var missingTargetFailure: GuideFailure {
        GuideFailure(
            stage: .capture,
            message: "The window selected when the guide started is no longer available.",
            recovery: "Bring that exact window forward and start the voice guide again."
        )
    }
}
