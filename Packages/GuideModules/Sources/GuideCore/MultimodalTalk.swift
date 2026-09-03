import CoreGraphics
import Foundation

public enum TalkProviderSelection: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case local
    case openAI

    public var displayName: String {
        switch self {
        case .local: "On-device"
        case .openAI: "OpenAI multimodal"
        }
    }
}

public struct TalkAuthorization: Equatable, Sendable {
    public let selection: TalkProviderSelection
    public let disclosureAccepted: Bool
    public let credentialAvailable: Bool
    public let credentialVerifiedUntil: Date?
    public let credentialMatchesVerification: Bool

    public init(
        selection: TalkProviderSelection,
        disclosureAccepted: Bool,
        credentialAvailable: Bool,
        credentialVerifiedUntil: Date?,
        credentialMatchesVerification: Bool
    ) {
        self.selection = selection
        self.disclosureAccepted = disclosureAccepted
        self.credentialAvailable = credentialAvailable
        self.credentialVerifiedUntil = credentialVerifiedUntil
        self.credentialMatchesVerification = credentialMatchesVerification
    }
}

public struct TalkAuthorizationPolicy: Sendable {
    public init() {}

    public func mayTransmit(_ authorization: TalkAuthorization, now: Date = Date()) -> Bool {
        authorization.selection == .openAI
            && authorization.disclosureAccepted
            && authorization.credentialAvailable
            && authorization.credentialMatchesVerification
            && (authorization.credentialVerifiedUntil.map { $0 > now } ?? false)
    }
}

public protocol TalkCredentialStoring: Sendable {
    func credential() throws -> String?
    func saveCredential(_ credential: String) throws
    func deleteCredential() throws
}

public protocol TalkCredentialVerifying: Sendable {
    /// Returns false only when the provider rejects the credential. Transport
    /// and service failures throw and remain unverified.
    func verifyCredential(_ credential: String) async throws -> Bool
}

public protocol TalkVerificationExpirySleeping: Sendable {
    func sleep(until: Date) async throws
}

public struct SystemTalkVerificationExpirySleeper: TalkVerificationExpirySleeping {
    public init() {}

    public func sleep(until: Date) async throws {
        let interval = until.timeIntervalSinceNow
        guard interval > 0 else { return }
        try await Task.sleep(for: .seconds(interval))
    }
}

public enum TalkCredentialVerificationState: Equatable, Sendable {
    case missing
    case savedUnverified
    case verifying
    case verified(until: Date)
    case verifiedInvalid

    public func isVerified(at date: Date = Date()) -> Bool {
        guard case let .verified(until) = self else { return false }
        return until > date
    }
}

public struct GuideRaster: Equatable, Sendable {
    public let bytes: Data
    public let mimeType: String
    public let pixelWidth: Int
    public let pixelHeight: Int

    public init(bytes: Data, mimeType: String, pixelWidth: Int, pixelHeight: Int) {
        self.bytes = bytes
        self.mimeType = mimeType
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
    }
}

public enum ScreenEvidenceSource: String, Codable, Equatable, Sendable {
    case accessibility
    case ocr
}

public struct ScreenEvidence: Equatable, Sendable {
    public let id: String
    public let text: String
    public let normalizedBounds: CGRect
    public let confidence: Float
    public let source: ScreenEvidenceSource

    public init(id: String, text: String, normalizedBounds: CGRect, confidence: Float, source: ScreenEvidenceSource) {
        self.id = id
        self.text = text
        self.normalizedBounds = normalizedBounds
        self.confidence = confidence
        self.source = source
    }
}

public struct MultimodalGuideRequest: Equatable, Sendable {
    public let question: String
    public let target: GuideWindowTarget
    public let raster: GuideRaster
    public let evidence: [ScreenEvidence]
    public let conversationSummary: String

    public init(question: String, target: GuideWindowTarget, raster: GuideRaster, evidence: [ScreenEvidence], conversationSummary: String) {
        self.question = question
        self.target = target
        self.raster = raster
        self.evidence = evidence
        self.conversationSummary = conversationSummary
    }

