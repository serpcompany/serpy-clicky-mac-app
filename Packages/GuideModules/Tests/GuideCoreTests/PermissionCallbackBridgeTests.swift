import Dispatch
import GuideMac
import Testing

@Suite("Permission callback bridge")
struct PermissionCallbackBridgeTests {
    @Test("background callbacks resume safely")
    @MainActor
    func backgroundCallbackResumesSafely() async {
        let granted = await PermissionCallbackBridge.request { completion in
            DispatchQueue.global(qos: .userInitiated).async {
                completion(true)
            }
        }

        #expect(granted)
    }
}
