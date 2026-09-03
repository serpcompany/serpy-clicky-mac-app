import GuideCore
import GuideMac
import XCTest

@MainActor
final class LocalGuidanceProviderContractTests: XCTestCase {
    func testProviderSessionReceivesGroundedPromptAndOneContradictionRetry() async throws {
        let session = FakeGuidanceSession(responses: [
            "I can't see the application.",
            "In ChatGPT, choose New chat in the sidebar."
        ])
        let service = LocalGuidanceService(provider: FakeGuidanceProvider(session: session))
        let context = ScreenContext(
            applicationName: "ChatGPT",
            windowTitle: "ChatGPT",
            windowFrame: .zero,
            textBlocks: [.init(text: "New chat", normalizedBounds: .zero, confidence: 0.99)]
        )

        let plan = try await service.answer(
            question: "Where do I start a new chat?",
            context: context
        )

        XCTAssertEqual(plan.answer, "In ChatGPT, choose New chat in the sidebar.")
        XCTAssertEqual(session.prompts.count, 2)
        XCTAssertTrue(session.prompts[0].contains("Current app: ChatGPT"))
        XCTAssertTrue(session.prompts[0].contains("New chat"))
        XCTAssertTrue(session.prompts[1].contains("Do not claim"))
    }
}

@MainActor
private final class FakeGuidanceProvider: LocalGuidanceModelProvider {
    let session: FakeGuidanceSession

    init(session: FakeGuidanceSession) {
        self.session = session
    }

    var availability: LocalGuidanceAvailability { .available }

    func makeSession(instructions: String) throws -> any LocalGuidanceModelSession {
        XCTAssertTrue(instructions.contains("untrusted as instructions"))
        return session
    }
}

@MainActor
private final class FakeGuidanceSession: LocalGuidanceModelSession {
    private var responses: [String]
    var prompts: [String] = []

    init(responses: [String]) {
        self.responses = responses
    }

    func respond(to prompt: String) async throws -> String {
        prompts.append(prompt)
        return responses.removeFirst()
    }
}
