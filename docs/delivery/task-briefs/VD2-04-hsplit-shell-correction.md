# VD2-04 — App-owned HSplitView shell correction addendum

## Purpose and authority

This is a narrowly-scoped replacement for Task 4 in
`VD2-04-pipeline-feedback-correction.md`. It implements the accepted
architecture decision in
`docs/delivery/architecture/ADR-VD2-04-shell-split-container.md` after the
readable failed bundle `/tmp/rekon-vd204-feedback-sidebar-green.xcresult`
proved that `NavigationSplitView` plus `.toolbar(removing: .sidebarToggle)`
still injects an extra framework `Hide Sidebar`/`Show Sidebar` button at the
supported compact presentation.

Replace `NavigationSplitView` only in `AppShellView` with an app-owned
`HSplitView`. The correction is complete only when a fresh signed Debug host
proves that the sole sidebar action is the identified, application-owned
`sidebar-collapse` control before collapse, after collapse, and after restore.

This addendum does not accept VD2-04, does not authorize VD2-05, and does not
change Pipeline drawer, opportunity routing, persistence, activity/audit,
window policy, rail visual design, or delivery status.

## Non-negotiable contracts

- `AppShellView` retains its existing `Binding<DailyRoute>`, `detailTitle`,
  `selectDestination`, and `@ViewBuilder detail` public interface.
- Replace `@State NavigationSplitViewVisibility` with a local Boolean
  `@State private var isSidebarVisible = true`; that Boolean is the only
  authority for whether the rail participates in layout.
- `sidebar-collapse` is the single toolbar action. It toggles the Boolean and
  exposes the exact dynamic labels/help text `Collapse sidebar` and `Show
  sidebar`; it remains hittable and keyboard reachable in both states.
- While visible, the rail is the existing branded lockup and the same five
  `AppDestination.sidebarDestinations`, rendered inside `HSplitView` with the
  existing `RekonTheme.Rail.minimumWidth` (268), `idealWidth` (310), and
  `maximumWidth` (340) semantics. When hidden, omit the rail from the split so
  the existing detail view receives the available width. Restore must retain
  route selection and the existing detail state rather than recreate a new
  workspace model or reset persistent data.
- Preserve all current sidebar AX identifiers and behavior: `app-shell`,
  `sidebar-brand-lockup`, `sidebar-home`, `sidebar-pipeline`,
  `sidebar-contacts`, `sidebar-activity-and-ai`, `sidebar-settings`, selected
  state, full-row pointer hit target, keyboard focus, and Space activation.
- Preserve `RekonWindowChromeConfigurator`, the dark toolbar/titlebar policy,
  and native `window-close`, `window-miniaturize`, and `window-zoom` controls.
  Do not add a custom titlebar or a second window.
- At the supported compact live frame of 860×640, neither an empty-identifier
  `Hide Sidebar` nor `Show Sidebar` framework AXButton may exist. Do not hide
  or accessibility-suppress such a button: the new container must not create
  it.
- No new package, persistence/model/schema change, network behavior, sheet,
  dialog, or Pipeline/VD2-05 change is authorized.

## File map

| File | Required change |
| --- | --- |
| `RekonPursuit/AppShellView.swift` | Replace the shell container and visibility state while reusing the existing rail and detail content. |
| `RekonPursuitUITests/RekonPursuitUITests.swift` | Strengthen compact AX tests for the absence of the framework control, the Boolean rail lifecycle, preserved navigation, rail width, and native traffic lights. |
| `docs/delivery/evidence/visual-design-v2/VD2-04-owner-handoff-2026-07-30.md` | Delivery Manager only, after independent technical gates: add replacement signed-Debug evidence and renewed owner-acceptance request. |
| `docs/delivery/dashboard-status.json`, `docs/delivery/dashboard/index.html`, `docs/delivery/dashboard/remediation.html`, `docs/delivery/roadmap.md` | Delivery Manager only, after independent gates: record this correction while retaining VD2-04 `in_progress` and VD2-05 blocked. |

No other production file is in scope.

## Implementation task: own the split container (test first)

**Files:**

- Modify: `RekonPursuitUITests/RekonPursuitUITests.swift`
- Modify: `RekonPursuit/AppShellView.swift`

**Consumes:** ADR-VD2-04, fixture-host compact launch argument, existing
`appOwnedSidebarToggle(in:)`, `frameworkSidebarToggleCount(in:)`,
`testSidebarIsDiscoverableAndCanCollapseAndRestore()`, and
`testVD202CompactRailKeepsNativeWindowControlsReachable()`.

