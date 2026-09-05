import Foundation
@testable import GuideMac
import Testing

#if canImport(FoundationModels)
import FoundationModels

struct FoundationGuidanceSchemaTests {
    @Test("typed local guidance encodes exact plan keys and preserves punctuation")
    func encodesPlan() throws {
        guard #available(macOS 26.0, *) else { return }
        let response = FoundationGuidanceResponse(
            answer: "Open the \"File\" menu.",
            steps: [.init(text: "Choose File.", completionEvidence: ["New Window"]),
                    .init(text: "Choose New Window.", completionEvidence: ["New Tab"])])
        let raw = try response.encodedPlan()
        let object = try #require(JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any])
        #expect(object["answer"] as? String == response.answer)
        let steps = try #require(object["steps"] as? [[String: Any]])
        #expect(steps.count == 2)
        #expect(steps[0]["completionEvidence"] as? [String] == ["New Window"])
        // Compiles the same Foundation Models schema used by the real adapter.
        _ = FoundationGuidanceResponse.generationSchema
    }
}
#endif
