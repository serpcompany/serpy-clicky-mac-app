import Testing
@testable import GuideTestSupport

@Suite("Golden runtime composition")
struct GoldenRuntimeCompositionTests {
    @Test("GT-UF00-001 UI runtime is selected before composition")
    func uiRuntimeSelection() throws {
        let runtime = try GoldenHostRuntimeContract.resolve(arguments: ["serpy", "--ui-testing"])

        #expect(runtime == .uiTest)
        #expect(runtime.capabilities == [.deterministicFixtures, .ephemeralStorage])
    }

    @Test("GT-UF00-004 Golden host refuses to compose without UI runtime")
    func goldenHostRefusesProductionRuntime() {
        #expect(throws: GoldenHostRuntimeError.uiTestingArgumentRequired) {
            try GoldenHostRuntimeContract.resolve(arguments: ["serpy"])
        }
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

}
