/// Reconciles transcripts produced from overlapping audio chunks by removing
/// the largest exact word suffix/prefix shared at the boundary.
public struct TranscriptOverlapReconciler: Sendable {
    public init() {}

    public func appending(_ existing: String, next: String) -> String {
        let left = existing.split(whereSeparator: \.isWhitespace).map(String.init)
        let right = next.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !left.isEmpty else { return right.joined(separator: " ") }
        guard !right.isEmpty else { return left.joined(separator: " ") }

        let maximum = min(left.count, right.count)
        let overlap = stride(from: maximum, through: 1, by: -1).first { count in
            Array(left.suffix(count)) == Array(right.prefix(count))
        } ?? 0
        return (left + right.dropFirst(overlap)).joined(separator: " ")
    }
}
