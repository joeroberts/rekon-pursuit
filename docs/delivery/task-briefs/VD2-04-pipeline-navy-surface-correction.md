# VD2-04 — Pipeline navy-surface correction

## Purpose and release boundary

The owner-approved navy-surface correction finishes the visual portion of
VD2-04 that remains unacceptable after the drawer, responsive toolbar, and
app-owned sidebar control work. The controlling design artifact is
`docs/superpowers/specs/2026-07-30-vd204-pipeline-navy-surface-correction-design.md`.
The three supplied Pipeline references are the acceptance baseline: Pipeline
must present layered deep navy surfaces with cyan/blue secondary outlines,
and the gradient is reserved for `Add opportunity`.

This is a presentation correction in the existing VD2-04 card. It applies to
the Pipeline canvas, shared toolbar controls, table/list rows, board cards,
drawer/inspector, and empty states. It does **not** alter Board columns,
drag/drop, opportunity data, stages, import behavior, routing, activity,
persistence, or any VD2-05+ work. VD2-05 remains blocked until this task has
all independent gates and product-owner re-acceptance.

## Current-state diagnosis

`RekonTheme` already defines navy tiers (`background`, `backgroundRaised`,
`surface`, and `elevatedSurface`). The visible gray comes from native macOS
control chrome that remains on top of `RekonControlSurface`'s navy wrapper.
The wrapper is therefore insufficient: the corrective implementation must
visibly own the Pipeline control chrome rather than merely painting behind it.

Existing successful VD2-04 work is a dependency, not a reopen:

- compact Table uses `pipeline-inspector-drawer` rather than a sheet/below-list
  detail panel;
- `PipelineTableRow` no longer renders a row-selection radio glyph;
- `pipeline-view-label` is omitted at compact width instead of wrapping;
- `AppShellView` supplies the one `sidebar-collapse` action.

Those contracts must remain green throughout this correction.

## Controlling contracts

1. Pipeline content has no large neutral-gray fill. The table/list rows,
   cards, drawer/inspector, and empty states use only the existing navy tier
   hierarchy and established borders.
2. Search, Stage, Include closed, view switching, and Import CSV have a navy
   resting fill and a 1-point blue/cyan outline. Hover, keyboard focus,
   pressed, selected, and disabled states are visibly distinguishable.
3. `Add opportunity` is the sole gradient primary action. Import CSV is an
   outlined, interactive secondary action.
4. Table and Board receive the same shared Pipeline presentation primitives.
   Board's behavior, card placement, drag/drop, and persistence do not change.
5. Existing stable accessibility IDs and semantics remain: `opportunity-search`
   is editable; `pipeline-stage-filter` is a discoverable stage chooser;
   `pipeline-include-closed` is an independently discoverable toggle;
   `pipeline-view-mode` remains an exclusive Table/Board choice; and
   `pipeline-import-csv` remains an actionable button.
6. Visual wrappers cannot take focus, consume keyboard activation, or replace
   the identifier of the underlying interactive control. The visible focus
   treatment must follow the real interactive element.
7. The correction must preserve signed-Debug test-host isolation and existing
   compact/wide fixtures. Do not add dependencies or change models, stores,
   networking, providers, or activity/audit code.

## File boundary

| File | Authorized responsibility |
| --- | --- |
| `RekonPursuit/RekonVisualTheme.swift` | Defines semantic navy Pipeline surface and control presentation constants/styles, including hover/focus/pressed/disabled rendering. |
| `RekonPursuit/PipelineView.swift` | Consumes the visual primitives in shared Table/Board presentation, table rows, board cards, drawer/inspector, empty states, and Pipeline toolbar controls. |
| `RekonPursuitTests/RekonPursuitTests.swift` | Tests pure visual-presentation state mapping and semantic color-tier contracts. |
| `RekonPursuitUITests/RekonPursuitUITests.swift` | Tests retained control semantics/identifiers/activation and captures compact/wide Table/Board signed-product visual evidence. |
| `docs/delivery/evidence/visual-design-v2/VD2-04-owner-handoff-2026-07-30.md` | Records objective evidence and independent review results after all implementation gates; does not claim owner acceptance. |
| Delivery dashboard records | Delivery Manager only, after independent evidence is complete. |

