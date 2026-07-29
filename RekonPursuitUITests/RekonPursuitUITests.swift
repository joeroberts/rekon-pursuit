import XCTest

final class RekonPursuitUITests: XCTestCase {
    private let fixtureSession = "ui-shell-\(UUID().uuidString)"

    @MainActor
    private func launchApp(fixture: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ApplePersistenceIgnoreState", "YES",
            "-rekon-visual-fixture", fixture
        ]
        app.launchEnvironment["REKON_VISUAL_FIXTURE_SESSION"] = fixtureSession
        app.launch()
        app.activate()
        return app
    }

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
        let app = launchApp(fixture: "empty")

        let shell = app.descendants(matching: .any)["app-shell"]
        let lockup = app.descendants(matching: .any)["sidebar-brand-lockup"]
        let collapse = app.descendants(matching: .any)["sidebar-collapse"]
        XCTAssertTrue(shell.waitForExistence(timeout: 5))
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(window.frame.width, 860)
        XCTAssertGreaterThanOrEqual(window.frame.height, 600)
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
        guard let focusedDestination = keyboardTraversableDestinations.first(where: hasVisibleKeyboardFocus) else {
            XCTFail("Expected a sidebar destination to have keyboard focus.")
            return
        }
        let routeMarkers = [
            "sidebar-home": "daily-route-home",
            "sidebar-pipeline": "daily-route-pipeline",
            "sidebar-contacts": "daily-route-contacts",
            "sidebar-activity-and-ai": "daily-route-activity-ai",
            "sidebar-settings": "daily-route-settings"
        ]
        app.typeKey(.space, modifierFlags: [])
        XCTAssertTrue(
            app.descendants(matching: .any)[routeMarkers[focusedDestination.identifier] ?? "daily-route-home"].waitForExistence(timeout: 5),
            "Space should activate the keyboard-focused sidebar destination."
        )
        XCTAssertTrue(focusedDestination.isSelected)
        XCTAssertFalse(app.buttons["sidebar-needs-attention"].exists)
        XCTAssertFalse(app.buttons["sidebar-add-opportunity"].exists)
        XCTAssertFalse(app.buttons["sidebar-import-csv"].exists)
    }

    @MainActor
    func testSidebarDestinationsExposeTheActiveDailyRoute() {
        let app = launchApp(fixture: "empty")

        let destinations: [(sidebarID: String, routeID: String)] = [
            ("sidebar-home", "daily-route-home"),
            ("sidebar-pipeline", "daily-route-pipeline"),
            ("sidebar-contacts", "daily-route-contacts"),
            ("sidebar-activity-and-ai", "daily-route-activity-ai"),
            ("sidebar-settings", "daily-route-settings")
        ]

        var previousRouteID: String?
        for destination in destinations {
            let sidebarItem = app.descendants(matching: .any)[destination.sidebarID]
            XCTAssertTrue(sidebarItem.waitForExistence(timeout: 5))
            sidebarItem.tap()
            XCTAssertTrue(
                app.descendants(matching: .any)[destination.routeID].waitForExistence(timeout: 5),
                "Expected \(destination.sidebarID) to make \(destination.routeID) active"
            )
            XCTAssertTrue(sidebarItem.isSelected, "Expected \(destination.sidebarID) to expose selected accessibility state")
            if let previousRouteID {
                XCTAssertFalse(
                    app.descendants(matching: .any)[previousRouteID].exists,
                    "Expected \(previousRouteID) to disappear after changing destinations"
                )
            }
            previousRouteID = destination.routeID
        }
    }

    @MainActor
    func testRecoveryFixtureShowsOnlyRecoveryActionsAndDoesNotOpenAWorkspace() {
        let app = launchApp(fixture: "recovery")

        XCTAssertTrue(app.descendants(matching: .any)["workspace-onboarding"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["workspace-gate-status"].waitForExistence(timeout: 5))
        let recheck = app.buttons["recheck-local-workspace"]
        XCTAssertTrue(recheck.waitForExistence(timeout: 5))
        recheck.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["workspace-onboarding"].exists,
            "Rechecking a recovery-only fixture must not open or create a workspace"
        )
        XCTAssertFalse(app.descendants(matching: .any)["daily-route-home"].exists)
    }

    @MainActor
    func testPopulatedFixtureCanOpenAnOpportunityAndSafelyReturnToPipeline() {
        let app = launchApp(fixture: "populated")
        app.descendants(matching: .any)["sidebar-pipeline"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["daily-route-pipeline"].waitForExistence(timeout: 5))

        let opportunity = app.staticTexts["Fixture opportunity"]
        XCTAssertTrue(opportunity.waitForExistence(timeout: 5))
        opportunity.tap()
        XCTAssertTrue(app.buttons["Back to Pipeline"].waitForExistence(timeout: 5))

        app.buttons["Back to Pipeline"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["daily-route-pipeline"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Back to Pipeline"].exists)
    }
}
