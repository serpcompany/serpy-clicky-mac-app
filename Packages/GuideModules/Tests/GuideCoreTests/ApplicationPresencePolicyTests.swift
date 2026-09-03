import GuideCore
import Testing

@Suite("Application presence policy")
struct ApplicationPresencePolicyTests {
    @Test("a running app stays regular when Settings opens or closes")
    func runningLifetimeIsAlwaysRegular() {
        let policy = ApplicationPresencePolicy()

        #expect(policy.presence(for: .running(settingsVisible: false)) == .regular)
        #expect(policy.presence(for: .running(settingsVisible: true)) == .regular)
        #expect(policy.presence(for: .terminating) == .prohibited)
    }
}
