import Foundation

public struct GuideProgressionObservation: Equatable, Sendable {
    public let visibleText: String
    public let baselineVisibleText: String?

    public init(visibleText: String, baselineVisibleText: String? = nil) {
        self.visibleText = visibleText
        self.baselineVisibleText = baselineVisibleText
    }
}

public enum GuideProgressionDecision: Equatable, Sendable {
    case advance(to: Int)
    case stay(reason: String)
    case complete
}

/// Pure policy evaluated only after an explicit Guide invocation and fresh
/// request-scoped capture. It observes; it never performs or schedules work.
public struct GuideProgressionPolicy: Sendable {
    public init() {}

    public func evaluate(
        plan: GuidancePlan,
        activeStepIndex: Int,
        observation: GuideProgressionObservation
    ) -> GuideProgressionDecision {
        guard plan.steps.indices.contains(activeStepIndex) else {
            return .stay(reason: "The current Guide step is unavailable. Start a new walkthrough.")
        }
        let step = plan.steps[activeStepIndex]
        guard !step.completionEvidence.isEmpty else {
            return .stay(reason: "Step \(activeStepIndex + 1) needs clearer on-screen evidence before SERPy can advance.")
        }
        let haystack = observation.visibleText.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: .current
        )
        let satisfied = step.completionEvidence.allSatisfy { evidence in
            let needle = evidence.folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: .current
            )
            return !needle.isEmpty && haystack.contains(needle)
        }
        guard satisfied else {
            return .stay(reason: "The expected result for Step \(activeStepIndex + 1) is not visible yet.")
        }
        if let baseline = observation.baselineVisibleText {
            let prior = baseline.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            let alreadySatisfied = step.completionEvidence.allSatisfy {
                prior.contains($0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current))
            }
            guard !alreadySatisfied else {
                return .stay(reason: "These labels were already visible before this step. Press Escape and ask for a walkthrough with clearer completion evidence.")
            }
        }
        return activeStepIndex == plan.steps.count - 1
            ? .complete
            : .advance(to: activeStepIndex + 1)
    }
}
