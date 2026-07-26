import XCTest

final class RekonPursuitUITests: XCTestCase {
    @MainActor
    func testSidebarAndOnboardingAreReachableWithoutRequiringReadyStateDiagnostics() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["sidebar-needs-attention"].waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.otherElements["workspace-onboarding"].waitForExistence(timeout: 5) ||
            app.staticTexts["needs-attention-home"].waitForExistence(timeout: 5)
        )
    }
}
