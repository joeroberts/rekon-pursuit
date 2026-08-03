# VD2-04 Pipeline Feedback Correction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Repair the approved VD2-04 Pipeline visual feedback while preserving local selection and the existing canonical details workflow.

**Architecture:** `PipelineView` continues to own only ephemeral presentation state. At compact widths, a selected row renders a trailing overlay drawer in the table region; at wide widths, the existing adjacent inspector remains. Theme components provide semantic control treatment, while `AppShellView` owns the sole sidebar-visibility toolbar action.

**Tech Stack:** Swift 6, SwiftUI on macOS, XCTest/XCUITest, Xcode signed Debug build.

## Global Constraints

- This is a VD2-04 correction; VD2-05 remains blocked.
- Do not modify `ContentView.swift`, `WorkspaceViewModel.swift`, models, stores, activity/audit behavior, Board behavior, or opportunity editing.
- The compact inspector is a right-edge in-place drawer, never a sheet or a below-table panel.
- Selection stays local and ephemeral; only the existing `Open details` callback may leave Pipeline.
- Use `RekonTheme` and `RekonVisualThemeContract`; add no dependency or hard-coded gray control system.
- Build and test signed Debug; never disable code signing.
- The worktree contains approved user changes. Stage or commit only the files explicitly modified for a slice, and only after checking the diff.

---

## File structure

| File | Responsibility |
| --- | --- |
| `RekonPursuit/PipelineView.swift` | Pipeline toolbar layout, compact drawer, selected-row presentation, inspector close affordance. |
| `RekonPursuit/RekonVisualTheme.swift` | Shared Pipeline control surface and secondary-button hover/focus/pressed presentation. |
| `RekonPursuit/AppShellView.swift` | App-owned sidebar collapse/show control and system-toggle suppression. |
| `RekonPursuitUITestHost/BootstrapApp.swift` | Test-host-only launch argument that selects deterministic compact or wide default window size. |
| `RekonPursuitUITestHostTests/RekonPursuitUITestHostTests.swift` | Unit coverage that the test-only size argument maps only to supported dimensions. |
| `RekonPursuitUITests/RekonPursuitUITests.swift` | Fixture-host regression coverage for drawer, selection semantics, toolbar, controls, and sidebar toggle. |
| `docs/delivery/*` | Delivery-manager-only evidence after independent technical gates pass. |

### Task 0: Calibrate the compact test surface and stale release record

**Files:**

- Modify: `RekonPursuitUITestHost/BootstrapApp.swift`
- Modify: `RekonPursuitUITestHostTests/RekonPursuitUITestHostTests.swift`
- Modify: `RekonPursuitUITests/RekonPursuitUITests.swift`
- Modify: delivery records only through the independent Delivery Manager gate.

**Interfaces:**

- Consumes: the fixture-host window, existing `sidebar-collapse`, and the current VD2-04 dashboard/owner handoff.
- Produces: a deterministic 860×640 supported compact assertion (from an 860×600 host request constrained by the existing shell minimum), a recorded framework-toggle AX selector, and a correction-in-progress delivery state.

- [ ] **Step 1: Write a failing test-host size-contract test.**

  Add a test-only `VisualFixtureWindowSize` value with cases `compact` and `wide`. In `RekonPursuitUITestHostTests`, assert `compact` maps to `CGSize(width: 860, height: 600)`, `wide` maps to `CGSize(width: 1100, height: 760)`, and absent, unsupported, and present-without-value `-rekon-visual-window-size` input each map safely to the existing 1100×760 default.

- [ ] **Step 2: Run the new host test expecting RED.**

  ```bash
  xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit -destination 'platform=macOS,arch=arm64' \
    -only-testing:RekonPursuitUITestHostTests/RekonPursuitUITestHostTests/testVisualFixtureWindowSizeParsesSupportedArguments \
    -resultBundlePath /tmp/rekon-vd204-feedback-window-red.xcresult
  ```

  Expected: RED because no test-host window-size launch configuration exists.

