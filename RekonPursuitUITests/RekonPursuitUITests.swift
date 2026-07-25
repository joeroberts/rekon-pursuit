import XCTest

final class RekonPursuitUITests: XCTestCase {
    @MainActor
    func testNeedsAttentionAndWorkspaceGateAreVisibleOnLaunch() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["sidebar-needs-attention"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["needs-attention-home"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.otherElements["workspace-gate"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testContactsWorkspaceIsReachable() {
        let app = XCUIApplication()
        app.launch()

        app.staticTexts["sidebar-contacts"].click()

        XCTAssertTrue(app.staticTexts["New contact"].waitForExistence(timeout: 5))
    }
}
