@testable import GuideMac
import XCTest

final class SpeechCompletionGateTests: XCTestCase {
    func testFinalResultBeforeHotKeyReleaseFinishesWhenStopped() {
        var gate = SpeechCompletionGate()

        gate.receiveFinalResult()

        XCTAssertTrue(gate.shouldFinishWhenStopped)
    }

    func testResetPreventsPriorPhraseFromCompletingNextRecording() {
        var gate = SpeechCompletionGate()
        gate.receiveFinalResult()

        gate.reset()

        XCTAssertFalse(gate.shouldFinishWhenStopped)
    }
}
