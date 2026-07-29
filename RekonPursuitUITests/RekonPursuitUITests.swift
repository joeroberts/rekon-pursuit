import XCTest

final class RekonPursuitUITests: XCTestCase {
    private let fixtureSession = "ui-shell-\(UUID().uuidString)"

    override func tearDown() {
        MainActor.assumeIsolated {
            let app = XCUIApplication()
            if app.state != .notRunning {
                app.terminate()
            }
        }
        super.tearDown()
    }

    @MainActor
    func testSidebarIsDiscoverableAndCanCollapseAndRestore() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ApplePersistenceIgnoreState", "YES",
            "-rekon-visual-fixture", "empty"
        ]
        app.launchEnvironment["REKON_VISUAL_FIXTURE_SESSION"] = fixtureSession
        app.launch()
        app.activate()

        let shell = app.descendants(matching: .any)["app-shell"]
        let lockup = app.descendants(matching: .any)["sidebar-brand-lockup"]
        let collapse = app.descendants(matching: .any)["sidebar-collapse"]
        XCTAssertTrue(shell.waitForExistence(timeout: 5))
        XCTAssertTrue(lockup.waitForExistence(timeout: 5))
        XCTAssertTrue(collapse.waitForExistence(timeout: 5))
        XCTAssertEqual(collapse.label, "Collapse sidebar")
        XCTAssertTrue(app.descendants(matching: .any)["sidebar-home"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["sidebar-pipeline"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["sidebar-contacts"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["sidebar-activity-and-ai"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["sidebar-settings"].waitForExistence(timeout: 5))
        collapse.tap()
        XCTAssertEqual(collapse.label, "Show sidebar")
        collapse.tap()
        XCTAssertTrue(app.descendants(matching: .any)["sidebar-home"].waitForExistence(timeout: 5))
        XCTAssertEqual(collapse.label, "Collapse sidebar")
        let keyboardTraversableDestinations = [
            app.descendants(matching: .any)["sidebar-home"],
            app.descendants(matching: .any)["sidebar-pipeline"],
            app.descendants(matching: .any)["sidebar-contacts"],
            app.descendants(matching: .any)["sidebar-activity-and-ai"],
            app.descendants(matching: .any)["sidebar-settings"]
        ]
        let hasVisibleKeyboardFocus: (XCUIElement) -> Bool = {
            ($0.value as? String) == "Keyboard focus"
        }
        for _ in 0..<8 where !keyboardTraversableDestinations.contains(where: hasVisibleKeyboardFocus) {
            app.typeKey(.tab, modifierFlags: [])
        }
        XCTAssertTrue(keyboardTraversableDestinations.contains(where: hasVisibleKeyboardFocus))
        XCTAssertFalse(app.buttons["sidebar-needs-attention"].exists)
        XCTAssertFalse(app.buttons["sidebar-add-opportunity"].exists)
        XCTAssertFalse(app.buttons["sidebar-import-csv"].exists)
    }
}
