# VD2-04 — Pipeline fidelity rebuild

## Purpose and boundary

This owner-approved rebuild makes Pipeline Table and Board recognizably match
the supplied information-dense mockups. The controlling artifact is
`docs/superpowers/specs/2026-07-30-vd204-pipeline-fidelity-rebuild-design.md`.
It is presentation and responsive-layout work only: retain opportunity data,
stage values, filters, persistence, routes, activity, Import CSV, keyboard
semantics, and the existing Board workflow. Do not add drag/drop.

The existing VD2-04 navy-control, compact right drawer, no-radio selection,
one-sidebar-control, and single-line/hidden compact View-label contracts are
dependencies and must remain green.

## Dependency-safe task sequence

### Task 1 — Release the fidelity contract

Before changing source or tests, Architect, TPM, QA, and Delivery Manager
independently review this brief and the controlling spec.

- Architect records the presentation-only four-lane mapping (`Saved`,
  `Applied` containing Applied and Screening, `Interviewing`, `Offer`), with
  `Closed` a fifth secondary lane only when Include closed is enabled.
- QA approves deterministic red-test fixtures and signed-product wide/compact
  capture criteria: dense table columns, inspector hierarchy, lane/card
  content, and no regression of retained VD2-04 controls.
- TPM confirms VD2-04 scope only; VD2-05 stays blocked.
- Delivery Manager records the gates and releases Task 2 only after the other
  three are recorded.

### Task 2 — Establish RED layout and semantic contracts

**Files:**

- Modify: `RekonPursuit/PipelineView.swift` — only the file-scope pure
  `PipelineBoardLane` mapping seam released by
  `ADR-VD2-04-pipeline-fidelity-lane-mapping.md`; no `PipelineView` body,
  layout, lane rendering, or call site may change in this task
- Modify: `RekonPursuit/RekonVisualTheme.swift:VisualFixtureWorkspace.seedFixtureIfNeeded` — the existing `#if REKON_UI_TEST_HOST`-compiled fixture seeding seam linked only into the `RekonPursuitUITestHost` target
- Modify: `RekonPursuitUITestHostTests/RekonPursuitUITestHostTests.swift`
- Modify: `RekonPursuitTests/RekonPursuitTests.swift`
- Modify: `RekonPursuitUITests/RekonPursuitUITests.swift`

**Produces:** a deterministic, test-host-only Pipeline fixture prerequisite,
then RED contracts for dense Table and grouped Board. The fixture change is
authorized only in the existing `REKON_UI_TEST_HOST` fixture seam and its
test-host tests; it must not modify product models, stores, persistence
semantics, routes, activity, Import CSV, or Board behavior.

1. Before writing a visual UI contract, expand only the deterministic
`pipeline` fixture and its test-host contract. Its exact inventory must have
one stable record in each precise stage: `Saved`, `Applied`, `Screening`,
`Interviewing`, `Offer`, and `Closed`. Every seeded record must provide a
nonempty title/company, locality/work arrangement, next action, and due date;
the Closed record remains hidden by default through the existing Include
closed control. Keep the existing fixed clock, UUID-session temporary
encrypted workspace, and relaunch behavior. The current implementation seam
is source-owned by `RekonPursuit/RekonVisualTheme.swift` but is conditionally
compiled exclusively for the `RekonPursuitUITestHost` target; do not relocate
it into production behavior.
2. Add a `RekonPursuitUITestHostTests` fixture-inventory regression test that
asserts exactly one record for each required stage and validates the required
card facts. Run it RED before seeding changes and GREEN after them using the
configured signed `RekonPursuitUITestHost` scheme. A fixture/build/signing
failure is not valid evidence for the later visual RED contract.
3. Add the minimal file-scope, module-internal, pure `PipelineBoardLane`
seam released by the ADR, then add pure, nonisolated tests for the reversible
Board lane mapping. Assert
   Saved maps only Saved; Applied contains Applied and Screening while each
   card retains its exact stage; Interviewing and Offer remain separate; and
   Closed is omitted/included solely by the existing filter.
   The tests must call that production seam directly; do not create a test-only
   mapping oracle. This mapping contract is GREEN when first run because its
   correct pure implementation is the narrow Task 2 testability enabler.
   The later Table and Board UI contracts remain intentionally RED.
