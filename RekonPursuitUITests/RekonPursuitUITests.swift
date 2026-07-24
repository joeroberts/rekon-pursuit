import XCTest

final class RekonPursuitUITests: XCTestCase {
    @MainActor
    func testBootstrapStatusIsVisible() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["bootstrap-status"].waitForExistence(timeout: 5))
    }
}