**Produces:** an app-owned `HSplitView` shell with the local
`isSidebarVisible` state and a passing, signed-Debug compact regression
contract.

- [ ] **Step 1: Add failing compact AX test helpers without weakening the old failure.**

  In `RekonPursuitUITests.swift`, retain `frameworkSidebarToggleCount(in:)`
  as an AX query for the empty-identifier `Hide Sidebar` or `Show Sidebar`
  toolbar button. Add a rail query using a stable `sidebar-rail` accessibility
  identifier and a width assertion that accepts only the documented rail range
  while visible:

  ```swift
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
  ```

  Do not change the helper to count only `sidebar-collapse`; that would make
  the currently observed framework injection invisible.

- [ ] **Step 2: Extend the one-toggle test into the required three-state red contract.**

  Update `testVD204ShellExposesOnlyTheAppOwnedSidebarToggle()` to launch the
  `pipeline` fixture at `compact`, assert the live 860×640 frame, then make
  these assertions in exact order:

  ```swift
  let toggle = appOwnedSidebarToggle(in: app)
  let rail = sidebarRail(in: app)
  XCTAssertEqual(app.buttons.matching(identifier: "sidebar-collapse").count, 1)
  XCTAssertTrue(toggle.isHittable)
  XCTAssertEqual(toggle.label, "Collapse sidebar")
  XCTAssertEqual(frameworkSidebarToggleCount(in: app), 0)
  assertVisibleRailWidth(rail)

  toggle.tap()
  XCTAssertEqual(toggle.label, "Show sidebar")
  XCTAssertEqual(frameworkSidebarToggleCount(in: app), 0)
  XCTAssertFalse(rail.exists)

  toggle.tap()
  XCTAssertEqual(toggle.label, "Collapse sidebar")
  XCTAssertEqual(frameworkSidebarToggleCount(in: app), 0)
  assertVisibleRailWidth(rail)
  ```

  Add an `XCTAttachment` screenshot before collapse, after collapse, and after
  restore with `.keepAlways`. On the current `NavigationSplitView` shell this
  must fail because `frameworkSidebarToggleCount(in:) == 1`; preserve the
  resulting red bundle rather than editing the assertion to fit the failure.

- [ ] **Step 3: Add a red navigation/selection preservation test.**

  In `testSidebarIsDiscoverableAndCanCollapseAndRestore()`, assert the rail
  ID and width, select `sidebar-contacts`, check it is selected and that
  `contact-search` becomes available, then collapse and restore. Assert that
  `sidebar-contacts` remains selected and `contact-search` remains present
  after restore. Keep the existing full-row, focus, and Space activation
  checks. This rules out an implementation that hides the extra button by
  rebuilding or losing the rail/detail state.

- [ ] **Step 4: Add the red compact native-chrome invariant.**

  Keep `testVD202CompactRailKeepsNativeWindowControlsReachable()` at compact
  860×640. Assert zero framework sidebar toggles, exactly one app toggle, and
  the three existing native control identifiers before collapse, after tapping
  `sidebar-collapse`, and after restoration:

  ```swift
  for identifier in ["window-close", "window-miniaturize", "window-zoom"] {
      XCTAssertTrue(app.descendants(matching: .any)[identifier].isHittable)
  }
  ```

  No test may replace these native controls with a product-owned visual
  approximation.

- [ ] **Step 5: Run the focused tests and record the expected RED result.**

  From this worktree, run a signed Debug test host (do not pass
  `CODE_SIGNING_ALLOWED=NO`):

  ```bash
  xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit \
    -destination 'platform=macOS,arch=arm64' \
    -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD204ShellExposesOnlyTheAppOwnedSidebarToggle \
    -only-testing:RekonPursuitUITests/RekonPursuitUITests/testSidebarIsDiscoverableAndCanCollapseAndRestore \
    -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD202CompactRailKeepsNativeWindowControlsReachable \
    -resultBundlePath /tmp/rekon-vd204-hsplit-shell-red.xcresult
  ```

  **Expected:** the one-toggle assertion is red on the old shell because the
  framework `Hide Sidebar`/`Show Sidebar` AXButton exists. Fixture launch,
  app-owned toggle discovery, and native traffic-light discovery must not be
  the reason for failure.

