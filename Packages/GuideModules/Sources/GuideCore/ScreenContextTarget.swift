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
