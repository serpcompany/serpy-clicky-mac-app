import XCTest
@testable import GuideUI

final class SettingsExperienceTests: XCTestCase {
    func testSettingsHomeExposesOnlyWorkingProductRoutes() {
        XCTAssertEqual(
            SERPySettingsRoute.allCases,
            [.setup, .guidance, .companion, .history, .privacy]
        )
        XCTAssertEqual(Set(SERPySettingsRoute.allCases.map(\.title)).count, 5)
        XCTAssertTrue(SERPySettingsRoute.allCases.allSatisfy { !$0.summary.isEmpty && !$0.symbol.isEmpty })
    }
}
