import GuideCore
import XCTest

final class DiagnosticIncidentTests: XCTestCase {
    func testMalformedGuidanceFailureProducesOnlyAllowlistedClassification() throws {
        let forbiddenQuestion = "SECRET-QUESTION-ORCHID-731"
        let forbiddenResponse = "SECRET-RESPONSE-RIVER-924"
        let failure = GuideFailure(
            stage: .guidance,
            code: .guidancePlanMalformed,
            provider: .local,
            message: "The local guide failed after \(forbiddenQuestion)",
            recovery: "Do not include \(forbiddenResponse)"
        )

        let incident = DiagnosticIncident(failure: failure)

        XCTAssertEqual(incident.code, .guidancePlanMalformed)
        XCTAssertEqual(incident.stage, .guidance)
        XCTAssertEqual(incident.provider, .local)
        let serialized = try JSONEncoder().encode(incident)
        let rendered = String(decoding: serialized, as: UTF8.self)
        XCTAssertFalse(rendered.contains(forbiddenQuestion))
        XCTAssertFalse(rendered.contains(forbiddenResponse))
        XCTAssertFalse(rendered.contains("message"))
        XCTAssertFalse(rendered.contains("recovery"))
    }
}