- [ ] **Step 3: Establish a deterministic compact-width test seam.**

  In `RekonPursuitUITestHost/BootstrapApp.swift`, parse `-rekon-visual-window-size compact|wide` in test-host-only code and feed the resulting `CGSize` to `.defaultSize(width:height:)`. Extend `launchApp(fixture:windowSize:)` to pass `compact`; before compact assertions, wait for the app window and assert its supported live frame is exactly 860×640 within `0.5` points. The host requests 860×600, while the established AppShell minimum height raises that request to 640; do not change the production minimum. Use `wide` in wide toolbar assertions.

- [ ] **Step 4: Capture the duplicate system-control baseline.**

  On the rejected compact build, run the compact fixture test with an AX-tree diagnostic attachment or `debugDescription`, inspect the second toolbar affordance, and record its live role, label, and identifier in a delivery evidence note plus the test helper. Query it separately from `sidebar-collapse`; never guess a label from framework documentation.

- [ ] **Step 5: Correct stale delivery state before release.**

  The Delivery Manager changes the handoff/dashboard/roadmap from `awaiting acceptance` to `correction in progress`, records the owner’s rejected sheet/stacked experience and approved right-drawer correction, sets `needsUserAction` false while engineering runs, keeps VD2-04 `in_progress`, and leaves VD2-05 blocked.

### Task 1: Establish the failing UI contract

**Files:**

- Modify: `RekonPursuitUITests/RekonPursuitUITests.swift`

**Interfaces:**

- Consumes: fixture `pipeline`, `pipeline-table-row-<id>`, `pipeline-inspector-<id>`, `pipeline-open-details-<id>`, and `sidebar-collapse`.
- Produces: `pipeline-inspector-drawer`, `pipeline-inspector-close`, `pipeline-view-mode`, and visible-only `pipeline-view-label` test contracts.

- [ ] **Step 1: Replace the sheet helper and migrate every former-sheet caller.**

  Delete `revealPipelineInspectorIfCompact(in:)` and migrate its seven prior callers. Compact assertions that formerly required `pipeline-inspector-empty` now assert the drawer is absent and `pipeline-table-region` remains hittable. Add helpers that query the app-owned `sidebar-collapse` control and count the Task 0 observed `Hide Sidebar` AXButton (empty identifier) separately.

- [ ] **Step 2: Add the compact-drawer RED test.**

  Add `testVD204PipelineCompactWindowUsesAnInPlaceRightDrawer`:

  ```swift
  row.tap()
  XCTAssertTrue(app.descendants(matching: .any)["pipeline-inspector-drawer"].waitForExistence(timeout: 5))
  XCTAssertTrue(app.descendants(matching: .any)["pipeline-inspector-\(id)"].exists)
  XCTAssertTrue(app.buttons["pipeline-inspector-close"].exists)
  XCTAssertEqual(app.sheets.count, 0)
  XCTAssertTrue(row.exists)
  let table = app.descendants(matching: .any)["pipeline-table-region"]
  let drawer = app.descendants(matching: .any)["pipeline-inspector-drawer"]
  XCTAssertGreaterThan(drawer.frame.minX, table.frame.minX)
  XCTAssertEqual(drawer.frame.maxX, table.frame.maxX, accuracy: 0.5)
  XCTAssertGreaterThanOrEqual(drawer.frame.minY, table.frame.minY)
  XCTAssertLessThanOrEqual(drawer.frame.maxY, table.frame.maxY)
  XCTAssertFalse(app.buttons["pipeline-inspector-disclosure"].exists)
  XCTAssertFalse(app.descendants(matching: .any)["pipeline-inspector-empty"].exists)
  app.buttons["pipeline-inspector-close"].tap()
  XCTAssertTrue(app.descendants(matching: .any)["pipeline-inspector-drawer"].waitForNonExistence(timeout: 5))
  XCTAssertTrue(row.isHittable)
  ```

  Attach a screenshot while open and another after close. Reselect a different
  row and assert only its inspector is present.

