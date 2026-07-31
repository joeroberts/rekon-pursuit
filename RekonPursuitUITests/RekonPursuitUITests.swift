import XCTest

final class RekonPursuitUITests: XCTestCase {
    private let fixtureSession = "ui-shell-\(UUID().uuidString)"

    /// UI tests own a UUID-qualified session. Teardown removes only that exact
    /// directory in the test process; relaunching an App whose initializer
    /// intentionally exits for cleanup leaves XCTest waiting for a launch
    /// handshake that can never complete. Production-host cleanup behavior is
    /// exercised independently by `RekonPursuitUITestHostTests`.
    private static func fixtureSessionRoot(for session: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("rekon-pursuit-visual-fixtures", isDirectory: true)
            .appendingPathComponent(session, isDirectory: true)
    }
    @MainActor
    private func launchApp(
        fixture: String,
        windowSize: String = "wide",
        session: String? = nil,
        reduceMotion: Bool = false
    ) -> XCUIApplication {
        let app = XCUIApplication(bundleIdentifier: "com.rekonlabs.RekonPursuitUITestHost")
        app.launchArguments = [
            "-ApplePersistenceIgnoreState", "YES",
            "-rekon-visual-fixture", fixture,
            "-rekon-visual-window-size", windowSize
        ]
        if reduceMotion {
            app.launchArguments += ["-NSAccessibilityReduceMotionEnabled", "YES"]
        }
        app.launchEnvironment["REKON_VISUAL_FIXTURE_SESSION"] = session ?? fixtureSession
        app.launch()
        app.activate()
        return app
    }

