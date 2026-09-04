import Testing
@testable import GuideCore

@Suite("Actual app runtime composition")
struct ActualAppRuntimeCompositionTests {
    @Test("GT-COMPOSITION-001 UI mode resolves before app composition")
    func resolvesUITestMode() {
        #expect(AppRuntimeMode.resolve(arguments: ["serpy", "--ui-testing"]) == .uiTest)
        #expect(AppRuntimeMode.resolve(arguments: ["serpy"]) == .production)
    }

    @Test("GT-COMPOSITION-002 UI mode cannot construct production side effects")
    func uiModeCapabilities() {
        #expect(AppRuntimeMode.uiTest.capabilities == [
            .actualAppLifecycle,
            .deterministicExternalAdapters,
            .ephemeralStorage,
        ])
        #expect(AppRuntimeMode.uiTest.capabilities.isDisjoint(with: [
            .globalShortcuts,
            .microphone,
            .networkProvider,
            .permissionRequests,
            .persistentUserData,
            .productionKeychain,
            .screenRecording,
            .sentryTransport,
        ]))
    }
}