- [ ] **Step 3: Add the selection-semantic RED test.**

  Add `testVD204PipelineTableSelectionHasNoRadioChildControl`. Assert the tapped row changes from `Not selected` to `Selected`, the Pipeline-table subtree has no selection-control role, and the drawer appears. Establish the current glyph in a compact baseline screenshot and require its absence in the GREEN screenshot/manual review; do not claim AX can prove removal of an accessibility-hidden visual glyph.

- [ ] **Step 4: Add responsive-toolbar/control RED tests.**

  Add `testVD204PipelineCompactToolbarKeepsTheViewSwitcherOnOneLine` and `testVD204PipelineControlsRemainKeyboardDiscoverableAndStyled`. At the deterministic 860×640 supported compact contract assert `pipeline-view-mode` is hittable with accessibility label `View` while `pipeline-view-label` is absent; at a wide layout assert both exist. Assert identifiers, native roles/labels, activation, and hittability for `opportunity-search`, `pipeline-stage-filter`, `pipeline-include-closed`, `pipeline-view-mode`, and `pipeline-import-csv`; do not assert literal Tab traversal because Full Keyboard Access is host-dependent. Attach compact and wide screenshots for visual review.

- [ ] **Step 5: Add the one-toggle RED test.**

  Add `testVD204ShellExposesOnlyTheAppOwnedSidebarToggle`. Assert one hittable `sidebar-collapse`, its Collapse/Show labels transition when tapped, and the observed framework sidebar control is absent.

- [ ] **Step 6: Run the five new tests expecting RED.**

  Run:

  ```bash
  xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit -destination 'platform=macOS,arch=arm64' \
    -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD204PipelineCompactWindowUsesAnInPlaceRightDrawer \
    -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD204PipelineTableSelectionHasNoRadioChildControl \
    -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD204PipelineCompactToolbarKeepsTheViewSwitcherOnOneLine \
    -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD204PipelineControlsRemainKeyboardDiscoverableAndStyled \
    -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD204ShellExposesOnlyTheAppOwnedSidebarToggle \
    -resultBundlePath /tmp/rekon-vd204-feedback-red.xcresult
  ```

  Expected: RED because the current app has a sheet/disclosure flow, row icon, wrapped View label, unthemed Pipeline controls, and a second sidebar button.

### Task 2: Replace compact sheet flow with local drawer

**Files:**

- Modify: `RekonPursuit/PipelineView.swift`
- Test: `RekonPursuitUITests/RekonPursuitUITests.swift`

**Interfaces:**

- Consumes: `selectedOpportunity`, `selectedTableID`, `open(_:)`, and Task 1 identifiers.
- Produces: a trailing `pipeline-inspector-drawer`, `pipeline-inspector-close`, and row-only selection affordance.

- [ ] **Step 1: Confirm drawer/row tests fail cleanly.**

  Run the two Task 1 tests individually and confirm the failure identifies the missing drawer/row contract rather than fixture launch or signing.

- [ ] **Step 2: Implement compact drawer state and geometry.**

  Remove `showsCompactInspector`, the `.sheet`, and the disclosure button. Use `selectedTableID` as the only compact-presentation state. In the compact `GeometryReader` branch, put `table` (identified as `pipeline-table-region`) in `ZStack(alignment: .trailing)`. When `selectedOpportunity` is non-nil, overlay:

  ```swift
  PipelineInspector(opportunity: selectedOpportunity, close: { selectedTableID = nil }) {
      anchorID = selectedOpportunity.id
      open(selectedOpportunity)
  }
  .accessibilityIdentifier("pipeline-inspector-drawer")
  .frame(width: min(380, max(300, geometry.size.width * 0.48)))
  .transition(.move(edge: .trailing).combined(with: .opacity))
  ```

  Read `@Environment(\.accessibilityReduceMotion)` and use a nil/no-motion transaction when it is true; otherwise use the trailing transition. Keep the table at full container width below the overlay.