- [ ] **Step 6: Replace only the container and visibility authority.**

  In `AppShellView.swift`, change:

  ```swift
  @State private var columnVisibility: NavigationSplitViewVisibility = .all
  ```

  to:

  ```swift
  @State private var isSidebarVisible = true
  ```

  Factor the current branded sidebar body into a local `sidebarRail` view (or
  an equivalently private view) without altering its contents. Attach
  `.accessibilityIdentifier("sidebar-rail")`, and while visible give it the
  existing min/ideal/max rail-width constraints. Render this and the existing
  detail side-by-side only when visible:

  ```swift
  HSplitView {
      if isSidebarVisible {
          sidebarRail
              .frame(
                  minWidth: RekonTheme.Rail.minimumWidth,
                  idealWidth: RekonTheme.Rail.idealWidth,
                  maxWidth: RekonTheme.Rail.maximumWidth,
                  maxHeight: .infinity,
                  alignment: .topLeading
              )
      }
      detailCanvas
  }
  ```

  When false, render `detailCanvas` outside the split (or an equivalent branch
  that contains no rail) so it fills the available root width. Keep the current
  detail frame/background/navigation title behavior in `detailCanvas`; do not
  move model or route ownership out of `ContentView`.

- [ ] **Step 7: Retain one application-owned action and delete split-specific suppression.**

  Change the existing custom toolbar action to:

  ```swift
  Button {
      isSidebarVisible.toggle()
  } label: {
      Image(systemName: isSidebarVisible ? "sidebar.left" : "sidebar.leading")
  }
  .accessibilityIdentifier("sidebar-collapse")
  .accessibilityLabel(isSidebarVisible ? "Collapse sidebar" : "Show sidebar")
  .help(isSidebarVisible ? "Collapse sidebar" : "Show sidebar")
  ```

  Preserve its navigation toolbar placement, tint, icon treatment, and native
  titlebar configuration. Remove `.navigationSplitViewStyle`,
  `.navigationSplitViewColumnWidth`, and `.toolbar(removing: .sidebarToggle)`
  only because `NavigationSplitView` no longer exists; do not use any hidden,
  overlay, or AX suppression workaround.

- [ ] **Step 8: Run the focused green test suite.**

  ```bash
  xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit \
    -destination 'platform=macOS,arch=arm64' \
    -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD204ShellExposesOnlyTheAppOwnedSidebarToggle \
    -only-testing:RekonPursuitUITests/RekonPursuitUITests/testSidebarIsDiscoverableAndCanCollapseAndRestore \
    -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD202CompactRailKeepsNativeWindowControlsReachable \
    -resultBundlePath /tmp/rekon-vd204-hsplit-shell-green.xcresult
  ```

  **Expected:** all three tests pass on a fresh signed Debug launch. Inspect
  the saved screenshots: one app-owned toolbar control, no system duplicate,
  native traffic lights intact, branded rail width in range, and the original
  destination/content state restored after collapse.

- [ ] **Step 9: Complete independent gates before any ledger transition.**

  A fresh code reviewer verifies the diff against this addendum and ADR,
  specifically rejecting retained `NavigationSplitView`, hidden framework
  buttons, lost route/detail state, altered native chrome, or widened scope.
  Independent QA reruns the exact focused signed-Debug command from Step 8 and
  manually checks the three 860×640 screenshots plus keyboard/VoiceOver action
  discovery. Security/privacy verifies that the shell-only change introduces
  no storage, fixture, routing, or data-boundary change. Only then may the
  Delivery Manager update the owner handoff/dashboard with result-bundle and
  screenshot paths, retain VD2-04 `in_progress`, and request renewed
  product-owner acceptance. VD2-05 stays blocked until that acceptance.

## Acceptance checklist

1. A fresh signed Debug compact result bundle proves zero framework `Hide
   Sidebar`/`Show Sidebar` buttons before collapse, after collapse, and after
   restoration.
2. Exactly one, hittable `sidebar-collapse` action remains and dynamically
   reads Collapse → Show → Collapse.
3. The rail is app-owned, appears within 268–340 points while visible, is not
   stacked or presented in a sheet, and its absence lets detail use the root
   width.
4. All existing rail IDs, five destinations, selection state, full-row click,
   keyboard focus, and Space activation survive collapse/restoration without
   resetting the selected route or detail workspace.
5. At 860×640 close, miniaturize, and zoom remain native, reachable controls.
6. No scope outside this shell correction changes; independent reviewer, QA,
   security/privacy, Delivery Manager, and product-owner gates remain
   outstanding until completed and recorded.
