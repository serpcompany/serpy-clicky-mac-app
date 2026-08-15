import Dispatch
import GuideMac
import Testing

@Suite("Main actor callback bridge")
struct MainActorCallbackBridgeTests {
    @Test("a callback created for an actor handler can arrive off actor")
    @MainActor
    func backgroundDeliveryReachesMainActor() async {
        var received = 0
        let callback = MainActorCallbackBridge.make { value in
            MainActor.assertIsolated()
            received = value
        }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                callback(42)
                continuation.resume()
            }
        }

        for _ in 0..<20 where received != 42 {
            await Task.yield()
        }
        #expect(received == 42)
    }
}
