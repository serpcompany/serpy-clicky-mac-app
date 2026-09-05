import Foundation

#if canImport(FoundationModels)
import FoundationModels

/// The local model generates this schema, never an unconstrained JSON string.
/// Encoding preserves the existing provider boundary and downstream validation.
@available(macOS 26.0, *)
@Generable
struct FoundationGuidanceResponse: Codable {
    @Guide(description: "A concise, grounded answer for the current application. No JSON or narrated punctuation.")
    var answer: String

    @Guide(description: "Ordered user-performed steps. Use at least two for a walkthrough; never invent a control absent from the evidence.", .count(1...6))
    var steps: [FoundationGuidanceStep]

    func encodedPlan() throws -> String {
        String(decoding: try JSONEncoder().encode(self), as: UTF8.self)
    }
}

@available(macOS 26.0, *)
@Generable
struct FoundationGuidanceStep: Codable {
    @Guide(description: "One action on an exact control named in the supplied evidence. Follow the user's requested route; for a menu walkthrough name the menu or item to click, not invented keyboard shortcuts. The user performs the action.")
    var text: String

    @Guide(description: "Exact literal UI labels visible after this action, such as New Window or New Tab. Copy labels from the supplied evidence. Never use descriptions like menu appears or window opens.", .count(1...4))
    var completionEvidence: [String]
}
#endif