    public static func bounded(
        question: String,
        target: GuideWindowTarget,
        raster: GuideRaster,
        evidence: [ScreenEvidence],
        conversation: [GuidanceMessage]
    ) -> Self {
        let summary = conversation.suffix(8).map { message in
            let role = message.role == .user ? "User" : "SERPy"
            return "\(role): \(message.content.prefix(420))"
        }.joined(separator: "\n")
        return Self(
            question: String(question.prefix(2_000)),
            target: target,
            raster: raster,
            evidence: Array(evidence.prefix(160)),
            conversationSummary: String(summary.prefix(4_000))
        )
    }
}

public enum GuidanceSpatialAction: Equatable, Sendable {
    case point(evidenceID: String, normalizedPoint: CGPoint, confidence: Float, label: String?)
    case highlight(evidenceID: String, normalizedRect: CGRect, confidence: Float, label: String?)
    case path(evidenceID: String, normalizedPoints: [CGPoint], confidence: Float, label: String?)
    case label(evidenceID: String, normalizedPoint: CGPoint, confidence: Float, text: String)
}

public struct GuidePointCue: Equatable, Sendable {
    public let target: GuideWindowTarget
    public let normalizedPoint: CGPoint
    public let label: String?

    public init(target: GuideWindowTarget, normalizedPoint: CGPoint, label: String?) {
        self.target = target
        self.normalizedPoint = normalizedPoint
        self.label = label
    }
}

public struct SpatialActionValidator: Sendable {
    public let minimumConfidence: Float

    public init(minimumConfidence: Float = 0.75) {
        self.minimumConfidence = minimumConfidence
    }

    public func validate(_ action: GuidanceSpatialAction, evidenceIDs: Set<String>) -> GuidanceSpatialAction? {
        validate(
            action,
            evidenceBounds: Dictionary(uniqueKeysWithValues: evidenceIDs.map { ($0, CGRect(x: 0, y: 0, width: 1, height: 1)) })
        )
    }

    public func validate(
        _ action: GuidanceSpatialAction,
        evidenceBounds: [String: CGRect]
    ) -> GuidanceSpatialAction? {
        let evidenceID: String
        let confidence: Float
        let geometryIsValid: Bool
        switch action {
        case let .point(id, point, score, _), let .label(id, point, score, _):
            evidenceID = id
            confidence = score
            geometryIsValid = Self.contains(point)
        case let .highlight(id, rect, score, _):
            evidenceID = id
            confidence = score
            geometryIsValid = rect.width > 0 && rect.height > 0
                && rect.minX >= 0 && rect.minY >= 0
                && rect.maxX <= 1 && rect.maxY <= 1
        case let .path(id, points, score, _):
            evidenceID = id
            confidence = score
            geometryIsValid = points.count >= 2 && points.allSatisfy(Self.contains)
        }
        guard let evidenceRect = evidenceBounds[evidenceID],
              confidence >= minimumConfidence,
              geometryIsValid,
              Self.isBound(action, to: evidenceRect)
        else { return nil }
        return action
    }

    private static func contains(_ point: CGPoint) -> Bool {
        (0...1).contains(point.x) && (0...1).contains(point.y)
    }

    private static func isBound(_ action: GuidanceSpatialAction, to evidenceRect: CGRect) -> Bool {
        switch action {
        case let .point(_, point, _, _), let .label(_, point, _, _):
            evidenceRect.contains(point)
        case let .highlight(_, rect, _, _):
            evidenceRect.intersects(rect)
        case let .path(_, points, _, _):
            points.contains(where: evidenceRect.contains)
        }
    }
}

public enum GuidanceStreamEvent: Equatable, Sendable {
    case textDelta(String)
    case sentenceReady(String)
    case spatialAction(GuidanceSpatialAction)
    case completed
}

public protocol GuidanceGenerating: AnyObject, Sendable {
    func stream(_ request: MultimodalGuideRequest) -> AsyncThrowingStream<GuidanceStreamEvent, Error>
    func cancel()
}

@MainActor
public final class TalkGenerationRouter: GuideTurnStreamingGenerating {
    private let local: any GuideTurnGenerating
    private let cloud: any GuidanceGenerating
    private let credentialStore: any TalkCredentialStoring
    private let authorizationPolicy = TalkAuthorizationPolicy()

