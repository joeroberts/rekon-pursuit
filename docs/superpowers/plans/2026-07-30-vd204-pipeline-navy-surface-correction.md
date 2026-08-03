# VD2-04 Pipeline Navy-Surface Correction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace generic gray Pipeline chrome with the owner-approved deep-navy and cyan visual system in both Table and Board while preserving all existing Pipeline behavior and accessibility semantics.

**Architecture:** The correction is presentation-only. `RekonVisualTheme.swift` supplies a pure, testable visual-state mapping and app-owned Pipeline primitives; `PipelineView.swift` applies those primitives to its shared toolbar and content surfaces without changing the workspace model, routing, Board workflow, or persistence. The real interactive control remains the focus and accessibility owner even where Rekon owns its visible chrome.

**Tech Stack:** Swift 6, SwiftUI/macOS, XCTest/XCUITest, signed Debug Xcode build; no new dependencies.

## Global Constraints

- This is an approved VD2-04 correction. VD2-05 remains blocked until independent gates and owner re-acceptance complete.
- The visual references in `docs/superpowers/specs/2026-07-30-vd204-pipeline-navy-surface-correction-design.md` are acceptance baseline.
- Change only Pipeline visual presentation; do not modify `ContentView.swift`, `WorkspaceViewModel.swift`, data models/stores, Board drag/drop or columns, routes, activity/audit behavior, or import semantics.
- Preserve IDs `opportunity-search`, `pipeline-stage-filter`, `pipeline-include-closed`, `pipeline-view-mode`, `pipeline-import-csv`, table/drawer IDs, and `sidebar-collapse`.
- Preserve editable/search, chooser, toggle, exclusive choice, and button accessibility semantics and actual keyboard activation; visual wrappers cannot own focus or activation.
- Retain the current compact right drawer, no row-radio glyph, unwrapped View label, and exactly one sidebar action.
- Use only existing `RekonTheme` navy tiers and semantic accents. No hard-coded neutral-gray Pipeline control/surface colors and no broad macOS appearance override.
- Run signed Debug tests only; never use `CODE_SIGNING_ALLOWED=NO`.
- Do not commit as part of this plan. Inspect the diff before every gate.

---

## File structure

| File | Responsibility |
| --- | --- |
| `RekonPursuit/RekonVisualTheme.swift` | Semantic state mapping and app-owned navy surface/control/button primitives. |
| `RekonPursuit/PipelineView.swift` | Instantiates shared primitives for Table, Board, toolbar, cards, inspector, and empty presentation. |
| `RekonPursuitTests/RekonPursuitTests.swift` | Pure mapping contract that prevents reintroduction of generic-gray state. |
| `RekonPursuitUITests/RekonPursuitUITests.swift` | Existing semantic regression tests plus new Table/Board capture-and-operation contract. |
| `docs/delivery/evidence/visual-design-v2/VD2-04-owner-handoff-2026-07-30.md` | Delivery record after independent gate results exist. |

### Task 0: Release implementation only after independent design gates

**Files:**

- Modify: no source files.
- Record: architecture, QA, TPM, and delivery-manager gate evidence in their normal delivery artifacts.

**Interfaces:**

- Consumes: owner-approved navy-surface spec and `VD2-04-pipeline-navy-surface-correction.md`.
- Produces: an Architect-approved visual-control decision, a QA-approved red/green capture method, TPM scope approval, and Delivery Manager task release.

- [ ] **Step 1: Architect selects the control seam.**

  Review the current `RekonControlSurface` wrapper in
  `RekonPursuit/RekonVisualTheme.swift` and establish whether each control can
  retain its native renderer or needs an app-owned accessible control. The
  written decision must guarantee a navy fill without a native gray overlay,
  preserve each ID/semantic role-equivalent/keyboard behavior, and explain why
  a global appearance override is rejected. Record an ADR before Task 1 if
  the chosen seam differs from the approved spec.

- [ ] **Step 2: QA fixes the visual evidence protocol.**

  Confirm that the new UI test will attach wide Table, wide Board, compact
  Table, and compact Board screenshots before the Import CSV dialog appears;
  confirm manual QA will inspect signed product captures and reject any
  generic gray control or large gray content region.

- [ ] **Step 3: TPM and Delivery Manager authorize Task 1.**

  Record that this is presentation-only VD2-04 work, that Board behavior and
  VD2-05 are not opened, that VD2-05 remains blocked, and that no product
  owner response is required while the correction is in progress.

### Task 1: Add a failing visual-presentation and semantic-operation contract

**Files:**

- Modify: `RekonPursuitTests/RekonPursuitTests.swift`
- Modify: `RekonPursuitUITests/RekonPursuitUITests.swift`