`ContentView.swift`, `WorkspaceViewModel.swift`, model/store files, Board
movement code, import implementation, activity/audit code, and VD2-05 files
are explicitly out of scope.

## Dependency-safe task sequence

### Task 0 — Required independent release gates

Before source or test implementation, the Architect, TPM, QA/test agent, and
Delivery Manager independently review this brief and the controlling spec.

- **Architect gate:** selects the precise app-owned control implementation
  that can suppress generic native gray fill while preserving the required
  accessibility roles/labels/IDs and keyboard behavior. Any divergence from
  the contracts above requires an ADR before release.
- **QA gate:** confirms the red-first test and screenshot strategy below,
  including real signed-product compact/wide Table/Board captures and a
  manual visual review that explicitly rejects gray surface/control chrome.
- **TPM gate:** confirms this remains VD2-04 and that no Board behavior or
  VD2-05 scope is being opened.
- **Delivery Manager gate:** records the correction as in progress, keeps
  VD2-05 blocked, and releases Task 1 only after the other three gates are
  recorded.

### Task 1 — Establish the navy-surface RED contract

**Files:**

- Modify: `RekonPursuitTests/RekonPursuitTests.swift`
- Modify: `RekonPursuitUITests/RekonPursuitUITests.swift`

**Consumes:** current `RekonTheme`, `RekonControlSurfacePresentation`, IDs,
and deterministic `pipeline` fixture.

**Produces:** a pure presentation-state test seam and visual/semantic UI
tests named `testVD204PipelineNavySurfacePresentationContract` and
`testVD204PipelineNavySurfaceControlsRemainSemanticallyOperableInTableAndBoard`.

1. Add a RED unit test for a public, nonisolated presentation seam that maps
   idle, hover, keyboard focus, pressed, selected, and disabled states to the
   semantic navy tiers and cyan/violet outline treatment. It must prove that
   the resting and selected control fills are Pipeline navy tiers, not a
   system-neutral color; it must prove 1-point resting borders and 2-point
   keyboard focus borders.
2. Add a RED UI test that runs the `pipeline` fixture at wide and supported
   860x640 compact window sizes. In both Table and Board it must assert all
   five existing control IDs, their semantic roles/labels, hittability, and
   normal activation: type a nonmatch and clear search; open/cancel Stage;
   toggle Include closed and observe the seeded closed row; switch Table to
   Board and back; and invoke Import CSV until the existing file-choice action
   appears.
3. Capture `XCTAttachment` screenshots before Import CSV opens a dialog for
   wide Table, wide Board, compact Table, and compact Board. Name attachments
   with the layout and control state so an independent reviewer can compare
   them to the supplied references.
4. Preserve the existing compact drawer, no-radio, responsive View, one-
   sidebar-toggle, return-routing, and filter-locality tests. No test may be
   deleted or weakened to accommodate restyling.
5. Run the new focused tests first and preserve the intentional RED result
   bundle. The expected failure is the missing Pipeline-navy presentation seam
   and/or current visible generic gray chrome, never a fixture, signing, or
   unrelated behavior error.

### Task 2 — Implement shared navy visual primitives

**Files:**

- Modify: `RekonPursuit/RekonVisualTheme.swift`
- Test: `RekonPursuitTests/RekonPursuitTests.swift`

**Consumes:** Task 1 red unit contract and the Architect-approved interface.

**Produces:** a semantic, reusable Pipeline navy-surface presentation API
that uses only `RekonTheme` tiers and named interaction states.

