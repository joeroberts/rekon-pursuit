# VD2-04 — Pipeline feedback correction (right drawer and control polish)

## Purpose and release boundary

This corrective brief implements the accepted product-owner feedback recorded in
`docs/superpowers/specs/2026-07-30-vd204-pipeline-feedback-design.md`. It
replaces the current compact inspector sheet and below-table disclosure with an
in-place, right-side drawer; removes the redundant radio/check-circle row
affordance; prevents toolbar wrapping; brings Pipeline controls into the Rekon
visual system; and leaves exactly one sidebar expand/collapse control.

This remains a **VD2-04 correction**, not a new card. `VD2-05` remains blocked
until the correction has passed all independent gates and the product owner has
re-accepted VD2-04.

## Controlling contracts

- `ContentView` remains the only owner of the workspace model, canonical route,
  dialogs, and Pipeline return anchor. `PipelineView` may own only local view
  state.
- A table-row selection is local and ephemeral: no store write, activity event,
  canonical selection, draft load, or route change may occur until **Open
  details** invokes the existing callback.
- The compact right drawer is an in-place overlay over the table's trailing
  edge. It is neither a SwiftUI sheet nor a panel stacked below the table.
  Wide layouts keep the adjacent persistent inspector.
- The existing `pipeline` fixture, test-host isolation, fixed clock, and
  signed-Debug test host remain mandatory. Do not add a dependency, schema,
  persistence, live-workspace access, or network behavior.
- Keyboard and VoiceOver must expose a selected row, view switcher, drawer and
  close action, existing Open details action, styled input/filter controls, and
  one sidebar-toggle action.

## File map

| File | Responsibility |
| --- | --- |
| `RekonPursuit/PipelineView.swift` | Responsive Pipeline toolbar, local drawer presentation, table rows, empty inspector surface, and Pipeline control styling hooks. |
| `RekonPursuit/RekonVisualTheme.swift` | Shared semantic presentation for secondary-button hover/pressed/focus and Pipeline form controls; no raw per-screen gray surfaces. |
| `RekonPursuit/AppShellView.swift` | Suppress the framework sidebar toggle while retaining the app-owned `sidebar-collapse` toolbar button. |
| `RekonPursuitUITestHost/BootstrapApp.swift` | Test-host-only compact/wide window-size launch seam. |
| `RekonPursuitUITestHostTests/RekonPursuitUITestHostTests.swift` | Deterministic window-size argument tests. |
| `RekonPursuitUITests/RekonPursuitUITests.swift` | Fixture-host UI regression tests for compact drawer, selection semantics, responsive toolbar, controls, and a single rail toggle. |
| `docs/delivery/evidence/visual-design-v2/VD2-04-owner-handoff-2026-07-30.md` | Replace superseded sheet evidence with correction evidence after all technical gates pass; do not claim owner acceptance. |
| `docs/delivery/dashboard-status.json`, `docs/delivery/dashboard/index.html`, `docs/delivery/dashboard/remediation.html`, `docs/delivery/roadmap.md` | Delivery manager only: keep VD2-04 in progress and record the owner-feedback correction and new evidence. |

No change is authorized to `ContentView.swift`, `WorkspaceViewModel.swift`,
store/model schema, activity/audit code, Board workflow, opportunity editing,
or VD2-05 files.

## Dependencies and order

1. **Task 1** establishes the red UI contract and accessible identifiers for
   the drawer, responsive toolbar, and one-toggle rule.
2. **Task 2** implements the drawer and row semantics against Task 1 tests.
3. **Task 3** implements the control/theme polish and toolbar adaptation
   against Task 1 tests.
4. **Task 4** removes the duplicate system sidebar affordance and verifies the
   shell does not regress.
5. **Task 5** is independent QA/delivery evidence after Tasks 2–4 are green.

Tasks 2–4 must be serial because they touch `PipelineView.swift` and/or
`AppShellView.swift`; no agents may edit those files concurrently.

## Gate amendments before implementation release

- The independent Delivery Manager first changes stale `awaiting acceptance`
  records to **correction in progress**, records the rejected compact sheet and
  below-list presentation, marks no owner action pending while repair runs,
  and keeps VD2-05 blocked.
- A test-host-only `-rekon-visual-window-size compact|wide` launch seam must
  request 860×600 or 1100×760 and be unit-tested before compact UI assertions.
  The existing production minimum makes the verified live compact surface
  860×640; no test may weaken that product constraint.
- The duplicate framework sidebar control must be measured by its live AX
  role/label/identifier on the rejected compact build before a suppression
  assertion prescribes a fix.
