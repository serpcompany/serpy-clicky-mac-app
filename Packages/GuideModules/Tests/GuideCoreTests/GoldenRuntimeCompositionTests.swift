import Testing
@testable import GuideTestSupport

@Suite("Golden runtime composition")
struct GoldenRuntimeCompositionTests {
    @Test("GT-UF00-001 UI runtime is selected before composition")
    func uiRuntimeSelection() {
        let runtime = AppRuntimeMode.resolve(arguments: ["serpy", "--ui-testing"])

        #expect(runtime == .uiTest)
        #expect(runtime.capabilities == [.deterministicFixtures, .ephemeralStorage])
    }

    @Test("GT-UF00-002 UI runtime rejects production capabilities")
    func uiRuntimeRejectsProductionCapabilities() {
        let forbidden: Set<AppRuntimeCapability> = [
            .microphone,
            .permissionRequests,
            .productionKeychain,
            .persistentUserData,
            .screenRecording,
            .sentryTransport,
            .networkProvider,
            .globalShortcuts,
        ]

        #expect(AppRuntimeMode.uiTest.capabilities.isDisjoint(with: forbidden))
    }

    @Test("GT-UF00-003 Production runtime is the default")
    func productionIsDefault() {
        #expect(AppRuntimeMode.resolve(arguments: ["serpy"]) == .production)
        #expect(AppRuntimeMode.production.capabilities.contains(.microphone))
        #expect(AppRuntimeMode.production.capabilities.contains(.productionKeychain))
    }
}