**Interfaces:**

- Consumes: existing `RekonTheme`, `RekonControlSurfacePresentation`, UI fixture `pipeline`, and currently stable Pipeline identifiers.
- Produces: `PipelineNavySurfaceInteractionState`, `PipelineNavySurfacePresentation`, `testVD204PipelineNavySurfacePresentationContract`, and `testVD204PipelineNavySurfaceControlsRemainSemanticallyOperableInTableAndBoard`.

- [ ] **Step 1: Write the failing pure presentation test.**

  Add this exact test shape to `RekonPursuitTests/RekonPursuitTests.swift`:

  ```swift
  func testVD204PipelineNavySurfacePresentationContract() {
      XCTAssertEqual(PipelineNavySurfacePresentation.fill(for: .idle), .surface)
      XCTAssertEqual(PipelineNavySurfacePresentation.fill(for: .pointerHover), .elevatedSurface)
      XCTAssertEqual(PipelineNavySurfacePresentation.fill(for: .keyboardFocus), .elevatedSurface)
      XCTAssertEqual(PipelineNavySurfacePresentation.outline(for: .idle), .border)
      XCTAssertEqual(PipelineNavySurfacePresentation.outline(for: .pointerHover), .accent)
      XCTAssertEqual(PipelineNavySurfacePresentation.outline(for: .keyboardFocus), .violet)
      XCTAssertEqual(PipelineNavySurfacePresentation.borderWidth(for: .idle), 1)
      XCTAssertEqual(PipelineNavySurfacePresentation.borderWidth(for: .keyboardFocus), 2)
      XCTAssertEqual(PipelineNavySurfacePresentation.opacity(for: .pressed), 0.62)
      XCTAssertEqual(PipelineNavySurfacePresentation.opacity(for: .disabled), 0.42)
  }
  ```

  Make `PipelineNavySurfaceInteractionState` conform to `CaseIterable` and
  add `selected` to the test once the Architect supplies the exact selected
  tier. Do not compare `Color` directly if the current toolchain does not
  conform it to `Equatable`; expose a nonisolated semantic token enum that
  maps to `RekonTheme` in the view layer instead.

- [ ] **Step 2: Run the unit test and preserve a clean RED result.**

  ```bash
  xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit \
    -destination 'platform=macOS,arch=arm64' \
    -only-testing:RekonPursuitTests/RekonPursuitTests/testVD204PipelineNavySurfacePresentationContract \
    -resultBundlePath /tmp/rekon-vd204-navy-surface-unit-red.xcresult
  ```

  Expected: compile/test failure because the new presentation seam does not
  exist. Stop if the failure is from fixture setup, code signing, or unrelated
  existing test failures.

- [ ] **Step 3: Write the failing Table/Board semantic UI test.**

  Add `testVD204PipelineNavySurfaceControlsRemainSemanticallyOperableInTableAndBoard`.
  At wide size it must exercise the current semantic roles and IDs:

  ```swift
  let search = app.textFields["opportunity-search"]
  XCTAssertTrue(search.waitForExistence(timeout: 5))
  XCTAssertEqual(search.elementType, .textField)
  search.click()
  search.typeText("no matching opportunity")
  XCTAssertTrue(app.staticTexts["No opportunities match"].waitForExistence(timeout: 5))
  app.buttons["pipeline-clear-filters"].tap()

  let stage = app.popUpButtons["pipeline-stage-filter"]
  XCTAssertTrue(stage.isHittable)
  stage.click()
  XCTAssertTrue(app.menuItems["All stages"].waitForExistence(timeout: 5))
  app.typeKey(.escape, modifierFlags: [])

  let closed = app.checkBoxes["pipeline-include-closed"]
  XCTAssertTrue(closed.isHittable)
  closed.click()
  XCTAssertEqual(String(describing: closed.value ?? ""), "1")

  let viewMode = app.descendants(matching: .any)["pipeline-view-mode"]
  XCTAssertTrue(viewMode.isHittable)
  viewMode.radioButtons["Board"].click()
  XCTAssertTrue(app.descendants(matching: .any)["pipeline-board-region"].waitForExistence(timeout: 5))
  ```

  Add screenshots named `VD204 navy surface — wide Table`, `VD204 navy surface
  — wide Board`, `VD204 navy surface — compact Table`, and `VD204 navy surface
  — compact Board`, each captured before `pipeline-import-csv` opens the file
  picker. Close/relaunch between compact and wide sessions as current tests do.

