import Foundation

public enum TranscriptDeliveryState: String, Codable, Equatable, Sendable {
    case pending
    case confirmed
    case unconfirmed
    case failed
}

public struct TranscriptHistoryEntry: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let createdAt: Date
    public let text: String
    public var targetBundleIdentifier: String?
    public var deliveryState: TranscriptDeliveryState
    public var deliveryMethod: String?
    public var audioFilename: String?
    public var retainedInHistory: Bool
    public var expiresAt: Date

    public init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        text: String,
        targetBundleIdentifier: String? = nil,
        deliveryState: TranscriptDeliveryState = .pending,
        deliveryMethod: String? = nil,
        audioFilename: String? = nil,
        retainedInHistory: Bool,
        expiresAt: Date
    ) {
        self.id = id
        self.createdAt = createdAt
        self.text = text
        self.targetBundleIdentifier = targetBundleIdentifier
        self.deliveryState = deliveryState
        self.deliveryMethod = deliveryMethod
        self.audioFilename = audioFilename
        self.retainedInHistory = retainedInHistory
        self.expiresAt = expiresAt
    }
}
