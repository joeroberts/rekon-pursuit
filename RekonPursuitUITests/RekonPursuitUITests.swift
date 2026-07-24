import XCTest

final class RekonPursuitUITests: XCTestCase {
    @MainActor
    func testWorkspaceStatusIsVisible() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["workspace-status"].waitForExistence(timeout: 5))
    }
}