- Drawer tests require a `pipeline-table-region` identifier and assert the
  drawer is trailing-aligned and within that region’s bounds (without an
  impossible half-width requirement at 860pt), and is not accompanied by the
  former disclosure or compact empty panel.
- The old selection glyph is accessibility-hidden; establish it in a baseline
  screenshot and require a GREEN screenshot/manual visual check, rather than
  claiming accessibility queries alone prove its absence.
- Migrate all sheet-helper callers. Compact return/filter/delete assertions
  must check that drawer/inspector are absent and the table stays accessible.
- Automation verifies roles, labels, identifiers, activation, and geometry;
  signed-Debug manual QA verifies pointer hover, focus/pressed treatment,
  visual no-wrap, real keyboard traversal, VoiceOver, and large-text layout.
- The compact drawer uses only `selectedTableID`/`selectedOpportunity` as its
  presentation state and suppresses insertion/removal animation when
  `accessibilityReduceMotion` is enabled.

## Task 1: Establish the corrective regression contract

**Files:**

- Modify: `RekonPursuitUITests/RekonPursuitUITests.swift`

**Consumes:** Existing `pipeline` fixture and identifiers
`pipeline-table-row-<opportunityID>`, `pipeline-inspector-<opportunityID>`,
`pipeline-open-details-<opportunityID>`, and `sidebar-collapse`.

**Produces:** The following test names and required identifiers:

- `pipeline-inspector-drawer`
- `pipeline-inspector-close`
- `pipeline-view-mode`
- `pipeline-view-label` (visible text only; absent when constrained)
- `pipeline-import-csv`
- `pipeline-stage-filter`, `pipeline-include-closed`, and
  `opportunity-search`
- `testVD204PipelineCompactWindowUsesAnInPlaceRightDrawer`
- `testVD204PipelineTableSelectionHasNoRadioChildControl`
- `testVD204PipelineCompactToolbarKeepsTheViewSwitcherOnOneLine`
- `testVD204PipelineControlsRemainKeyboardDiscoverableAndStyled`
- `testVD204ShellExposesOnlyTheAppOwnedSidebarToggle`

- [ ] **Step 1: Replace the obsolete compact-sheet helper with drawer-aware test helpers.**

  Delete `revealPipelineInspectorIfCompact(in:)`; a compact row tap must now
  immediately expose the inspector. Add a helper that returns the app-owned
  sidebar toggle and a helper that counts the measured framework `Hide Sidebar`
  AXButton (empty identifier) separately from `sidebar-collapse`.

- [ ] **Step 2: Write the failing compact drawer test.**

  In `testVD204PipelineCompactWindowUsesAnInPlaceRightDrawer`, launch the
  `pipeline` fixture at the supported 860×640 live compact window, enter Pipeline, tap a
  row, and assert all of the following:

  ```swift
  XCTAssertTrue(app.descendants(matching: .any)["pipeline-inspector-drawer"].waitForExistence(timeout: 5))
  XCTAssertTrue(app.descendants(matching: .any)["pipeline-inspector-\\(id)"].exists)
  XCTAssertTrue(app.buttons["pipeline-inspector-close"].exists)
  XCTAssertEqual(app.sheets.count, 0)
  XCTAssertTrue(row.exists)
  XCTAssertGreaterThanOrEqual(drawer.frame.minY, table.frame.minY)
  XCTAssertLessThanOrEqual(drawer.frame.maxY, table.frame.maxY)
  app.buttons["pipeline-inspector-close"].tap()
  XCTAssertTrue(app.descendants(matching: .any)["pipeline-inspector-drawer"].waitForNonExistence(timeout: 5))
  XCTAssertTrue(row.isHittable)
  ```

  Attach screenshots with the drawer open and after close. Tap a second row
  after closing and prove the drawer contains only that row's inspector. This
  specifically rejects the former disclosure, sheet, and below-table empty-state flow.

- [ ] **Step 3: Write the failing row-semantic test.**

  In `testVD204PipelineTableSelectionHasNoRadioChildControl`, tap a fixture
  row, assert its accessibility value changes from `Not selected` to
  `Selected`, and assert there is no separately discoverable child button,
  checkbox, radio button, or image exposed as a selection control. The test
  must query the row's descendant accessibility elements rather than its
  rendered pixels. Selecting the row must still expose its inspector.

