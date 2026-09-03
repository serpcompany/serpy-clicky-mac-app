import CoreGraphics
import Foundation
import GuideCore
import XCTest

final class MultimodalTalkContractTests: XCTestCase {
    func testCloudTalkRequiresSelectionConsentAndCredential() {
        let policy = TalkAuthorizationPolicy()
        let now = Date(timeIntervalSince1970: 1_000)
        let validUntil = now.addingTimeInterval(900)

        XCTAssertFalse(policy.mayTransmit(.init(selection: .local, disclosureAccepted: true, credentialAvailable: true, credentialVerifiedUntil: validUntil, credentialMatchesVerification: true), now: now))
        XCTAssertFalse(policy.mayTransmit(.init(selection: .openAI, disclosureAccepted: false, credentialAvailable: true, credentialVerifiedUntil: validUntil, credentialMatchesVerification: true), now: now))
        XCTAssertFalse(policy.mayTransmit(.init(selection: .openAI, disclosureAccepted: true, credentialAvailable: false, credentialVerifiedUntil: validUntil, credentialMatchesVerification: true), now: now))
        XCTAssertFalse(policy.mayTransmit(.init(selection: .openAI, disclosureAccepted: true, credentialAvailable: true, credentialVerifiedUntil: nil, credentialMatchesVerification: true), now: now))
        XCTAssertFalse(policy.mayTransmit(.init(selection: .openAI, disclosureAccepted: true, credentialAvailable: true, credentialVerifiedUntil: now, credentialMatchesVerification: true), now: now))
        XCTAssertFalse(policy.mayTransmit(.init(selection: .openAI, disclosureAccepted: true, credentialAvailable: true, credentialVerifiedUntil: validUntil, credentialMatchesVerification: false), now: now))
        XCTAssertTrue(policy.mayTransmit(.init(selection: .openAI, disclosureAccepted: true, credentialAvailable: true, credentialVerifiedUntil: validUntil, credentialMatchesVerification: true), now: now))
    }

    func testRequestPreservesRasterEvidenceAndBoundsConversation() {
        let target = GuideWindowTarget(
            processIdentifier: 10,
            windowIdentifier: 20,
            applicationName: "TextEdit",
            windowTitle: "Fixture",
            frame: CGRect(x: 50, y: 60, width: 800, height: 600)
        )
        let raster = GuideRaster(
            bytes: Data([0x89, 0x50, 0x4E, 0x47]),
            mimeType: "image/png",
            pixelWidth: 1600,
            pixelHeight: 1200
        )
        let evidence = ScreenEvidence(
            id: "ocr-1",
            text: "ORCHID RIVER 731",
            normalizedBounds: CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.1),
            confidence: 0.99,
            source: .ocr
        )
        let conversation = (0..<20).map {
            GuidanceMessage(role: $0.isMultiple(of: 2) ? .user : .guide, content: String(repeating: "x", count: 900))
        }

        let request = MultimodalGuideRequest.bounded(
            question: "What phrase is visible?",
            target: target,
            raster: raster,
            evidence: [evidence],
            conversation: conversation
        )

        XCTAssertEqual(request.raster, raster)
        XCTAssertEqual(request.evidence, [evidence])
        XCTAssertEqual(request.target.windowIdentifier, 20)
        XCTAssertLessThanOrEqual(request.conversationSummary.count, 4_000)
        XCTAssertFalse(request.conversationSummary.contains(String(repeating: "x", count: 900)))
    }

    func testSpatialActionRequiresKnownEvidenceAndLockedNormalizedBounds() {
        let validator = SpatialActionValidator(minimumConfidence: 0.75)
        let known = ["ocr-1": CGRect(x: 0.4, y: 0.3, width: 0.2, height: 0.2)]
        let valid = GuidanceSpatialAction.point(
            evidenceID: "ocr-1",
            normalizedPoint: CGPoint(x: 0.5, y: 0.4),
            confidence: 0.9,
            label: "Continue"
        )

        XCTAssertEqual(validator.validate(valid, evidenceBounds: known), valid)
        XCTAssertNil(validator.validate(.point(evidenceID: "missing", normalizedPoint: CGPoint(x: 0.5, y: 0.4), confidence: 0.9, label: nil), evidenceBounds: known))
        XCTAssertNil(validator.validate(.point(evidenceID: "ocr-1", normalizedPoint: CGPoint(x: 1.2, y: 0.4), confidence: 0.9, label: nil), evidenceBounds: known))
        XCTAssertNil(validator.validate(.point(evidenceID: "ocr-1", normalizedPoint: CGPoint(x: 0.8, y: 0.8), confidence: 0.9, label: nil), evidenceBounds: known))
        XCTAssertNil(validator.validate(.point(evidenceID: "ocr-1", normalizedPoint: CGPoint(x: 0.5, y: 0.4), confidence: 0.7, label: nil), evidenceBounds: known))
    }
}
