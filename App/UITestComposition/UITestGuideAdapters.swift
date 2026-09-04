import AppKit
import Foundation
import GuideCore
import GuideMac
import GuideUI

final class UITestScreenContextService: AppScreenContextServicing, DeterministicUITestAdapter, @unchecked Sendable {
    @MainActor private var captureCount = 0
    private let block: Bool
    private let stepwise: Bool
    private let sessionRoot: URL
    init(block: Bool, stepwise: Bool, sessionRoot: URL) {
        self.block = block
        self.stepwise = stepwise
        self.sessionRoot = sessionRoot
    }
    @MainActor func rememberFrontmostApplication() {}
    @MainActor func snapshotTarget() throws -> GuideWindowTarget {
        GuideWindowTarget(
            processIdentifier: Int32(ProcessInfo.processInfo.processIdentifier),
            windowIdentifier: 1,
            applicationName: "Fixture Browser",
            windowTitle: "Fixture Window",
            frame: CGRect(x: 200, y: 200, width: 900, height: 700)
        )
    }
    func capture(_ target: GuideWindowTarget) async throws -> ScreenContext {
        if block { try await Task.sleep(for: .seconds(3_600)) }
        if stepwise { try await waitForUITestRelease(sessionRoot.appendingPathComponent("capture.release")) }
        let count = await MainActor.run { captureCount += 1; return captureCount }
        let visible = switch count {
        case 2: "Unchanged fixture"
        case 3: "File menu open"
        case 4...: "New Window visible"
        default: "File New Window"
        }
        return ScreenContext(
            applicationName: target.applicationName,
            windowTitle: target.windowTitle,
            windowFrame: target.frame,
            textBlocks: [.init(text: visible, normalizedBounds: CGRect(x: 0.1, y: 0.1, width: 0.3, height: 0.1), confidence: 1)],
            raster: GuideRaster(bytes: Data("png".utf8), mimeType: "image/png", pixelWidth: 2, pixelHeight: 2)
        )
    }
}

@MainActor
final class UITestGuideTranscriber: AppGuideTranscribing, DeterministicUITestAdapter {
    var isOnDeviceAvailable: Bool { true }
    func start(onPartial: @escaping @MainActor @Sendable (String) -> Void) throws { onPartial("Open a new window") }
    func stop() async throws -> String { "Open a new window" }
    func cancel() {}
}

@MainActor
final class UITestGuideGenerator: GuideTurnGenerating, DeterministicUITestAdapter {
    private let malformed: Bool
    private let block: Bool
    private let stepwise: Bool
    private let sessionRoot: URL
    init(arguments: [String], sessionRoot: URL) {
        malformed = arguments.contains("--inject-guide-failure")
            || arguments.contains("--golden-flow=UF-12")
        block = arguments.contains("--block-guide-generation")
        stepwise = arguments.contains("--stepwise-guide")
        self.sessionRoot = sessionRoot
    }
    func answer(question: String, context: ScreenContext, conversation: [GuidanceMessage]) async throws -> GuidancePlan {
        if malformed { throw GuideFailure.malformedGuidance(provider: .local) }
        if block { try await Task.sleep(for: .seconds(3_600)) }
        if stepwise { try await waitForUITestRelease(sessionRoot.appendingPathComponent("generation.release")) }
        return GuidancePlan(
            answer: "Open the File menu, then choose New Window.",
            confidence: 1,
            steps: [
                GuidanceStep(id: 1, text: "Open the File menu.", completionEvidence: ["File menu open"]),
                GuidanceStep(id: 2, text: "Choose New Window.", completionEvidence: ["New Window visible"]),
            ]
        )
    }
}

@MainActor
final class UITestGuideSpeaker: GuideTurnSpeaking, DeterministicUITestAdapter {
    private let block: Bool
    private let stepwise: Bool
    private let sessionRoot: URL
    init(block: Bool, stepwise: Bool, sessionRoot: URL) {
        self.block = block
        self.stepwise = stepwise
        self.sessionRoot = sessionRoot
    }
    func speak(_ text: String) async throws {
        if block { try await Task.sleep(for: .seconds(3_600)) }
        if stepwise { try await waitForUITestRelease(sessionRoot.appendingPathComponent("speech.release")) }
    }
    func stop() {}
}

@MainActor
final class UITestLocalModelProvider: LocalGuidanceModelProvider, DeterministicUITestAdapter {
    var availability: LocalGuidanceAvailability { .available }
    func makeSession(instructions: String) throws -> any LocalGuidanceModelSession { UITestLocalModelSession() }
}

@MainActor
private final class UITestLocalModelSession: LocalGuidanceModelSession {
    func respond(to prompt: String) async throws -> String { "{\"answer\":\"Fixture\",\"steps\":[]}" }
}

private func waitForUITestRelease(_ url: URL) async throws {
    for _ in 0..<100 {
        try Task.checkCancellation()
        if FileManager.default.fileExists(atPath: url.path) { return }
        try await Task.sleep(for: .milliseconds(50))
    }
    throw GuideFailure(
        stage: .presentation,
        message: "The deterministic UI fixture timed out.",
        recovery: "Fix the test driver release signal."
    )
}