- [ ] **Step 4: Write the failing compact-toolbar and controls tests.**

  At the supported 860×640 live compact window, assert `pipeline-view-mode` is present, hittable, has the
  accessibility label `View`, and its visible `pipeline-view-label` is absent.
  At a wide window, assert both label and segmented switcher exist. In the
  controls test, assert the native roles, labels, stable identifiers,
  activation, and `isHittable` status of the search, stage selector, Closed
  checkbox, segmented switcher, and Import CSV action. Do not assert literal
  Tab traversal because Full Keyboard Access is host-dependent. Capture an
  `XCTAttachment` screenshot at both widths for independent visual review.

- [ ] **Step 5: Write the failing one-sidebar-toggle test.**

  Assert exactly one hittable element has identifier `sidebar-collapse`; it
  alternates labels `Collapse sidebar` and `Show sidebar` when activated.
  Assert the measured framework `Hide Sidebar` AXButton with empty identifier is absent from the
  accessibility tree. Do not rely only on the custom identifier, because that
  would miss a second framework button.

- [ ] **Step 6: Run the new tests and preserve the expected RED evidence.**

  Run from the repository worktree:

  ```bash
  xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit \
    -destination 'platform=macOS,arch=arm64' \
    -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD204PipelineCompactWindowUsesAnInPlaceRightDrawer \
    -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD204PipelineTableSelectionHasNoRadioChildControl \
    -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD204PipelineCompactToolbarKeepsTheViewSwitcherOnOneLine \
    -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD204PipelineControlsRemainKeyboardDiscoverableAndStyled \
    -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD204ShellExposesOnlyTheAppOwnedSidebarToggle \
    -resultBundlePath /tmp/rekon-vd204-feedback-red.xcresult
  ```

  **Expected:** failure because the current code presents a sheet/disclosure,
  shows a radio-style image, allows the visible View label to wrap, and exposes
  a second sidebar button in the reported compact layout.

## Task 2: Implement the local compact right drawer and honest row selection

**Files:**

- Modify: `RekonPursuit/PipelineView.swift`
- Test: `RekonPursuitUITests/RekonPursuitUITests.swift`

**Consumes:** Task 1 identifiers and compact-drawer tests.

**Produces:** Local `@State` drawer visibility derived from selection, the
`pipeline-inspector-drawer` and `pipeline-inspector-close` controls, and
selection-only row accessibility state.

- [ ] **Step 1: Keep Task 1 drawer and row tests failing before production edits.**

  Re-run the two Task 1 tests individually and confirm each fails for the
  intended missing/incorrect behavior, not a fixture launch error.

- [ ] **Step 2: Replace the compact `.sheet` and disclosure/stack branch.**

  Remove `showsCompactInspector`, the `.sheet(isPresented:)` modifier, and the
  `Show selection details` button. In the compact `responsiveTable` branch,
  render the table at full available width inside a trailing-aligned `ZStack`.
  When `selectedOpportunity` is non-nil, overlay an in-place drawer aligned to
  `.trailing`, constrained to a readable width that leaves table context where
  space permits. It must contain `PipelineInspector`, have accessibility ID
  `pipeline-inspector-drawer`, and animate insertion/removal from the trailing
  edge while respecting Reduce Motion.

  Give `PipelineInspector` an optional close callback used only in the compact
  drawer. Its close button has ID `pipeline-inspector-close` and an accessible
  label such as `Close selection details`. Preserve the existing Open details
  callback and ID unchanged. Closing hides the drawer only; it does not route,
  clear persistence, or mutate the row/store. A new row tap while open changes
  the drawer content to the new current filtered record.

- [ ] **Step 3: Remove the radio/check-circle visual.**

  Delete the `Image(systemName: isSelected ? "checkmark.circle.fill" :
  "circle")` from `PipelineTableRow`. Retain the existing full-row selection
  background and row-level `Selected`/`Not selected` accessibility value; do
  not add any replacement radio button or independent selection control.

- [ ] **Step 4: Correct the no-selection presentation.**

  In the wide adjacent inspector retain a concise, details-panel-consistent
  empty message with a matching panel icon (not `sidebar.right`). In compact
  layout do not render a large below-list empty panel: no selected record means
  the full table remains unobstructed. Filtering/deletion must close the
  drawer when the selected ID leaves the filtered projection.

- [ ] **Step 5: Run focused GREEN checks.**

  ```bash
  xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit \
    -destination 'platform=macOS,arch=arm64' \
    -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD204PipelineCompactWindowUsesAnInPlaceRightDrawer \
    -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD204PipelineTableSelectionHasNoRadioChildControl \
    -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD204PipelineTableSelectsAnEphemeralInspectorAndOnlyOpenDetailsRoutes \
    -resultBundlePath /tmp/rekon-vd204-feedback-drawer-green.xcresult
  ```

  **Expected:** all selected tests pass. Inspect the result attachment to prove
  the drawer is not a sheet and table content is not stacked below it.