1. Re-run the Task 1 unit test and confirm a clean RED failure.
2. Define the Architect-approved nonisolated interaction-state enum and
   presentation mapping in `RekonVisualTheme.swift`. It must express at least
   surface fill, outline color, outline width, and opacity for idle, pointer
   hover, keyboard focus, pressed, selected, and disabled states.
3. Implement the corresponding SwiftUI primitive(s) so their painting is
   app-owned and uses `background`, `backgroundRaised`, `surface`,
   `elevatedSurface`, `border`, `accent`, and `violet`; do not add literal gray
   color values or a broad macOS appearance override.
4. Keep real controls as the accessibility/focus owners. If a native control
   cannot visually meet the contract, use the Architect-approved app-owned
   accessible control while retaining the existing semantic role-equivalent
   behavior, identifier, label, value, and keyboard activation.
5. Refactor `RekonSecondaryButtonStyle` to consume the shared presentation
   primitive for a visibly interactive, outlined Import CSV state. It must
   remain a secondary button and never use `actionGradient`.
6. Run the pure presentation test green and inspect `git diff --check`.

### Task 3 — Apply navy surfaces across shared Pipeline presentation

**Files:**

- Modify: `RekonPursuit/PipelineView.swift`
- Modify only if required by Task 2 interface: `RekonPursuit/RekonVisualTheme.swift`
- Test: `RekonPursuitUITests/RekonPursuitUITests.swift`

**Consumes:** Task 2 primitive and all retained Pipeline identifiers.

**Produces:** visibly navy/cyan Pipeline controls and content surfaces in both
Table and Board without behavior or persistence changes.

1. Re-run both Task 1 UI tests and identify the red condition before editing
   production code.
2. Replace gray-producing control composition for Search, Stage, Include
   closed, and Table/Board selection with the Task 2 app-owned primitives.
   Preserve their identifiers, discoverability, labels, activation, values,
   and visible keyboard focus on the actual interactive control.
3. Apply the navy hierarchy to the shared canvas, List/table row background,
   selected table row, `OpportunityCard`, Board stage column/card surfaces,
   `PipelineInspector`, and empty states. Preserve Table drawer geometry,
   compact no-selection behavior, row selection, Board card activation, and
   all current strings.
4. Keep the View label's current `ViewThatFits` behavior: it has one line when
   present and is absent when constrained. Do not alter Board's data/drag/drop
   flow or Table's selection routing.
5. Run the new UI test and all retained VD2-04 focused tests green in a signed
   Debug test run. Review test attachments before giving the slice to an
   independent code reviewer.

### Task 4 — Independent implementation gates

Task 4 starts only after Tasks 1–3 are green. The Task 3 implementer cannot
perform any of these reviews.

1. A fresh Code Reviewer verifies the diff against this brief: no generic gray
   Pipeline surface/control chrome remains; visual primitives are semantic;
   no behavior, data, persistence, routing, activity, import, or Board
   workflow changed; and stable accessibility contracts are retained.
2. A fresh QA verifier runs the complete focused signed-Debug test list,
   inspects the four attachments, and opens actual signed product captures at
   compact and wide sizes. QA rejects any large gray content surface, generic
   gray native input/control fill, wrapped View label, below-list details,
   row radio glyph, or duplicate sidebar action.
3. Architect reviews the implementation against its released design decision
   and records any approved deviation through an ADR. TPM confirms scope and
   dependency status. Security/privacy verifies the diff did not touch
   storage, network, providers, document/import handling, or activity routes.
4. Delivery Manager records all evidence, technical gate outcomes, residual
   risks, and a fresh product-owner acceptance request. VD2-04 remains
   `in_progress` until the owner accepts it; VD2-05 remains blocked.

## Required signed-Debug verification command

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

Run without `CODE_SIGNING_ALLOWED=NO`. A passing automation run is not by
itself visual acceptance: QA must inspect the signed-product captures against
the references before the product owner is asked to accept VD2-04.
