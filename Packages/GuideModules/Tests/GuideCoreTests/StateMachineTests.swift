import GuideCore
import XCTest

final class StateMachineTests: XCTestCase {
    func testPermissionCannotRequestBeforeExplanation() {
        var machine = PermissionStateMachine()

        XCTAssertThrowsError(try machine.beginRequest())
        XCTAssertEqual(machine.state, .unknown)
    }

    func testPermissionHappyPath() throws {
        var machine = PermissionStateMachine()

        machine.explain()
        try machine.beginRequest()
        machine.resolve(granted: true)

        XCTAssertEqual(machine.state, .granted)
    }

    func testDictationHappyPath() throws {
        var machine = DictationStateMachine()

        try machine.prepare()
        try machine.beginRecording()
        try machine.beginTranscription()
        try machine.beginInsertion()
        try machine.succeed()

        XCTAssertEqual(machine.phase, .succeeded)
    }

    func testDictationCancellationNeverInserts() throws {
        var machine = DictationStateMachine()
        try machine.prepare()
        try machine.beginRecording()

        machine.cancel()

        XCTAssertEqual(machine.phase, .cancelled)
        XCTAssertThrowsError(try machine.beginInsertion())
    }

    func testCompanionReturnsAfterTemporaryHide() {
        var machine = CompanionStateMachine(isEnabled: true)

        machine.temporarilyHide(reason: "display transition")
        machine.clearBlockerOrTemporaryHide()

        XCTAssertEqual(machine.visibility, .visible)
        XCTAssertTrue(machine.isEnabled)
    }

    func testDisabledCompanionCannotBecomeBlocked() {
        var machine = CompanionStateMachine()

        machine.block(.permission("Accessibility"))

        XCTAssertEqual(machine.visibility, .disabled)
    }
}

final class GuidanceValidationTests: XCTestCase {
    func testLowConfidenceNeverPoints() {
        let plan = GuidancePlan(answer: "Try Settings", point: CGPoint(x: 20, y: 20), confidence: 0.5)
        let validated = GuidancePlanValidator.validate(plan, in: CGRect(x: 0, y: 0, width: 100, height: 100))
        XCTAssertNil(validated.point)
    }

    func testOutOfBoundsPointIsRemoved() {
        let plan = GuidancePlan(answer: "Try Settings", point: CGPoint(x: 200, y: 20), confidence: 0.9)
        let validated = GuidancePlanValidator.validate(plan, in: CGRect(x: 0, y: 0, width: 100, height: 100))
        XCTAssertNil(validated.point)
    }

    func testHighConfidencePointInsideWindowSurvives() {
        let plan = GuidancePlan(answer: "Try Settings", point: CGPoint(x: 20, y: 20), confidence: 0.9)
        let validated = GuidancePlanValidator.validate(plan, in: CGRect(x: 0, y: 0, width: 100, height: 100))
        XCTAssertEqual(validated.point, CGPoint(x: 20, y: 20))
    }
}