## Task 3: Make the Pipeline toolbar and controls responsive and coherent

**Files:**

- Modify: `RekonPursuit/PipelineView.swift`
- Modify: `RekonPursuit/RekonVisualTheme.swift`
- Test: `RekonPursuitUITests/RekonPursuitUITests.swift`

**Consumes:** Task 1 toolbar/control tests and existing semantic Rekon tokens.

**Produces:** A compact-safe `pipeline-view-mode` switcher, visible-only
`pipeline-view-label`, and shared focus/hover/pressed control treatments.

- [ ] **Step 1: Re-run the two Task 1 visual-control tests and confirm RED.**

  The failures must identify the View-label/wrapping or control presentation
  contract, not interaction regressions introduced by Task 2.

- [ ] **Step 2: Make the toolbar adapt before labels wrap.**

  Give the Table/Board picker identifier `pipeline-view-mode` and accessibility
  label `View`. Use a width-aware toolbar arrangement (`ViewThatFits` or the
  existing geometry seam) that retains a visible `Text("View")` with ID
  `pipeline-view-label` only when it and the segmented control fit on one line.
  At constrained widths omit that visible label rather than allowing character
  wrapping; do not hide the picker accessibility label. Allow other groups to
  reflow as complete control groups, never with a broken text label.

- [ ] **Step 3: Apply semantic Pipeline form-control surfaces.**

  Apply one shared dark elevated/surface background, border, pointer-hover,
  keyboard-focus, and pressed treatment to the Pipeline search field, Stage
  picker, checkbox, and segmented view switcher. The style must use
  `RekonTheme` semantic colors and `RekonVisualThemeContract` constants rather
  than hard-coded gray literals in `PipelineView`. Preserve native keyboard
  behavior and VoiceOver roles for `TextField`, `Picker`, `Toggle`, and
  segmented control.

- [ ] **Step 4: Strengthen the secondary Import CSV affordance without making it primary.**

  Extend `RekonSecondaryButtonStyle` with explicit `onHover` state and retain
  existing focus/pressed handling, using semantic surface/border/accent tokens.
  Import CSV must visibly react on pointer hover, keyboard focus, and press;
  Add opportunity remains the only primary-gradient action. Check every caller
  of `RekonSecondaryButtonStyle` visually so the shared change does not erase
  existing labels, hit targets, or disabled-state contrast.

- [ ] **Step 5: Run the focused GREEN checks.**

  ```bash
  xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit \
    -destination 'platform=macOS,arch=arm64' \
    -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD204PipelineCompactToolbarKeepsTheViewSwitcherOnOneLine \
    -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD204PipelineControlsRemainKeyboardDiscoverableAndStyled \
    -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD204PipelineFiltersUseOnlyTheSessionLocalControlsAndExposeTruthfulNoResults \
    -resultBundlePath /tmp/rekon-vd204-feedback-controls-green.xcresult
  ```

  **Expected:** all selected tests pass. The implementer must inspect captured
  860×640 and wide screenshots for no wrapped `View` text, no unstyled gray
  control surfaces, and a visibly responsive Import CSV button.

## Task 4: Restore exactly one sidebar expansion/collapse affordance

**Files:**

- Modify: `RekonPursuit/AppShellView.swift`
- Test: `RekonPursuitUITests/RekonPursuitUITests.swift`

**Consumes:** Task 1 one-toggle test and existing `sidebar-collapse` behavior.

**Produces:** The only sidebar visibility action is the app-owned toolbar
button with stable identifier `sidebar-collapse`.

- [ ] **Step 1: Re-run the one-toggle test and confirm it is RED against the reported compact layout.**

  Verify the failure is a second framework-supplied toggle, not a missing
  app-owned toggle.

- [ ] **Step 2: Remove the framework toggle at the owning NavigationSplitView boundary.**

  Retain the current custom `ToolbarItem(placement: .navigation)` control and
  its dynamic Show/Collapse labels. Move `.toolbar(removing: .sidebarToggle)`
  after the custom `.toolbar` so it is the outermost toolbar-ownership
  modifier and macOS cannot reintroduce the system sidebar toggle beside it at
  compact width. Update the old compact-rail test from one framework button to
  zero `Hide Sidebar`/`Show Sidebar` controls before collapse, after collapse,
  and after restore. Do not remove native traffic-light controls or substitute
  a non-accessible image gesture.

