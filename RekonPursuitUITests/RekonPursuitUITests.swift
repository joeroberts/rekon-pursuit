import XCTest

final class RekonPursuitUITests: XCTestCase {
    @MainActor
    func testSidebarAndOnboardingAreReachableWithoutRequiringReadyStateDiagnostics() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["sidebar-home"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["sidebar-needs-attention"].exists)
        XCTAssertFalse(app.staticTexts["sidebar-add-opportunity"].exists)
        XCTAssertFalse(app.staticTexts["sidebar-import-csv"].exists)
        XCTAssertTrue(
            app.otherElements["workspace-onboarding"].waitForExistence(timeout: 5) ||
            app.staticTexts["home-content"].waitForExistence(timeout: 5)
        )
    }
}
