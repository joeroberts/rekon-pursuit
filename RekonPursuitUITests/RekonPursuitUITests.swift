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
    private func openContactsFixture(
        windowSize: String = "wide",
        fixture: String = "contacts",
        session: String? = nil
    ) -> XCUIApplication {
        let app = launchApp(fixture: fixture, windowSize: windowSize, session: session)
        let contacts = app.descendants(matching: .any)["sidebar-contacts"]
        XCTAssertTrue(contacts.waitForExistence(timeout: 5), "Contacts navigation must be available in the ready fixture.")
        contacts.tap()
        XCTAssertTrue(contacts.isSelected, "The Contacts route must become selected before presentation contracts are evaluated.")
        XCTAssertTrue(app.textFields["contact-search"].waitForExistence(timeout: 5), "The existing Contacts route must load before a VD2-06 presentation RED can qualify.")
        return app
    }

    @MainActor
    private func replaceText(in field: XCUIElement, with value: String) {
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Expected the named field before replacing its value.")
        field.click()
        field.typeKey("a", modifierFlags: [.command])
        field.typeText(value)
    }

    @MainActor
    private func activityEvidence(named prefix: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["sidebar-activity-and-ai"].tap()
        XCTAssertTrue(app.textFields["activity-search"].waitForExistence(timeout: 5), "Expected the real local Activity & AI ledger.")
        return app.staticTexts
            .matching(NSPredicate(format: "value BEGINSWITH %@", prefix))
            .firstMatch
    }

    @MainActor
    private func tabToKeyboardFocus(
        _ target: XCUIElement,
        in app: XCUIApplication,
        maximumTabPresses: Int
    ) -> Bool {
        for _ in 0...maximumTabPresses {
            if (target.value as? String ?? "").contains("Keyboard focus") {
                return true
            }
            app.typeKey(.tab, modifierFlags: [])
            let focusExpectation = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "value CONTAINS %@", "Keyboard focus"),
                object: target
            )
            if XCTWaiter().wait(for: [focusExpectation], timeout: 0.2) == .completed {
                return true
            }
        }
        return false
    }

    @MainActor
    private func recordUnrenderedVisualSelectors(
        _ selectors: [String],
        in app: XCUIApplication
    ) -> Bool {
        var isMissingAnySelector = false
        for selector in selectors {
            let exactMatches = app.descendants(matching: .any)
                .matching(NSPredicate(format: "identifier == %@", selector))
                .count
            let isRendered = exactMatches > 0
                || (selector == "settings-reference-tab-strip"
                    && app.descendants(matching: .any)["settings-secondary-navigation"].exists)
                || (selector == "settings-reference-tab-recovery-archives"
                    && app.buttons["settings-section-recovery-archives"].exists)
            if !isRendered {
                isMissingAnySelector = true
                XCTFail("VD2-07x RED: unrendered visual selector \(selector)")
            }
        }
        return isMissingAnySelector
    }

    @MainActor
    private func assertNoActionableDescendants(
        in element: XCUIElement,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for elementType in [XCUIElement.ElementType.button, .link, .menuButton, .textField, .switch, .checkBox] {
            XCTAssertEqual(element.descendants(matching: elementType).count, 0, file: file, line: line)
        }
    }

    @MainActor
    private func assertNoDisclosedSettingsSentinels(
        _ sentinels: [String],
        in element: XCUIElement,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for sentinel in sentinels {
            let disclosed = element.descendants(matching: .any).matching(
                NSPredicate(format: "label CONTAINS[c] %@ OR value CONTAINS[c] %@", sentinel, sentinel)
            ).firstMatch
            XCTAssertFalse(disclosed.exists, "Settings disclosed \(sentinel).", file: file, line: line)
        }
    }

    @MainActor
    private func attachContactsPresentationScreenshot(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func attachSettingsPresentationScreenshot(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
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
    private func canonicalStageSubmenu(from moveItem: XCUIElement) -> XCUIElement {
        let expectedTargets = ["Saved", "Applied", "Screening", "Interviewing", "Offer", "Closed"]
        let stageMenu = moveItem.descendants(matching: .menu).firstMatch
        XCTAssertTrue(
            stageMenu.waitForExistence(timeout: 5),
            "Expected Move to stage… to expose its canonical submenu."
        )
        let directItems = stageMenu.children(matching: .menuItem)
        XCTAssertEqual(directItems.count, expectedTargets.count)
        for (index, title) in expectedTargets.enumerated() {
            XCTAssertEqual(directItems.element(boundBy: index).label, title)
        }
        XCTAssertTrue(directItems["Saved"].isSelected)
        return stageMenu
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
        move.hover()
        XCTAssertTrue(app.menuItems["Saved"].waitForExistence(timeout: 5))
        let stageMenu = canonicalStageSubmenu(from: move)
        XCTAssertTrue(stageMenu.waitForExistence(timeout: 5))
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
        move.hover()
        XCTAssertTrue(app.menuItems["Saved"].waitForExistence(timeout: 5))
        let presentedMenu = canonicalStageSubmenu(from: move)
        XCTAssertTrue(presentedMenu.waitForExistence(timeout: 5))
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
    func testVD206ContactsWideMasterDetailContract() {
        // This catches a Contacts redesign that omits the named wide regions,
        // independent scroll containers, selected-row value, or explicit
        // action controls required for a usable master-detail presentation.
        let app = openContactsFixture()
        defer { attachContactsPresentationScreenshot(app, named: "VD2-06 Contacts wide master-detail RED") }

        XCTAssertTrue(app.descendants(matching: .any)["contact-wide-master-detail"].waitForExistence(timeout: 2), "Missing VD2-06 wide Contacts master-detail region.")
        XCTAssertTrue(app.descendants(matching: .any)["contact-list-scroll"].exists, "Missing VD2-06 independently scrollable contact list region.")
        XCTAssertTrue(app.descendants(matching: .any)["contact-detail-scroll"].exists, "Missing VD2-06 independently scrollable contact detail region.")
        XCTAssertTrue(app.descendants(matching: .any)["contact-row-contacts-primary"].exists, "Missing VD2-06 Contacts Primary row identifier.")
        XCTAssertEqual(app.descendants(matching: .any)["contact-row-contacts-primary"].value as? String, "Selected", "Missing non-color selected Contacts Primary value.")
        XCTAssertTrue(app.buttons["contact-new"].exists, "Missing VD2-06 New contact control.")
        XCTAssertTrue(app.buttons["contact-edit"].exists, "Missing VD2-06 Edit contact control.")
        XCTAssertTrue(app.buttons["contact-overflow"].exists, "Missing VD2-06 contact overflow control.")
        XCTAssertTrue(app.buttons["contact-related-disclosure"].exists, "Missing VD2-06 related-opportunities disclosure control.")
        XCTAssertTrue(app.buttons["contact-manage-related"].exists, "Missing VD2-06 Manage related opportunities control.")
    }

    @MainActor
    func testVD206ContactsCompactDetailBackContract() {
        // This catches a compact Contacts route that leaves the master pane in
        // place, has no named Back control, or cannot restore focus to the
        // selected source row after returning.
        let app = openContactsFixture(windowSize: "compact")
        defer { attachContactsPresentationScreenshot(app, named: "VD2-06 Contacts compact detail RED") }

        XCTAssertTrue(app.descendants(matching: .any)["contact-row-contacts-primary"].waitForExistence(timeout: 2), "Missing VD2-06 compact Contacts Primary row identifier.")
        app.descendants(matching: .any)["contact-row-contacts-primary"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["contact-compact-detail"].waitForExistence(timeout: 2), "Missing VD2-06 compact detail replacement region.")
        XCTAssertTrue(app.buttons["contact-detail-back"].exists, "Missing VD2-06 compact Back control.")
        XCTAssertEqual(app.descendants(matching: .any)["contact-focus-return"].value as? String, "Contacts Primary", "Missing VD2-06 focus-return state for Contacts Primary.")
    }

    @MainActor
    func testVD206ContactsTruthfulEmptyStatesContract() {
        // This catches an empty or filtered Contacts route that fabricates a
        // selected record or leaves no stable, named state for empty results
        // and unlinked related-opportunity management.
        let emptyApp = openContactsFixture(fixture: "contacts-empty")
        defer { attachContactsPresentationScreenshot(emptyApp, named: "VD2-06 Contacts truthful empty states RED") }

        XCTAssertTrue(emptyApp.descendants(matching: .any)["contact-empty-state"].waitForExistence(timeout: 2), "Missing VD2-06 empty Contacts state.")
        XCTAssertTrue(emptyApp.descendants(matching: .any)["contact-no-selection-state"].exists, "Missing VD2-06 no-selection Contacts state.")
        XCTAssertTrue(emptyApp.descendants(matching: .any)["contact-related-opportunities-empty-state"].exists, "Missing VD2-06 no-related-opportunities state.")

        let populatedApp = openContactsFixture(fixture: "contacts")
        defer { attachContactsPresentationScreenshot(populatedApp, named: "VD2-06 Contacts no-results state RED") }
        let search = populatedApp.textFields["contact-search"]
        search.click()
        search.typeText("No matching contact")
        XCTAssertTrue(populatedApp.descendants(matching: .any)["contact-no-results-state"].waitForExistence(timeout: 2), "Missing VD2-06 Contacts no-results state.")
    }

    @MainActor
    func testVD206ContactsEditCancelSaveAndRelaunchContract() {
        // This catches a Contact editor that writes on Cancel, loses a valid
        // save across a fresh process, or omits the existing local activity
        // evidence for the real persistence path.
        let session = "vd206-contact-editor-\(UUID().uuidString)"
        var app = openContactsFixture(session: session)
        let primaryRow = app.descendants(matching: .any)["contact-row-contacts-primary"]
        XCTAssertTrue(primaryRow.waitForExistence(timeout: 5))

        app.buttons["contact-edit"].click()
        replaceText(in: app.textFields["contact-name"], with: "Cancelled edit")
        app.buttons["Cancel"].click()
        XCTAssertTrue(primaryRow.waitForExistence(timeout: 5))
        XCTAssertTrue(
            (primaryRow.value as? String ?? "").hasPrefix("Selected"),
            "Cancelling an edit must retain the selected state even when keyboard focus is also exposed."
        )

        app.buttons["contact-new"].click()
        replaceText(in: app.textFields["contact-name"], with: "Cancelled new contact")
        app.buttons["Cancel"].click()
        XCTAssertFalse(app.descendants(matching: .any)["contact-row-cancelled-new-contact"].exists)

        app.buttons["contact-new"].click()
        replaceText(in: app.textFields["contact-name"], with: "Contacts Saved")
        app.buttons["save-contact"].click()
        XCTAssertTrue(app.descendants(matching: .any)["contact-row-contacts-saved"].waitForExistence(timeout: 5))

        app.terminate()
        app = openContactsFixture(session: session)
        XCTAssertTrue(app.descendants(matching: .any)["contact-row-contacts-primary"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["contact-row-cancelled-new-contact"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["contact-row-contacts-saved"].exists)
        XCTAssertTrue(
            activityEvidence(named: "Contact Created", in: app).waitForExistence(timeout: 5),
            "A valid Contact save must retain the existing local create activity after relaunch."
        )
    }

    @MainActor
    func testVD206ContactChannelsEditorAndDetailActionsContract() {
        // This catches a missing editor channel, a channel value that does not
        // survive the real save/relaunch path, or detail actions exposed for
        // an empty channel.
        let session = "vd206-contact-channels-\(UUID().uuidString)"
        var app = openContactsFixture(session: session)
        let primaryRow = app.descendants(matching: .any)["contact-row-contacts-primary"]
        XCTAssertTrue(primaryRow.waitForExistence(timeout: 5))
        primaryRow.click()
        app.buttons["contact-edit"].click()
        for identifier in ["contact-work-email", "contact-personal-email", "contact-mobile-phone", "contact-office-phone", "contact-linkedin", "contact-instagram", "contact-facebook"] {
            XCTAssertTrue(app.textFields[identifier].waitForExistence(timeout: 5), "Missing Contact channel editor \(identifier).")
        }
        replaceText(in: app.textFields["contact-work-email"], with: "saved.work@example.test")
        replaceText(in: app.textFields["contact-personal-email"], with: "saved.personal@example.test")
        replaceText(in: app.textFields["contact-mobile-phone"], with: "+1 212 555 0191")
        replaceText(in: app.textFields["contact-office-phone"], with: "+1 212 555 0192")
        replaceText(in: app.textFields["contact-linkedin"], with: "https://linkedin.example.test/in/saved")
        replaceText(in: app.textFields["contact-instagram"], with: "https://instagram.example.test/saved")
        replaceText(in: app.textFields["contact-facebook"], with: "https://facebook.example.test/saved")
        app.buttons["save-contact"].click()

        app.terminate()
        app = openContactsFixture(session: session)
        app.descendants(matching: .any)["contact-row-contacts-primary"].click()
        for label in [
            "Work email for Contacts Primary: saved.work@example.test",
            "Personal email for Contacts Primary: saved.personal@example.test",
            "Mobile phone for Contacts Primary: +1 212 555 0191",
            "Office phone for Contacts Primary: +1 212 555 0192",
            "LinkedIn for Contacts Primary: https://linkedin.example.test/in/saved",
            "Instagram for Contacts Primary: https://instagram.example.test/saved",
            "Facebook for Contacts Primary: https://facebook.example.test/saved"
        ] {
            XCTAssertTrue(app.links.matching(NSPredicate(format: "label == %@", label)).firstMatch.waitForExistence(timeout: 5), "Missing populated Contact action \(label).")
        }

        app.descendants(matching: .any)["contact-row-contacts-secondary"].click()
        XCTAssertEqual(app.links.matching(NSPredicate(format: "label CONTAINS %@", "for Contacts Secondary:")).count, 0, "Empty Contact channels must not expose detail actions.")
    }

    @MainActor
    func testVD206ContactsRelatedOpportunitiesAndAssociationContract() {
        // This catches related-opportunity browsing that writes implicitly or
        // Link/Unlink commands that fail to use the persisted association and
        // existing local audit path.
        let session = "vd206-contact-association-\(UUID().uuidString)"
        var app = openContactsFixture(session: session)
        let disclosure = app.buttons["contact-related-disclosure"]
        XCTAssertTrue(disclosure.waitForExistence(timeout: 5))
        disclosure.click()
        XCTAssertTrue((disclosure.value as? String ?? "").hasPrefix("Expanded"))
        XCTAssertTrue(app.buttons["Open"].waitForExistence(timeout: 5))
        app.buttons["Open"].click()
        XCTAssertTrue(app.buttons["Back to Pipeline"].waitForExistence(timeout: 5), "Open must use the canonical opportunity route.")
        app.descendants(matching: .any)["sidebar-contacts"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["contact-row-contacts-primary"].waitForExistence(timeout: 5))

        app.buttons["contact-manage-related"].click()
        XCTAssertTrue(app.buttons["Link"].waitForExistence(timeout: 5))
        app.buttons["Link"].click()
        app.buttons["Done"].click()

        app.terminate()
        app = openContactsFixture(session: session)
        app.buttons["contact-related-disclosure"].click()
        XCTAssertEqual(app.buttons.matching(identifier: "Open").count, 2, "Explicit Link must persist the second fixture association after relaunch.")
        XCTAssertTrue(
            activityEvidence(named: "Contact Linked", in: app).waitForExistence(timeout: 5),
            "Explicit Link must retain existing local activity evidence after relaunch."
        )

        app.descendants(matching: .any)["sidebar-contacts"].tap()
        XCTAssertTrue(app.buttons["contact-manage-related"].waitForExistence(timeout: 5))
        app.buttons["contact-manage-related"].click()
        let unlink = app.buttons["Unlink"].firstMatch
        XCTAssertTrue(unlink.waitForExistence(timeout: 5))
        unlink.click()
        app.buttons["Done"].click()

        app.terminate()
        app = openContactsFixture(session: session)
        XCTAssertTrue(
            activityEvidence(named: "Contact Unlinked", in: app).waitForExistence(timeout: 5),
            "Explicit Unlink must retain existing local activity evidence after relaunch."
        )
        app.descendants(matching: .any)["sidebar-contacts"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["contact-row-contacts-primary"].waitForExistence(timeout: 5))
        let persistedDisclosure = app.buttons["contact-related-disclosure"]
        XCTAssertTrue(persistedDisclosure.waitForExistence(timeout: 5))
        persistedDisclosure.click()
        XCTAssertEqual(
            app.buttons.matching(identifier: "Open").count,
            1,
            "Explicit Unlink must leave exactly one persisted related-opportunity Open action after relaunch."
        )
    }

    @MainActor
    func testVD206ContactsDeleteSafetyContract() {
        // This catches a destructive flow that writes on cancellation or
        // leaves a deleted Contact selected in the detail/relationship state.
        let cancelSession = "vd206-contact-delete-cancel-\(UUID().uuidString)"
        var cancelApp = openContactsFixture(session: cancelSession)
        let cancelRow = cancelApp.descendants(matching: .any)["contact-row-contacts-primary"]
        XCTAssertTrue(cancelRow.waitForExistence(timeout: 5))
        cancelApp.buttons["contact-overflow"].click()
        let cancelDeleteContact = cancelApp.sheets.buttons["Delete contact"].firstMatch
        XCTAssertTrue(cancelDeleteContact.waitForExistence(timeout: 5))
        cancelDeleteContact.click()
        let cancelConfirmation = cancelApp.sheets.buttons["Cancel"]
        XCTAssertTrue(cancelConfirmation.waitForExistence(timeout: 5))
        cancelConfirmation.click()
        XCTAssertTrue(cancelRow.waitForExistence(timeout: 5))
        XCTAssertEqual(cancelRow.value as? String, "Selected")
        cancelApp.terminate()
        cancelApp = openContactsFixture(session: cancelSession)
        XCTAssertTrue(cancelApp.descendants(matching: .any)["contact-row-contacts-primary"].waitForExistence(timeout: 5))

        let confirmSession = "vd206-contact-delete-confirm-\(UUID().uuidString)"
        var confirmApp = openContactsFixture(session: confirmSession)
        confirmApp.buttons["contact-overflow"].click()
        let confirmDeleteContact = confirmApp.sheets.buttons["Delete contact"].firstMatch
        XCTAssertTrue(confirmDeleteContact.waitForExistence(timeout: 5))
        confirmDeleteContact.click()
        let confirmDeletion = confirmApp.sheets.buttons["Delete"]
        XCTAssertTrue(confirmDeletion.waitForExistence(timeout: 5))
        confirmDeletion.click()
        XCTAssertTrue(confirmApp.descendants(matching: .any)["contact-row-contacts-primary"].waitForNonExistence(timeout: 5))
        XCTAssertFalse(confirmApp.staticTexts["Contacts Primary"].exists, "A confirmed deletion must remove the stale selected detail.")
        confirmApp.terminate()
        confirmApp = openContactsFixture(session: confirmSession)
        XCTAssertFalse(confirmApp.descendants(matching: .any)["contact-row-contacts-primary"].exists)
        XCTAssertTrue(
            activityEvidence(named: "Contact Deleted", in: confirmApp).waitForExistence(timeout: 5),
            "Confirmed deletion must retain existing local deletion activity after relaunch."
        )
    }

    @MainActor
    func testVD206ContactsErrorAccessibilityContract() {
        // This catches a validation failure that hides the draft/recovery
        // controls, lacks a named accessible error, or confuses normalized
        // duplicate Contact rows in the accessibility tree.
        let session = "vd206-contact-accessibility-\(UUID().uuidString)"
        let app = openContactsFixture(session: session)
        let primaryRow = app.descendants(matching: .any)["contact-row-contacts-primary"]
        XCTAssertTrue(primaryRow.waitForExistence(timeout: 5))
        XCTAssertEqual(primaryRow.value as? String, "Selected")

        let disclosure = app.buttons["contact-related-disclosure"]
        disclosure.click()
        XCTAssertTrue((disclosure.value as? String ?? "").hasPrefix("Expanded"), "Disclosure state needs an accessible non-color value.")

        app.buttons["contact-new"].click()
        replaceText(in: app.textFields["contact-name"], with: "Contacts Primary")
        replaceText(in: app.textFields["contact-work-email"], with: "invalid@")
        app.buttons["save-contact"].click()
        let error = app.descendants(matching: .any)["contact-operation-error"]
        XCTAssertTrue(error.waitForExistence(timeout: 5))
        XCTAssertFalse(error.label.isEmpty)
        XCTAssertTrue(app.buttons["save-contact"].exists)
        XCTAssertTrue(app.buttons["Cancel"].exists)
        XCTAssertEqual(
            app.descendants(matching: .any)
                .matching(identifier: "contact-row-contacts-primary").count,
            1,
            "Validation must not announce or persist a false success."
        )

        replaceText(in: app.textFields["contact-work-email"], with: "primary-duplicate@example.test")
        app.buttons["save-contact"].click()
        let duplicateRows = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "contact-row-contacts-primary-"))
        XCTAssertEqual(duplicateRows.count, 2, "Normalized duplicate names must receive two persisted-ID-qualified row identifiers.")
        XCTAssertNotEqual(duplicateRows.element(boundBy: 0).identifier, duplicateRows.element(boundBy: 1).identifier)
    }

    @MainActor
    func testVD206ContactsKeyboardContract() {
        // This catches Contacts controls that are present only for pointer use
        // or lose their truthful compact/error states when activated through
        // their semantic keyboard actions.
        let app = openContactsFixture(windowSize: "compact")
        let primaryRow = app.descendants(matching: .any)["contact-row-contacts-primary"]
        XCTAssertTrue(primaryRow.waitForExistence(timeout: 5))
        app.textFields["contact-search"].click()
        XCTAssertTrue(
            tabToKeyboardFocus(primaryRow, in: app, maximumTabPresses: 32),
            "The compact contact row must expose keyboard focus before Space activates it."
        )
        app.typeKey(.space, modifierFlags: [])
        XCTAssertTrue(app.descendants(matching: .any)["contact-compact-detail"].waitForExistence(timeout: 5))
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(primaryRow.waitForExistence(timeout: 5))

        app.buttons["contact-new"].click()
        XCTAssertTrue(app.textFields["contact-name"].waitForExistence(timeout: 5))
        replaceText(in: app.textFields["contact-name"], with: "Keyboard contact")
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(primaryRow.waitForExistence(timeout: 5))

        XCTAssertTrue(
            tabToKeyboardFocus(primaryRow, in: app, maximumTabPresses: 32),
            "The compact contact row must regain keyboard focus before Space opens detail."
        )
        app.typeKey(.space, modifierFlags: [])
        let disclosure = app.buttons["contact-related-disclosure"]
        XCTAssertTrue(
            tabToKeyboardFocus(disclosure, in: app, maximumTabPresses: 32),
            "The related-opportunities disclosure must expose keyboard focus before Space toggles it."
        )
        app.typeKey(.space, modifierFlags: [])
        XCTAssertTrue((disclosure.value as? String ?? "").hasPrefix("Expanded"))
        let manageRelated = app.buttons["contact-manage-related"]
        XCTAssertTrue(
            tabToKeyboardFocus(manageRelated, in: app, maximumTabPresses: 32),
            "Manage related opportunities must expose keyboard focus before Space opens it."
        )
        app.typeKey(.space, modifierFlags: [])
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5))
        app.typeKey(.return, modifierFlags: [])
        XCTAssertFalse(app.buttons["Done"].waitForExistence(timeout: 2))

        let emptyApp = openContactsFixture(fixture: "contacts-empty")
        XCTAssertTrue(emptyApp.descendants(matching: .any)["contact-empty-state"].waitForExistence(timeout: 5))
        XCTAssertTrue(emptyApp.descendants(matching: .any)["contact-no-selection-state"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testVD202RecoveryFixtureExposesAnExplicitRecoveryOnlySafetyMarker() {
        let app = launchApp(fixture: "recovery")
        XCTAssertTrue(
            app.descendants(matching: .any)["recovery-only-workspace-gate"].waitForExistence(timeout: 2),
            "Recovery fixtures must expose an explicit marker that normal workspace routes cannot become active."
        )
    }

    @MainActor
    func testVD207SettingsSecondaryNavigationDefaultsToRecoveryAndKeepsGlobalRail() {
        let app = launchApp(fixture: "populated")
        let rail = app.descendants(matching: .any)["sidebar-settings"]
        XCTAssertTrue(rail.waitForExistence(timeout: 5))
        rail.tap()
        XCTAssertTrue(rail.isSelected)
        XCTAssertTrue(app.descendants(matching: .any)["settings-secondary-navigation"].waitForExistence(timeout: 2))

        let recovery = app.buttons["settings-section-recovery-archives"]
        XCTAssertTrue(recovery.waitForExistence(timeout: 2))
        XCTAssertTrue((recovery.value as? String ?? "").hasPrefix("Selected"))
        XCTAssertTrue(app.descendants(matching: .any)["settings-section-recovery-archives-panel"].exists)
        XCTAssertTrue(app.buttons["set-up-recovery-key"].exists)

        for (control, panel) in [
            ("settings-section-workspace", "settings-section-workspace-panel"),
            ("settings-section-document-references", "settings-section-document-references-panel"),
            ("settings-section-ai-connections", "settings-section-ai-connections-panel")
        ] {
            app.buttons[control].tap()
            XCTAssertTrue(app.descendants(matching: .any)[panel].waitForExistence(timeout: 2))
            XCTAssertTrue((app.buttons[control].value as? String ?? "").hasPrefix("Selected"))
            XCTAssertTrue(rail.isSelected)
        }
    }

    @MainActor
    func testVD207ReferenceRecoveryDashboardKeepsRailAndUsesCardComposition() {
        let app = launchApp(fixture: "archive")
        let rail = app.descendants(matching: .any)["sidebar-settings"]
        XCTAssertTrue(rail.waitForExistence(timeout: 5))
        rail.tap()
        XCTAssertTrue(rail.isSelected)

        let panel = app.descendants(matching: .any)["settings-section-recovery-archives-panel"]
        XCTAssertTrue(panel.waitForExistence(timeout: 2))
        for identifier in ["create-portable-archive", "create-protected-export", "purge-retained-archive-data", "restore-portable-archive"] {
            XCTAssertTrue(app.buttons[identifier].exists, "Missing retained recovery action \(identifier).")
        }
        let summary = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "settings-archive-summary-"))
            .firstMatch
        XCTAssertTrue(summary.waitForExistence(timeout: 2))
        XCTAssertEqual(
            summary.value as? String,
            "created=2025-05-06T12:00:00Z;expires=2025-06-05T12:00:00Z;lifecycle=Verified"
        )
        XCTAssertTrue(app.buttons["create-portable-archive"].isEnabled)
        XCTAssertTrue(app.buttons["create-protected-export"].isEnabled)
        XCTAssertTrue(app.buttons["purge-retained-archive-data"].isEnabled)
        XCTAssertTrue(app.buttons["restore-portable-archive"].isEnabled)
        attachSettingsPresentationScreenshot(app, named: "VD2-07x-wide-recovery")

        app.buttons["create-portable-archive"].tap()
        XCTAssertTrue(app.staticTexts["Create portable recovery archive"].waitForExistence(timeout: 2))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(summary.waitForExistence(timeout: 2))

        app.buttons["create-protected-export"].tap()
        XCTAssertTrue(app.staticTexts["Export protected copy"].waitForExistence(timeout: 2))
        app.buttons["Choose destination and review"].tap()
        let protectedExportError = app.staticTexts["protected-export-error"]
        XCTAssertTrue(protectedExportError.waitForExistence(timeout: 2))
        XCTAssertEqual(protectedExportError.label, "Enter the complete recovery key, including its checksum.")
        app.buttons["Cancel"].tap()
        XCTAssertTrue(summary.waitForExistence(timeout: 2))

        app.buttons["purge-retained-archive-data"].tap()
        XCTAssertTrue(app.staticTexts["Purge deleted data from retained archives"].waitForExistence(timeout: 2))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(summary.waitForExistence(timeout: 2))

        if recordUnrenderedVisualSelectors([
            "settings-reference-tab-strip",
            "settings-reference-tab-recovery-archives",
            "settings-recovery-overview-card",
            "settings-recovery-status-enrollment",
            "settings-recovery-status-state",
            "settings-recovery-archive-detail-card",
            "settings-recovery-action-create",
            "settings-recovery-action-purge",
            "settings-recovery-action-restore",
            "settings-recovery-protected-export"
        ], in: app) {
            return
        }

        assertNoDisclosedSettingsSentinels(
            ["fixture-document-hash", "application/pdf", "/private/", "recovery key"],
            in: panel
        )
    }

    @MainActor
    func testVD207ReferenceRecoveryDoesNotInventExportSuccess() {
        let app = launchApp(fixture: "archive")
        let rail = app.descendants(matching: .any)["sidebar-settings"]
        XCTAssertTrue(rail.waitForExistence(timeout: 5))
        rail.tap()
        XCTAssertTrue(rail.isSelected)
        XCTAssertTrue(app.descendants(matching: .any)["settings-section-recovery-archives-panel"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.descendants(matching: .any)["settings-protected-export-success-dialog"].exists)
    }

    @MainActor
    func testVD207ReferenceTabsKeepKeyboardSelectionAtCompactWidth() {
        let app = launchApp(fixture: "populated", windowSize: "compact")
        let rail = app.descendants(matching: .any)["sidebar-settings"]
        XCTAssertTrue(rail.waitForExistence(timeout: 5))
        rail.tap()
        XCTAssertTrue(rail.isSelected)

        let selectorsAndPanels = [
            ("settings-section-workspace", "settings-section-workspace-panel"),
            ("settings-section-recovery-archives", "settings-section-recovery-archives-panel"),
            ("settings-section-document-references", "settings-section-document-references-panel"),
            ("settings-section-ai-connections", "settings-section-ai-connections-panel")
        ]
        for (selector, _) in selectorsAndPanels {
            let section = app.buttons[selector]
            XCTAssertTrue(section.waitForExistence(timeout: 2))
            XCTAssertTrue(section.isHittable)
            XCTAssertTrue(
                tabToKeyboardFocus(section, in: app, maximumTabPresses: 32),
                "The compact Settings selector must expose semantic keyboard focus."
            )
        }

        XCTAssertTrue(app.descendants(matching: .any)["settings-section-recovery-archives-panel"].waitForExistence(timeout: 2))
        for (selector, panel) in selectorsAndPanels where selector != "settings-section-recovery-archives" {
            let section = app.buttons[selector]
            XCTAssertTrue(section.waitForExistence(timeout: 2))
            XCTAssertTrue(tabToKeyboardFocus(section, in: app, maximumTabPresses: 32))
            XCTAssertEqual(section.value as? String, "Not selected; Keyboard focus")
            app.typeKey(.space, modifierFlags: [])
            XCTAssertEqual(section.value as? String, "Selected; Keyboard focus")
            XCTAssertTrue(app.descendants(matching: .any)[panel].waitForExistence(timeout: 2))
            XCTAssertTrue(rail.isSelected)
        }

        if recordUnrenderedVisualSelectors([
            "settings-reference-tab-strip",
            "settings-reference-tab-recovery-archives"
        ], in: app) {
            return
        }

        for (selector, _) in selectorsAndPanels {
            XCTAssertTrue(app.buttons[selector].exists)
            XCTAssertTrue(app.buttons[selector].isHittable)
        }
    }

    @MainActor
    func testVD207ReferenceOtherSettingsSectionsUseTruthfulInformationalCards() {
        let app = launchApp(fixture: "document-relink")
        let rail = app.descendants(matching: .any)["sidebar-settings"]
        XCTAssertTrue(rail.waitForExistence(timeout: 5))
        rail.tap()
        XCTAssertTrue(rail.isSelected)

        app.buttons["settings-section-document-references"].tap()
        let documentPanel = app.descendants(matching: .any)["settings-section-document-references-panel"]
        XCTAssertTrue(documentPanel.waitForExistence(timeout: 2))
        let summary = app.descendants(matching: .any)["settings-document-reference-summary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 2))
        XCTAssertEqual(summary.value as? String, "0 available · 1 require relinking")
        assertNoActionableDescendants(in: documentPanel)
        assertNoDisclosedSettingsSentinels(
            ["fixture-resume.pdf", "fixture-document-hash", "application/pdf", "/private/"],
            in: documentPanel
        )
        if recordUnrenderedVisualSelectors([
            "settings-document-overview-card",
            "settings-document-available-card",
            "settings-document-relink-card",
            "settings-document-privacy-card"
        ], in: app) {
            return
        }

        XCTAssertTrue(app.descendants(matching: .any)["settings-document-available-card"].label.contains("Available"))
        XCTAssertTrue(app.descendants(matching: .any)["settings-document-available-card"].label.contains("0"))
        XCTAssertTrue(app.descendants(matching: .any)["settings-document-relink-card"].label.contains("Needs relinking"))
        XCTAssertTrue(app.descendants(matching: .any)["settings-document-relink-card"].label.contains("1"))
        XCTAssertTrue(app.descendants(matching: .any)["settings-document-privacy-card"].label.contains("names and locations stay private"))
        attachSettingsPresentationScreenshot(app, named: "VD2-07x-wide-document-references")

        app.buttons["settings-section-ai-connections"].tap()
        let aiPanel = app.descendants(matching: .any)["settings-section-ai-connections-panel"]
        XCTAssertTrue(aiPanel.waitForExistence(timeout: 2))
        assertNoActionableDescendants(in: aiPanel)
        assertNoDisclosedSettingsSentinels(
            ["fixture-resume.pdf", "fixture-document-hash", "application/pdf", "/private/"],
            in: aiPanel
        )
        if recordUnrenderedVisualSelectors([
            "settings-ai-overview-card",
            "settings-ai-assistant-card",
            "settings-ai-email-calendar-card",
            "settings-ai-cloud-card",
            "settings-ai-privacy-card"
        ], in: app) {
            return
        }

        let aiOverview = app.descendants(matching: .any)["settings-ai-overview-card"]
        XCTAssertTrue(aiOverview.label.contains("No activity recorded"))
        XCTAssertTrue(aiOverview.label.contains("Connection status"))
        XCTAssertTrue(aiOverview.label.contains("Offline"))
        XCTAssertTrue(app.descendants(matching: .any)["settings-ai-assistant-card"].label.contains("AI assistant"))
        XCTAssertTrue(app.descendants(matching: .any)["settings-ai-assistant-card"].label.contains("Not configured"))
        XCTAssertTrue(app.descendants(matching: .any)["settings-ai-email-calendar-card"].label.contains("Email & calendar"))
        XCTAssertTrue(app.descendants(matching: .any)["settings-ai-email-calendar-card"].label.contains("Not connected"))
        XCTAssertTrue(app.descendants(matching: .any)["settings-ai-cloud-card"].label.contains("Cloud sync"))
        XCTAssertTrue(app.descendants(matching: .any)["settings-ai-cloud-card"].label.contains("Not configured"))
        attachSettingsPresentationScreenshot(app, named: "VD2-07x-wide-ai-connections")
        assertNoActionableDescendants(in: documentPanel)
        assertNoActionableDescendants(in: aiPanel)

        app.buttons["settings-section-workspace"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["settings-section-workspace-panel"].waitForExistence(timeout: 2))
        if recordUnrenderedVisualSelectors([
            "settings-workspace-overview-card",
            "settings-workspace-recovery-card",
            "settings-workspace-return-card"
        ], in: app) {
            return
        }

        let workspaceCard = app.descendants(matching: .any)["settings-workspace-overview-card"]
        XCTAssertTrue(workspaceCard.label.contains("Local workspace"))
        XCTAssertTrue(workspaceCard.label.contains("Workspace status"))
        XCTAssertTrue(workspaceCard.label.contains("Active"))
        XCTAssertTrue(workspaceCard.label.contains("Storage"))
        XCTAssertTrue(workspaceCard.label.contains("Local only"))

        let returnCard = app.descendants(matching: .any)["settings-workspace-return-card"]
        XCTAssertTrue(returnCard.label.contains("No preserved workspace available"))
        XCTAssertTrue(returnCard.value as? String == "Disabled")
        XCTAssertEqual(returnCard.descendants(matching: .button).count, 0)
        XCTAssertEqual(returnCard.descendants(matching: .link).count, 0)
        XCTAssertEqual(returnCard.descendants(matching: .menuButton).count, 0)
        attachSettingsPresentationScreenshot(app, named: "VD2-07x-wide-workspace")
    }

    @MainActor
    func testVD207SettingsSecondaryNavigationIsKeyboardOperableAtCompactWidth() {
        let app = launchApp(fixture: "populated", windowSize: "compact")
        app.descendants(matching: .any)["sidebar-settings"].tap()

        let document = app.buttons["settings-section-document-references"]
        XCTAssertTrue(document.waitForExistence(timeout: 2))
        XCTAssertTrue(document.isHittable)
        XCTAssertTrue(
            tabToKeyboardFocus(document, in: app, maximumTabPresses: 20),
            "The compact Settings selector must expose semantic keyboard focus."
        )
        XCTAssertEqual(document.value as? String, "Not selected; Keyboard focus")
        app.typeKey(.space, modifierFlags: [])
        XCTAssertTrue(app.descendants(matching: .any)["settings-section-document-references-panel"].waitForExistence(timeout: 2))
        XCTAssertEqual(document.value as? String, "Selected; Keyboard focus")
        XCTAssertTrue(app.descendants(matching: .any)["sidebar-settings"].isSelected)
    }

    @MainActor
    func testVD207ProtectedExportEntryUsesRootDialogAndRetainsErrorUntilCancel() {
        let app = launchApp(fixture: "archive")
        app.descendants(matching: .any)["sidebar-settings"].tap()
        app.buttons["create-protected-export"].tap()

        XCTAssertTrue(app.staticTexts["Export protected copy"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.textFields["Recovery key"].exists)
        XCTAssertTrue(app.buttons["Choose destination and review"].exists)
        XCTAssertEqual(
            app.buttons["Choose destination and review"].frame.width,
            app.textFields["Recovery key"].frame.width,
            accuracy: 1,
            "The protected-export primary action must span the custom dialog form width."
        )
        XCTAssertEqual(app.sheets.count, 0)

        app.buttons["Choose destination and review"].tap()
        let error = app.staticTexts["protected-export-error"]
        XCTAssertTrue(error.waitForExistence(timeout: 2))
        XCTAssertEqual(error.label, "Enter the complete recovery key, including its checksum.")
        XCTAssertTrue(app.staticTexts["Export protected copy"].exists)
        XCTAssertTrue(app.textFields["Recovery key"].exists)
        XCTAssertTrue(app.buttons["Choose destination and review"].exists)
        XCTAssertEqual(app.sheets.count, 0)
        XCTAssertFalse(app.descendants(matching: .any)["settings-protected-export-success-dialog"].exists)

        app.buttons["Cancel"].tap()
        XCTAssertFalse(error.exists)
        XCTAssertFalse(app.staticTexts["Export protected copy"].exists)
        XCTAssertEqual(app.sheets.count, 0)
        XCTAssertTrue(app.buttons["create-protected-export"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testVD207SettingsRecoveryRetainsArchiveTruthAndRootOwnedCancellation() {
        let app = launchApp(fixture: "archive")
        app.descendants(matching: .any)["sidebar-settings"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["settings-section-recovery-archives-panel"].waitForExistence(timeout: 2))
        for identifier in ["create-portable-archive", "create-protected-export", "purge-retained-archive-data", "restore-portable-archive"] {
            XCTAssertTrue(app.buttons[identifier].exists, "Missing retained recovery action \(identifier).")
        }
        let summary = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "settings-archive-summary-"))
            .firstMatch
        XCTAssertTrue(summary.waitForExistence(timeout: 2))
        XCTAssertTrue(summary.label.contains("Fixture Archive.rekonarchive"))
        XCTAssertTrue(summary.label.contains("Verified"))
        XCTAssertEqual(
            summary.value as? String,
            "created=2025-05-06T12:00:00Z;expires=2025-06-05T12:00:00Z;lifecycle=Verified"
        )
        XCTAssertTrue(app.buttons["create-portable-archive"].isEnabled)
        XCTAssertTrue(app.buttons["create-protected-export"].isEnabled)
        XCTAssertTrue(app.buttons["purge-retained-archive-data"].isEnabled)
        XCTAssertTrue(app.buttons["restore-portable-archive"].isEnabled)

        app.buttons["create-portable-archive"].tap()
        XCTAssertTrue(app.staticTexts["Create portable recovery archive"].waitForExistence(timeout: 2))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(summary.waitForExistence(timeout: 2))
        XCTAssertEqual(summary.value as? String, "created=2025-05-06T12:00:00Z;expires=2025-06-05T12:00:00Z;lifecycle=Verified")

        app.buttons["create-protected-export"].tap()
        XCTAssertTrue(app.staticTexts["Export protected copy"].waitForExistence(timeout: 2))
        app.buttons["Choose destination and review"].tap()
        let protectedExportError = app.staticTexts["protected-export-error"]
        XCTAssertTrue(protectedExportError.waitForExistence(timeout: 2))
        XCTAssertEqual(
            protectedExportError.label,
            "Enter the complete recovery key, including its checksum."
        )
        app.buttons["Cancel"].tap()
        XCTAssertTrue(summary.waitForExistence(timeout: 2))
        XCTAssertEqual(summary.value as? String, "created=2025-05-06T12:00:00Z;expires=2025-06-05T12:00:00Z;lifecycle=Verified")

        app.buttons["purge-retained-archive-data"].tap()
        XCTAssertTrue(app.staticTexts["Purge deleted data from retained archives"].waitForExistence(timeout: 2))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(summary.waitForExistence(timeout: 2))
        XCTAssertEqual(summary.value as? String, "created=2025-05-06T12:00:00Z;expires=2025-06-05T12:00:00Z;lifecycle=Verified")
    }

    @MainActor
    func testVD207SettingsDocumentAndAISectionsStayAggregateAndUnavailable() {
        let app = launchApp(fixture: "document-relink")
        app.descendants(matching: .any)["sidebar-settings"].tap()
        app.buttons["settings-section-document-references"].tap()

        let summary = app.descendants(matching: .any)["settings-document-reference-summary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 2))
        XCTAssertEqual(summary.value as? String, "0 available · 1 require relinking")
        let documentPanel = app.descendants(matching: .any)["settings-section-document-references-panel"]
        for metadataSentinel in ["fixture-resume.pdf", "fixture-document-hash", "application/pdf"] {
            let matchingDescendant = documentPanel.descendants(matching: .any).matching(
                NSPredicate(
                    format: "label CONTAINS[c] %@ OR value CONTAINS[c] %@",
                    metadataSentinel,
                    metadataSentinel
                )
            ).firstMatch
            XCTAssertFalse(matchingDescendant.exists, "Document panel disclosed \(metadataSentinel).")
        }
        XCTAssertEqual(documentPanel.descendants(matching: .button).count, 0)
        XCTAssertEqual(documentPanel.descendants(matching: .menuButton).count, 0)
        XCTAssertEqual(documentPanel.descendants(matching: .link).count, 0)
        XCTAssertEqual(documentPanel.descendants(matching: .checkBox).count, 0)
        XCTAssertEqual(documentPanel.descendants(matching: .switch).count, 0)
        XCTAssertEqual(documentPanel.descendants(matching: .textField).count, 0)

        app.buttons["settings-section-ai-connections"].tap()
        let aiPanel = app.descendants(matching: .any)["settings-section-ai-connections-panel"]
        XCTAssertTrue(aiPanel.waitForExistence(timeout: 2))
        let unavailable = app.descendants(matching: .any)["settings-ai-connections-unavailable"]
        XCTAssertTrue(unavailable.waitForExistence(timeout: 2))
        XCTAssertTrue(unavailable.label.contains("No AI requests"))
        XCTAssertTrue(unavailable.label.contains("Gmail"))
        XCTAssertTrue(unavailable.label.contains("Calendar"))
        let unavailableStaticText = app.staticTexts["settings-ai-connections-unavailable"]
        XCTAssertTrue(unavailableStaticText.waitForExistence(timeout: 2))
        XCTAssertTrue(unavailableStaticText.label.contains("No AI requests"))
        XCTAssertTrue(unavailableStaticText.label.contains("Gmail"))
        XCTAssertTrue(unavailableStaticText.label.contains("Calendar"))
        XCTAssertEqual(aiPanel.descendants(matching: .button).count, 0)
        XCTAssertEqual(aiPanel.descendants(matching: .menuButton).count, 0)
        XCTAssertEqual(aiPanel.descendants(matching: .link).count, 0)
        XCTAssertEqual(aiPanel.descendants(matching: .checkBox).count, 0)
        XCTAssertEqual(aiPanel.descendants(matching: .switch).count, 0)
        XCTAssertEqual(aiPanel.descendants(matching: .textField).count, 0)
    }

    @MainActor
    func testVD207SettingsRelaunchKeepsFixtureTruthAndResetsLocalSelection() {
        let session = "ui-shell-\(UUID().uuidString)"
        var app = launchApp(fixture: "document-relink", session: session)
        defer {
            if app.state != .notRunning {
                app.terminate()
            }
            Self.removeFixtureSessionFromTestProcess(session)
        }

        app.descendants(matching: .any)["sidebar-settings"].tap()
        app.buttons["settings-section-document-references"].tap()
        let documentSummary = app.descendants(matching: .any)["settings-document-reference-summary"]
        XCTAssertTrue(documentSummary.waitForExistence(timeout: 2))
        let preRelaunchSummary = documentSummary.value as? String
        XCTAssertEqual(preRelaunchSummary, "0 available · 1 require relinking")

        app.terminate()
        app = launchApp(fixture: "document-relink", session: session)
        app.descendants(matching: .any)["sidebar-settings"].tap()
        let recovery = app.buttons["settings-section-recovery-archives"]
        XCTAssertTrue(recovery.waitForExistence(timeout: 2))
        XCTAssertTrue((recovery.value as? String ?? "").hasPrefix("Selected"))
        XCTAssertTrue(app.descendants(matching: .any)["settings-section-recovery-archives-panel"].exists)

        app.buttons["settings-section-document-references"].tap()
        XCTAssertTrue(documentSummary.waitForExistence(timeout: 2))
        XCTAssertEqual(documentSummary.value as? String, preRelaunchSummary)
    }

    @MainActor
    func testVD207ReferenceTabsSelectByPointerAtCompactWidth() {
        let app = launchApp(fixture: "populated", windowSize: "compact")
        let rail = app.descendants(matching: .any)["sidebar-settings"]
        XCTAssertTrue(rail.waitForExistence(timeout: 5))
        rail.tap()
        XCTAssertTrue(rail.isSelected)

        let sections = [
            ("settings-section-workspace", "settings-section-workspace-panel", "VD2-07x-compact-workspace"),
            ("settings-section-recovery-archives", "settings-section-recovery-archives-panel", "VD2-07x-compact-recovery"),
            ("settings-section-document-references", "settings-section-document-references-panel", "VD2-07x-compact-document-references"),
            ("settings-section-ai-connections", "settings-section-ai-connections-panel", "VD2-07x-compact-ai-connections")
        ]

        for (selector, panel, screenshotName) in sections {
            let section = app.buttons[selector]
            XCTAssertTrue(section.waitForExistence(timeout: 2))
            section.tap()
            XCTAssertTrue(app.descendants(matching: .any)[panel].waitForExistence(timeout: 2))
            XCTAssertTrue((section.value as? String ?? "").hasPrefix("Selected"))
            XCTAssertTrue(rail.isSelected)
            attachSettingsPresentationScreenshot(app, named: screenshotName)
        }
    }

    @MainActor
    func testVD207ReferenceAIVisualContentBoundary() {
        let app = launchApp(fixture: "document-relink")
        let rail = app.descendants(matching: .any)["sidebar-settings"]
        XCTAssertTrue(rail.waitForExistence(timeout: 5))
        rail.tap()
        XCTAssertTrue(rail.isSelected)

        app.buttons["settings-section-document-references"].tap()
        let documentPanel = app.descendants(matching: .any)["settings-section-document-references-panel"]
        XCTAssertTrue(documentPanel.waitForExistence(timeout: 2))
        let summary = app.descendants(matching: .any)["settings-document-reference-summary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 2))
        XCTAssertEqual(summary.value as? String, "0 available · 1 require relinking")
        assertNoActionableDescendants(in: documentPanel)
        assertNoDisclosedSettingsSentinels(
            ["fixture-resume.pdf", "fixture-document-hash", "application/pdf", "/private/"],
            in: documentPanel
        )

        app.buttons["settings-section-ai-connections"].tap()
        let aiPanel = app.descendants(matching: .any)["settings-section-ai-connections-panel"]
        XCTAssertTrue(aiPanel.waitForExistence(timeout: 2))

        let overview = app.descendants(matching: .any)["settings-ai-overview-card"]
        XCTAssertTrue(overview.waitForExistence(timeout: 2))
        XCTAssertTrue(overview.label.contains("AI activity"))
        XCTAssertTrue(overview.label.contains("No activity recorded"))
        XCTAssertTrue(overview.label.contains("Connection status"))
        XCTAssertTrue(overview.label.contains("Offline"))

        let assistant = app.descendants(matching: .any)["settings-ai-assistant-card"]
        XCTAssertTrue(assistant.waitForExistence(timeout: 2))
        XCTAssertTrue(assistant.label.contains("AI assistant"))
        XCTAssertTrue(assistant.label.contains("Not configured"))

        let emailCalendar = app.descendants(matching: .any)["settings-ai-email-calendar-card"]
        XCTAssertTrue(emailCalendar.waitForExistence(timeout: 2))
        XCTAssertTrue(emailCalendar.label.contains("Email & calendar"))
        XCTAssertTrue(emailCalendar.label.contains("Not connected"))

        let cloud = app.descendants(matching: .any)["settings-ai-cloud-card"]
        XCTAssertTrue(cloud.waitForExistence(timeout: 2))
        XCTAssertTrue(cloud.label.contains("Cloud sync"))
        XCTAssertTrue(cloud.label.contains("Not configured"))

        let privacy = app.descendants(matching: .any)["settings-ai-privacy-card"]
        XCTAssertTrue(privacy.waitForExistence(timeout: 2))
        XCTAssertTrue(privacy.label.contains("workspace remains local and private"))

        assertNoActionableDescendants(in: aiPanel)
        assertNoDisclosedSettingsSentinels(
            ["fixture-resume.pdf", "fixture-document-hash", "application/pdf", "/private/"],
            in: aiPanel
        )
        attachSettingsPresentationScreenshot(app, named: "VD2-07x-wide-ai-connections")
    }

    /// Task 2 must expose this additive, content-free projection beside the
    /// existing control. Keeping the selector separate prevents a visual
    /// treatment from replacing native roles, labels, values, or focus order.
    @MainActor
    private func assertSharedControlSurface(
        _ key: String,
        kind: String,
        state: String,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let projection = app.descendants(matching: .any)["shared-control-surface-\(key)"]
        guard projection.exists else {
            XCTFail(
                "VD2-07b RED [\(key)]: expected additive shared-control-surface-\(key) projection.",
                file: file,
                line: line
            )
            return
        }
        XCTAssertEqual(
            projection.value as? String,
            "kind=\(kind);state=\(state)",
            "VD2-07b RED [\(key)]: expected content-free kind/state projection.",
            file: file,
            line: line
        )
    }

    @MainActor
    private func assertReadyTextControl(
        _ element: XCUIElement,
        key: String,
        label: String? = nil
    ) {
        guard element.waitForExistence(timeout: 5) else {
            XCTFail("VD2-07b baseline [\(key)]: expected current control.")
            return
        }
        XCTAssertTrue(element.isEnabled, "VD2-07b baseline [\(key)]: expected current enabled state.")
        if let label {
            XCTAssertEqual(element.label, label, "VD2-07b baseline [\(key)]: label must remain truthful.")
        }
    }

    @MainActor
    private func assertReadyPicker(
        _ label: String,
        index: Int,
        key: String,
        in app: XCUIApplication
    ) {
        let pickerLabel = app.staticTexts
            .matching(NSPredicate(format: "value == %@", label))
            .firstMatch
        assertReadyTextControl(pickerLabel, key: "\(key).label")
        XCTAssertEqual(pickerLabel.value as? String, label, "VD2-07b baseline [\(key)]: picker label must remain truthful.")

        let picker = app.popUpButtons.element(boundBy: index)
        XCTAssertTrue(picker.waitForExistence(timeout: 5), "VD2-07b baseline [\(key)]: expected current selected-value control.")
        XCTAssertEqual(picker.elementType, .popUpButton, "VD2-07b baseline [\(key)]: SwiftUI picker must retain its native popup role.")
        XCTAssertTrue(picker.isEnabled, "VD2-07b baseline [\(key)]: expected current enabled state.")
        XCTAssertFalse((picker.value as? String ?? "").isEmpty, "VD2-07b baseline [\(key)]: picker must retain selected-value disclosure.")
    }

    /// SwiftUI Form text fields without an explicit accessibility identifier
    /// expose their source label as a StaticText sibling and retain an
    /// unlabeled TextField input. The source order keeps these anonymous
    /// inputs deterministic within each form.
    @MainActor
    private func assertReadyFormTextField(
        _ label: String,
        index: Int,
        key: String,
        in app: XCUIApplication
    ) {
        let fieldLabel = app.staticTexts
            .matching(NSPredicate(format: "value == %@", label))
            .firstMatch
        assertReadyTextControl(fieldLabel, key: "\(key).label")
        XCTAssertEqual(fieldLabel.value as? String, label, "VD2-07b baseline [\(key)]: field label must remain truthful.")

        let field = app.textFields
            .matching(NSPredicate(format: "identifier == ''"))
            .element(boundBy: index)
        assertReadyTextControl(field, key: key)
        XCTAssertEqual(field.elementType, .textField, "VD2-07b baseline [\(key)]: field must retain its native text role.")
    }

    @MainActor
    private func assertScrollRevealsAction(
        _ action: XCUIElement,
        in scrollContainer: XCUIElement,
        key: String
    ) {
        XCTAssertTrue(action.waitForExistence(timeout: 5), "VD2-07b baseline [\(key)]: expected current action.")
        XCTAssertTrue(scrollContainer.waitForExistence(timeout: 5), "VD2-07b baseline [\(key)]: expected scrollable form container.")
        for _ in 0 ..< 3 where !action.isHittable {
            scrollContainer.swipeUp()
        }
        XCTAssertTrue(action.isHittable, "VD2-07b baseline [\(key)]: action must remain reachable after scrolling.")
    }

    @MainActor
    func testVD207bSharedFormControlAlignmentAcrossContactsPipelineAndActivity() {
        let pipelineApp = launchApp(fixture: "populated")
        pipelineApp.descendants(matching: .any)["sidebar-pipeline"].tap()

        let pipelineRows = pipelineApp.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "pipeline-table-row-"))
        XCTAssertTrue(pipelineRows.firstMatch.waitForExistence(timeout: 5), "VD2-07b baseline [pipeline]: populated route must be ready.")
        let pipelineControls: [(String, XCUIElement, String, String)] = [
            ("pipeline.search", pipelineApp.textFields["opportunity-search"], "search", "idle"),
            ("pipeline.stage", pipelineApp.popUpButtons["pipeline-stage-filter"], "picker", "idle"),
            ("pipeline.includeClosed", pipelineApp.checkBoxes["pipeline-include-closed"], "checkbox", "unchecked"),
            ("pipeline.viewMode", pipelineApp.descendants(matching: .any)["pipeline-view-mode"], "radioGroup", "selected")
        ]
        for (key, element, kind, state) in pipelineControls {
            assertReadyTextControl(element, key: key)
        }
        pipelineApp.descendants(matching: .any)["pipeline-view-mode"].radioButtons["Board"].click()
        XCTAssertTrue(pipelineApp.descendants(matching: .any)["pipeline-board-region"].waitForExistence(timeout: 5))
        for (key, _, kind, state) in pipelineControls {
            assertSharedControlSurface(key, kind: kind, state: state, in: pipelineApp)
        }
        pipelineApp.terminate()

        let contactsApp = openContactsFixture(fixture: "contacts")
        let contactSearch = contactsApp.textFields["contact-search"]
        assertReadyTextControl(contactSearch, key: "contacts.search", label: "Search contacts")
        contactSearch.click()
        contactSearch.typeText("no matching contact")
        XCTAssertTrue(contactsApp.descendants(matching: .any)["contact-no-results-state"].waitForExistence(timeout: 5))
        contactSearch.typeKey("a", modifierFlags: [.command])
        contactSearch.typeKey(.delete, modifierFlags: [])
        let employerFilter = contactsApp.popUpButtons["Filter contacts by employer"]
        assertReadyTextControl(employerFilter, key: "contacts.employerFilter")

        contactsApp.buttons["contact-new"].click()
        let contactKeys: [(String, XCUIElement, String)] = [
            ("contacts.name", contactsApp.textFields["contact-name"], "text"),
            ("contacts.workEmail", contactsApp.textFields["contact-work-email"], "text"),
            ("contacts.personalEmail", contactsApp.textFields["contact-personal-email"], "text"),
            ("contacts.mobilePhone", contactsApp.textFields["contact-mobile-phone"], "text"),
            ("contacts.officePhone", contactsApp.textFields["contact-office-phone"], "text"),
            ("contacts.linkedIn", contactsApp.textFields["contact-linkedin"], "text"),
            ("contacts.instagram", contactsApp.textFields["contact-instagram"], "text"),
            ("contacts.facebook", contactsApp.textFields["contact-facebook"], "text"),
            ("contacts.employerSearch", contactsApp.textFields["contact-employer-search"], "search")
        ]
        for (key, element, kind) in contactKeys {
            assertReadyTextControl(element, key: key)
        }
        assertReadyFormTextField("Title (optional)", index: 0, key: "contacts.title", in: contactsApp)
        replaceText(in: contactsApp.textFields["contact-employer-search"], with: "VD2-07b temporary employer")
        contactsApp.buttons["Add VD2-07b temporary employer as new employer"].click()
        assertReadyFormTextField("New employer (optional)", index: 1, key: "contacts.newEmployer", in: contactsApp)
        XCTAssertEqual(contactsApp.textViews.count, 2, "VD2-07b baseline [contacts multiline]: both editors must remain rendered.")
        for editorTitle in ["Relationship context (optional)", "Notes (optional)"] {
            let expansionControl = contactsApp.buttons[editorTitle]
            assertReadyTextControl(expansionControl, key: "contacts.\(editorTitle).expansion", label: editorTitle)
            XCTAssertEqual(
                expansionControl.value as? String,
                "Collapsed",
                "VD2-07b baseline [contacts \(editorTitle)]: multiline editor must retain its collapsed disclosure state."
            )
        }
        for (key, _, kind) in contactKeys {
            assertSharedControlSurface(key, kind: kind, state: "idle", in: contactsApp)
        }
        assertSharedControlSurface("contacts.title", kind: "text", state: "idle", in: contactsApp)
        assertSharedControlSurface("contacts.search", kind: "search", state: "idle", in: contactsApp)
        assertSharedControlSurface("contacts.employerFilter", kind: "picker", state: "idle", in: contactsApp)
        assertSharedControlSurface("contacts.newEmployer", kind: "text", state: "idle", in: contactsApp)
        assertSharedControlSurface("contacts.relationshipContext", kind: "multiline", state: "idle", in: contactsApp)
        assertSharedControlSurface("contacts.notes", kind: "multiline", state: "idle", in: contactsApp)
        contactsApp.terminate()

        let activityApp = launchApp(fixture: "populated")
        activityApp.descendants(matching: .any)["sidebar-activity-and-ai"].tap()
        let activityKeys: [(String, XCUIElement, String)] = [
            ("activity.search", activityApp.textFields["activity-search"], "search"),
            ("ai.time", activityApp.popUpButtons["ai-ledger-time-filter"], "picker"),
            ("ai.feature", activityApp.textFields["ai-ledger-feature-filter"], "text"),
            ("ai.opportunity", activityApp.popUpButtons["ai-ledger-opportunity-filter"], "picker"),
            ("ai.route", activityApp.popUpButtons["ai-ledger-route-filter"], "picker"),
            ("ai.model", activityApp.textFields["ai-ledger-model-filter"], "text"),
            ("ai.completion", activityApp.popUpButtons["ai-ledger-completion-filter"], "picker"),
            ("ai.minimumCost", activityApp.textFields["ai-ledger-min-cost-filter"], "numeric"),
            ("ai.maximumCost", activityApp.textFields["ai-ledger-max-cost-filter"], "numeric")
        ]
        for (key, element, kind) in activityKeys {
            assertReadyTextControl(element, key: key)
        }
        for (key, _, kind) in activityKeys {
            assertSharedControlSurface(key, kind: kind, state: "idle", in: activityApp)
        }
    }

    @MainActor
    func testVD207bOpportunityEditorsRetainBindingsValidationAndNoSaveBack() {
        let session = "vd207b-opportunity-\(UUID().uuidString)"
        var app = launchApp(fixture: "populated", session: session)
        app.descendants(matching: .any)["sidebar-pipeline"].tap()
        let rows = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "pipeline-table-row-"))
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 5))
        let originalRowCount = rows.count

        app.buttons["pipeline-add-opportunity"].click()
        let addControls: [(String, XCUIElement, String)] = [
            ("add.title", app.textFields["opportunity-title"], "text"),
            ("add.company", app.textFields["opportunity-company"], "text")
        ]
        for (key, element, _) in addControls { assertReadyTextControl(element, key: key) }
        XCTAssertGreaterThanOrEqual(app.textFields.count, 2, "VD2-07b baseline [add]: text bindings must remain available.")
        XCTAssertGreaterThanOrEqual(app.textViews.count, 2, "VD2-07b baseline [add multiline]: description and notes must remain available.")
        for (index, label) in ["Pay period", "Work arrangement", "Current response", "Stage", "Next action"].enumerated() {
            assertReadyPicker(label, index: index, key: "add.\(label)", in: app)
        }
        XCTAssertTrue(app.checkBoxes["Add applied date"].isEnabled)
        XCTAssertTrue(app.checkBoxes["Add a due date"].isEnabled)
        replaceText(in: app.textFields["opportunity-title"], with: "VD2-07b cancelled draft")
        app.buttons["cancel-add-opportunity"].click()
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(rows.count, originalRowCount, "VD2-07b baseline [add]: Cancel must not write a row.")

        let originalRow = rows.firstMatch
        let originalLabel = originalRow.label
        let opportunityID = String(originalRow.identifier.dropFirst("pipeline-table-row-".count))
        originalRow.click()
        app.buttons["pipeline-open-details-\(opportunityID)"].click()
        let overviewControls: [(String, XCUIElement, String)] = [
            ("overview.title", app.textFields["selected-opportunity-title"], "text")
        ]
        for (key, element, _) in overviewControls { assertReadyTextControl(element, key: key) }
        XCTAssertGreaterThanOrEqual(app.textFields.count, 1, "VD2-07b baseline [overview]: text bindings must remain available.")
        XCTAssertGreaterThanOrEqual(app.textViews.count, 2, "VD2-07b baseline [overview multiline]: description and notes must remain editable.")
        for (index, label) in ["Pay period", "Work arrangement", "Stage", "Next action"].enumerated() {
            assertReadyPicker(label, index: index, key: "overview.\(label)", in: app)
        }
        replaceText(in: app.textFields["selected-opportunity-title"], with: "VD2-07b unsaved overview")
        app.buttons["Back to Pipeline"].click()
        XCTAssertTrue(app.descendants(matching: .any)["pipeline-table-row-\(opportunityID)"].waitForExistence(timeout: 5))
        XCTAssertEqual(rows.count, originalRowCount, "VD2-07b baseline [overview]: Back must not fabricate a row.")

        app.terminate()
        app = launchApp(fixture: "populated", session: session)
        app.descendants(matching: .any)["sidebar-pipeline"].tap()
        let persistedRow = app.descendants(matching: .any)["pipeline-table-row-\(opportunityID)"]
        XCTAssertTrue(persistedRow.waitForExistence(timeout: 5))
        XCTAssertEqual(persistedRow.label, originalLabel, "VD2-07b baseline [overview]: relaunch must discard Back-only edits.")
        app.buttons["pipeline-import-csv"].click()
        XCTAssertTrue(app.buttons["choose-csv-file"].waitForExistence(timeout: 5), "VD2-07b static-only [CSV]: existing app-side trigger must remain available.")
        app.descendants(matching: .any)["sidebar-pipeline"].tap()

        for (key, _, kind) in addControls + overviewControls {
            assertSharedControlSurface(key, kind: kind, state: "idle", in: app)
        }
        for key in ["add.url", "add.minimum", "add.maximum", "add.location", "overview.company", "overview.url", "overview.minimum", "overview.maximum", "overview.location"] {
            assertSharedControlSurface(key, kind: "text", state: "idle", in: app)
        }
        for key in ["add.description", "add.notes", "overview.description", "overview.notes"] {
            assertSharedControlSurface(key, kind: "multiline", state: "idle", in: app)
        }
        for key in ["add.payPeriod", "add.workArrangement", "add.response", "add.stage", "add.nextAction", "overview.payPeriod", "overview.workArrangement", "overview.stage", "overview.nextAction"] {
            assertSharedControlSurface(key, kind: "picker", state: "idle", in: app)
        }

        let reconciliationApp = launchApp(fixture: "reconciliation")
        reconciliationApp.buttons["Open Review reconciliation evidence"].click()
        for (index, label) in ["Local outcome", "Classification", "Reason", "Confidence"].enumerated() {
            assertReadyPicker(label, index: index, key: "reconcile.\(label)", in: reconciliationApp)
        }
        assertReadyFormTextField("Evidence or error reviewed", index: 0, key: "reconcile.evidence", in: reconciliationApp)
        for key in ["reconcile.outcome", "reconcile.classification", "reconcile.reason", "reconcile.confidence"] {
            assertSharedControlSurface(key, kind: "picker", state: "idle", in: reconciliationApp)
        }
        assertSharedControlSurface("reconcile.evidence", kind: "multiline", state: "idle", in: reconciliationApp)
    }

    @MainActor
    func testVD207bSettingsRecoveryFieldsRetainRootOwnershipAndFilePanelsRemainNative() {
        let archiveApp = launchApp(fixture: "archive")
        archiveApp.descendants(matching: .any)["sidebar-settings"].tap()
        let summary = archiveApp.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "settings-archive-summary-")).firstMatch
        XCTAssertTrue(summary.waitForExistence(timeout: 5), "VD2-07b baseline [settings]: archive truth must be present.")
        XCTAssertFalse(archiveApp.descendants(matching: .any)["settings-protected-export-success-dialog"].exists)

        archiveApp.buttons["create-portable-archive"].click()
        let archiveReentry = archiveApp.textFields["Re-enter the complete recovery key"]
        assertReadyTextControl(archiveReentry, key: "recovery.archiveReentry")
        archiveApp.buttons["Cancel"].click()
        XCTAssertTrue(summary.waitForExistence(timeout: 5))

        archiveApp.buttons["create-protected-export"].click()
        let protectedReentry = archiveApp.textFields["Recovery key"]
        assertReadyTextControl(protectedReentry, key: "settings.protectedExportReentry")
        archiveApp.buttons["Choose destination and review"].click()
        XCTAssertTrue(archiveApp.staticTexts["protected-export-error"].waitForExistence(timeout: 5), "VD2-07b baseline [protected export]: empty-key error must remain truthful.")
        XCTAssertFalse(archiveApp.descendants(matching: .any)["settings-protected-export-success-dialog"].exists)
        archiveApp.buttons["Cancel"].click()

        archiveApp.buttons["purge-retained-archive-data"].click()
        assertReadyTextControl(archiveApp.textFields["Recovery key"], key: "recovery.retainedPurgeReentry")
        archiveApp.buttons["Cancel"].click()
        XCTAssertTrue(archiveApp.buttons["restore-portable-archive"].isEnabled, "VD2-07b static-only [recovery.restoreReentry]: only the app-side trigger is observable without entering the excluded boundary.")
        assertSharedControlSurface("recovery.archiveReentry", kind: "text", state: "idle", in: archiveApp)
        assertSharedControlSurface("recovery.retainedPurgeReentry", kind: "text", state: "idle", in: archiveApp)
        assertSharedControlSurface("settings.protectedExportReentry", kind: "text", state: "idle", in: archiveApp)

        let documentApp = launchApp(fixture: "document-relink")
        documentApp.descendants(matching: .any)["sidebar-settings"].tap()
        documentApp.buttons["settings-section-document-references"].click()
        let documentPanel = documentApp.descendants(matching: .any)["settings-section-document-references-panel"]
        XCTAssertTrue(documentPanel.waitForExistence(timeout: 5))
        XCTAssertEqual(documentPanel.descendants(matching: .button).count, 0, "VD2-07b baseline [documents]: Settings remains aggregate-only.")
        XCTAssertFalse(documentApp.descendants(matching: .any)["settings-protected-export-success-dialog"].exists)
    }

    @MainActor
    func testVD207bCompactAndLargeTextControlLayout() {
        for windowSize in ["wide", "compact"] {
            let contactsApp = openContactsFixture(windowSize: windowSize)
            contactsApp.buttons["contact-new"].click()
            XCTAssertGreaterThanOrEqual(contactsApp.textViews.count, 2, "VD2-07b baseline [\(windowSize) contacts]: both multiline editors must remain scrollable.")
            if windowSize == "wide" {
                assertScrollRevealsAction(
                    contactsApp.buttons["Cancel"],
                    in: contactsApp.descendants(matching: .any)["contact-detail-scroll"],
                    key: "wide contacts Cancel"
                )
            } else {
                let compactDetail = contactsApp.descendants(matching: .any)["contact-compact-detail"]
                XCTAssertTrue(compactDetail.waitForExistence(timeout: 5), "VD2-07b baseline [compact contacts]: expected compact detail content layout.")
                XCTAssertFalse(compactDetail.frame.isEmpty, "VD2-07b baseline [compact contacts]: compact detail content must remain laid out.")
                replaceText(in: contactsApp.textFields["contact-name"], with: "VD2-07b compact draft")
                let compactScroll = contactsApp.scrollViews
                    .containing(.button, identifier: "save-contact")
                    .firstMatch
                assertScrollRevealsAction(
                    contactsApp.buttons["Cancel"],
                    in: compactScroll,
                    key: "compact contacts Cancel"
                )
                XCTAssertTrue(contactsApp.buttons["save-contact"].isHittable, "VD2-07b baseline [compact contacts Save]: primary action must remain reachable.")
            }
            assertSharedControlSurface("contacts.relationshipContext", kind: "multiline", state: "idle", in: contactsApp)
            assertSharedControlSurface("contacts.notes", kind: "multiline", state: "idle", in: contactsApp)
            contactsApp.terminate()

            let app = launchApp(fixture: "populated", windowSize: windowSize)
            app.descendants(matching: .any)["sidebar-pipeline"].tap()
            app.buttons["pipeline-add-opportunity"].click()
            XCTAssertGreaterThanOrEqual(app.textViews.count, 2, "VD2-07b baseline [\(windowSize) add]: description and notes must remain scrollable.")
            let addScroll = app.scrollViews
                .containing(.button, identifier: "cancel-add-opportunity")
                .firstMatch
            assertScrollRevealsAction(
                app.buttons["cancel-add-opportunity"],
                in: addScroll,
                key: "\(windowSize) add Cancel"
            )
            assertSharedControlSurface("add.description", kind: "multiline", state: "idle", in: app)
            assertSharedControlSurface("add.notes", kind: "multiline", state: "idle", in: app)
            app.terminate()
        }
    }
}