- [ ] **Step 3: Add the close affordance without route/persistence effects.**

  Extend `PipelineInspector` with `let close: (() -> Void)?`. When non-nil, render a close `Button` with identifier `pipeline-inspector-close`, accessibility label `Close selection details`, and a plain, visible X-mark. Calling it clears only `selectedTableID`. Retain `pipeline-open-details-<id>` exactly.

- [ ] **Step 4: Remove the redundant row icon and compact empty panel.**

  Delete the `circle`/`checkmark.circle.fill` image in `PipelineTableRow`. Retain selected background and row accessibility value. In compact no-selection state render only the table. In wide no-selection inspector use `rectangle.rightthird.inset.filled` and concise matching copy.

- [ ] **Step 5: Run focused GREEN verification.**

  ```bash
  xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit -destination 'platform=macOS,arch=arm64' \
    -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD204PipelineCompactWindowUsesAnInPlaceRightDrawer \
    -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD204PipelineTableSelectionHasNoRadioChildControl \
    -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD204PipelineTableSelectsAnEphemeralInspectorAndOnlyOpenDetailsRoutes \
    -resultBundlePath /tmp/rekon-vd204-feedback-drawer-green.xcresult
  ```

### Task 3: Make Pipeline controls responsive and styled

**Files:**

- Modify: `RekonPursuit/PipelineView.swift`
- Modify: `RekonPursuit/RekonVisualTheme.swift`
- Test: `RekonPursuitUITests/RekonPursuitUITests.swift`

**Interfaces:**

- Consumes: `RekonTheme`, `RekonVisualThemeContract`, and Task 1 control identifiers.
- Produces: one-line accessible `pipeline-view-mode`, visible-only `pipeline-view-label`, semantic Pipeline control styles, and hover-responsive secondary buttons.

- [ ] **Step 1: Confirm toolbar/control tests are RED.**

  Re-run the Task 1 toolbar/control tests. Confirm failures concern the visual-control contract, not Task 2 behavior.

- [ ] **Step 2: Implement the width-aware toolbar arrangement.**

  Split Pipeline controls into complete groups. Use `ViewThatFits(in: .horizontal)` (or the existing geometry seam) so the wide variant includes:

  ```swift
  Text("View").accessibilityIdentifier("pipeline-view-label")
  Picker("View", selection: $showsBoard) { ... }
      .labelsHidden()
      .pickerStyle(.segmented)
      .accessibilityIdentifier("pipeline-view-mode")
      .accessibilityLabel("View")
  ```

  The compact variant omits the visible `Text` but retains the labelled picker. Do not allow the label to wrap.

- [ ] **Step 3: Add shared semantic Pipeline control treatment.**

  Define a focused/hover-aware control-surface modifier or style in `RekonVisualTheme.swift` using `RekonTheme.surface`, `elevatedSurface`, `border`, and `accent` plus existing contract widths. Reuse the globally applied `RekonTextFieldStyle` rather than double-wrapping its search field; apply the new surface once to Pipeline Picker/Toggle/segmented containers without changing their native roles.

- [ ] **Step 4: Strengthen secondary-button interaction feedback.**

  Add `@State private var isPointerHovering = false` to `RekonSecondaryButtonStyle`, then use `.onHover { isPointerHovering = $0 }` and semantic accent/border/surface changes for hover, focus, and pressed state. Do not make Import CSV primary-gradient.

- [ ] **Step 5: Run focused GREEN verification.**

  ```bash
  xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit -destination 'platform=macOS,arch=arm64' \
    -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD204PipelineCompactToolbarKeepsTheViewSwitcherOnOneLine \
    -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD204PipelineControlsRemainKeyboardDiscoverableAndStyled \
    -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD204PipelineFiltersUseOnlyTheSessionLocalControlsAndExposeTruthfulNoResults \
    -resultBundlePath /tmp/rekon-vd204-feedback-controls-green.xcresult
  ```

### Task 4: Guarantee one sidebar visibility affordance

**Files:**

- Modify: `RekonPursuit/AppShellView.swift`
- Test: `RekonPursuitUITests/RekonPursuitUITests.swift`

