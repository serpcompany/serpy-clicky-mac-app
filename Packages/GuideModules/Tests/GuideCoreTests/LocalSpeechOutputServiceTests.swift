import GuideMac
import XCTest

@MainActor
final class LocalSpeechOutputServiceTests: XCTestCase {
    func testEmptyGuidanceNeverStartsSpeech() {
        let service = LocalSpeechOutputService()

        XCTAssertFalse(service.speak("  \n "))
        XCTAssertFalse(service.isSpeaking)
    }
}
