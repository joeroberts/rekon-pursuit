import XCTest

final class RekonPursuitUITests: XCTestCase {
    @MainActor
    func testNeedsAttentionIsTheDefaultHome() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["needs-attention-home"].waitForExistence(timeout: 5))
    }
}
