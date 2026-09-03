import GuideCore
import Testing

@Suite("Explicit Guide progression")
struct GuideProgressionPolicyTests {
    private let plan = GuidancePlan(
        answer: "Open a new Chrome window.",
        confidence: 0.9,
        steps: [
            GuidanceStep(id: 1, text: "Open File.", completionEvidence: ["New Window"]),
            GuidanceStep(id: 2, text: "Choose New Window.", completionEvidence: ["New Tab"])
        ]
    )

    @Test("fresh request-scoped evidence advances, stays, or completes exactly")
    func explicitObservationControlsProgress() {
        let policy = GuideProgressionPolicy()

        #expect(policy.evaluate(plan: plan, activeStepIndex: 0, observation: .init(visibleText: "File  New Window  Open Location")) == .advance(to: 1))
        #expect(policy.evaluate(plan: plan, activeStepIndex: 0, observation: .init(visibleText: "Chrome new tab")) == .stay(reason: "The expected result for Step 1 is not visible yet."))
        #expect(policy.evaluate(plan: plan, activeStepIndex: 1, observation: .init(visibleText: "New Tab  History")) == .complete)
    }
}
