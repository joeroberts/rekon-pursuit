import XCTest

final class RekonPursuitUITests: XCTestCase {
    @MainActor
    func testNeedsAttentionAndWorkspaceGateStatusAreVisibleOnLaunch() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["sidebar-needs-attention"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["needs-attention-home"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["workspace-gate-status"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testContactsWorkspaceIsReachable() {
        let app = XCUIApplication()
        app.launch()

        app.staticTexts["sidebar-contacts"].click()

        XCTAssertTrue(app.textFields["contact-name"].waitForExistence(timeout: 5))
    }
}
