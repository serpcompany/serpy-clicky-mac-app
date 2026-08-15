public struct EphemeralTranscriptRecovery: Equatable, Sendable {
    public private(set) var transcript: String?

    public init(transcript: String? = nil) {
        self.transcript = transcript?.isEmpty == false ? transcript : nil
    }

    public var isAvailable: Bool {
        transcript != nil
    }

    public mutating func preserve(_ transcript: String) {
        guard !transcript.isEmpty else { return }
        self.transcript = transcript
    }

    public mutating func clear() {
        transcript = nil
    }
}