- [ ] **Step 4: Run the UI contract and preserve a clean RED result.**

  ```bash
  xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit \
    -destination 'platform=macOS,arch=arm64' \
    -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD204PipelineNavySurfaceControlsRemainSemanticallyOperableInTableAndBoard \
    -resultBundlePath /tmp/rekon-vd204-navy-surface-ui-red.xcresult
  ```

  Expected: intentional red because the new test contract/attachments are not
  implemented. Do not falsely call a semantic-only pass proof of the visual
  requirement; screenshot review is required in Task 4.

### Task 2: Implement the shared, app-owned navy presentation primitive

**Files:**

- Modify: `RekonPursuit/RekonVisualTheme.swift`
- Test: `RekonPursuitTests/RekonPursuitTests.swift`

**Interfaces:**

- Consumes: `PipelineNavySurfaceInteractionState` test contract and the architecture decision from Task 0.
- Produces: a nonisolated semantic state mapping plus a SwiftUI presentation primitive that does not place a gray native fill above its navy surface.

- [ ] **Step 1: Confirm Task 1's pure test is RED.**

  Re-run the Task 1 unit command. Verify the missing type or intended
  presentation-mapping assertion is the failure.

- [ ] **Step 2: Implement a pure token mapping.**

  Add the following nonisolated API near `RekonControlSurfacePresentation`:

  ```swift
  nonisolated enum PipelineNavySurfaceInteractionState: CaseIterable {
      case idle, pointerHover, keyboardFocus, pressed, selected, disabled
  }

  nonisolated enum PipelineNavySurfaceToken: Equatable {
      case surface, elevatedSurface, border, accent, violet
  }

  nonisolated enum PipelineNavySurfacePresentation {
      static func fill(for state: PipelineNavySurfaceInteractionState) -> PipelineNavySurfaceToken
      static func outline(for state: PipelineNavySurfaceInteractionState) -> PipelineNavySurfaceToken
      static func borderWidth(for state: PipelineNavySurfaceInteractionState) -> CGFloat
      static func opacity(for state: PipelineNavySurfaceInteractionState) -> Double
  }
  ```

  Map idle to `.surface`/`.border`/`1`/`1`, pointer hover and keyboard focus
  to `.elevatedSurface`, hover outline to `.accent`, focus outline to `.violet`,
  pressed opacity to `0.62`, and disabled opacity to `0.42`. The Architect
  must record the selected-state mapping before implementation; use that exact
  recorded mapping rather than an unreviewed color choice.

- [ ] **Step 3: Implement the SwiftUI primitive with real-control ownership.**

  Implement the Architect-approved `ViewModifier`/style that converts those
  tokens to `RekonTheme` colors and paints the background, outline, and focus
  treatment. It may observe hover and receive a focus binding, but it must not
  call `.focusable()`, add a gesture, replace an accessibility identifier, or
  make the wrapper an accessibility element. Where system Picker/Toggle
  rendering leaves a generic gray fill visible, instantiate the
  Architect-approved accessible app-owned control instead of wrapping the
  gray renderer.

- [ ] **Step 4: Restyle Import CSV through the same semantic system.**

  Update `RekonSecondaryButtonBody` to derive its hover, keyboard focus,
  pressed, and disabled visual state from the new mapping. It must retain a
  navy background plus cyan/blue outline and must not reference
  `RekonTheme.actionGradient`.

- [ ] **Step 5: Run the unit contract green.**

  Run the Task 1 unit command again. Expected: PASS. Then run:

  ```bash
  git diff --check
  ```

  Expected: no whitespace errors.

### Task 3: Apply the primitive to Table and Board without behavior changes

**Files:**

- Modify: `RekonPursuit/PipelineView.swift`
- Modify only if required by the Task 2 public interface: `RekonPursuit/RekonVisualTheme.swift`
- Test: `RekonPursuitUITests/RekonPursuitUITests.swift`

**Interfaces:**

- Consumes: Task 2 primitive and all current Pipeline IDs.
- Produces: navy/cyan shared controls, navy pipeline surfaces, and unchanged Table/Board interaction/persistence behavior.

- [ ] **Step 1: Re-run the Task 1 UI test and inspect its pre-change captures.**

  Confirm the app starts signed, the fixture loads, and the control interactions
  work. The pre-change visual evidence should still reveal the generic-gray
  problem described in the spec.

- [ ] **Step 2: Replace gray-rendering controls while preserving exact contracts.**

  Apply Task 2's presentation to `searchControl`, `filterControls`, and
  `viewModeControl(showsLabel:)`. Preserve `opportunity-search`,
  `pipeline-stage-filter`, `pipeline-include-closed`, and
  `pipeline-view-mode`; preserve Search typeability, Stage selection/cancel,
  checkbox state updates, and Table/Board radio activation. Keep visible
  keyboard focus attached to the actual interactive element.