**Interfaces:**

- Consumes: `columnVisibility`, existing app-owned `sidebar-collapse`, and Task 1 framework-toggle query.
- Produces: exactly one accessible sidebar visibility action without affecting native traffic-light controls.

- [ ] **Step 1: Confirm one-toggle test is RED.**

  Run the Task 1 shell test and record the framework control’s actual AX role/label in the test assertion before changing the shell.

- [ ] **Step 2: Correct toolbar ownership.**

  Retain the app-owned toolbar item and dynamic `Show sidebar`/`Collapse sidebar` labels. Make `.toolbar(removing: .sidebarToggle)` the outermost toolbar-ownership modifier after the custom `.toolbar`, so the framework button cannot render next to the app control at compact width. Update the legacy compact-rail assertion from one framework toggle to zero; verify both `Hide Sidebar` and `Show Sidebar` are absent before collapse, after collapse, and after restore. Do not change native title-bar controls.

- [ ] **Step 3: Run shell GREEN verification.**

  ```bash
  xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit -destination 'platform=macOS,arch=arm64' \
    -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD204ShellExposesOnlyTheAppOwnedSidebarToggle \
    -only-testing:RekonPursuitUITests/RekonPursuitUITests/testSidebarIsDiscoverableAndCanCollapseAndRestore \
    -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD202CompactRailKeepsNativeWindowControlsReachable \
    -resultBundlePath /tmp/rekon-vd204-feedback-sidebar-green.xcresult
  ```

### Task 5: Independent release gates and owner re-acceptance

**Files:**

- Modify after independent code/QA/security sign-off only: `docs/delivery/evidence/visual-design-v2/VD2-04-owner-handoff-2026-07-30.md`, `docs/delivery/dashboard-status.json`, `docs/delivery/dashboard/index.html`, `docs/delivery/dashboard/remediation.html`, and `docs/delivery/roadmap.md`.

**Interfaces:**

- Consumes: reviewer, QA, architect, TPM, security, and delivery-manager evidence.
- Produces: an updated in-progress VD2-04 record and a renewed product-owner acceptance request; VD2-05 stays blocked.

- [ ] **Step 1: Run independent code review.**

  Confirm no compact `.sheet`, disclosure button, stacked empty inspector, or row radio/check-circle remains; verify only Open details routes and no out-of-scope persistence/model/Board changes exist.

- [ ] **Step 2: Run independent QA and security/privacy verification.**

  ```bash
  xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit -destination 'platform=macOS,arch=arm64' \
    -only-testing:RekonPursuitTests -only-testing:RekonPursuitUITests -only-testing:RekonPursuitUITestHostTests \
    -resultBundlePath /tmp/rekon-vd204-feedback-final.xcresult
  xcodebuild build -project RekonPursuit.xcodeproj -scheme RekonPursuit -configuration Debug -destination 'platform=macOS,arch=arm64'
  git diff --check
  ```

  Verify UI behavior and scope: no storage, provider, network, or activity route changed.

- [ ] **Step 3: Conduct signed-Debug visual/accessibility inspection.**

  Review 860×640 supported compact and wide Pipeline at default and increased text size; drawer open/close/reselect; no-results and filtered/deleted selections; keyboard/VoiceOver; Import CSV hover/focus/press; and the one sidebar toggle. Record screenshots and paths.

- [ ] **Step 4: Update the delivery ledger without accepting.**

  Record the user’s prior visual rejection, approved correction, technical gate evidence, and remaining owner re-acceptance. Keep VD2-04 `in_progress`, owner action required, and VD2-05 blocked.

## Self-review

- Spec coverage: Tasks 2–4 cover every approved correction; Task 5 preserves required independent governance and dashboard updates.
- Completeness scan: every code task identifies files, interfaces, tests, and commands.
- Type consistency: `PipelineInspector.close`, `pipeline-inspector-drawer`, `pipeline-inspector-close`, `pipeline-view-mode`, and `pipeline-view-label` are defined once and consumed consistently.
