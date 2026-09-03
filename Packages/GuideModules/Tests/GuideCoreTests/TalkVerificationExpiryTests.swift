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
            talkGenerator: router,
            shortcutMonitorFactory: { _, _ in ExpiryNoopShortcutMonitor() }
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

    func testFailedKeychainSaveKeepsPriorVerificationExpiryScheduled() async throws {
        let fixture = makeFixture()
        await fixture.model.testSavedTalkCredential()
        XCTAssertTrue(fixture.model.openAITalkReady)
        await fixture.sleeper.waitUntilScheduled()
        fixture.store.failSave = true
        fixture.model.talkCredentialDraft = "replacement-key-value-long-enough"

        fixture.model.saveTalkCredential()
        await fixture.sleeper.fire()
        for _ in 0..<1_000 where fixture.model.talkCredentialVerification.isVerified() {
            await Task.yield()
        }

        XCTAssertEqual(fixture.model.talkCredentialVerification, .savedUnverified)
        XCTAssertFalse(fixture.model.openAITalkReady)
    }

    func testFailedKeychainDeleteKeepsPriorVerificationExpiryScheduled() async throws {
        let fixture = makeFixture()
        await fixture.model.testSavedTalkCredential()
        XCTAssertTrue(fixture.model.openAITalkReady)
        await fixture.sleeper.waitUntilScheduled()
        fixture.store.failDelete = true

        fixture.model.deleteTalkCredential()
        await fixture.sleeper.fire()
        for _ in 0..<1_000 where fixture.model.talkCredentialVerification.isVerified() {
            await Task.yield()
        }

        XCTAssertEqual(fixture.model.talkCredentialVerification, .savedUnverified)
        XCTAssertFalse(fixture.model.openAITalkReady)
    }

    private func makeFixture() -> (model: GuideAppModel, sleeper: ManualTalkExpirySleeper, store: ExpiryMemoryCredentialStore) {
        let defaults = UserDefaults(suiteName: "SERPy.TalkExpiry.\(UUID().uuidString)")!
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
            talkGenerator: router,
            shortcutMonitorFactory: { _, _ in ExpiryNoopShortcutMonitor() }
        )
        model.talkProviderSelection = .openAI
        model.talkDisclosureAccepted = true
        return (model, sleeper, store)
    }
}

private final class ExpiryMemoryCredentialStore: TalkCredentialStoring, @unchecked Sendable {
    private var value: String?
    var failSave = false
    var failDelete = false

    init(value: String?) { self.value = value }
    func credential() throws -> String? { value }
    func saveCredential(_ credential: String) throws {
        if failSave { throw ExpiryFixtureFailure() }
        value = credential
    }
    func deleteCredential() throws {
        if failDelete { throw ExpiryFixtureFailure() }
        value = nil
    }
}

private struct ExpiryFixtureFailure: Error {}

@MainActor
private final class ExpiryNoopShortcutMonitor: GlobalShortcutMonitoring {
    func start() throws {}
    func stop() {}
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
