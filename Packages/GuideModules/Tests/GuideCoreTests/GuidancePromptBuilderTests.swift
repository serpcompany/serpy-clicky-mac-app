import GuideCore
import XCTest

final class GuidancePromptBuilderTests: XCTestCase {
    func testControlledOCRScenariosProduceGroundedUntrustedContextPrompts() throws {
        let data = try Data(contentsOf: Bundle.module.url(
            forResource: "GroundingScenarios",
            withExtension: "json"
        )!)
        let scenarios = try JSONDecoder().decode([GroundingScenario].self, from: data)
        let builder = GuidancePromptBuilder()

        XCTAssertEqual(scenarios.map(\.name), ["chatgpt", "unique-phrase"])
        for scenario in scenarios {
            let context = ScreenContext(
                applicationName: scenario.application,
                windowTitle: scenario.window,
                windowFrame: .zero,
                textBlocks: [.init(text: scenario.visibleText, normalizedBounds: .zero, confidence: 0.99)]
            )
            let prompt = builder.prompt(
                question: scenario.question,
                context: context,
                conversation: []
            )

            XCTAssertTrue(prompt.contains("Current app: \(scenario.application)"))
            XCTAssertTrue(prompt.contains("Current window: \(scenario.window)"))
            XCTAssertTrue(prompt.contains(scenario.visibleText))
            XCTAssertTrue(prompt.contains("untrusted screen data"))
        }
    }

    func testContradictoryChatGPTAnswerGetsGroundedRecovery() {
        let policy = GuidanceAnswerGroundingPolicy()
        let context = ScreenContextIdentity(applicationName: "ChatGPT", windowTitle: "ChatGPT")

        XCTAssertEqual(
            policy.disposition(
                for: "I can't see the application.",
                context: context,
                hasVisibleText: true
            ),
            .retryWithGroundedContext
        )
        XCTAssertEqual(
            policy.resolvedAnswer(
                initial: "I can't see the application.",
                retry: "In ChatGPT, choose New chat in the sidebar.",
                context: context,
                hasVisibleText: true
            ),
            "In ChatGPT, choose New chat in the sidebar."
        )
    }

    func testSpokenAnswerBudgetKeepsTheDisplayedAnswerAtFiftyFiveWords() {
        let source = (1...70).map { "word\($0)" }.joined(separator: " ")

        let bounded = GuidanceAnswerBudget(maxWords: 55).bounded(source)

        XCTAssertEqual(bounded.split(whereSeparator: \.isWhitespace).count, 55)
        XCTAssertTrue(bounded.hasSuffix("…"))
    }

    func testReadableResponseRemainsStationaryUntilDismissed() {
        let policy = CompanionResponseAnchorPolicy()
        let current = CGRect(x: 100, y: 120, width: 380, height: 140)
        let pointerMovedProposal = CGRect(x: 500, y: 420, width: 380, height: 140)

        XCTAssertEqual(
            policy.frame(current: current, proposed: pointerMovedProposal, responseIsVisible: true),
            current
        )
        XCTAssertEqual(
            policy.frame(current: nil, proposed: pointerMovedProposal, responseIsVisible: false),
            pointerMovedProposal
        )
    }

    func testLiveTranscriptPreviewIsBoundedAndKeepsTheNewestWords() {
        let preview = GuidanceLiveTranscriptPreview(maxCharacters: 24)

        let text = preview.displayText(for: "old words that can leave\nnewest useful words")

        XCTAssertLessThanOrEqual(text.count, 24)
        XCTAssertTrue(text.hasPrefix("…"))
        XCTAssertTrue(text.hasSuffix("newest useful words"))
        XCTAssertFalse(text.contains("\n"))
    }
}

private struct GroundingScenario: Decodable {
    let name: String
    let application: String
    let window: String
    let question: String
    let visibleText: String
}
