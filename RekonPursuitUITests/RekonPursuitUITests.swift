import XCTest

final class RekonPursuitUITests: XCTestCase {
    @MainActor
    func testHomeSidebarAndOnboardingAreReachableWithoutReadyStateDiagnostics() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.buttons["sidebar-home"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["sidebar-needs-attention"].exists)
        XCTAssertFalse(app.buttons["sidebar-add-opportunity"].exists)
        XCTAssertFalse(app.buttons["sidebar-import-csv"].exists)
        XCTAssertTrue(
            app.otherElements["workspace-onboarding"].waitForExistence(timeout: 5) ||
            app.staticTexts["home-content"].waitForExistence(timeout: 5)
        )
    }
}