- [ ] **Step 3: Run focused shell GREEN checks.**

  ```bash
  xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit \
    -destination 'platform=macOS,arch=arm64' \
    -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD204ShellExposesOnlyTheAppOwnedSidebarToggle \
    -only-testing:RekonPursuitUITests/RekonPursuitUITests/testSidebarIsDiscoverableAndCanCollapseAndRestore \
    -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD202CompactRailKeepsNativeWindowControlsReachable \
    -resultBundlePath /tmp/rekon-vd204-feedback-sidebar-green.xcresult
  ```

  **Expected:** all selected tests pass, one toggle is visible/accessible, and
  native close/minimize/zoom controls remain reachable.

## Task 5: Independent verification, evidence, and release decision

**Files:**

- Modify only after technical sign-off: the VD2-04 owner handoff and delivery
  dashboard/roadmap files listed in the file map.

**Dependencies:** Tasks 2–4 accepted by independent code review and QA.

- [ ] **Step 1: Independent reviewer checks the correction against this brief.**

  Confirm no `.sheet`/disclosure/below-table compact inspector remains; no
  `checkmark.circle.fill`/`circle` row selector remains; `Open details` is the
  sole route-changing selection action; and no unauthorized model/store/board
  changes are present.

- [ ] **Step 2: Independent QA runs the focused suite and VD2-04 regressions.**

  ```bash
  xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit \
    -destination 'platform=macOS,arch=arm64' \
    -only-testing:RekonPursuitTests \
    -only-testing:RekonPursuitUITests \
    -only-testing:RekonPursuitUITestHostTests \
    -resultBundlePath /tmp/rekon-vd204-feedback-final.xcresult

  xcodebuild build -project RekonPursuit.xcodeproj -scheme RekonPursuit \
    -configuration Debug -destination 'platform=macOS,arch=arm64'

  git diff --check
  ```

  **Expected:** signed Debug build succeeds; all selected test targets pass;
  `git diff --check` has no output. Do not suppress signing.

- [ ] **Step 3: Conduct independent visual/accessibility QA.**

  In signed Debug, inspect 860×640 and wide Pipeline windows at default and
  increased text sizes; keyboard-only navigation; VoiceOver labels/values;
  pointer hover/focus/pressed Import CSV; drawer open/close/reselect; empty,
  no-results, filtered-away, and deleted selected-row cases; and one sidebar
  toggle. Record screenshots/result-bundle paths and any limitation in the
  owner handoff.

- [ ] **Step 4: Delivery manager updates status without prematurely accepting.**

  Keep VD2-04 `in_progress` and owner action required. Record the original
  product-owner visual rejection, this accepted correction brief, independent
  review/QA evidence, remaining owner visual acceptance, and that VD2-05 stays
  blocked. Do not mark VD2-04 accepted or open VD2-05.

## Acceptance criteria

1. At the supported compact width, tapping a Pipeline row immediately opens an
   accessible right-side in-place drawer. It is not a sheet and it does not put
   an inspector/empty state below the list; close returns to an unobstructed,
   usable table.
2. The wide layout retains the adjacent read-only inspector. Both layouts show
   real selected-record data and retain canonical Open details behavior.
3. Rows have no radio/check-circle child control. Full-row selection is
   visually and accessibly exposed without relying on color alone.
4. The Table/Board control never renders a wrapped `View` label. Its label
   remains accessible when hidden visually at constrained widths.
5. Search, Stage, Closed, and Table/Board controls use coherent Rekon semantic
   dark surfaces, borders, hover/focus/pressed feedback. Import CSV has an
   unmistakable secondary-action hover/focus/pressed response.
6. Exactly one sidebar visibility affordance exists: the accessible app-owned
   `sidebar-collapse`; native window controls continue to work.
7. Selection, filtering, deletion, canonical edit/open/back, persistence,
   activity evidence, Add opportunity, Import CSV, and reconciliation safety
   retain the previously accepted VD2-04 behavior.
8. Independent reviewer, QA, architect, TPM, delivery manager, security/privacy
   verification (scope rechecked), and then the product owner each record their
   gates before VD2-04 can be accepted and VD2-05 released.

## Explicitly out of scope

- VD2-05 Board redesign, drag/drop, stage movement, or workflow changes.
- Store/schema/activity/audit changes, global preferences, route ownership,
  opportunity editor changes, or persistence changes.
- New assets, dependencies, network calls, live workspace access, settings
  redesign, or navigation information-architecture changes.
