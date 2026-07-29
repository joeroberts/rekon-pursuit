import XCTest

final class RekonPursuitUITests: XCTestCase {
    private let fixtureSession = "ui-shell-\(UUID().uuidString)"

    override func tearDown() async throws {
        let session = fixtureSession
        await MainActor.run {
            let cleanup = XCUIApplication()
            cleanup.launchArguments = ["-rekon-visual-fixture-cleanup", "empty"]
            cleanup.launchEnvironment["REKON_VISUAL_FIXTURE_SESSION"] = session
            cleanup.launch()
            XCTAssertEqual(cleanup.wait(for: .notRunning, timeout: 5), true)
        }
        try await super.tearDown()
    }

    @MainActor
    func testHomeSidebarAndOnboardingAreReachableWithoutReadyStateDiagnostics() {
        let app = XCUIApplication()
        app.launchArguments = ["-rekon-visual-fixture", "empty"]
        app.launchEnvironment["REKON_VISUAL_FIXTURE_SESSION"] = fixtureSession
        app.launch()

        XCTAssertTrue(app.otherElements["app-shell"].waitForExistence(timeout: 5))
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