4. Add UI contracts, using the expanded signed `pipeline` fixture, that assert wide
   Table exposes the aligned Role, Employer, Stage, Next action, and Due date
   headers, result count, selected-row state, and the approved inspector
   hierarchy. At compact width, assert metadata deliberately collapses and the
   existing in-place right drawer opens rather than a modal or below-list view.
5. Add UI contracts for Board lane header/count/add affordance and rich card
   metadata (company, exact stage, location/work arrangement, next action,
   due date). Assert four primary lanes with Include closed off and secondary
   Closed only when it is toggled on.
6. Keep every existing VD2-04 test intact. Capture named XCTAttachments for
   wide Table, compact Table with drawer, wide Board, and compact Board before
   external dialogs open. Run focused tests and preserve an intentional RED
   bundle caused only by missing fidelity presentation, never a fixture,
   signing, or build failure.

### Task 3 — Implement dense Table and inspector

**Files:**

- Modify: `RekonPursuit/PipelineView.swift`
- Modify only if the existing Pipeline presentation seam requires it:
  `RekonPursuit/RekonVisualTheme.swift`
- Test: `RekonPursuitTests/RekonPursuitTests.swift`
- Test: `RekonPursuitUITests/RekonPursuitUITests.swift`

**Consumes:** Task 2 RED Table contracts and existing navy/cyan primitives.
**Produces:** a responsive dense Table and a mockup-hierarchy inspector with
unchanged selection/open route behavior.

1. Re-run the focused Table tests and confirm RED before implementation.
2. Replace the current stacked `List` row summaries with an aligned dense
table surface. At normal desktop width render Role, Employer, Stage, Next
action, and Due date; role/employer cells include employer identity and
location/work arrangement; Stage is a chip; selected rows retain cyan/violet
treatment; show a result-count footer. At narrow widths hide defined metadata
columns rather than reverting to tall cards.
3. Rebuild `PipelineInspector` hierarchy with compact close control, employer
identity/mark, title, company/location, stage chip, structured facts, and an
outlined secondary `Open details` action. Preserve the existing IDs, the
compact right drawer, selected row semantics, canonical route, context delete,
and no-radio behavior.
4. Preserve the toolbar control IDs/roles and the existing `ViewThatFits`
behavior. Add no literal gray chrome, no dependencies, and no model/store or
routing edits. Run Table contracts and retained VD2-04 focused tests green.

### Task 4 — Implement Board, visual proof, and final gates

**Files:**

- Modify: `RekonPursuit/PipelineView.swift`
- Modify only if necessary for Task 2 test seams:
  `RekonPursuit/RekonVisualTheme.swift`
- Modify: `RekonPursuitUITests/RekonPursuitUITests.swift`
- Modify: `docs/delivery/evidence/visual-design-v2/VD2-04-owner-handoff-2026-07-30.md`

**Consumes:** Task 2 Board RED contracts and Task 3 shared table/inspector
visual language. **Produces:** four/five-lane responsive Board visual proof
and independent release evidence.

1. Re-run Board RED contracts. Replace the six equal stage columns with the
approved visual mapping, retaining exact card stages and existing card-open
route/anchor behavior. Include lane icon, label, count, optional menu visual,
and add affordance; render intentional empty-lane states without fake
drag/drop.
2. Rebuild Board cards to show employer identity, exact stage chip,
location/work arrangement, next action, due date, and existing owner/avatar
data when available. Keep controls and cards navy/cyan, preserve identifiers,
and do not mutate opportunities, stages, storage, activity, import, or Board
workflow.
3. Run all focused contracts in signed Debug, inspect all four captures at
normal desktop and compact dimensions, and record command, result bundle,
attachments, reviewer outcomes, risks, and an owner-acceptance request in the
handoff evidence. A pass alone is not visual acceptance.
4. Fresh Code Reviewer and QA verifier independently review Task 3–4;
Architect verifies the lane decision or records an ADR; TPM validates scope;
Security/privacy confirms high-risk paths were untouched. Delivery Manager
records gates, keeps VD2-04 `in_progress` until owner acceptance, and keeps
VD2-05 blocked.

## Required verification

Run the Task 2–4 focused tests with `xcodebuild test -project
RekonPursuit.xcodeproj -scheme RekonPursuit -destination
'platform=macOS,arch=arm64'` without `CODE_SIGNING_ALLOWED=NO`, preserving
the existing VD2-04 targeted tests plus the new Table/Board fidelity tests.
Use `/tmp/rekon-vd204-pipeline-fidelity.xcresult` for the final result bundle.
