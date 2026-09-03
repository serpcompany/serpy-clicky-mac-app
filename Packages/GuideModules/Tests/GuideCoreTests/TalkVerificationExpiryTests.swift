import Foundation
import GuideCore
import GuideMac
import GuideUI
import XCTest

@MainActor
final class TalkVerificationExpiryTests: XCTestCase {
    func testVerificationExpiryRevokesReadyStateAndPublishesRecovery() async throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "SERPy.TalkExpiry.\(UUID().uuidString)"))
        let store = ExpiryMemoryCredentialStore(value: "tester-key-value-long-enough")
        let sleeper = ManualTalkExpirySleeper()
        let local = LocalGuidanceService()
        let router = TalkGenerationRouter(
            local: local,
            cloud: ExpiryNoopGuidanceGenerator(),
            credentialStore: store
        )
        let model = GuideAppModel(
            defaults: defaults,
            localGuidanceService: local,
            talkCredentialStore: store,
            talkCredentialVerifier: AlwaysValidCredentialVerifier(),
            talkVerificationExpirySleeper: sleeper,
            talkGenerator: router
        )
        model.talkProviderSelection = .openAI
        model.talkDisclosureAccepted = true

        await model.testSavedTalkCredential()
        XCTAssertTrue(model.openAITalkReady)
        await sleeper.waitUntilScheduled()
        await sleeper.fire()
        for _ in 0..<1_000 where model.talkCredentialVerification.isVerified() {
            await Task.yield()
        }

        XCTAssertEqual(model.talkCredentialVerification, .savedUnverified)
        XCTAssertFalse(model.openAITalkReady)
        XCTAssertTrue(model.talkCredentialStatus.contains("expired"))
    }
}

private final class ExpiryMemoryCredentialStore: TalkCredentialStoring, @unchecked Sendable {
    private var value: String?

    init(value: String?) { self.value = value }
    func credential() throws -> String? { value }
    func saveCredential(_ credential: String) throws { value = credential }
    func deleteCredential() throws { value = nil }
}

private struct AlwaysValidCredentialVerifier: TalkCredentialVerifying {
    func verifyCredential(_ credential: String) async throws -> Bool { true }
}

private actor ManualTalkExpirySleeper: TalkVerificationExpirySleeping {
    private var continuation: CheckedContinuation<Void, Error>?

    func sleep(until: Date) async throws {
        try await withCheckedThrowingContinuation { continuation = $0 }
    }

    func waitUntilScheduled() async {
        while continuation == nil { await Task.yield() }
    }

    func fire() {
        continuation?.resume()
        continuation = nil
    }
}

private final class ExpiryNoopGuidanceGenerator: GuidanceGenerating, @unchecked Sendable {
    func stream(_ request: MultimodalGuideRequest) -> AsyncThrowingStream<GuidanceStreamEvent, Error> {
        AsyncThrowingStream { $0.finish() }
    }
    func cancel() {}
}