    public private(set) var selection: TalkProviderSelection
    public private(set) var disclosureAccepted: Bool
    public private(set) var credentialVerifiedUntil: Date?
    private var verifiedCredential: String?

    public init(
        local: any GuideTurnGenerating,
        cloud: any GuidanceGenerating,
        credentialStore: any TalkCredentialStoring,
        selection: TalkProviderSelection = .local,
        disclosureAccepted: Bool = false,
        credentialVerifiedUntil: Date? = nil,
        verifiedCredential: String? = nil
    ) {
        self.local = local
        self.cloud = cloud
        self.credentialStore = credentialStore
        self.selection = selection
        self.disclosureAccepted = disclosureAccepted
        self.credentialVerifiedUntil = credentialVerifiedUntil
        self.verifiedCredential = verifiedCredential
    }

    public var thinkingStatusText: String {
        selection == .openAI ? "Looking at this window with OpenAI…" : "Thinking locally…"
    }

    public func configure(
        selection: TalkProviderSelection,
        disclosureAccepted: Bool,
        credentialVerifiedUntil: Date? = nil,
        verifiedCredential: String? = nil
    ) {
        self.selection = selection
        self.disclosureAccepted = disclosureAccepted
        self.credentialVerifiedUntil = credentialVerifiedUntil
        self.verifiedCredential = verifiedCredential
    }

    public func answer(
        question: String,
        context: ScreenContext,
        conversation: [GuidanceMessage]
    ) async throws -> GuidancePlan {
        guard selection == .local else {
            throw GuideFailure(
                stage: .guidance,
                message: "OpenAI Talk requires the exact locked-window identity.",
                recovery: "Start a new voice question so SERPy can lock and capture the target window."
            )
        }
        return try await local.answer(question: question, context: context, conversation: conversation)
    }

    public func streamAnswer(
        question: String,
        target: GuideWindowTarget,
        context: ScreenContext,
        conversation: [GuidanceMessage]
    ) throws -> AsyncThrowingStream<GuidanceStreamEvent, Error> {
        guard selection == .openAI else {
            return AsyncThrowingStream { [local] continuation in
                let task = Task { @MainActor in
                    do {
                        let plan = try await local.answer(
                            question: question,
                            context: context,
                            conversation: conversation
                        )
                        continuation.yield(.textDelta(plan.answer))
                        continuation.yield(.sentenceReady(plan.answer))
                        continuation.yield(.completed)
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }
                continuation.onTermination = { _ in task.cancel() }
            }
        }

        let currentCredential = try? credentialStore.credential()
        let credentialAvailable = currentCredential?.isEmpty == false
        guard authorizationPolicy.mayTransmit(.init(
            selection: selection,
            disclosureAccepted: disclosureAccepted,
            credentialAvailable: credentialAvailable,
            credentialVerifiedUntil: credentialVerifiedUntil,
            credentialMatchesVerification: currentCredential != nil && currentCredential == verifiedCredential
        )) else {
            throw GuideFailure(
                stage: .guidance,
                message: "OpenAI Talk is not ready to send this question.",
                recovery: "In SERPy Settings, select OpenAI, accept the disclosure, save a tester-owned key, and choose Verify Provider."
            )
        }
        guard let raster = context.raster else {
            throw GuideFailure(
                stage: .capture,
                message: "The exact locked window did not produce screenshot pixels.",
                recovery: "Check Screen Recording permission, bring the target window forward, and try again."
            )
        }
        return cloud.stream(.bounded(
            question: question,
            target: target,
            raster: raster,
            evidence: [],
            conversation: conversation
        ))
    }

    public func cancelGeneration() {
        cloud.cancel()
    }
}

public struct SentenceChunker: Sendable {
    private var buffer = ""

    public init() {}

    public mutating func append(_ delta: String) -> [String] {
        buffer += delta
        var chunks: [String] = []
        while let boundary = buffer.firstIndex(where: { ".!?\n".contains($0) }) {
            let end = buffer.index(after: boundary)
            let sentence = String(buffer[..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
            buffer.removeSubrange(..<end)
            if !sentence.isEmpty { chunks.append(sentence) }
        }
        return chunks
    }

    public mutating func finish() -> String? {
        let remainder = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
        buffer = ""
        return remainder.isEmpty ? nil : remainder
    }
}
