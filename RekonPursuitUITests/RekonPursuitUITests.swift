import XCTest

final class RekonPursuitUITests: XCTestCase {
    @MainActor
    func testNeedsAttentionIsTheDefaultHome() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["needs-attention-home"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testContactsWorkspaceIsReachable() {
        let app = XCUIApplication()
        app.launch()

        app.radioButtons["Contacts"].click()

        XCTAssertTrue(app.staticTexts["New contact"].waitForExistence(timeout: 5))
    }
}
