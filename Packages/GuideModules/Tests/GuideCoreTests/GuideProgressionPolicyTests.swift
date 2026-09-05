import GuideCore
import Testing

@Suite("Explicit Guide progression")
struct GuideProgressionPolicyTests {
    @Test("preexisting completion labels do not prove a step happened")
    func preexistingLabelCannotAdvance() {
        let plan = GuidancePlan(answer: "Open File", confidence: 0.9, steps: [
            GuidanceStep(id: 1, text: "Open File", completionEvidence: ["File"]),
            GuidanceStep(id: 2, text: "Choose New Window", completionEvidence: ["New Tab"])
        ])
        let result = GuideProgressionPolicy().evaluate(plan: plan, activeStepIndex: 0,
            observation: .init(visibleText: "File Edit View", baselineVisibleText: "File Edit View"))
        guard case .stay = result else {
            Issue.record("An unchanged menu label incorrectly advanced the walkthrough")
            return
        }
    }

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

    @Test("malformed, one-step, and out-of-bounds walkthroughs are rejected")
    func planContractRejectsIncompleteOutput() {
        let validator = GuidancePlanContractValidator()
        #expect(throws: GuideFailure.self) {
            try validator.validate(GuidancePlan(
                answer: "Too short",
                confidence: 0.9,
                steps: [GuidanceStep(id: 1, text: "Only step")]
            ))
        }
        #expect(throws: GuideFailure.self) {
            try validator.validate(GuidancePlan(
                answer: "Bad point",
                confidence: 0.9,
                steps: [
                    GuidanceStep(id: 1, text: "First", point: .init(normalizedPoint: .init(x: 2, y: 0.5), confidence: 0.9)),
                    GuidanceStep(id: 2, text: "Second")
                ]
            ))
        }
    }
}