- [ ] **Step 3: Apply the navy hierarchy to shared content.**

  Style `table`, `PipelineTableRow`, `PipelineInspector`, the wide inspector
  empty state, and `OpportunityCard` using only Task 2/RekonTheme semantic
  navy surfaces and borders. Preserve List selection, the compact drawer
  overlay geometry, selected-row semantics, Board card open behavior, and
  all layout/strings. Never add a Board gesture or touch `showsBoard` behavior.

- [ ] **Step 4: Preserve known VD2-04 repairs.**

  Keep `ViewThatFits` and `Text("View").lineLimit(1)` behavior exactly: at
  compact width `pipeline-view-label` remains absent and `pipeline-view-mode`
  remains labelled `View`; at wide width label and switcher remain on one line.
  Do not reintroduce a selection glyph, compact sheet, below-list empty state,
  or framework sidebar control.

- [ ] **Step 5: Run the focused signed-Debug regression set.**

  ```bash
  xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit \
    -destination 'platform=macOS,arch=arm64' \
    -only-testing:RekonPursuitTests/RekonPursuitTests/testVD204PipelineNavySurfacePresentationContract \
    -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD204PipelineNavySurfaceControlsRemainSemanticallyOperableInTableAndBoard \
    -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD204PipelineCompactWindowUsesAnInPlaceRightDrawer \
    -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD204PipelineTableSelectionHasNoRadioChildControl \
    -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD204PipelineCompactToolbarKeepsTheViewSwitcherOnOneLine \
    -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD204PipelineControlsRemainKeyboardDiscoverableAndStyled \
    -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD204ShellExposesOnlyTheAppOwnedSidebarToggle \
    -resultBundlePath /tmp/rekon-vd204-navy-surface-green.xcresult
  ```

  Expected: all selected tests pass under the configured signing identity.

### Task 4: Independent review, visual QA, delivery evidence, and owner re-acceptance

**Files:**

- Modify after sign-off only: `docs/delivery/evidence/visual-design-v2/VD2-04-owner-handoff-2026-07-30.md`
- Modify after sign-off only: delivery dashboard/roadmap records owned by the Delivery Manager.

**Interfaces:**

- Consumes: Task 3 green result bundle and four named visual attachments.
- Produces: independently accepted technical evidence, delivery status, and a product-owner re-acceptance request.

- [ ] **Step 1: Conduct independent code review.**

  A fresh reviewer inspects `git diff -- RekonPursuit/RekonVisualTheme.swift RekonPursuit/PipelineView.swift RekonPursuitTests/RekonPursuitTests.swift RekonPursuitUITests/RekonPursuitUITests.swift`. Reject the slice if it changes persistence, Board workflow, routing, imports, activity/audit code, IDs/semantics, or leaves a native gray control fill above a navy wrapper.

- [ ] **Step 2: Conduct independent signed-product visual QA.**

  A fresh QA agent runs Task 3's command, opens its four attachments and the
  actual signed app at 860x640 and wide dimensions, and compares all to the
  owner references. Reject any neutral-gray Pipeline region/control, gray
  generic input chrome, missing cyan secondary outline, gray Import CSV,
  wrapped View, below-list details, radio glyph, or duplicate sidebar action.

- [ ] **Step 3: Obtain architecture, TPM, and security/privacy closeout.**

  Architect checks conformance to Task 0's decision and writes an ADR for any
  deviation. TPM confirms no scope creep and VD2-05 remains blocked.
  Security/privacy confirms the diff touches only visual/test files and did
  not change storage, providers, network, import/file handling, or activity
  routes.

- [ ] **Step 4: Update delivery records and request owner acceptance.**

  The Delivery Manager records result-bundle paths, screenshot paths, all
  reviewer outcomes, the prior rejection, and remaining owner action. Keep
  VD2-04 `in_progress` and VD2-05 blocked until the product owner accepts the
  corrected signed product.

## Self-review

- Spec coverage: Tasks 1–3 implement the complete navy/cyan correction for all required shared Pipeline controls and Table/Board surfaces; Task 4 supplies every independent gate and delivery handoff.
- No placeholders: the production APIs, test names, identifiers, state mappings, and Xcode commands are explicit. The only decision intentionally owned by the Architect is the exact renderer seam needed to preserve true accessibility while eliminating native gray chrome; Task 0 requires that decision before implementation.
- Type consistency: `PipelineNavySurfaceInteractionState`, `PipelineNavySurfaceToken`, and `PipelineNavySurfacePresentation` are defined in Task 2 and consumed in Tasks 1–3 under the same names.