    @MainActor
    private func openPipelineBoard(in app: XCUIApplication) {
        app.descendants(matching: .any)["sidebar-pipeline"].tap()
        let viewMode = app.descendants(matching: .any)["pipeline-view-mode"]
        XCTAssertTrue(viewMode.waitForExistence(timeout: 5))
        viewMode.radioButtons["Board"].click()
        XCTAssertTrue(app.descendants(matching: .any)["pipeline-board-region"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func boardCard(named title: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons
            .matching(
                NSPredicate(
                    format: "identifier BEGINSWITH %@ AND label == %@",
                    "pipeline-opportunity-",
                    title
                )
            )
            .firstMatch
    }

    @MainActor
    private func actionsMenu(for opportunityID: String, in app: XCUIApplication) -> XCUIElement {
        app.menuButtons["pipeline-card-actions-\(opportunityID)"]
    }

    @MainActor
    private func moveWithMenu(
        opportunityID: String,
        to target: String,
        in app: XCUIApplication
    ) {
        let menu = actionsMenu(for: opportunityID, in: app)
        XCTAssertTrue(menu.waitForExistence(timeout: 5))
        menu.click()
        let move = app.menuItems["Move to stage…"]
        XCTAssertTrue(move.waitForExistence(timeout: 5))
        move.click()
        let item = app.menuItems[target]
        XCTAssertTrue(item.waitForExistence(timeout: 5))
        item.click()
    }

    @MainActor
    private func boardLaneCount(named lane: String, in app: XCUIApplication) -> Int {
        let value = app.descendants(matching: .any)["pipeline-board-lane-\(lane)"].value as? String ?? ""
        return Int(value.split(separator: " ").first ?? "") ?? -1
    }

    @MainActor
    private func boardCardCount(in app: XCUIApplication, lanes: [String]) -> Int {
        lanes.reduce(0) { $0 + boardLaneCount(named: $1, in: app) }
    }

    @MainActor
    private func selectStageFilter(_ title: String, in app: XCUIApplication) {
        let filter = app.popUpButtons["pipeline-stage-filter"]
        XCTAssertTrue(filter.waitForExistence(timeout: 5))
        filter.click()
        let item = app.menuItems[title]
        XCTAssertTrue(item.waitForExistence(timeout: 5))
        item.click()
    }

    @MainActor
    private func scrollBoardToLane(_ title: String, in app: XCUIApplication) {
        let board = app.descendants(matching: .any)["pipeline-board-region"]
        XCTAssertTrue(board.waitForExistence(timeout: 5))
        for _ in 0..<12 where (board.value as? String) != "Horizontal lane: \(title)" {
            board.coordinate(withNormalizedOffset: CGVector(dx: 0.82, dy: 0.5)).swipeLeft()
            RunLoop.current.run(until: Date().addingTimeInterval(0.15))
        }
        XCTAssertEqual(board.value as? String, "Horizontal lane: \(title)")
    }

    @MainActor
    private func configureBoardReturnContext(in app: XCUIApplication) -> String {
        openPipelineBoard(in: app)
        let search = app.textFields["opportunity-search"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.click()
        search.typeKey("a", modifierFlags: [.command])
        search.typeText("Product")
        XCTAssertEqual(search.value as? String, "Product")
        selectStageFilter("Screening", in: app)
        let includeClosed = app.checkBoxes["pipeline-include-closed"]
        XCTAssertTrue(includeClosed.waitForExistence(timeout: 5))
        if String(describing: includeClosed.value ?? "") == "0" {
            includeClosed.click()
        }
        let productDesigner = boardCard(named: "Product Designer", in: app)
        XCTAssertTrue(productDesigner.waitForExistence(timeout: 5))
        let opportunityID = String(productDesigner.identifier.dropFirst("pipeline-opportunity-".count))
        productDesigner.click()
        let back = app.buttons["Back to Pipeline"]
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        back.click()
        XCTAssertTrue(app.descendants(matching: .any)["pipeline-board-region"].waitForExistence(timeout: 5))
        let card = app.groups["pipeline-stage-move-card-\(opportunityID)"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertEqual(card.value as? String, "Anchored")
        scrollBoardToLane("Offer", in: app)
        return opportunityID
    }

    @MainActor
    private func populateInvalidAddDraft(in app: XCUIApplication) {
        let url = app.textFields["Job URL (optional)"]
        XCTAssertTrue(url.waitForExistence(timeout: 5))
        url.click()
        url.typeText("not a url")
        let warning = app.staticTexts["add-opportunity-url-warning"]
        XCTAssertTrue(warning.waitForExistence(timeout: 5))
        XCTAssertEqual(
            warning.label,
            "Use an absolute http or https URL with a host. Imported legacy URLs are preserved until changed."
        )
        let action = app.popUpButtons["Next action"]
        XCTAssertTrue(action.waitForExistence(timeout: 5))
        action.click()
        XCTAssertTrue(app.menuItems["Other"].waitForExistence(timeout: 5))
        app.menuItems["Other"].click()
        let customAction = app.textFields["opportunity-next-action"]
        XCTAssertTrue(customAction.waitForExistence(timeout: 5))
        customAction.click()
        customAction.typeText("Follow up")
        let dueToggle = app.checkBoxes["Add a due date"]
        XCTAssertTrue(dueToggle.waitForExistence(timeout: 5))
        dueToggle.click()
        XCTAssertTrue(app.datePickers["Due"].waitForExistence(timeout: 5))
    }

    private struct SubjectHistoryCounts: Equatable {
        let activityRows: Int
        let stageRows: Int
        let stageMoveActivities: Int
        let savedToScreeningRows: Int
    }

    @MainActor
    private func openSubjectHistory(
        opportunityID: String,
        in app: XCUIApplication
    ) {
        let pipeline = app.descendants(matching: .any)["sidebar-pipeline"]
        XCTAssertTrue(pipeline.waitForExistence(timeout: 5))
        pipeline.tap()
        let viewMode = app.descendants(matching: .any)["pipeline-view-mode"]
        XCTAssertTrue(viewMode.waitForExistence(timeout: 5))
        viewMode.radioButtons["Table"].click()
        let row = app.descendants(matching: .any)["pipeline-table-row-\(opportunityID)"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        XCTAssertTrue(app.descendants(matching: .any)["pipeline-inspector-\(opportunityID)"].waitForExistence(timeout: 5))
        app.buttons["pipeline-open-details-\(opportunityID)"].tap()
        XCTAssertTrue(app.buttons["Back to Pipeline"].waitForExistence(timeout: 5))
        let more = app.descendants(matching: .any)["More"]
        XCTAssertTrue(more.waitForExistence(timeout: 5))
        more.tap()
        let history = app.menuItems["Activity & history"]
        XCTAssertTrue(history.waitForExistence(timeout: 5))
        history.click()
        XCTAssertTrue(app.staticTexts["Activity & history"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func subjectHistoryCounts(in app: XCUIApplication) -> SubjectHistoryCounts {
        let stageRows = app.staticTexts.matching(
            NSPredicate(
                format: "value MATCHES %@",
                "^(Created|Saved|Applied|Screening|Interviewing|Offer|Closed) → (Saved|Applied|Screening|Interviewing|Offer|Closed) · .+$"
            )
        ).count
        let activityRows = app.staticTexts.matching(
            NSPredicate(format: "value MATCHES %@", "^[A-Za-z ]+ · .+$")
        ).count
        return SubjectHistoryCounts(
            activityRows: activityRows,
            stageRows: stageRows,
            stageMoveActivities: app.staticTexts.matching(
                NSPredicate(format: "value BEGINSWITH %@", "Opportunity Stage Changed")
            ).count,
            savedToScreeningRows: app.staticTexts.matching(
                NSPredicate(format: "value BEGINSWITH %@", "Saved → Screening")
            ).count
        )
    }

    @MainActor
    private func returnFromSubjectHistoryToBoard(in app: XCUIApplication) {
        let backToSubject = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@ AND label != %@", "Back to ", "Back to Pipeline")
        ).firstMatch
        XCTAssertTrue(backToSubject.waitForExistence(timeout: 5))
        backToSubject.tap()
        let backToPipeline = app.buttons["Back to Pipeline"]
        XCTAssertTrue(backToPipeline.waitForExistence(timeout: 5))
        backToPipeline.tap()
        openPipelineBoard(in: app)
    }

    @MainActor
    private func isContained(_ element: XCUIElement, in container: XCUIElement) -> Bool {
        let tolerance: CGFloat = 8
        let elementFrame = element.frame
        let containerFrame = container.frame
        return elementFrame.width > 0
            && elementFrame.height > 0
            && elementFrame.minX >= containerFrame.minX - tolerance
            && elementFrame.maxX <= containerFrame.maxX + tolerance
            && elementFrame.minY >= containerFrame.minY - tolerance
            && elementFrame.maxY <= containerFrame.maxY + tolerance
    }

    /// SwiftUI `Menu` is exposed by AppKit as an AXMenuButton, rather than an
    /// AXButton. Keep the UI tests aligned with the production accessibility
    /// role so the action control remains both discoverable and tappable.
    @MainActor
    private func homeActionMenu(in app: XCUIApplication) -> XCUIElement {
        app.menuButtons
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "home-actions-"))
            .firstMatch
    }

    /// The action menu and its containing card are independent accessibility
    /// queries. Pair them by their shared task identifier rather than relying
    /// on AppKit's unspecified ordering of separate query result sets.
    @MainActor
    private func homeAttentionCard(in app: XCUIApplication, for actions: XCUIElement) -> XCUIElement? {
        let actionPrefix = "home-actions-"
        guard actions.identifier.hasPrefix(actionPrefix) else {
            return nil
        }
        let taskID = String(actions.identifier.dropFirst(actionPrefix.count))
        return app.descendants(matching: .any)["home-attention-\(taskID)"]
    }

    @MainActor
    private func assertWindow(_ window: XCUIElement, hasSize expectedSize: CGSize) {
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        XCTAssertEqual(window.frame.width, expectedSize.width, accuracy: 0.5)
        XCTAssertEqual(window.frame.height, expectedSize.height, accuracy: 0.5)
    }

    /// Captured from the compact rejected-build AX tree on 2026-07-30: this
    /// framework toolbar control is an AXButton labeled either "Hide Sidebar"
    /// or "Show Sidebar" with no accessibility identifier. It is intentionally
    /// distinct from the product-owned `sidebar-collapse` button beside it.
    @MainActor
    private func appOwnedSidebarToggle(in app: XCUIApplication) -> XCUIElement {
        app.buttons["sidebar-collapse"]
    }

    @MainActor
    private func frameworkSidebarToggleCount(in app: XCUIApplication) -> Int {
        app.toolbars.buttons.matching(
            NSPredicate(
                format: "(label == %@ OR label == %@) AND identifier == %@",
                "Hide Sidebar",
                "Show Sidebar",
                ""
            )
        ).count
    }

    @MainActor
    private func sidebarRail(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["sidebar-rail"]
    }

    @MainActor
    private func assertVisibleRailWidth(_ rail: XCUIElement) {
        XCTAssertTrue(rail.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(rail.frame.width, 268)
        XCTAssertLessThanOrEqual(rail.frame.width, 340)
    }

    @MainActor
    private func assertNativeWindowControlsAreHittable(in app: XCUIApplication) {
        for identifier in ["window-close", "window-miniaturize", "window-zoom"] {
            XCTAssertTrue(app.descendants(matching: .any)[identifier].isHittable)
        }
    }

    override func tearDown() {
        let session = fixtureSession
        MainActor.assumeIsolated {
            let app = XCUIApplication(bundleIdentifier: "com.rekonlabs.RekonPursuitUITestHost")
            if app.state != .notRunning {
                app.terminate()
            }
        }
        Self.removeFixtureSessionFromTestProcess(session)
        super.tearDown()
    }

    /// This is deliberately narrower than app-host cleanup: the private
    /// per-test UUID lets the test runner reclaim only its own session without
    /// launching an app that is designed to terminate during initialization.
    private static func removeFixtureSessionFromTestProcess(_ session: String) {
        let sessionPrefix = "ui-shell-"
        guard session.hasPrefix(sessionPrefix),
              UUID(uuidString: String(session.dropFirst(sessionPrefix.count))) != nil else {
            XCTFail("UI fixture cleanup refused a non-UUID session identifier.")
            return
        }

        let root = fixtureSessionRoot(for: session).standardizedFileURL
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("rekon-pursuit-visual-fixtures", isDirectory: true)
            .standardizedFileURL
        guard root.deletingLastPathComponent() == base,
              (try? FileManager.default.destinationOfSymbolicLink(atPath: root.path)) == nil else {
            XCTFail("UI fixture cleanup refused a path outside its exact non-symlink session root.")
            return
        }

        do {
            if FileManager.default.fileExists(atPath: root.path) {
                try FileManager.default.removeItem(at: root)
            }
            XCTAssertFalse(FileManager.default.fileExists(atPath: root.path))
        } catch {
            XCTFail("UI fixture cleanup failed for its exact session root: \(error)")
        }
    }

    @MainActor
    func testSidebarIsDiscoverableAndCanCollapseAndRestore() {
        let app = launchApp(fixture: "populated")

        let shell = app.descendants(matching: .any)["app-shell"]
        let lockup = app.descendants(matching: .any)["sidebar-brand-lockup"]
        let collapse = app.descendants(matching: .any)["sidebar-collapse"]
        let rail = sidebarRail(in: app)
        XCTAssertTrue(shell.waitForExistence(timeout: 5))
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(window.frame.width, 860)
        XCTAssertGreaterThanOrEqual(window.frame.height, 600)
        XCTAssertTrue(lockup.waitForExistence(timeout: 5))
        assertVisibleRailWidth(rail)
        XCTAssertTrue(collapse.waitForExistence(timeout: 5))
        XCTAssertEqual(collapse.label, "Collapse sidebar")
        XCTAssertTrue(app.descendants(matching: .any)["sidebar-home"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["sidebar-pipeline"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["sidebar-contacts"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["sidebar-activity-and-ai"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["sidebar-settings"].waitForExistence(timeout: 5))
        let contacts = app.descendants(matching: .any)["sidebar-contacts"]
        contacts.tap()
        XCTAssertTrue(contacts.isSelected)
        XCTAssertTrue(app.textFields["contact-search"].waitForExistence(timeout: 5))
        collapse.tap()
        XCTAssertEqual(collapse.label, "Show sidebar")
        XCTAssertFalse(rail.exists)
        collapse.tap()
        XCTAssertTrue(app.descendants(matching: .any)["sidebar-home"].waitForExistence(timeout: 5))
        XCTAssertEqual(collapse.label, "Collapse sidebar")
        assertVisibleRailWidth(rail)
        XCTAssertTrue(contacts.isSelected)
        XCTAssertTrue(app.textFields["contact-search"].waitForExistence(timeout: 5))
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
        for _ in 0...(keyboardTraversableDestinations.count + 2) where !keyboardTraversableDestinations.contains(where: hasVisibleKeyboardFocus) {
            app.typeKey(.tab, modifierFlags: [])
        }
        XCTAssertTrue(keyboardTraversableDestinations.contains(where: hasVisibleKeyboardFocus))
        guard let focusedDestination = keyboardTraversableDestinations.first(where: hasVisibleKeyboardFocus) else {
            XCTFail("Expected a sidebar destination to have keyboard focus.")
            return
        }
        app.typeKey(.space, modifierFlags: [])
        XCTAssertTrue(focusedDestination.isSelected, "Space should activate the keyboard-focused sidebar destination.")
        XCTAssertFalse(app.buttons["sidebar-needs-attention"].exists)
        XCTAssertFalse(app.buttons["sidebar-add-opportunity"].exists)
        XCTAssertFalse(app.buttons["sidebar-import-csv"].exists)
    }

    @MainActor
    func testVD204PipelineTableSelectsAnEphemeralInspectorAndOnlyOpenDetailsRoutes() {
        let app = launchApp(fixture: "pipeline")
        app.descendants(matching: .any)["sidebar-pipeline"].tap()

        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "pipeline-table-row-")).firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["opportunity-search"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["pipeline-stage-filter"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["pipeline-include-closed"].exists)

        let rows = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "pipeline-table-row-"))
        XCTAssertGreaterThanOrEqual(rows.count, 2)
        let firstRow = rows.element(boundBy: 0)
        let secondRow = rows.element(boundBy: 1)
        let firstID = String(firstRow.identifier.dropFirst("pipeline-table-row-".count))
        let secondID = String(secondRow.identifier.dropFirst("pipeline-table-row-".count))
        firstRow.tap()

        XCTAssertEqual(firstRow.value as? String, "Selected", "Selecting a Pipeline table row must update only its local selection state before the inspector is rendered.")
        XCTAssertTrue(app.descendants(matching: .any)["pipeline-inspector-\(firstID)"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["pipeline-inspector-company-\(firstID)"].exists)
        XCTAssertFalse(app.textFields["selected-opportunity-title"].exists)
        XCTAssertFalse(app.buttons["Back to Pipeline"].exists)

        secondRow.tap()
        XCTAssertTrue(app.descendants(matching: .any)["pipeline-inspector-\(secondID)"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["pipeline-inspector-\(firstID)"].exists)

        app.buttons["pipeline-open-details-\(secondID)"].tap()
        XCTAssertTrue(app.textFields["selected-opportunity-title"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Back to Pipeline"].exists)
        app.buttons["Back to Pipeline"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["pipeline-table-row-\(secondID)"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["pipeline-inspector-drawer"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["pipeline-table-region"].isHittable)
    }

    @MainActor
    func testVD204PipelineFidelityTableContract() {
        let wideApp = launchApp(fixture: "pipeline", windowSize: "wide")
        // The fixture requests a 1600×1000 content size. AppKit reports the
        // unified-compact frame six points shorter because its titlebar is
        // excluded from this AX frame; assert the actual fixed host frame.
        assertWindow(wideApp.windows.firstMatch, hasSize: CGSize(width: 1600, height: 994))
        wideApp.descendants(matching: .any)["sidebar-pipeline"].tap()
        XCTAssertTrue(wideApp.descendants(matching: .any)["pipeline-table-region"].waitForExistence(timeout: 5))

        let headers = [
            (name: "Role", identifier: "pipeline-table-header-role"),
            (name: "Employer", identifier: "pipeline-table-header-employer"),
            (name: "Stage", identifier: "pipeline-table-header-stage"),
            (name: "Next action", identifier: "pipeline-table-header-next-action"),
            (name: "Due date", identifier: "pipeline-table-header-due-date")
        ].map { header in
            (name: header.name, element: wideApp.descendants(matching: .any)[header.identifier])
        }
        let resultCount = wideApp.descendants(matching: .any)["pipeline-table-result-count"]

        let savedRow = wideApp.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label BEGINSWITH %@", "pipeline-table-row-", "Senior iOS Engineer, Nebula Labs, Saved"))
            .firstMatch
        let savedRowExists = savedRow.waitForExistence(timeout: 5)
        savedRow.tap()
        let savedID = String(savedRow.identifier.dropFirst("pipeline-table-row-".count))
        let savedSelection = savedRow.value as? String
        let employerMark = wideApp.descendants(matching: .any)["pipeline-inspector-employer-mark-\(savedID)"]
        let stage = wideApp.descendants(matching: .any)["pipeline-inspector-stage-\(savedID)"]
        let nextAction = wideApp.descendants(matching: .any)["pipeline-inspector-fact-next-action-\(savedID)"]
        let openDetails = wideApp.descendants(matching: .any)["pipeline-open-details-\(savedID)"]
        let currentInspector = wideApp.descendants(matching: .any)["pipeline-inspector-\(savedID)"]

        // These are retained-state prerequisites for the owner-facing
        // capture, not the deliberately RED future fidelity identifiers.
        XCTAssertTrue(savedRowExists)
        XCTAssertEqual(savedSelection, "Selected")
        XCTAssertTrue(currentInspector.waitForExistence(timeout: 5))

        // The owner-facing Table capture must show the selected data row and
        // the adjacent inspector hierarchy together, not an unselected empty
        // state that cannot establish the intended dense-workspace layout.
        let wideCapture = XCTAttachment(screenshot: wideApp.screenshot())
        wideCapture.name = "vd204-fidelity-wide-table"
        wideCapture.lifetime = .keepAlways
        add(wideCapture)

        for header in headers {
            XCTAssertTrue(
                header.element.exists,
                "The desktop Table must expose its aligned \(header.name) column header."
            )
        }
        // The mock-aligned 1600×1000 host must render content-led desktop
        // tracks beside the persistent inspector. Identifier existence alone
        // is insufficient: the header and matching representative cell must
        // each receive their documented readable track.
        let tableViewport = wideApp.descendants(matching: .any)["pipeline-table-region"]
        XCTAssertTrue(tableViewport.isHittable)
        for header in headers {
            XCTAssertTrue(header.element.isHittable, "The \(header.name) heading must remain readable in the desktop Table.")
            XCTAssertGreaterThanOrEqual(header.element.frame.minX, tableViewport.frame.minX)
            XCTAssertLessThanOrEqual(
                header.element.frame.maxX,
                tableViewport.frame.maxX,
                "The normal desktop Table must not clip \(header.name) behind the inspector."
            )
        }
        XCTAssertGreaterThanOrEqual(savedRow.frame.minX, tableViewport.frame.minX)
        XCTAssertLessThanOrEqual(
            savedRow.frame.maxX,
            tableViewport.frame.maxX,
            "The representative dense Table row must stay entirely in the visible Table viewport."
        )
        XCTAssertTrue(resultCount.exists)
        XCTAssertTrue(employerMark.exists)
        XCTAssertTrue(stage.exists)
        XCTAssertTrue(nextAction.exists)
        XCTAssertTrue(openDetails.exists)

        wideApp.terminate()
        let compactApp = launchApp(fixture: "pipeline", windowSize: "compact")
        assertWindow(compactApp.windows.firstMatch, hasSize: CGSize(width: 860, height: 640))
        compactApp.descendants(matching: .any)["sidebar-pipeline"].tap()
        XCTAssertTrue(compactApp.descendants(matching: .any)["pipeline-table-header-role"].waitForExistence(timeout: 5))
        XCTAssertTrue(compactApp.descendants(matching: .any)["pipeline-table-header-stage"].exists)
        XCTAssertFalse(compactApp.descendants(matching: .any)["pipeline-table-header-employer"].exists)
        XCTAssertFalse(compactApp.descendants(matching: .any)["pipeline-table-header-next-action"].exists)
        XCTAssertFalse(compactApp.descendants(matching: .any)["pipeline-table-header-due-date"].exists)
        let compactRow = compactApp.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label BEGINSWITH %@", "pipeline-table-row-", "Senior iOS Engineer, Nebula Labs, Saved"))
            .firstMatch
        let compactRowExists = compactRow.waitForExistence(timeout: 5)
        compactRow.tap()
        let compactDrawer = compactApp.descendants(matching: .any)["pipeline-inspector-drawer"]
        let compactDrawerExists = compactDrawer.waitForExistence(timeout: 5)
        let compactSheetCount = compactApp.sheets.count
        let compactCapture = XCTAttachment(screenshot: compactApp.screenshot())
        compactCapture.name = "vd204-fidelity-compact-table-drawer"
        compactCapture.lifetime = .keepAlways
        add(compactCapture)
        XCTAssertTrue(compactRowExists)
        XCTAssertTrue(compactDrawerExists)
        XCTAssertEqual(compactSheetCount, 0)
    }

    @MainActor
    func testVD204PipelineFidelityBoardContract() {
        let wideApp = launchApp(fixture: "pipeline", windowSize: "wide")
        wideApp.descendants(matching: .any)["sidebar-pipeline"].tap()
        let viewMode = wideApp.descendants(matching: .any)["pipeline-view-mode"]
        XCTAssertTrue(viewMode.waitForExistence(timeout: 5))
        viewMode.radioButtons["Board"].click()
        XCTAssertTrue(wideApp.descendants(matching: .any)["pipeline-board-region"].waitForExistence(timeout: 5))

        let wideCapture = XCTAttachment(screenshot: wideApp.screenshot())
        wideCapture.name = "vd204-fidelity-wide-board"
        wideCapture.lifetime = .keepAlways
        add(wideCapture)

        wideApp.terminate()
        let compactApp = launchApp(fixture: "pipeline", windowSize: "compact")
        assertWindow(compactApp.windows.firstMatch, hasSize: CGSize(width: 860, height: 640))
        compactApp.descendants(matching: .any)["sidebar-pipeline"].tap()
        let compactViewMode = compactApp.descendants(matching: .any)["pipeline-view-mode"]
        XCTAssertTrue(compactViewMode.waitForExistence(timeout: 5))
        compactViewMode.radioButtons["Board"].click()
        XCTAssertTrue(compactApp.descendants(matching: .any)["pipeline-board-region"].waitForExistence(timeout: 5))

        let compactIncludeClosed = compactApp.checkBoxes["pipeline-include-closed"]
        XCTAssertTrue(compactIncludeClosed.waitForExistence(timeout: 5))
        XCTAssertEqual(String(describing: compactIncludeClosed.value ?? ""), "0")
        compactIncludeClosed.click()
        XCTAssertEqual(String(describing: compactIncludeClosed.value ?? ""), "1")
        // Include Closed is not proven merely by its checked value or by an
        // offscreen accessibility node. Move the bounded horizontal Board
        // viewport until the real Closed lane and its known card are rendered
        // inside both the Board and the compact window before capturing it.
        let compactBoard = compactApp.descendants(matching: .any)["pipeline-board-region"]
        let closedLane = compactApp.descendants(matching: .any)["pipeline-board-lane-closed"]
        let closedCard = compactApp.buttons
            .matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label == %@", "pipeline-opportunity-", "Closed opportunity"))
            .firstMatch
        let compactWindow = compactApp.windows.firstMatch
        let visibilityTolerance: CGFloat = 2
        func isVisible(_ element: XCUIElement) -> Bool {
            let elementFrame = element.frame
            let boardFrame = compactBoard.frame
            let windowFrame = compactWindow.frame
            return elementFrame.width > 0
                && elementFrame.height > 0
                && elementFrame.minX >= boardFrame.minX - visibilityTolerance
                && elementFrame.maxX <= boardFrame.maxX + visibilityTolerance
                && elementFrame.minY >= boardFrame.minY - visibilityTolerance
                && elementFrame.maxY <= boardFrame.maxY + visibilityTolerance
                && elementFrame.minX >= windowFrame.minX - visibilityTolerance
                && elementFrame.maxX <= windowFrame.maxX + visibilityTolerance
                && elementFrame.minY >= windowFrame.minY - visibilityTolerance
                && elementFrame.maxY <= windowFrame.maxY + visibilityTolerance
        }

        XCTAssertTrue(closedLane.waitForExistence(timeout: 5))
        XCTAssertTrue(closedCard.waitForExistence(timeout: 5))
        for _ in 0..<8 where !(isVisible(closedLane) && isVisible(closedCard)) {
            compactBoard.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5)).swipeLeft()
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        XCTAssertTrue(isVisible(closedLane), "The compact Board capture must visibly frame the enabled Closed lane.")
        XCTAssertTrue(isVisible(closedCard), "The compact Board capture must visibly frame the seeded Closed opportunity.")
        let compactCapture = XCTAttachment(screenshot: compactApp.screenshot())
        compactCapture.name = "vd204-fidelity-compact-board"
        compactCapture.lifetime = .keepAlways
        add(compactCapture)

        // Both Board visual states are now attached. Relaunch the wide state
        // for the deliberate RED semantic checks so a missing future element
        // cannot prevent capture of the compact Include-closed state.
        compactApp.terminate()
        let assertionApp = launchApp(fixture: "pipeline", windowSize: "wide")
        assertionApp.descendants(matching: .any)["sidebar-pipeline"].tap()
        let assertionViewMode = assertionApp.descendants(matching: .any)["pipeline-view-mode"]
        XCTAssertTrue(assertionViewMode.waitForExistence(timeout: 5))
        assertionViewMode.radioButtons["Board"].click()
        XCTAssertTrue(assertionApp.descendants(matching: .any)["pipeline-board-region"].waitForExistence(timeout: 5))

        for lane in ["saved", "applied", "interviewing", "offer"] {
            XCTAssertTrue(assertionApp.descendants(matching: .any)["pipeline-board-lane-\(lane)"].exists)
            XCTAssertTrue(assertionApp.descendants(matching: .any)["pipeline-board-lane-count-\(lane)"].exists)
            XCTAssertTrue(assertionApp.buttons["pipeline-board-lane-add-\(lane)"].exists)
        }
        XCTAssertFalse(assertionApp.descendants(matching: .any)["pipeline-board-lane-closed"].exists)
        let appliedLane = assertionApp.descendants(matching: .any)["pipeline-board-lane-applied"]
        XCTAssertTrue(appliedLane.waitForExistence(timeout: 5))
        // AppKit exposes a rendered Board card as one atomic Button, so its
        // rich child metadata is not independently queryable by XCTest. The
        // deterministic fixture and pure lane-mapping contract cover the
        // canonical Screening record; fresh signed-capture visual QA covers
        // the visible employer, chip, locality, next-action, and due-date
        // facts. Keep executable proof here of the globally named card and
        // its visual containment within the live Applied lane.
        let screeningCard = assertionApp.buttons
            .matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label == %@", "pipeline-opportunity-", "Product Designer"))
            .firstMatch
        XCTAssertTrue(screeningCard.waitForExistence(timeout: 5))
        let appliedFrame = appliedLane.frame
        let cardFrame = screeningCard.frame
        let accessibilityFrameTolerance: CGFloat = 8
        XCTAssertGreaterThan(cardFrame.width, 0)
        XCTAssertGreaterThan(cardFrame.height, 0)
        XCTAssertGreaterThanOrEqual(cardFrame.minX, appliedFrame.minX - accessibilityFrameTolerance)
        XCTAssertGreaterThanOrEqual(cardFrame.minY, appliedFrame.minY - accessibilityFrameTolerance)
        XCTAssertLessThanOrEqual(cardFrame.maxX, appliedFrame.maxX + accessibilityFrameTolerance)
        XCTAssertLessThanOrEqual(cardFrame.maxY, appliedFrame.maxY + accessibilityFrameTolerance)
        let includeClosed = assertionApp.checkBoxes["pipeline-include-closed"]
        XCTAssertTrue(includeClosed.waitForExistence(timeout: 5))
        includeClosed.click()
        XCTAssertTrue(assertionApp.descendants(matching: .any)["pipeline-board-lane-closed"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testVD205BoardRendersExactAppliedAndScreeningLanesAndDropTargets() throws {
        let app = launchApp(fixture: "pipeline", windowSize: "wide")
        openPipelineBoard(in: app)

        let defaultLanes = ["saved", "applied", "screening", "interviewing", "offer"]
        for lane in defaultLanes {
            XCTAssertTrue(app.descendants(matching: .any)["pipeline-board-lane-\(lane)"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.descendants(matching: .any)["pipeline-board-lane-count-\(lane)"].exists)
        }
        XCTAssertFalse(app.descendants(matching: .any)["pipeline-board-lane-closed"].exists)

        let appliedLane = app.descendants(matching: .any)["pipeline-board-lane-applied"]
        let screeningLane = app.descendants(matching: .any)["pipeline-board-lane-screening"]
        let appliedCard = boardCard(named: "Senior Product Manager", in: app)
        let screeningCard = boardCard(named: "Product Designer", in: app)
        XCTAssertTrue(appliedCard.waitForExistence(timeout: 5))
        XCTAssertTrue(screeningCard.waitForExistence(timeout: 5))
        XCTAssertEqual(appliedCard.label, "Senior Product Manager")
        XCTAssertEqual(screeningCard.label, "Product Designer")
        XCTAssertTrue(isContained(appliedCard, in: appliedLane))
        XCTAssertTrue(isContained(screeningCard, in: screeningLane))
        XCTAssertFalse(isContained(appliedCard, in: screeningLane))
        XCTAssertFalse(isContained(screeningCard, in: appliedLane))

        let includeClosed = app.checkBoxes["pipeline-include-closed"]
        XCTAssertTrue(includeClosed.waitForExistence(timeout: 5))
        includeClosed.click()
        XCTAssertTrue(app.descendants(matching: .any)["pipeline-board-lane-closed"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["pipeline-board-lane-count-closed"].exists)
        app.terminate()

        func assertNativeMove(to destination: String, expectedOutcome: String) {
            let session = "ui-shell-\(UUID().uuidString)"
            var movingApp = launchApp(fixture: "pipeline", windowSize: "wide", session: session)
            openPipelineBoard(in: movingApp)
            let subject = boardCard(named: "Senior iOS Engineer", in: movingApp)
            XCTAssertTrue(subject.waitForExistence(timeout: 5))
            let opportunityID = String(subject.identifier.dropFirst("pipeline-opportunity-".count))
            openSubjectHistory(opportunityID: opportunityID, in: movingApp)
            let before = subjectHistoryCounts(in: movingApp)
            returnFromSubjectHistoryToBoard(in: movingApp)
            let target = movingApp.descendants(matching: .any)["pipeline-board-lane-\(destination.lowercased())"]
            XCTAssertTrue(target.waitForExistence(timeout: 5))
            subject.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(
                forDuration: 0.7,
                thenDragTo: target.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            )
            XCTAssertTrue(movingApp.staticTexts[expectedOutcome].waitForExistence(timeout: 5))
            XCTAssertTrue(isContained(movingApp.buttons["pipeline-opportunity-\(opportunityID)"], in: target))
            movingApp.terminate()
            movingApp = launchApp(fixture: "pipeline", windowSize: "wide", session: session)
            openSubjectHistory(opportunityID: opportunityID, in: movingApp)
            let after = subjectHistoryCounts(in: movingApp)
            XCTAssertEqual(after.activityRows, before.activityRows + 1)
            XCTAssertEqual(after.stageRows, before.stageRows + 1)
            movingApp.terminate()
            Self.removeFixtureSessionFromTestProcess(session)
        }

        assertNativeMove(to: "Applied", expectedOutcome: "Moved to Applied.")
        assertNativeMove(to: "Screening", expectedOutcome: "Moved to Screening.")
    }

    @MainActor
    func testVD205BoardActionsMenuEditsAndMovesWithoutOldControls() throws {
        let app = launchApp(fixture: "pipeline", windowSize: "wide")
        openPipelineBoard(in: app)
        let card = boardCard(named: "Senior iOS Engineer", in: app)
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        let opportunityID = String(card.identifier.dropFirst("pipeline-opportunity-".count))
        let actions = actionsMenu(for: opportunityID, in: app)
        XCTAssertTrue(actions.waitForExistence(timeout: 5))
        XCTAssertEqual(actions.elementType, .menuButton)
        XCTAssertEqual(actions.label, "Actions for Senior iOS Engineer")
        XCTAssertEqual(actions.value as? String, "Current stage: Saved")
        actions.hover()
        let actionsTooltip = app.descendants(matching: .helpTag)
            .matching(NSPredicate(format: "label == %@", "Actions for Senior iOS Engineer"))
            .firstMatch
        XCTAssertTrue(
            actionsTooltip.waitForExistence(timeout: 3),
            "Hover must expose the production NSButton tooltip/AXHelp text, not merely keep the actions control hittable."
        )
        XCTAssertEqual(actionsTooltip.label, actions.label)
        XCTAssertGreaterThan(actions.frame.minX, card.frame.midX)
        XCTAssertLessThanOrEqual(actions.frame.maxY, card.frame.maxY + 4)

        app.typeKey("m", modifierFlags: [.command, .shift])
        expectation(for: NSPredicate(format: "value CONTAINS %@", "Keyboard focus"), evaluatedWith: actions)
        waitForExpectations(timeout: 5)
        actions.typeKey(.space, modifierFlags: [])
        let edit = app.menuItems["Edit opportunity"]
        let move = app.menuItems["Move to stage…"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        XCTAssertTrue(move.exists)
        let outerMenu = app.menus.containing(.menuItem, identifier: "Move to stage…").firstMatch
        XCTAssertTrue(outerMenu.waitForExistence(timeout: 5))
        XCTAssertEqual(outerMenu.menuItems.count, 2)
        XCTAssertEqual(outerMenu.menuItems.element(boundBy: 0).label, "Edit opportunity")
        XCTAssertEqual(outerMenu.menuItems.element(boundBy: 1).label, "Move to stage…")
        move.click()
        let expectedTargets = ["Saved", "Applied", "Screening", "Interviewing", "Offer", "Closed"]
        let stageMenu = app.menus.containing(.menuItem, identifier: "Screening").firstMatch
        XCTAssertTrue(stageMenu.waitForExistence(timeout: 5))
        XCTAssertEqual(stageMenu.menuItems.count, expectedTargets.count)
        for (index, title) in expectedTargets.enumerated() {
            XCTAssertEqual(stageMenu.menuItems.element(boundBy: index).label, title)
        }
        XCTAssertTrue(stageMenu.menuItems["Saved"].isSelected)
        app.typeKey(.escape, modifierFlags: [])
        app.typeKey(.escape, modifierFlags: [])

        card.click()
        XCTAssertTrue(app.buttons["Back to Pipeline"].waitForExistence(timeout: 5))
        app.terminate()

        let editSession = "ui-shell-\(UUID().uuidString)"
        let editApp = launchApp(fixture: "pipeline", windowSize: "wide", session: editSession)
        openPipelineBoard(in: editApp)
        let editCard = boardCard(named: "Senior iOS Engineer", in: editApp)
        XCTAssertTrue(editCard.waitForExistence(timeout: 5))
        let editID = String(editCard.identifier.dropFirst("pipeline-opportunity-".count))
        let editActions = actionsMenu(for: editID, in: editApp)
        XCTAssertTrue(editActions.waitForExistence(timeout: 5))
        editActions.click()
        XCTAssertTrue(editApp.menuItems["Edit opportunity"].waitForExistence(timeout: 5))
        editApp.menuItems["Edit opportunity"].click()
        XCTAssertTrue(editApp.buttons["Back to Pipeline"].waitForExistence(timeout: 5))
        XCTAssertFalse(editApp.descendants(matching: .any)["pipeline-board-card-stage-\(editID)"].exists)
        XCTAssertFalse(editApp.descendants(matching: .any)["pipeline-move-stage-\(editID)"].exists)
        editApp.terminate()
        Self.removeFixtureSessionFromTestProcess(editSession)
    }

    @MainActor
    private func assertBoardAddDismissalRestoresContext(usingEscape: Bool) {
        let app = launchApp(fixture: "pipeline", windowSize: "compact")
        let home = app.descendants(matching: .any)["sidebar-home"]
        XCTAssertTrue(home.waitForExistence(timeout: 5))
        home.click()
        let baselineHomeAttention = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "home-attention-"))
            .count
        let baselineHomeActive = app.descendants(matching: .any)["home-active-opportunities"].value as? String

        let productDesignerID = configureBoardReturnContext(in: app)
        let lanes = ["saved", "applied", "screening", "interviewing", "offer", "closed"]
        let baselineBoardCount = boardCardCount(in: app, lanes: lanes)
        openSubjectHistory(opportunityID: productDesignerID, in: app)
        let baselineHistory = subjectHistoryCounts(in: app)
        returnFromSubjectHistoryToBoard(in: app)
        _ = configureBoardReturnContext(in: app)

        let add = app.buttons["pipeline-add-opportunity"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.click()
        XCTAssertTrue(app.buttons["cancel-add-opportunity"].waitForExistence(timeout: 5))
        populateInvalidAddDraft(in: app)

        let cancel = app.buttons["cancel-add-opportunity"]
        XCTAssertTrue(cancel.isEnabled)
        if usingEscape {
            app.typeKey(.escape, modifierFlags: [])
        } else {
            cancel.click()
        }

        let board = app.descendants(matching: .any)["pipeline-board-region"]
        XCTAssertTrue(board.waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["opportunity-search"].value as? String, "Product")
        XCTAssertEqual(app.popUpButtons["pipeline-stage-filter"].value as? String, "Screening")
        XCTAssertEqual(String(describing: app.checkBoxes["pipeline-include-closed"].value ?? ""), "1")
        XCTAssertEqual(board.value as? String, "Horizontal lane: Offer")
        XCTAssertEqual(
            app.groups["pipeline-stage-move-card-\(productDesignerID)"].value as? String,
            "Anchored"
        )
        XCTAssertEqual(boardCardCount(in: app, lanes: lanes), baselineBoardCount)

        add.click()
        let url = app.textFields["Job URL (optional)"]
        XCTAssertTrue(url.waitForExistence(timeout: 5))
        XCTAssertEqual(url.value as? String, "")
        XCTAssertFalse(app.staticTexts["add-opportunity-url-warning"].exists)
        XCTAssertFalse(app.textFields["opportunity-next-action"].exists)
        app.buttons["cancel-add-opportunity"].click()

        openSubjectHistory(opportunityID: productDesignerID, in: app)
        XCTAssertEqual(subjectHistoryCounts(in: app), baselineHistory)
        app.terminate()
        app.launch()
        app.activate()
        XCTAssertTrue(app.descendants(matching: .any)["home-content"].waitForExistence(timeout: 5))
        XCTAssertEqual(
            app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "home-attention-")).count,
            baselineHomeAttention
        )
        XCTAssertEqual(app.descendants(matching: .any)["home-active-opportunities"].value as? String, baselineHomeActive)
        let relaunchedProductDesignerID = configureBoardReturnContext(in: app)
        XCTAssertEqual(relaunchedProductDesignerID, productDesignerID)
        XCTAssertEqual(boardCardCount(in: app, lanes: lanes), baselineBoardCount)
    }

    @MainActor
    func testVD205BoardCancelRestoresExactOriginContextAndWritesNothing() throws {
        assertBoardAddDismissalRestoresContext(usingEscape: false)
    }

    @MainActor
    func testVD205BoardEscapeRestoresExactOriginContextAndWritesNothing() throws {
        assertBoardAddDismissalRestoresContext(usingEscape: true)
    }

    @MainActor
    func testVD205BoardNativeDragSavedToScreeningPersistsAndRelaunches() throws {
        var app = launchApp(fixture: "pipeline", windowSize: "wide")
        openPipelineBoard(in: app)

        let savedLane = app.descendants(matching: .any)["pipeline-board-lane-saved"]
        let appliedLane = app.descendants(matching: .any)["pipeline-board-lane-applied"]
        let subject = boardCard(named: "Senior iOS Engineer", in: app)
        XCTAssertTrue(subject.waitForExistence(timeout: 5))
        XCTAssertTrue(savedLane.waitForExistence(timeout: 5))
        XCTAssertTrue(appliedLane.waitForExistence(timeout: 5))
        XCTAssertTrue(isContained(subject, in: savedLane))
        let opportunityID = String(subject.identifier.dropFirst("pipeline-opportunity-".count))

        subject.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(
                forDuration: 0.7,
                thenDragTo: appliedLane.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            )

        XCTAssertTrue(app.staticTexts["Moved to Applied."].waitForExistence(timeout: 5))
        let moved = app.buttons["pipeline-opportunity-\(opportunityID)"]
        XCTAssertTrue(moved.waitForExistence(timeout: 5))
        XCTAssertTrue(isContained(moved, in: appliedLane))
        XCTAssertTrue(actionsMenu(for: opportunityID, in: app).exists)
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = "vd205-board-wide-persisted-move"
        capture.lifetime = .keepAlways
        add(capture)

        app.terminate()
        app = launchApp(fixture: "pipeline", windowSize: "wide")
        openPipelineBoard(in: app)
        let relaunched = app.buttons["pipeline-opportunity-\(opportunityID)"]
        XCTAssertTrue(relaunched.waitForExistence(timeout: 5))
        XCTAssertTrue(isContained(relaunched, in: app.descendants(matching: .any)["pipeline-board-lane-applied"]))
        XCTAssertEqual(
            actionsMenu(for: opportunityID, in: app).value as? String,
            "Current stage: Applied"
        )
        moveWithMenu(opportunityID: opportunityID, to: "Applied", in: app)
        XCTAssertTrue(app.staticTexts["Already in Applied."].waitForExistence(timeout: 5))
    }

    @MainActor
    func testVD205BoardKeyboardMoveFocusesControlAndCompletes() throws {
        let app = launchApp(fixture: "pipeline", windowSize: "compact")
        openPipelineBoard(in: app)
        let subject = boardCard(named: "Senior iOS Engineer", in: app)
        XCTAssertTrue(subject.waitForExistence(timeout: 5))
        let opportunityID = String(subject.identifier.dropFirst("pipeline-opportunity-".count))
        let menu = actionsMenu(for: opportunityID, in: app)
        XCTAssertTrue(menu.waitForExistence(timeout: 5))

        app.typeKey("m", modifierFlags: [.command, .shift])
        app.typeKey(.space, modifierFlags: [])
        XCTAssertTrue(app.menuItems["Move to stage…"].waitForExistence(timeout: 5))
        app.menuItems["Move to stage…"].click()
        XCTAssertTrue(app.menuItems["Screening"].waitForExistence(timeout: 5))
        app.menuItems["Screening"].click()

        XCTAssertTrue(app.staticTexts["Moved to Screening."].waitForExistence(timeout: 5))
        app.typeKey(.space, modifierFlags: [])
        XCTAssertTrue(app.menuItems["Move to stage…"].waitForExistence(timeout: 5))
        app.typeKey(.escape, modifierFlags: [])
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = "vd205-board-compact-keyboard-move"
        capture.lifetime = .keepAlways
        add(capture)
    }

    @MainActor
    func testVD205BoardMenuExposesExactTargetsAndCurrentStageAXState() throws {
        let app = launchApp(fixture: "pipeline")
        openPipelineBoard(in: app)
        let subject = boardCard(named: "Senior iOS Engineer", in: app)
        XCTAssertTrue(subject.waitForExistence(timeout: 5))
        let opportunityID = String(subject.identifier.dropFirst("pipeline-opportunity-".count))
        let card = app.groups["pipeline-stage-move-card-\(opportunityID)"]
        let menu = actionsMenu(for: opportunityID, in: app)

        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertEqual(card.elementType, .group)
        XCTAssertTrue(menu.waitForExistence(timeout: 5))
        XCTAssertEqual(menu.elementType, .menuButton)
        XCTAssertEqual(menu.label, "Actions for Senior iOS Engineer")
        XCTAssertEqual(menu.value as? String, "Current stage: Saved")
        menu.click()
        XCTAssertTrue(app.menuItems["Edit opportunity"].waitForExistence(timeout: 5))
        let move = app.menuItems["Move to stage…"]
        XCTAssertTrue(move.exists)
        move.click()
        let expectedTargets = ["Saved", "Applied", "Screening", "Interviewing", "Offer", "Closed"]
        let presentedMenu = app.menus.containing(.menuItem, identifier: "Screening").firstMatch
        XCTAssertTrue(presentedMenu.waitForExistence(timeout: 5))
        for target in expectedTargets {
            XCTAssertTrue(presentedMenu.menuItems[target].waitForExistence(timeout: 5))
        }
        XCTAssertEqual(presentedMenu.menuItems.count, expectedTargets.count)
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(app.descendants(matching: .any)["pipeline-stage-move-outcome"].waitForNonExistence(timeout: 1))
    }

    @MainActor
    func testVD205BoardNoOpBlockedUnavailableFailedCancelAndInvalidRetainSource() throws {
        let invalidSession = "ui-shell-\(UUID().uuidString)"
        let invalidApp = launchApp(fixture: "pipeline", session: invalidSession)
        openPipelineBoard(in: invalidApp)
        let invalidSubject = boardCard(named: "Senior iOS Engineer", in: invalidApp)
        let invalidSavedLane = invalidApp.descendants(matching: .any)["pipeline-board-lane-saved"]
        let invalidTarget = invalidApp.descendants(matching: .any)["pipeline-board-lane-applied"]
        XCTAssertTrue(invalidSubject.waitForExistence(timeout: 5))
        XCTAssertTrue(invalidSavedLane.waitForExistence(timeout: 5))
        XCTAssertTrue(invalidTarget.waitForExistence(timeout: 5))
        XCTAssertTrue(isContained(invalidSubject, in: invalidSavedLane))
        XCTAssertFalse(invalidApp.descendants(matching: .any)["pipeline-stage-move-outcome"].exists)
        let invalidOpportunityID = String(invalidSubject.identifier.dropFirst("pipeline-opportunity-".count))

        openSubjectHistory(opportunityID: invalidOpportunityID, in: invalidApp)
        let invalidBaseline = subjectHistoryCounts(in: invalidApp)
        returnFromSubjectHistoryToBoard(in: invalidApp)

        for identifier in [
            "pipeline-invalid-drag-empty",
            "pipeline-invalid-drag-oversized",
            "pipeline-invalid-drag-malformed",
            "pipeline-invalid-drag-unknown"
        ] {
            let source = invalidApp.descendants(matching: .any)[identifier]
            XCTAssertTrue(source.waitForExistence(timeout: 5))
            source.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                .press(
                    forDuration: 0.7,
                    thenDragTo: invalidTarget.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                )
        }

        let invalidObservation = invalidApp.descendants(matching: .any)["pipeline-invalid-drag-observation"]
        XCTAssertTrue(invalidObservation.waitForExistence(timeout: 5))
        expectation(
            for: NSPredicate(
                format: "label == %@",
                "deliveries=4; rejections=4; commands=0"
            ),
            evaluatedWith: invalidObservation
        )
        waitForExpectations(timeout: 5)
        XCTAssertFalse(invalidApp.descendants(matching: .any)["pipeline-stage-move-outcome"].exists)
        XCTAssertTrue(
            isContained(
                invalidApp.buttons["pipeline-opportunity-\(invalidOpportunityID)"],
                in: invalidSavedLane
            )
        )

        invalidApp.terminate()
        invalidApp.launch()
        invalidApp.activate()
        openPipelineBoard(in: invalidApp)
        XCTAssertTrue(
            isContained(
                invalidApp.buttons["pipeline-opportunity-\(invalidOpportunityID)"],
                in: invalidApp.descendants(matching: .any)["pipeline-board-lane-saved"]
            )
        )
        openSubjectHistory(opportunityID: invalidOpportunityID, in: invalidApp)
        XCTAssertEqual(subjectHistoryCounts(in: invalidApp), invalidBaseline)
        invalidApp.terminate()
        Self.removeFixtureSessionFromTestProcess(invalidSession)

        func exercise(
            fixture: String,
            target: String,
            expectedOutcome: String,
            session: String = "ui-shell-\(UUID().uuidString)"
        ) {
            let app = launchApp(fixture: fixture, session: session)
            openPipelineBoard(in: app)
            let title = fixture == "pipeline" ? "Senior iOS Engineer" : "Stage move subject"
            let subject = boardCard(named: title, in: app)
            let savedLane = app.descendants(matching: .any)["pipeline-board-lane-saved"]
            XCTAssertTrue(subject.waitForExistence(timeout: 5))
            XCTAssertTrue(savedLane.waitForExistence(timeout: 5))
            let opportunityID = String(subject.identifier.dropFirst("pipeline-opportunity-".count))
            moveWithMenu(opportunityID: opportunityID, to: target, in: app)
            XCTAssertTrue(app.staticTexts[expectedOutcome].waitForExistence(timeout: 5))
            XCTAssertTrue(isContained(app.buttons["pipeline-opportunity-\(opportunityID)"], in: savedLane))
            if fixture == "stage-move-blocked-close" {
                let capture = XCTAttachment(screenshot: app.screenshot())
                capture.name = "vd205-board-close-reconciliation-blocked"
                capture.lifetime = .keepAlways
                self.add(capture)
            } else if fixture == "stage-move-write-failure" {
                let capture = XCTAttachment(screenshot: app.screenshot())
                capture.name = "vd205-board-local-failure-recovery"
                capture.lifetime = .keepAlways
                self.add(capture)
            }
            app.terminate()
            Self.removeFixtureSessionFromTestProcess(session)
        }

        exercise(fixture: "pipeline", target: "Saved", expectedOutcome: "Already in Saved.")
        exercise(
            fixture: "stage-move-blocked-close",
            target: "Closed",
            expectedOutcome: "Confirm reconciliation before moving to Closed."
        )
        exercise(
            fixture: "stage-move-unavailable",
            target: "Screening",
            expectedOutcome: "Opportunity is no longer available locally."
        )
        exercise(
            fixture: "stage-move-write-failure",
            target: "Screening",
            expectedOutcome: "The local stage was not changed."
        )
        exercise(
            fixture: "stage-move-projection-failure",
            target: "Screening",
            expectedOutcome: "The local stage was not changed."
        )

        let cancelSession = "ui-shell-\(UUID().uuidString)"
        let cancelApp = launchApp(fixture: "pipeline", session: cancelSession)
        openPipelineBoard(in: cancelApp)
        let cancelSubject = boardCard(named: "Senior iOS Engineer", in: cancelApp)
        let cancelLane = cancelApp.descendants(matching: .any)["pipeline-board-lane-saved"]
        XCTAssertTrue(cancelSubject.waitForExistence(timeout: 5))
        cancelSubject.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(
                forDuration: 0.7,
                thenDragTo: cancelApp.windows.firstMatch.coordinate(
                    withNormalizedOffset: CGVector(dx: 0.95, dy: 0.05)
                )
            )
        XCTAssertTrue(isContained(cancelSubject, in: cancelLane))
        XCTAssertFalse(cancelApp.descendants(matching: .any)["pipeline-stage-move-outcome"].exists)

        let add = cancelApp.buttons["pipeline-add-opportunity"]
        let appliedLane = cancelApp.descendants(matching: .any)["pipeline-board-lane-applied"]
        add.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(
                forDuration: 0.7,
                thenDragTo: appliedLane.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            )
        XCTAssertTrue(isContained(cancelSubject, in: cancelLane))
        XCTAssertFalse(cancelApp.descendants(matching: .any)["pipeline-stage-move-outcome"].exists)
        cancelApp.terminate()
        Self.removeFixtureSessionFromTestProcess(cancelSession)
    }

    @MainActor
    func testVD205BoardClosedFilterStaysSessionLocalDuringMove() throws {
        let app = launchApp(fixture: "pipeline")
        openPipelineBoard(in: app)
        let includeClosed = app.checkBoxes["pipeline-include-closed"]
        XCTAssertTrue(includeClosed.waitForExistence(timeout: 5))
        includeClosed.click()
        XCTAssertEqual(String(describing: includeClosed.value ?? ""), "1")
        let subject = boardCard(named: "Senior iOS Engineer", in: app)
        XCTAssertTrue(subject.waitForExistence(timeout: 5))
        let opportunityID = String(subject.identifier.dropFirst("pipeline-opportunity-".count))

        moveWithMenu(opportunityID: opportunityID, to: "Closed", in: app)
        XCTAssertEqual(String(describing: includeClosed.value ?? ""), "1")
        let closedLane = app.descendants(matching: .any)["pipeline-board-lane-closed"]
        let closedCard = closedLane.buttons["pipeline-opportunity-\(opportunityID)"]
        XCTAssertTrue(closedCard.waitForExistence(timeout: 5))
        XCTAssertTrue(isContained(closedCard, in: closedLane))

        moveWithMenu(opportunityID: opportunityID, to: "Saved", in: app)
        XCTAssertEqual(String(describing: includeClosed.value ?? ""), "1")
        let savedLane = app.descendants(matching: .any)["pipeline-board-lane-saved"]
        let savedCard = savedLane.buttons["pipeline-opportunity-\(opportunityID)"]
        XCTAssertTrue(savedCard.waitForExistence(timeout: 5))
        XCTAssertTrue(isContained(savedCard, in: savedLane))
    }

    @MainActor
    func testVD205BoardHistoryContainsExactlyOneNewSubjectTransition() throws {
        let app = launchApp(fixture: "pipeline")
        openPipelineBoard(in: app)
        let subject = boardCard(named: "Senior iOS Engineer", in: app)
        XCTAssertTrue(subject.waitForExistence(timeout: 5))
        let opportunityID = String(subject.identifier.dropFirst("pipeline-opportunity-".count))
        XCTAssertTrue(
            isContained(
                subject,
                in: app.descendants(matching: .any)["pipeline-board-lane-saved"]
            )
        )

        openSubjectHistory(opportunityID: opportunityID, in: app)
        let baseline = subjectHistoryCounts(in: app)
        returnFromSubjectHistoryToBoard(in: app)
        moveWithMenu(opportunityID: opportunityID, to: "Screening", in: app)
        XCTAssertTrue(app.staticTexts["Moved to Screening."].waitForExistence(timeout: 5))

        let screeningLane = app.descendants(matching: .any)["pipeline-board-lane-screening"]
        let movedCard = screeningLane.buttons["pipeline-opportunity-\(opportunityID)"]
        XCTAssertTrue(movedCard.waitForExistence(timeout: 5))
        XCTAssertTrue(isContained(movedCard, in: screeningLane))

        app.terminate()
        app.launch()
        app.activate()
        openSubjectHistory(opportunityID: opportunityID, in: app)
        let relaunched = subjectHistoryCounts(in: app)
        XCTAssertEqual(relaunched.stageMoveActivities, baseline.stageMoveActivities + 1)
        XCTAssertEqual(relaunched.savedToScreeningRows, baseline.savedToScreeningRows + 1)
        XCTAssertEqual(relaunched.activityRows, baseline.activityRows + 1)
        XCTAssertEqual(relaunched.stageRows, baseline.stageRows + 1)
    }

    @MainActor
    func testVD205BoardReduceMotionHasNoSpatialTransitionAndRetainsFocus() throws {
        let normalSession = "ui-shell-\(UUID().uuidString)"
        let normalApp = launchApp(fixture: "pipeline", session: normalSession)
        openPipelineBoard(in: normalApp)
        let normalSubject = boardCard(named: "Senior iOS Engineer", in: normalApp)
        let normalTarget = normalApp.descendants(matching: .any)["pipeline-board-lane-applied"]
        XCTAssertTrue(normalSubject.waitForExistence(timeout: 5))
        XCTAssertTrue(normalTarget.waitForExistence(timeout: 5))
        normalSubject.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(
                forDuration: 0.7,
                thenDragTo: normalTarget.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            )
        XCTAssertTrue(normalApp.staticTexts["Moved to Applied."].waitForExistence(timeout: 5))
        let normalObservation = normalApp.descendants(matching: .any)["pipeline-stage-move-motion-observation"]
        XCTAssertTrue(normalObservation.waitForExistence(timeout: 5))
        expectation(
            for: NSPredicate(format: "label == %@", "executed=1; suppressed=0"),
            evaluatedWith: normalObservation
        )
        waitForExpectations(timeout: 5)
        normalApp.terminate()
        Self.removeFixtureSessionFromTestProcess(normalSession)

        let reducedSession = "ui-shell-\(UUID().uuidString)"
        let app = launchApp(fixture: "pipeline", session: reducedSession, reduceMotion: true)
        openPipelineBoard(in: app)
        let subject = boardCard(named: "Senior iOS Engineer", in: app)
        let savedLane = app.descendants(matching: .any)["pipeline-board-lane-saved"]
        let appliedLane = app.descendants(matching: .any)["pipeline-board-lane-applied"]
        XCTAssertTrue(subject.waitForExistence(timeout: 5))
        XCTAssertTrue(savedLane.waitForExistence(timeout: 5))
        XCTAssertTrue(appliedLane.waitForExistence(timeout: 5))
        XCTAssertTrue(isContained(subject, in: savedLane))
        let opportunityID = String(subject.identifier.dropFirst("pipeline-opportunity-".count))
        let menu = actionsMenu(for: opportunityID, in: app)
        XCTAssertTrue(menu.waitForExistence(timeout: 5))
        app.typeKey("m", modifierFlags: [.command, .shift])
        expectation(
            for: NSPredicate(format: "value CONTAINS %@", "Keyboard focus"),
            evaluatedWith: menu
        )
        waitForExpectations(timeout: 5)
        subject.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(
                forDuration: 0.7,
                thenDragTo: appliedLane.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            )
        XCTAssertTrue(app.staticTexts["Moved to Applied."].waitForExistence(timeout: 5))
        XCTAssertTrue(
            isContained(
                app.buttons["pipeline-opportunity-\(opportunityID)"],
                in: appliedLane
            )
        )
        let observation = app.descendants(matching: .any)["pipeline-stage-move-motion-observation"]
        XCTAssertTrue(observation.waitForExistence(timeout: 5))
        expectation(
            for: NSPredicate(format: "label == %@", "executed=0; suppressed=1"),
            evaluatedWith: observation
        )
        waitForExpectations(timeout: 5)
        let restoredMenu = actionsMenu(for: opportunityID, in: app)
        XCTAssertTrue(restoredMenu.waitForExistence(timeout: 5))
        expectation(
            for: NSPredicate(format: "value CONTAINS %@", "Keyboard focus"),
            evaluatedWith: restoredMenu
        )
        waitForExpectations(timeout: 5)
        app.terminate()
        Self.removeFixtureSessionFromTestProcess(reducedSession)
    }

    @MainActor
    func testVD204PipelineCompactWindowUsesAnInPlaceRightDrawer() {
        let app = launchApp(fixture: "pipeline", windowSize: "compact")
        let window = app.windows.firstMatch
        assertWindow(window, hasSize: CGSize(width: 860, height: 640))
        app.descendants(matching: .any)["sidebar-pipeline"].tap()

        let rows = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "pipeline-table-row-"))
        let row = rows.firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(rows.count, 2)
        let id = String(row.identifier.dropFirst("pipeline-table-row-".count))
        row.tap()

        let drawer = app.descendants(matching: .any)["pipeline-inspector-drawer"]
        XCTAssertTrue(drawer.waitForExistence(timeout: 5))
        let openDrawerScreenshot = XCTAttachment(screenshot: app.screenshot())
        openDrawerScreenshot.name = "VD204 compact drawer open — expected future state (intentional RED until drawer exists)"
        openDrawerScreenshot.lifetime = .keepAlways
        add(openDrawerScreenshot)
        XCTAssertTrue(app.descendants(matching: .any)["pipeline-inspector-\(id)"].exists)
        let close = app.buttons["pipeline-inspector-close"]
        XCTAssertTrue(close.exists)
        XCTAssertEqual(app.sheets.count, 0)
        XCTAssertTrue(row.exists)
        let table = app.descendants(matching: .any)["pipeline-table-region"]
        XCTAssertTrue(table.exists)
        XCTAssertGreaterThan(drawer.frame.minX, table.frame.minX)
        XCTAssertEqual(drawer.frame.maxX, table.frame.maxX, accuracy: 0.5)
        XCTAssertGreaterThanOrEqual(drawer.frame.minY, table.frame.minY)
        XCTAssertLessThanOrEqual(drawer.frame.maxY, table.frame.maxY)
        XCTAssertFalse(app.buttons["pipeline-inspector-disclosure"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["pipeline-inspector-empty"].exists)
        if close.exists {
            close.tap()
        }
        XCTAssertTrue(drawer.waitForNonExistence(timeout: 5))
        let closedDrawerScreenshot = XCTAttachment(screenshot: app.screenshot())
        closedDrawerScreenshot.name = "VD204 compact drawer after close — expected future state (intentional RED until close exists)"
        closedDrawerScreenshot.lifetime = .keepAlways
        add(closedDrawerScreenshot)
        XCTAssertTrue(row.isHittable)

        let secondRow = rows.element(boundBy: 1)
        let secondID = String(secondRow.identifier.dropFirst("pipeline-table-row-".count))
        secondRow.tap()
        XCTAssertTrue(app.descendants(matching: .any)["pipeline-inspector-drawer"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["pipeline-inspector-\(secondID)"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["pipeline-inspector-\(id)"].exists)
    }

    @MainActor
    func testVD204PipelineTableSelectionHasNoRadioChildControl() {
        let app = launchApp(fixture: "pipeline", windowSize: "compact")
        assertWindow(app.windows.firstMatch, hasSize: CGSize(width: 860, height: 640))
        app.descendants(matching: .any)["sidebar-pipeline"].tap()

        let row = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "pipeline-table-row-"))
            .firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertEqual(row.value as? String, "Not selected")
        row.tap()
        XCTAssertEqual(row.value as? String, "Selected")

        // Keep this screenshot for manual visual review of the selection
        // treatment alongside the row's semantic selection checks above.
        let baseline = XCTAttachment(screenshot: app.screenshot())
        baseline.name = "VD204 compact selection treatment — manual visual review"
        baseline.lifetime = .keepAlways
        add(baseline)

        let table = app.descendants(matching: .any)["pipeline-table-region"]
        XCTAssertTrue(table.exists)
        XCTAssertEqual(table.radioButtons.count, 0)
        XCTAssertEqual(table.checkBoxes.count, 0)
        XCTAssertTrue(app.descendants(matching: .any)["pipeline-inspector-drawer"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testVD204PipelineCompactToolbarKeepsTheViewSwitcherOnOneLine() {
        let compactApp = launchApp(fixture: "pipeline", windowSize: "compact")
        assertWindow(compactApp.windows.firstMatch, hasSize: CGSize(width: 860, height: 640))
        compactApp.descendants(matching: .any)["sidebar-pipeline"].tap()

        let compactViewMode = compactApp.descendants(matching: .any)["pipeline-view-mode"]
        XCTAssertTrue(compactViewMode.waitForExistence(timeout: 5))
        XCTAssertTrue(compactViewMode.isHittable)
        XCTAssertEqual(compactViewMode.label, "View, View")
        XCTAssertFalse(compactApp.staticTexts["pipeline-view-label"].exists)
        let compactScreenshot = XCTAttachment(screenshot: compactApp.screenshot())
        compactScreenshot.name = "VD204 compact Pipeline toolbar"
        compactScreenshot.lifetime = .keepAlways
        add(compactScreenshot)

        compactApp.terminate()
        let wideApp = launchApp(fixture: "pipeline", windowSize: "wide")
        wideApp.descendants(matching: .any)["sidebar-pipeline"].tap()
        XCTAssertTrue(wideApp.descendants(matching: .any)["pipeline-view-mode"].waitForExistence(timeout: 5))
        XCTAssertTrue(wideApp.staticTexts["pipeline-view-label"].exists)
        let wideScreenshot = XCTAttachment(screenshot: wideApp.screenshot())
        wideScreenshot.name = "VD204 wide Pipeline toolbar"
        wideScreenshot.lifetime = .keepAlways
        add(wideScreenshot)
    }

    @MainActor
    func testVD204PipelineControlsRemainKeyboardDiscoverableAndStyled() {
        let app = launchApp(fixture: "pipeline", windowSize: "wide")
        app.descendants(matching: .any)["sidebar-pipeline"].tap()

        let search = app.textFields["opportunity-search"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        XCTAssertEqual(search.elementType, .textField)
        XCTAssertEqual(search.label, "Search opportunities")
        XCTAssertTrue(search.isHittable)
        search.click()
        search.typeText("no matching opportunity")
        XCTAssertTrue(
            app.staticTexts["No opportunities match"].waitForExistence(timeout: 5),
            "Activating Search must filter the Pipeline surface for a deterministic unmatched query."
        )
        XCTAssertTrue(app.buttons["pipeline-clear-filters"].exists)
        app.buttons["pipeline-clear-filters"].tap()

        let stage = app.popUpButtons["pipeline-stage-filter"]
        XCTAssertTrue(stage.exists)
        XCTAssertEqual(stage.elementType, .popUpButton)
        XCTAssertEqual(stage.label, "Stage")
        XCTAssertTrue(stage.isHittable)
        stage.click()
        XCTAssertTrue(app.menuItems["All stages"].waitForExistence(timeout: 5))
        app.typeKey(.escape, modifierFlags: [])

        let includeClosed = app.checkBoxes["pipeline-include-closed"]
        XCTAssertTrue(includeClosed.exists)
        XCTAssertEqual(includeClosed.elementType, .checkBox)
        XCTAssertEqual(includeClosed.label, "Include closed")
        XCTAssertTrue(includeClosed.isHittable)
        XCTAssertEqual(String(describing: includeClosed.value ?? ""), "0")
        includeClosed.click()
        XCTAssertEqual(String(describing: includeClosed.value ?? ""), "1")
        let closedRow = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label BEGINSWITH %@", "pipeline-table-row-", "Closed opportunity, Northstar Labs, Closed"))
            .firstMatch
        XCTAssertTrue(
            closedRow.waitForExistence(timeout: 5),
            "Activating Include closed must reveal the seeded closed Pipeline opportunity."
        )

        let viewMode = app.descendants(matching: .any)["pipeline-view-mode"]
        XCTAssertTrue(viewMode.exists)
        XCTAssertEqual(viewMode.label, "View, View")
        XCTAssertTrue(viewMode.isHittable)
        XCTAssertTrue(app.descendants(matching: .any)["pipeline-table-region"].waitForExistence(timeout: 5))
        viewMode.radioButtons["Board"].click()
        XCTAssertTrue(
            app.descendants(matching: .any)["pipeline-board-region"].waitForExistence(timeout: 5),
            "Activating Board must replace the table with the Board-specific Pipeline surface."
        )
        viewMode.radioButtons["Table"].click()
        XCTAssertTrue(
            app.descendants(matching: .any)["pipeline-table-region"].waitForExistence(timeout: 5),
            "Activating Table must restore the table-specific Pipeline surface."
        )

        // Diagnostic capture for VD2-04 product-owner feedback: this is taken
        // after every normal Pipeline control has been exercised, but before
        // Import CSV presents its file-picker flow, so it records the actual
        // rendered control surfaces rather than a dialog overlay.
        let normalControls = XCTAttachment(screenshot: app.screenshot())
        normalControls.name = "VD204 diagnostic — normal Pipeline controls before Import CSV"
        normalControls.lifetime = .keepAlways
        add(normalControls)

        let importCSV = app.buttons["pipeline-import-csv"]
        XCTAssertTrue(importCSV.exists)
        XCTAssertEqual(importCSV.elementType, .button)
        XCTAssertEqual(importCSV.label, "Import CSV")
        XCTAssertTrue(importCSV.isHittable)
        importCSV.tap()
        XCTAssertTrue(app.buttons["choose-csv-file"].waitForExistence(timeout: 5))

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "VD204 wide Pipeline controls"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testVD204PipelineNavySurfaceControlsRemainSemanticallyOperableInTableAndBoard() {
        func exerciseAndCapture(windowSize: String, layoutName: String) {
            let app = launchApp(fixture: "pipeline", windowSize: windowSize)
            if windowSize == "compact" {
                assertWindow(app.windows.firstMatch, hasSize: CGSize(width: 860, height: 640))
            }
            app.descendants(matching: .any)["sidebar-pipeline"].tap()

            let search = app.textFields["opportunity-search"]
            XCTAssertTrue(search.waitForExistence(timeout: 5))
            XCTAssertEqual(search.elementType, .textField)
            XCTAssertEqual(search.label, "Search opportunities")
            XCTAssertTrue(search.isHittable)
            search.click()
            search.typeText("no matching opportunity")
            XCTAssertTrue(app.staticTexts["No opportunities match"].waitForExistence(timeout: 5))
            let clearFilters = app.buttons["pipeline-clear-filters"]
            XCTAssertTrue(clearFilters.isHittable)
            clearFilters.tap()

            let stage = app.popUpButtons["pipeline-stage-filter"]
            XCTAssertTrue(stage.waitForExistence(timeout: 5))
            XCTAssertEqual(stage.elementType, .popUpButton)
            XCTAssertEqual(stage.label, "Stage")
            XCTAssertTrue(stage.isHittable)
            stage.click()
            let tableAllStages = app.menuItems["All stages"]
            XCTAssertTrue(tableAllStages.waitForExistence(timeout: 5))
            app.typeKey(.escape, modifierFlags: [])
            XCTAssertTrue(tableAllStages.waitForNonExistence(timeout: 5))

            let includeClosed = app.checkBoxes["pipeline-include-closed"]
            XCTAssertTrue(includeClosed.waitForExistence(timeout: 5))
            XCTAssertEqual(includeClosed.elementType, .checkBox)
            XCTAssertEqual(includeClosed.label, "Include closed")
            XCTAssertTrue(includeClosed.isHittable)
            XCTAssertEqual(String(describing: includeClosed.value ?? ""), "0")
            includeClosed.click()
            XCTAssertEqual(String(describing: includeClosed.value ?? ""), "1")
            let closedRow = app.descendants(matching: .any)
                .matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label BEGINSWITH %@", "pipeline-table-row-", "Closed opportunity, Northstar Labs, Closed"))
                .firstMatch
            XCTAssertTrue(closedRow.waitForExistence(timeout: 5))
            includeClosed.click()
            XCTAssertEqual(String(describing: includeClosed.value ?? ""), "0")

            let table = app.descendants(matching: .any)["pipeline-table-region"]
            XCTAssertTrue(table.waitForExistence(timeout: 5))
            let viewMode = app.descendants(matching: .any)["pipeline-view-mode"]
            XCTAssertTrue(viewMode.waitForExistence(timeout: 5))
            XCTAssertEqual(viewMode.elementType, .radioGroup)
            XCTAssertEqual(viewMode.label, "View, View")
            XCTAssertTrue(viewMode.isHittable)
            XCTAssertTrue(viewMode.radioButtons["Board"].isHittable)

            let tableCapture = XCTAttachment(screenshot: app.screenshot())
            tableCapture.name = "VD204 navy surface — \(layoutName) Table"
            tableCapture.lifetime = .keepAlways
            add(tableCapture)

            let tableImportCSV = app.buttons["pipeline-import-csv"]
            XCTAssertTrue(tableImportCSV.waitForExistence(timeout: 5))
            XCTAssertEqual(tableImportCSV.elementType, .button)
            XCTAssertEqual(tableImportCSV.label, "Import CSV")
            XCTAssertTrue(tableImportCSV.isHittable)
            tableImportCSV.tap()
            let tableChooser = app.buttons["choose-csv-file"]
            XCTAssertTrue(tableChooser.waitForExistence(timeout: 5))
            // Import CSV is a routed screen, not a transient dialog. Return
            // through the existing Pipeline destination after proving that
            // the Import action reached its actual chooser state.
            app.descendants(matching: .any)["sidebar-pipeline"].tap()
            XCTAssertTrue(tableChooser.waitForNonExistence(timeout: 5))
            XCTAssertTrue(viewMode.waitForExistence(timeout: 5))

            viewMode.radioButtons["Board"].click()
            XCTAssertTrue(app.descendants(matching: .any)["pipeline-board-region"].waitForExistence(timeout: 5))

            XCTAssertTrue(search.exists)
            XCTAssertEqual(search.elementType, .textField)
            XCTAssertEqual(search.label, "Search opportunities")
            XCTAssertTrue(search.isHittable)
            XCTAssertTrue(stage.exists)
            XCTAssertEqual(stage.elementType, .popUpButton)
            XCTAssertEqual(stage.label, "Stage")
            XCTAssertTrue(stage.isHittable)
            XCTAssertTrue(includeClosed.exists)
            XCTAssertEqual(includeClosed.elementType, .checkBox)
            XCTAssertEqual(includeClosed.label, "Include closed")
            XCTAssertTrue(includeClosed.isHittable)
            XCTAssertTrue(viewMode.exists)
            XCTAssertEqual(viewMode.elementType, .radioGroup)
            XCTAssertEqual(viewMode.label, "View, View")
            XCTAssertTrue(viewMode.isHittable)
            XCTAssertTrue(viewMode.radioButtons["Table"].isHittable)
            XCTAssertTrue(viewMode.radioButtons["Board"].isHittable)

            let boardCapture = XCTAttachment(screenshot: app.screenshot())
            boardCapture.name = "VD204 navy surface — \(layoutName) Board"
            boardCapture.lifetime = .keepAlways
            add(boardCapture)

            search.click()
            search.typeText("no matching opportunity")
            XCTAssertTrue(app.staticTexts["No opportunities match"].waitForExistence(timeout: 5))
            let boardClearFilters = app.buttons["pipeline-clear-filters"]
            XCTAssertTrue(boardClearFilters.isHittable)
            boardClearFilters.tap()

            stage.click()
            let boardAllStages = app.menuItems["All stages"]
            XCTAssertTrue(boardAllStages.waitForExistence(timeout: 5))
            app.typeKey(.escape, modifierFlags: [])
            XCTAssertTrue(boardAllStages.waitForNonExistence(timeout: 5))

            XCTAssertEqual(String(describing: includeClosed.value ?? ""), "0")
            includeClosed.click()
            XCTAssertEqual(String(describing: includeClosed.value ?? ""), "1")
            let closedBoardCard = app.buttons
                .matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label == %@", "pipeline-opportunity-", "Closed opportunity"))
                .firstMatch
            XCTAssertTrue(closedBoardCard.waitForExistence(timeout: 5))

            let boardImportCSV = app.buttons["pipeline-import-csv"]
            XCTAssertTrue(boardImportCSV.waitForExistence(timeout: 5))
            XCTAssertEqual(boardImportCSV.elementType, .button)
            XCTAssertEqual(boardImportCSV.label, "Import CSV")
            XCTAssertTrue(boardImportCSV.isHittable)
            boardImportCSV.tap()
            let boardChooser = app.buttons["choose-csv-file"]
            XCTAssertTrue(boardChooser.waitForExistence(timeout: 5))
            app.descendants(matching: .any)["sidebar-pipeline"].tap()
            XCTAssertTrue(boardChooser.waitForNonExistence(timeout: 5))

            viewMode.radioButtons["Table"].click()
            XCTAssertTrue(app.descendants(matching: .any)["pipeline-table-region"].waitForExistence(timeout: 5))
            app.terminate()
        }

        exerciseAndCapture(windowSize: "wide", layoutName: "wide")
        exerciseAndCapture(windowSize: "compact", layoutName: "compact")
    }

    @MainActor
    func testVD204ShellExposesOnlyTheAppOwnedSidebarToggle() {
        let app = launchApp(fixture: "pipeline", windowSize: "compact")
        assertWindow(app.windows.firstMatch, hasSize: CGSize(width: 860, height: 640))

        let sidebarToggle = appOwnedSidebarToggle(in: app)
        let rail = sidebarRail(in: app)
        XCTAssertEqual(app.buttons.matching(identifier: "sidebar-collapse").count, 1)
        XCTAssertTrue(sidebarToggle.isHittable)
        XCTAssertEqual(sidebarToggle.label, "Collapse sidebar")
        XCTAssertEqual(frameworkSidebarToggleCount(in: app), 0)
        assertVisibleRailWidth(rail)
        let beforeCollapse = XCTAttachment(screenshot: app.screenshot())
        beforeCollapse.name = "VD204 HSplit shell before collapse"
        beforeCollapse.lifetime = .keepAlways
        add(beforeCollapse)

        sidebarToggle.tap()
        XCTAssertEqual(app.buttons.matching(identifier: "sidebar-collapse").count, 1)
        XCTAssertTrue(sidebarToggle.isHittable)
        XCTAssertEqual(sidebarToggle.label, "Show sidebar")
        XCTAssertEqual(frameworkSidebarToggleCount(in: app), 0)
        XCTAssertFalse(rail.exists)
        let afterCollapse = XCTAttachment(screenshot: app.screenshot())
        afterCollapse.name = "VD204 HSplit shell after collapse"
        afterCollapse.lifetime = .keepAlways
        add(afterCollapse)

        sidebarToggle.tap()
        XCTAssertEqual(app.buttons.matching(identifier: "sidebar-collapse").count, 1)
        XCTAssertTrue(sidebarToggle.isHittable)
        XCTAssertEqual(sidebarToggle.label, "Collapse sidebar")
        XCTAssertEqual(frameworkSidebarToggleCount(in: app), 0)
        assertVisibleRailWidth(rail)
        let afterRestore = XCTAttachment(screenshot: app.screenshot())
        afterRestore.name = "VD204 HSplit shell after restore"
        afterRestore.lifetime = .keepAlways
        add(afterRestore)
    }

    @MainActor
    func testVD204PipelineOpenDetailsSavesAndRelaunchesCanonicalEditWithActivityEvidence() {
        // This catches a route shortcut or fixture reseed that makes a table
        // edit look saved in memory but bypasses the canonical local store and
        // its existing opportunity_updated activity evidence.
        let persistedTitle = "Senior Product Manager — saved"
        var app = launchApp(fixture: "pipeline")
        app.descendants(matching: .any)["sidebar-pipeline"].tap()

        let seniorRow = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Senior Product Manager, Northstar Labs, Applied"))
            .firstMatch
        XCTAssertTrue(seniorRow.waitForExistence(timeout: 5))
        let seniorID = String(seniorRow.identifier.dropFirst("pipeline-table-row-".count))
        XCTAssertFalse(seniorID.isEmpty)
        seniorRow.tap()
        XCTAssertTrue(app.buttons["pipeline-open-details-\(seniorID)"].waitForExistence(timeout: 5))

        app.buttons["pipeline-open-details-\(seniorID)"].tap()
        let title = app.textFields["selected-opportunity-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.click()
        title.typeKey("a", modifierFlags: [.command])
        title.typeText(persistedTitle)
        app.buttons["save-opportunity-changes"].tap()

        app.descendants(matching: .any)["sidebar-activity-and-ai"].tap()
        XCTAssertTrue(
            app.textFields["activity-search"].waitForExistence(timeout: 5),
            "Saving through the canonical overview must return to the real local Activity & AI ledger."
        )
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "value BEGINSWITH %@", "Opportunity Updated")).firstMatch.waitForExistence(timeout: 5),
            "Saving through the canonical overview must retain the existing local update activity evidence."
        )

        app.terminate()
        app = launchApp(fixture: "pipeline")
        app.descendants(matching: .any)["sidebar-pipeline"].tap()

        let persistedRow = app.descendants(matching: .any)["pipeline-table-row-\(seniorID)"]
        XCTAssertTrue(persistedRow.waitForExistence(timeout: 5))
        XCTAssertTrue(persistedRow.label.hasPrefix("\(persistedTitle), Northstar Labs, Applied"))
        persistedRow.tap()
        XCTAssertTrue(app.descendants(matching: .any)["pipeline-inspector-\(seniorID)"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts[persistedTitle].exists)

        app.descendants(matching: .any)["sidebar-activity-and-ai"].tap()
        XCTAssertTrue(
            app.textFields["activity-search"].waitForExistence(timeout: 5),
            "Relaunch must return to the real local Activity & AI ledger before checking persisted evidence."
        )
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "value BEGINSWITH %@", "Opportunity Updated")).firstMatch.waitForExistence(timeout: 5),
            "Relaunch must reopen both the persisted canonical edit and its local activity evidence from the fixture store."
        )
    }

    @MainActor
    func testVD204PipelineFiltersUseOnlyTheSessionLocalControlsAndExposeTruthfulNoResults() {
        let app = launchApp(fixture: "pipeline")
        app.descendants(matching: .any)["sidebar-pipeline"].tap()

        let rows = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "pipeline-table-row-"))
        let search = app.textFields["opportunity-search"]
        let stage = app.popUpButtons["pipeline-stage-filter"]
        let includeClosed = app.checkBoxes["pipeline-include-closed"]

        XCTAssertTrue(search.waitForExistence(timeout: 5))
        XCTAssertEqual(rows.count, 5, "The closed fixture record must be excluded before the local Closed control is enabled.")
        let selectedRow = rows.firstMatch
        selectedRow.tap()
        XCTAssertEqual(selectedRow.value as? String, "Selected")

        search.click()
        search.typeText("northstar senior")
        XCTAssertEqual(rows.count, 1, "Multi-token search must match truthful title/company values across fields.")

        search.typeKey("a", modifierFlags: [.command])
        search.typeText("no matching opportunity")
        XCTAssertTrue(app.buttons["pipeline-clear-filters"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["No opportunities match"].exists)
        app.buttons["pipeline-clear-filters"].tap()
        XCTAssertEqual(rows.count, 5)
        XCTAssertFalse(app.descendants(matching: .any)["pipeline-inspector-drawer"].exists, "Filtering a selected record out must clear, rather than retain, the ephemeral inspector selection.")
        XCTAssertTrue(app.descendants(matching: .any)["pipeline-table-region"].isHittable)

        XCTAssertTrue(stage.waitForExistence(timeout: 5))
        stage.click()
        XCTAssertTrue(app.menuItems["Screening"].waitForExistence(timeout: 5))
        app.menuItems["Screening"].click()
        XCTAssertEqual(rows.count, 1)

        stage.click()
        XCTAssertTrue(app.menuItems["All stages"].waitForExistence(timeout: 5))
        app.menuItems["All stages"].click()
        XCTAssertTrue(includeClosed.waitForExistence(timeout: 5))
        let closedRow = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label BEGINSWITH %@", "pipeline-table-row-", "Closed opportunity, Northstar Labs, Closed"))
            .firstMatch
        XCTAssertFalse(
            closedRow.exists,
            "The known Closed fixture row must remain absent until the explicit Pipeline Closed control is enabled."
        )
        includeClosed.click()
        XCTAssertTrue(
            closedRow.waitForExistence(timeout: 5),
            "Only the explicit Pipeline Closed control may reveal the closed fixture record."
        )
    }

    @MainActor
    func testVD204DeletingASelectedTableRowUsesTheExistingConfirmationAndClearsTheInspector() {
        let app = launchApp(fixture: "pipeline")
        app.descendants(matching: .any)["sidebar-pipeline"].tap()

        let row = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "pipeline-table-row-"))
            .firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        let id = String(row.identifier.dropFirst("pipeline-table-row-".count))
        row.tap()
        XCTAssertTrue(app.descendants(matching: .any)["pipeline-inspector-\(id)"].waitForExistence(timeout: 5))

        row.rightClick()
        let delete = app.menuItems["pipeline-delete-\(id)"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        delete.click()
        XCTAssertTrue(app.staticTexts["Delete opportunity?"].waitForExistence(timeout: 5))
        app.sheets.firstMatch.buttons["Delete"].click()

        let deletedRow = app.descendants(matching: .any)["pipeline-table-row-\(id)"]
        XCTAssertTrue(
            deletedRow.waitForNonExistence(timeout: 5),
            "The deleted opportunity must eventually leave the real Pipeline table accessibility tree."
        )
        XCTAssertTrue(app.descendants(matching: .any)["pipeline-inspector-drawer"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["pipeline-table-region"].isHittable)
    }

    @MainActor
    func testSidebarDestinationsExposeTheActiveDailyRoute() {
        let app = launchApp(fixture: "empty")

        let destinations = [
            "sidebar-home",
            "sidebar-pipeline",
            "sidebar-contacts",
            "sidebar-activity-and-ai",
            "sidebar-settings"
        ]

        var previousSidebarID: String?
        for sidebarID in destinations {
            let sidebarItem = app.descendants(matching: .any)[sidebarID]
            XCTAssertTrue(sidebarItem.waitForExistence(timeout: 5))
            sidebarItem.tap()
            XCTAssertTrue(sidebarItem.isSelected, "Expected \(sidebarID) to expose selected accessibility state")
            let selectedDestinationCount = destinations.reduce(into: 0) { count, candidate in
                if app.descendants(matching: .any)[candidate].isSelected {
                    count += 1
                }
            }
            XCTAssertEqual(
                selectedDestinationCount,
                1,
                "Exactly one real sidebar destination must expose selected accessibility state."
            )
            if let previousSidebarID {
                XCTAssertFalse(
                    app.descendants(matching: .any)[previousSidebarID].isSelected,
                    "Expected \(previousSidebarID) to relinquish selected state after changing destinations"
                )
            }
            previousSidebarID = sidebarID
        }
    }

    @MainActor
    func testVD203HomeUsesTheLiveWorkspaceDashboardSurface() {
        let app = launchApp(fixture: "populated")

        XCTAssertTrue(app.descendants(matching: .any)["home-content"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["home-active-opportunities"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["home-applied-this-week"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["home-interviews"].exists)
        XCTAssertTrue(app.buttons["show-add-opportunity"].isHittable)
    }

    @MainActor
    func testVD203HomeOpenRoutesToTheAttentionTaskOpportunity() {
        let app = launchApp(fixture: "populated")
        let open = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "home-open-")).firstMatch

        XCTAssertTrue(open.waitForExistence(timeout: 5))
        open.tap()

        XCTAssertTrue(app.buttons["Back to Pipeline"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testVD203HomeActionMenuExposesAndCompletesTheTask() {
        let app = launchApp(fixture: "populated")
        let actions = homeActionMenu(in: app)

        XCTAssertTrue(actions.waitForExistence(timeout: 5))
        guard let card = homeAttentionCard(in: app, for: actions) else {
            XCTFail("The selected Home action menu must identify its task card.")
            return
        }
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertTrue(actions.isHittable)
        actions.tap()
        XCTAssertTrue(app.menuItems["Snooze 1 day"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.menuItems["Reschedule…"].exists)
        XCTAssertTrue(app.menuItems["Complete"].exists)
        app.menuItems["Complete"].tap()
        XCTAssertFalse(card.waitForExistence(timeout: 1))
    }

    @MainActor
    func testVD203HomeSnoozeUpdatesTheDisplayedDueDateAndSurvivesRelaunch() {
        let app = launchApp(fixture: "populated")
        let actions = homeActionMenu(in: app)
        let dueDate = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "home-due-")).firstMatch

        XCTAssertTrue(actions.waitForExistence(timeout: 5))
        XCTAssertTrue(dueDate.waitForExistence(timeout: 5))
        let originalDueDate = dueDate.value as? String
        actions.tap()
        XCTAssertTrue(app.menuItems["Snooze 1 day"].waitForExistence(timeout: 5))
        app.menuItems["Snooze 1 day"].tap()
        XCTAssertNotEqual(dueDate.value as? String, originalDueDate)

        app.terminate()
        app.launch()
        app.activate()
        XCTAssertTrue(dueDate.waitForExistence(timeout: 5))
        XCTAssertNotEqual(dueDate.value as? String, originalDueDate)
    }

    @MainActor
    func testVD203HomeReconciliationActionMenuHidesDirectCompletion() {
        let app = launchApp(fixture: "reconciliation")
        let actions = app.menuButtons["Actions for Review reconciliation evidence"]

        XCTAssertTrue(actions.waitForExistence(timeout: 5))
        actions.tap()
        XCTAssertTrue(app.menuItems["Snooze 1 day"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.menuItems["Reschedule…"].exists)
        XCTAssertFalse(app.menuItems["Complete"].exists)
    }

    @MainActor
    func testVD203HomeReconciliationOpenRoutesToReconcilePosting() {
        let app = launchApp(fixture: "reconciliation")
        let open = app.buttons["Open Review reconciliation evidence"]

        XCTAssertTrue(open.waitForExistence(timeout: 5))
        open.tap()
        XCTAssertTrue(app.staticTexts["Reconcile posting"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testVD203HomeReschedulePresentsAndSavesTheActionSheet() {
        let app = launchApp(fixture: "populated")
        let actions = homeActionMenu(in: app)

        XCTAssertTrue(actions.waitForExistence(timeout: 5))
        actions.tap()
        XCTAssertTrue(app.menuItems["Reschedule…"].waitForExistence(timeout: 5))
        app.menuItems["Reschedule…"].tap()
        XCTAssertTrue(app.staticTexts["Reschedule action"].waitForExistence(timeout: 5))
        app.buttons["Save locally"].tap()
        XCTAssertFalse(app.staticTexts["Reschedule action"].waitForExistence(timeout: 1))
    }

    @MainActor
    func testVD203HomeCompletionPersistsAfterFixtureRelaunch() {
        let app = launchApp(fixture: "populated")
        let actions = homeActionMenu(in: app)

        XCTAssertTrue(actions.waitForExistence(timeout: 5))
        guard let card = homeAttentionCard(in: app, for: actions) else {
            XCTFail("The selected Home action menu must identify its task card.")
            return
        }
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        actions.tap()
        app.menuItems["Complete"].tap()
        XCTAssertFalse(card.waitForExistence(timeout: 1))

        app.terminate()
        app.launch()
        app.activate()
        XCTAssertTrue(app.descendants(matching: .any)["home-content"].waitForExistence(timeout: 5))
        let cardsAfterRelaunch = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "home-attention-"))
        XCTAssertEqual(cardsAfterRelaunch.count, 0, "A completed Home task must remain complete after the fixture process relaunches.")
    }

    @MainActor
    func testVD203HomeSnoozeChangesAndPersistsTheDueDateAfterFixtureRelaunch() {
        let app = launchApp(fixture: "populated")
        let card = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "home-attention-"))
            .firstMatch
        let due = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "home-due-"))
            .firstMatch
        let actions = homeActionMenu(in: app)

        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertTrue(due.waitForExistence(timeout: 5))
        let originalDue = due.label
        actions.tap()
        app.menuItems["Snooze 1 day"].tap()
        XCTAssertTrue(due.waitForExistence(timeout: 5))
        XCTAssertNotEqual(due.label, originalDue)
        let snoozedDue = due.label

        app.terminate()
        app.launch()
        app.activate()
        let persistedDue = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "home-due-"))
            .firstMatch
        XCTAssertTrue(persistedDue.waitForExistence(timeout: 5))
        XCTAssertEqual(persistedDue.label, snoozedDue)
    }

    @MainActor
    func testVD203HomeRescheduleChangesAndPersistsTheDueDateAfterFixtureRelaunch() {
        let app = launchApp(fixture: "populated")
        let due = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "home-due-"))
            .firstMatch
        let actions = homeActionMenu(in: app)

        XCTAssertTrue(due.waitForExistence(timeout: 5))
        let originalDue = due.label
        actions.tap()
        app.menuItems["Reschedule…"].tap()
        let picker = app.datePickers["home-reschedule-due-date"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        XCTAssertEqual(picker.label, "New due date")
        picker.click()
        picker.typeKey(.upArrow, modifierFlags: [])
        app.buttons["Save locally"].tap()
        XCTAssertTrue(due.waitForExistence(timeout: 5))
        XCTAssertNotEqual(due.label, originalDue)
        let rescheduledDue = due.label

        app.terminate()
        app.launch()
        app.activate()
        let persistedDue = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "home-due-"))
            .firstMatch
        XCTAssertTrue(persistedDue.waitForExistence(timeout: 5))
        XCTAssertEqual(persistedDue.label, rescheduledDue)
    }

    @MainActor
    func testVD203HomeFixtureUsesItsFixedCalendarForRenderedAppliedMetric() {
        let app = launchApp(fixture: "populated")

        let metric = app.descendants(matching: .any)["home-applied-this-week"]
        XCTAssertTrue(metric.waitForExistence(timeout: 5))
        XCTAssertEqual(
            metric.value as? String,
            "Applied this week, 1",
            "The populated fixture's fixed-week application must render as one applied this week."
        )
    }

    @MainActor
    func testVD203HomeIsUnavailableInTheErrorFixture() {
        let app = launchApp(fixture: "error")

        XCTAssertTrue(app.descendants(matching: .any)["workspace-onboarding"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["daily-route-home"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["home-content"].exists)
    }

    @MainActor
    func testKeyboardActivationChangesFromHomeToANonCurrentSidebarDestination() {
        // The empty fixture intentionally represents an unopened workspace;
        // exercise real Home and Settings content with a ready workspace.
        let app = launchApp(fixture: "populated")
        let home = app.descendants(matching: .any)["sidebar-home"]
        let settings = app.descendants(matching: .any)["sidebar-settings"]

        XCTAssertTrue(home.waitForExistence(timeout: 5))
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        home.tap()
        XCTAssertTrue(home.isSelected)
        XCTAssertTrue(app.descendants(matching: .any)["home-content"].waitForExistence(timeout: 5))

        for _ in 0...(5 + 2) where (settings.value as? String) != "Keyboard focus" {
            app.typeKey(.tab, modifierFlags: [])
        }
        XCTAssertEqual(settings.value as? String, "Keyboard focus")

        app.typeKey(.space, modifierFlags: [])
        XCTAssertTrue(settings.isSelected)
        XCTAssertFalse(home.isSelected)
        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.buttons["set-up-recovery-key"].waitForExistence(timeout: 5),
            "Keyboard Space must select Settings and expose its real recovery setup control."
        )
    }

    @MainActor
    func testRecoveryFixtureShowsOnlyRecoveryActionsAndDoesNotOpenAWorkspace() {
        let app = launchApp(fixture: "recovery")

        XCTAssertTrue(app.descendants(matching: .any)["workspace-onboarding"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["workspace-gate-status"].waitForExistence(timeout: 5))
        let recheck = app.buttons["recheck-local-workspace"]
        XCTAssertTrue(recheck.waitForExistence(timeout: 5))
        XCTAssertTrue(recheck.isHittable)
        XCTAssertEqual(recheck.label, "Recheck local workspace")
        XCTAssertTrue(app.buttons["choose-existing-workspace-folder"].isHittable)
        XCTAssertTrue(app.buttons["create-separate-local-workspace"].isHittable)
        for normalRoute in ["daily-route-home", "daily-route-pipeline", "daily-route-contacts", "daily-route-activity-ai", "daily-route-settings"] {
            XCTAssertFalse(app.descendants(matching: .any)[normalRoute].exists, "Recovery must not expose normal workspace route \(normalRoute).")
        }
        recheck.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["workspace-onboarding"].exists,
            "Rechecking a recovery-only fixture must not open or create a workspace"
        )
        XCTAssertFalse(app.descendants(matching: .any)["daily-route-home"].exists)
    }

    @MainActor
    func testPopulatedFixtureCanOpenTableSelectionDetailsAndSafelyReturnToPipeline() {
        let app = launchApp(fixture: "populated")
        let pipeline = app.descendants(matching: .any)["sidebar-pipeline"]
        XCTAssertTrue(pipeline.waitForExistence(timeout: 5))
        pipeline.tap()

        let row = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "pipeline-table-row-"))
            .firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        let id = String(row.identifier.dropFirst("pipeline-table-row-".count))
        row.tap()
        XCTAssertTrue(app.descendants(matching: .any)["pipeline-inspector-\(id)"].waitForExistence(timeout: 5))

        let openDetails = app.buttons["pipeline-open-details-\(id)"]
        XCTAssertTrue(openDetails.waitForExistence(timeout: 5))
        openDetails.tap()
        XCTAssertTrue(app.buttons["Back to Pipeline"].waitForExistence(timeout: 5))

        app.buttons["Back to Pipeline"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["pipeline-table-row-\(id)"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Back to Pipeline"].exists)
    }

    @MainActor
    func testTableSelectionOpenDetailsAndSidebarDepartureLeaveOpportunityDetail() {
        let app = launchApp(fixture: "populated")
        let pipeline = app.descendants(matching: .any)["sidebar-pipeline"]
        XCTAssertTrue(pipeline.waitForExistence(timeout: 5))
        pipeline.tap()

        let row = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "pipeline-table-row-"))
            .firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        let id = String(row.identifier.dropFirst("pipeline-table-row-".count))
        row.tap()
        XCTAssertTrue(app.descendants(matching: .any)["pipeline-inspector-\(id)"].waitForExistence(timeout: 5))
        app.buttons["pipeline-open-details-\(id)"].tap()
        XCTAssertTrue(app.buttons["Back to Pipeline"].waitForExistence(timeout: 5))

        let contacts = app.descendants(matching: .any)["sidebar-contacts"]
        XCTAssertTrue(contacts.waitForExistence(timeout: 5))
        contacts.tap()
        XCTAssertTrue(contacts.isSelected)
        XCTAssertFalse(app.buttons["Back to Pipeline"].exists)
    }

    // VD2-02 red proof: the visual fixture needs a deterministic, non-network
    // active-check seam so departure blocking can be exercised safely.
    @MainActor
    func testVD202PublicURLCheckBlocksRailDepartureUntilCancelled() {
        let app = launchApp(fixture: "reconciliation")
        app.descendants(matching: .any)["sidebar-pipeline"].tap()
        let row = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "pipeline-table-row-"))
            .firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        let id = String(row.identifier.dropFirst("pipeline-table-row-".count))
        XCTAssertFalse(id.isEmpty)
        row.tap()
        let openDetails = app.buttons["pipeline-open-details-\(id)"]
        XCTAssertTrue(openDetails.waitForExistence(timeout: 5))
        openDetails.tap()

        let more = app.descendants(matching: .any)["More"]
        XCTAssertTrue(more.waitForExistence(timeout: 5))
        more.tap()
        let reconcile = app.menuItems["Reconcile posting"]
        XCTAssertTrue(reconcile.waitForExistence(timeout: 5))
        reconcile.click()
        XCTAssertTrue(app.staticTexts["Reconcile posting"].waitForExistence(timeout: 5))

        app.buttons["check-public-url"].tap()
        let cancel = app.buttons["cancel-public-url-check"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 2), "Fixture host must expose a deterministic active-check cancellation control.")
        app.descendants(matching: .any)["sidebar-contacts"].tap()
        XCTAssertFalse(app.descendants(matching: .any)["daily-route-contacts"].exists, "An active check must block rail departure.")
        cancel.tap()
        XCTAssertTrue(cancel.waitForNonExistence(timeout: 5), "The active-check cancellation control must leave before retrying departure.")
        XCTAssertTrue(
            app.buttons["check-public-url"].waitForExistence(timeout: 5),
            "Cancellation must complete before the guarded sidebar departure is retried."
        )
        let contacts = app.descendants(matching: .any)["sidebar-contacts"]
        XCTAssertTrue(contacts.waitForExistence(timeout: 5))
        XCTAssertTrue(contacts.isHittable, "The real Contacts rail control must be usable once cancellation completes.")
        contacts.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(contacts.isSelected, "After cancellation, Contacts must become the active rail destination.")
        XCTAssertTrue(
            app.textFields["contact-search"].waitForExistence(timeout: 5),
            "After cancellation, the real Contacts surface must replace the reconciliation route."
        )
    }

    @MainActor
    func testVD202CompactRailKeepsNativeWindowControlsReachable() {
        let app = launchApp(fixture: "empty", windowSize: "compact")
        let window = app.windows.firstMatch
        // The 860×600 test-host request is constrained to the same supported
        // 860×640 production-shell frame asserted by the compact pipeline test.
        assertWindow(window, hasSize: CGSize(width: 860, height: 640))
        XCTAssertEqual(frameworkSidebarToggleCount(in: app), 0)
        let sidebarToggle = appOwnedSidebarToggle(in: app)
        XCTAssertEqual(app.buttons.matching(identifier: "sidebar-collapse").count, 1)
        XCTAssertTrue(sidebarToggle.isHittable)
        XCTAssertEqual(sidebarToggle.label, "Collapse sidebar")
        assertNativeWindowControlsAreHittable(in: app)

        sidebarToggle.tap()
        XCTAssertEqual(frameworkSidebarToggleCount(in: app), 0)
        XCTAssertEqual(app.buttons.matching(identifier: "sidebar-collapse").count, 1)
        XCTAssertTrue(sidebarToggle.isHittable)
        XCTAssertEqual(sidebarToggle.label, "Show sidebar")
        assertNativeWindowControlsAreHittable(in: app)

        sidebarToggle.tap()
        XCTAssertEqual(frameworkSidebarToggleCount(in: app), 0)
        XCTAssertEqual(app.buttons.matching(identifier: "sidebar-collapse").count, 1)
        XCTAssertTrue(sidebarToggle.isHittable)
        XCTAssertEqual(sidebarToggle.label, "Collapse sidebar")
        assertNativeWindowControlsAreHittable(in: app)
    }

    @MainActor
    func testVD202RecoveryFixtureExposesAnExplicitRecoveryOnlySafetyMarker() {
        let app = launchApp(fixture: "recovery")
        XCTAssertTrue(
            app.descendants(matching: .any)["recovery-only-workspace-gate"].waitForExistence(timeout: 2),
            "Recovery fixtures must expose an explicit marker that normal workspace routes cannot become active."
        )
    }
}
