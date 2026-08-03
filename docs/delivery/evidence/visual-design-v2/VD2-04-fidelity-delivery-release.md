# VD2-04 Pipeline fidelity rebuild — Delivery Manager Task 2 release

**Date:** 2026-07-30  
**Role:** Independent Delivery Manager  
**Decision:** **Release Task 2 only — test-host fixture and RED test-contract work.**

## Delivery state

- `VD2-04` remains **in progress** and is not product-owner accepted.
- The fidelity rebuild supersedes the prior owner-handoff request as the
  active VD2-04 corrective path; it does not make prior correction evidence
  acceptance evidence for the rebuild.
- `VD2-05` remains **blocked/backlog**. It must not be planned, implemented,
  reviewed, or advanced until VD2-04 has completed its fresh implementation
  gates and received renewed explicit product-owner acceptance.
- The delivery dashboard is intentionally unchanged by this release. Its
  current `VD2-04: in_progress` and `VD2-05: backlog` dependency state is
  correct.

## Independent Task 1 gates inspected

| Gate | Evidence inspected | Delivery finding |
| --- | --- | --- |
| Owner-approved design and planning | `docs/superpowers/specs/2026-07-30-vd204-pipeline-fidelity-rebuild-design.md`; `docs/delivery/task-briefs/VD2-04-pipeline-fidelity-rebuild.md`; `docs/superpowers/plans/2026-07-30-vd204-pipeline-fidelity-rebuild.md` | Defines a presentation-only, dependency-safe Task 1–4 sequence with Task 2 preceding all production layout work. |
| Architecture | `docs/delivery/architecture/ADR-VD2-04-pipeline-fidelity-lane-mapping.md` | Accepts only a later view-local, reversible lane projection. It forbids stage/model/store/persistence/routing changes, drag/drop, and workflow mutation. |
| QA/test | `docs/delivery/evidence/visual-design-v2/VD2-04-fidelity-qa-strategy.md` | Releases deterministic test-host fixture expansion and intentional RED contracts only. It requires fixture RED then GREEN, signed Debug evidence, retained regressions, and four later captures. |
| TPM | `docs/delivery/evidence/visual-design-v2/VD2-04-fidelity-tpm-gate.md` | Confirms VD2-04-only presentation scope and keeps VD2-05 ineligible. |

All required Task 1 gate records are present. No gate releases Tasks 3 or 4.

## Authorized Task 2 boundary

Task 2 may establish a deterministic synthetic `pipeline` fixture and write
the intentionally failing fidelity contracts. The fixture must contain exactly
one record in each of `Saved`, `Applied`, `Screening`, `Interviewing`, `Offer`,
and `Closed`, with required display facts, while the existing Include closed
control continues to hide Closed by default. The fixture remains isolated to
the existing test-host conditional seam, temporary encrypted workspace,
fixed-clock, and teardown behavior.

The allowed source and test files are **exactly**:

1. `RekonPursuit/PipelineView.swift` — only the file-scope,
   module-internal `PipelineBoardLane` declaration and its pure
   `includes(_:)` / `displayedLanes(includesClosed:)` implementations, as
   specified by `ADR-VD2-04-pipeline-fidelity-lane-mapping.md`. The
   `PipelineView` body, layout, rendered lane sequence, and all call sites are
   expressly excluded until Task 4.
2. `RekonPursuit/RekonVisualTheme.swift` — only
   `VisualFixtureWorkspace.seedFixtureIfNeeded`'s existing
   `#if REKON_UI_TEST_HOST` Pipeline-fixture branch. No non-test-host path in
   this file may change.
3. `RekonPursuitUITestHostTests/RekonPursuitUITestHostTests.swift` — the
   deterministic Pipeline fixture-inventory regression contract only.
4. `RekonPursuitTests/RekonPursuitTests.swift` — pure, non-persistence Board
   lane-mapping contract(s) only.
5. `RekonPursuitUITests/RekonPursuitUITests.swift` — signed-product Table and
   Board RED accessibility/layout contracts, named capture attachments, and
   retained VD2-04 regression assertions only.
6. `docs/delivery/evidence/visual-design-v2/VD2-04-fidelity-delivery-release.md`
   — this delivery record only.

## Explicit holds and non-authorizations

- Except for the pure file-scope mapping seam described above,
  `RekonPursuit/PipelineView.swift` is **not released**: no dense Table,
  inspector, Board lanes/cards, toolbar, responsive production-layout, or use
  of the mapping seam may begin in Task 2.
- No production models, `PipelineStage`, stores, `WorkspaceViewModel`,
  persistence, routing, activity/audit evidence, import behavior, sidebar,
  right drawer, keyboard semantics, or Board workflow may change.
- No drag/drop, stage movement, card relocation, or pseudo-stage data may be
  introduced.
- No dashboard, roadmap, acceptance status, or VD2-05 edits are authorized.
- Existing dirty shared-worktree changes are neither reset nor reclassified by
  this release. Task 2 evidence must identify its own bounded edits and
  signed results.

## Required return evidence before Task 3 consideration

1. Test-host fixture inventory contract shown RED for the pre-expansion
   fixture, then GREEN in the configured signed `RekonPursuitUITestHost`
   scheme.
2. The direct production `PipelineBoardLane` mapping contract shown GREEN;
   Table/Board UI contracts shown intentionally RED only for missing fidelity
   presentation—not compilation, signing, fixture isolation, or unrelated
   failures. A duplicate test-only mapping or unresolved-symbol compile RED is
   invalid evidence.
3. Retained VD2-04 drawer, no-radio, toolbar, semantic-control, sidebar,
   route, filter, and delete regressions remain intact.
4. Result-bundle paths, signing verification, and the four named attachments
   are recorded for subsequent independent code review and QA. A red
   contract is not a release of production layout work.

**Release outcome:** Task 2 is now eligible. Tasks 3–4, VD2-05, dashboard
advancement, and product-owner acceptance remain withheld.

---

## Amended Task 2 repair release — signed-host evidence and capture-state correction

**Date:** 2026-07-30  
**Role:** Independent Delivery Manager  
**Decision:** **Release a single bounded Task 2 repair. Task 3 remains
withheld.**

### Independent failure evidence inspected

| Review | Evidence | Finding |
| --- | --- | --- |
| QA verifier | QA Task 2 verdict and `/tmp/rekon-vd204-pipeline-fidelity-ui-red.xcresult` | The fixture inventory and intentional presentation RED are usable, but the dedicated UI-test host disables signing. The Board contract also does not prove that the Screening record is shown in the Applied lane while retaining its exact stage, and two named captures do not establish their required selected/Closed states. |
| Code reviewer | `/tmp/rekon-vd204-pipeline-fidelity-mapping-green-retry.xcresult`; `/tmp/rekon-vd204-pipeline-fidelity-fixture-green-retry.xcresult`; `/tmp/rekon-vd204-pipeline-fidelity-ui-red.xcresult` | The pure mapping is real, file-scope, and correctly test-covered; the test-host-only six-record fixture is bounded; the UI RED is presentation-only. However, its host app and host-test bundle explicitly contain `CODE_SIGNING_ALLOWED = NO` and `CODE_SIGNING_REQUIRED = NO`, so neither bundle is valid signed-product evidence. |

The underlying Task 2 fixture and mapping evidence is not reopened by this
repair. The repair is solely to make the stipulated signed host available and
to make the already-authorized UI contracts truthfully capture the required
states.

### Only authorized edits

The fresh implementer may modify **only** these two files:

1. `RekonPursuit.xcodeproj/project.pbxproj`
   - For the `RekonPursuitUITestHost` and
     `RekonPursuitUITestHostTests` Debug and Release build configurations,
     remove `CODE_SIGNING_ALLOWED = NO` and `CODE_SIGNING_REQUIRED = NO`.
   - Restore the project-standard configured signing values:
     `CODE_SIGN_STYLE = Automatic` and `DEVELOPMENT_TEAM = 2UA854NLX4`.
   - Do not change target membership, product identifiers, sources,
     frameworks, entitlements, schemes, dependencies, or any non-host
     configuration.
2. `RekonPursuitUITests/RekonPursuitUITests.swift`
   - Correct the Board UI contract to identify the deterministic **Screening**
     fixture card in the Applied presentation lane and assert its exact
     `Screening` stage fact remains exposed.
   - Move the wide Table attachment until after the row is selected and the
     inspector is visible, so `vd204-fidelity-wide-table` records the
     required selected-table state.
   - In the compact Board path, activate the existing
     `pipeline-include-closed` checkbox and wait for the existing Closed lane
     before creating `vd204-fidelity-compact-board`, so the attachment records
     the required secondary-lane state.
   - Preserve every existing test and assertion except for these precise
     corrections. Do not weaken a failure condition or replace semantic
     assertions with screenshots.

### Explicit non-authorizations

This repair does **not** release changes to `PipelineView.swift`, product
fixtures, models, stores, persistence, filters, routes, activity/audit,
Import CSV, navigation, sidebar/drawer behavior, Board workflow, dashboard,
roadmap, or VD2-05. It does not permit drag/drop, stage mutation, product
layout, visual implementation, test-host architecture changes, or a commit.
No source or test/config file beyond the two enumerated files is in scope.

### Required return evidence and gate condition

The implementer must run the existing Task 2 focused fixture/mapping/UI
commands in configured signed Debug, without a command-line signing override.
The return must include:

1. `xcodebuild -showBuildSettings` evidence for both dedicated host targets
   showing automatic signing, team `2UA854NLX4`, and no disabled-signing
   setting.
2. A fresh signed result bundle for the focused UI RED, preserving that its
   only failures are absent fidelity presentation—not compile, fixture,
   signing, or launch failures.
3. `codesign --verify --deep --strict` success for the generated
   `RekonPursuitUITestHost.app` and its generated test bundle, with an
   inspectable configured signing identity.
4. The four named attachments, with `vd204-fidelity-wide-table` visibly
   selected/inspected and `vd204-fidelity-compact-board` visibly including
   the Closed lane.
5. Fresh independent code-review and QA verdicts on the repair.

This is a corrective evidence release only. It is not Task 2 completion or a
release of Task 3. The delivery dashboard remains unchanged: `VD2-04` stays
`in_progress`; `VD2-05` stays blocked/backlog pending fresh full VD2-04
implementation gates and explicit product-owner acceptance.

---

## Task 2 acceptance and Task 3 release — dense Table and inspector

**Date:** 2026-07-30  
**Role:** Independent Delivery Manager  
**Decision:** **Task 2 accepted. Release Task 3 only.**

### Acceptance evidence inspected

| Gate | Evidence | Delivery finding |
| --- | --- | --- |
| Fixture contract | `/tmp/rekon-vd204-pipeline-fidelity-fixture-red-isolated.xcresult`; `/tmp/rekon-vd204-pipeline-fidelity-fixture-green-retry.xcresult` | The deterministic test-host-only fixture first failed for the missing inventory, then passed with exactly one populated record for Saved, Applied, Screening, Interviewing, Offer, and Closed. |
| Presentation mapping | `/tmp/rekon-vd204-pipeline-fidelity-mapping-green-retry.xcresult` | The direct, pure production `PipelineBoardLane` contract passed. Its four-primary/fifth-conditional projection remains unused by the current Board until Task 4. |
| Signed RED UI contract | `/tmp/rekon-vd204-fidelity-task2-repair-capture-red.xcresult` | The signed focused UI run has two expected failures only: the absent dense Table headers and the absent grouped Board presentation. It has no compile, launch, fixture-isolation, or signing failure. The four required attachments are recorded before the future-layout assertions. |
| Repair signing and capture-state review | Fresh independent Code Review and QA verdicts for the capture repair | Both accepted the restored automatic host signing, explicit selected-row/inspector prerequisite for the wide Table capture, and Include closed/raw Closed-header prerequisite for the compact Board capture. |

The Task 2 repair stayed within its release boundary: host signing configuration
and fidelity UI capture contracts. The fixture/mapping implementation remains
the already accepted narrow Task 2 scope. Existing unrelated dirty worktree
changes are not reclassified by this decision.

### Authorized Task 3 boundary

A fresh implementer may now modify only the following Task 3 surfaces:

1. `RekonPursuit/PipelineView.swift` — dense, responsive Table and inspector
   hierarchy only.
2. `RekonPursuit/RekonVisualTheme.swift` — only if the existing Pipeline
   presentation seam is demonstrably required; no fixture or product-behavior
   change.
3. `RekonPursuitTests/RekonPursuitTests.swift` and
   `RekonPursuitUITests/RekonPursuitUITests.swift` — Table-contract and
   retained-regression coverage only.
4. This delivery evidence and the delivery dashboard projection.

Before implementation, the implementer must re-run the focused Table contract
and show its intentional RED state. The slice must then make the dense Table
and inspector assertions green while retaining the approved right drawer,
selection/no-radio behavior, canonical Open details route, toolbar semantics,
single sidebar control, and compact View-label behavior. It must not implement
or invoke Board lane mapping, add drag/drop, or change models, stores,
persistence, filters, activity, routes, Import CSV, or stage movement.

### Holds

- Task 4 (Board fidelity) remains withheld until Task 3 has fresh independent
  Code Review and QA acceptance.
- `VD2-04` remains **in progress** and has no product-owner acceptance. The
  later owner handoff must be based on the completed Table and Board fidelity
  work, not this RED-contract milestone.
- `VD2-05` remains **backlog/blocked by dependency** and is not released.
- The dashboard records this material transition but does not mark any future
  task eligible.

---

## Task 3 rejection and narrow responsive/evidence repair release

**Date:** 2026-07-30  
**Role:** Independent Delivery Manager  
**Decision:** **Task 3 is rejected. Release one repair only; Task 4 remains withheld.**

### Independent rejection evidence inspected

| Gate | Evidence | Delivery finding |
| --- | --- | --- |
| Code review | Fresh Task 3 review; `/tmp/rekon-vd204-task3-retained-green.xcresult`; `/tmp/rekon-vd204-task3-table-retained-core.xcresult` | The Table/inspector scope did not enter Board or workflow code, but the normal-host wide capture visibly clips required content: the five-column Table’s `Due date` header/cells are not usable beside the fixed inspector. The reviewer also found no later finalized retained-control green evidence. |
| QA | Fresh Task 3 QA verdict and signed Table-contract result | The focused signed Table contract passes and includes wide/compact captures, but the retained combined UI execution did not finalize as a valid green runtime gate. The Board remains intentional RED and must not be treated as a Task 3 failure to repair. |

The rejected result does **not** accept Task 3, release Task 4, or alter the VD2-04/VD2-05 dependency state. Existing Task 2 fixture, mapping, signing, and RED-contract evidence remains valid and is not reopened.

### Authorized repair boundary

A fresh implementer may make the following—and only the following—changes:

1. `RekonPursuit/PipelineView.swift`: correct the **Table-only** responsive allocation/column sizing at the configured normal UI-test-host wide size. With the inspector visible, every required Table header (`Role`, `Employer`, `Stage`, `Next action`, and `Due date`) and the corresponding representative row cells must render fully usable in the table viewport. Do not solve this by clipping, truncating, horizontally scrolling, hiding a required normal-width column, or collapsing the desktop Table back into cards. The existing compact breakpoint may continue to hide defined metadata columns, and the existing compact right drawer must remain in place.
2. `RekonPursuitUITests/RekonPursuitUITests.swift`: only additive/stronger Table geometry or visibility assertions needed to prevent this exact normal-width clipping regression. Existing assertions, identifiers, captures, and test names may not be weakened, deleted, or redefined.
3. This delivery release, the delivery dashboard projection, and roadmap status text.

The repair expressly forbids Board markup/lane-mapping use, drag/drop, stage movement, fixture changes, test-host configuration or signing edits, model, store, persistence, filter, activity, routing, import, sidebar, or compact-drawer behavior changes. It also forbids replacing retained tests with a smaller suite or treating an interrupted bundle as evidence.

### Required verification before fresh review and QA

1. Re-run the focused signed Table contract from a clean, UUID-qualified host session. Record a finalized `.xcresult` bundle with zero failures and the wide/compact attachments. A reviewer must visually inspect the wide attachment for all five headers and representative cells, including `Due date`, beside the inspector.
2. Run every retained VD2-04 UI control regression in **focused signed batches** if a combined invocation is unstable. Batches may be one test per invocation; every original test must run unchanged, and each result bundle must finalize with zero failures, zero skips, and its command/result path recorded. The retained set includes selection/open-details, compact drawer, no-radio selection, compact toolbar, normal controls/Table-Board switching, navy semantic controls, sidebar toggle, canonical edit/activity route, filters, and selected-row deletion.
3. The Task 2 Board fidelity contract remains intentional RED and is excluded only from the Task 3 green gate. Do not alter or satisfy it during this repair.
4. Fresh Code Review and QA must separately approve the repaired source and all finalized signed evidence. Only then may Delivery consider releasing Task 4.

### Delivery state

`VD2-04` remains **in progress**. Task 3 is returned to repair, Task 4 remains withheld, and `VD2-05` remains backlog/blocked pending completed VD2-04 and renewed explicit product-owner acceptance.

---

## Task 3 responsive-repair diagnosis and compact-drawer alignment release

**Date:** 2026-07-30  
**Role:** Independent Delivery Manager  
**Decision:** **Task 3 remains rejected. Release one geometry-only repair for
the compact Table drawer; Board fidelity remains withheld.**

### Independent diagnosis

| Evidence | Finding |
| --- | --- |
| Finalized compact-drawer control bundle: `/tmp/rekon-vd204-task3-retained-compact-drawer-final.xcresult` | This is a valid, finalized runtime failure of only `testVD204PipelineCompactWindowUsesAnInPlaceRightDrawer`: `drawer.maxX = 1267.5`, `table.maxX = 1266.5`, tolerance `0.5`. It is a real one-point edge-alignment regression. |
| Current `PipelineView.swift` compact layout | The in-place trailing `ZStack` already supplies the intended shared trailing edge. The explicit `.offset(x: 1)` on `pipeline-inspector-drawer` moves only the drawer one point beyond the Table region. Removing that offset restores the contract without changing the test or presentation behavior. |
| Retained-run diagnosis and result-bundle inspection | A retained host reported not-running during normal test teardown; that is not a product launch or signing defect. Earlier malformed/incomplete result bundles were externally interrupted and are invalid as gate evidence. They must not be repaired by weakening tests or counted as product failures. |

The previous normal-width Table-content repair remains independently required;
this release does not treat its separate evidence as accepted. The focused
compact-drawer failure is sufficient to keep Task 3 rejected.

### Only authorized corrective change

A fresh implementer may modify **only**:

1. `RekonPursuit/PipelineView.swift` — remove or otherwise eliminate the
   compact drawer's one-point trailing displacement so
   `pipeline-inspector-drawer.maxX` equals `pipeline-table-region.maxX` within
   the existing `0.5`-point test tolerance. The compact drawer must remain an
   in-place, trailing overlay; its width, close behavior, transition,
   selection semantics, and all identifiers must remain unchanged.
2. This delivery evidence, the canonical delivery-dashboard projection, and
   roadmap status text — delivery records only.

No test change is authorized. In particular, do not relax the geometry
tolerance, alter the test window, replace a semantic assertion with a
screenshot, or suppress the retained drawer test. Board markup, lane mapping,
drag/drop, fixtures, host configuration/signing, model/store/persistence,
filters, routes, Import CSV, sidebar behavior, and Task 4 are expressly out
of scope.

### Required signed verification before fresh review and QA

The implementer must run each retained VD2-04 control test as **one signed
`xcodebuild test` invocation per finalized result bundle**, using the existing
project, `RekonPursuit` scheme, macOS arm64 destination, and no command-line
signing override. The following original tests must run unchanged:

1. `testVD204PipelineTableSelectsAnEphemeralInspectorAndOnlyOpenDetailsRoutes`
2. `testVD204PipelineCompactWindowUsesAnInPlaceRightDrawer`
3. `testVD204PipelineTableSelectionHasNoRadioChildControl`
4. `testVD204PipelineCompactToolbarKeepsTheViewSwitcherOnOneLine`
5. `testVD204PipelineControlsRemainKeyboardDiscoverableAndStyled`
6. `testVD204PipelineNavySurfaceControlsRemainSemanticallyOperableInTableAndBoard`
7. `testVD204ShellExposesOnlyTheAppOwnedSidebarToggle`
8. `testVD204PipelineOpenDetailsSavesAndRelaunchesCanonicalEditWithActivityEvidence`
9. `testVD204PipelineFiltersUseOnlyTheSessionLocalControlsAndExposeTruthfulNoResults`
10. `testVD204DeletingASelectedTableRowUsesTheExistingConfirmationAndClearsTheInspector`

For every bundle, record the exact command and path, then validate both
`plutil -p <bundle>/Info.plist` and
`xcrun xcresulttool get test-results summary --path <bundle>`. Each summary
must be finalized `Passed` with exactly one passed test, zero failed tests,
and zero skipped tests. A host-not-running message is acceptable only after a
passing finalized summary; a malformed, missing-Info.plist, or externally
interrupted bundle is not evidence and must be rerun under a new path.

The existing focused dense-Table repair evidence must also be rerun or
preserved as a separately valid signed gate; this alignment release does not
weaken or replace it. Fresh independent Code Review and QA must approve the
source boundary and all finalized evidence before Delivery may reconsider
Task 3. Task 4, product-owner acceptance, and VD2-05 remain withheld.

---

## Retained filter-contract correction release

**Date:** 2026-07-30  
**Role:** Independent Delivery Manager  
**Decision:** **Release one test-only retained-contract correction. Task 3
remains rejected; Task 4 and VD2-05 remain withheld.**

### Independent diagnosis

| Evidence inspected | Finding |
| --- | --- |
| `RekonPursuit/RekonVisualTheme.swift:seedFixtureIfNeeded` | The approved, test-host-only `pipeline` fixture contains exactly six records: one each in Saved, Applied, Screening, Interviewing, Offer, and Closed. Its existing filter contract excludes only Closed by default, so five rows must be visible before Include closed is enabled. |
| `RekonPursuitUITestHostTests.testVD204PipelineFixtureSeedsTruthfulCrossFieldAndEditSafeRecords` | The fixture-host regression asserts the six-record inventory and records the deterministic Closed fixture fact. |
| `RekonPursuitUITests.testVD204PipelineFiltersUseOnlyTheSessionLocalControlsAndExposeTruthfulNoResults` | The retained test still asserts a three-row pre-toggle/reset inventory inherited from the earlier fixture. It therefore contradicts the approved six-record fixture while its later Closed-toggle assertion remains correctly scoped. |

This is a stale UI-test expectation, not evidence of a product filter,
fixture, Board, persistence, or routing regression. Changing product behavior
to restore a three-row default would violate the approved fixture contract.

### Sole authorized correction

A fresh implementer may modify **only**
`RekonPursuitUITests/RekonPursuitUITests.swift`, and only within
`testVD204PipelineFiltersUseOnlyTheSessionLocalControlsAndExposeTruthfulNoResults`:

1. Change the default and post-clear-filter row-count expectations from `3`
   to `5`.
2. Add an explicit assertion, before the Include closed control is toggled,
   that the known `Closed opportunity, Northstar Labs, Closed` row is absent.

The added absence check must use the existing stable Pipeline-row identity and
must precede the existing positive assertion after the control is enabled.
It must not remove, weaken, reorder away, or replace the existing search,
clear-filter, stage, selection-clearing, or post-toggle assertions.

### Explicit holds and return gate

No production source, fixture, filter semantics, Board markup/mapping,
drag/drop, signing/configuration, model/store/persistence, activity, route,
Import CSV, sidebar, compact drawer, dashboard workflow state, or other test
is released by this correction. The prior Table geometry repair and its
one-command-per-finalized-bundle retained verification remain independently
required. A fresh Code Reviewer and QA verifier must review the focused signed
filter result after this correction; only then can Delivery re-evaluate the
already-rejected Task 3. Task 4, product-owner acceptance, and VD2-05 remain
withheld.

---

## Task 3 responsive-width policy repair release

**Date:** 2026-07-30  
**Role:** Independent Delivery Manager  
**Decision:** **Task 3 remains rejected. Release one narrow responsive
Table repair; Task 4, product-owner acceptance, and VD2-05 remain withheld.**

### Independent decision and supersession

The independent architecture decision
[`ADR-VD2-04-table-responsive-width-policy.md`](../../architecture/ADR-VD2-04-table-responsive-width-policy.md)
is accepted. It finds that the prior Task 3 geometry boundary tried to prove
the mock's five-column desktop Table in an 1100×760 `wide` fixture. That leaves
insufficient Pipeline content width beside an inspector and produced the
observed clipped Due-date column. A header identifier or a passing narrow
track is not evidence of readable desktop content.

This release **supersedes the previous Task 3 normal-width geometry boundary**.
It does not reopen the separate compact-drawer alignment repair or the
test-only retained-filter correction. Those corrections and their evidence
remain required. This release replaces neither acceptance nor the Board hold.

### Sole authorized implementation boundary

A fresh implementer may modify only these files:

1. `RekonPursuitUITestHost/BootstrapApp.swift` — set only
   `VisualFixtureWindowSize.wide` to **1600×1000**. This is mock-aligned test
   evidence, not a production minimum-window change.
2. `RekonPursuit/PipelineView.swift` — implement only the Table responsive
   regimes and tracks specified by the ADR:
   - when available Pipeline content width is **at least 1220 pt**, render the
     dense five-column Table beside the existing persistent **320–340 pt**
     right-hand inspector; Role, Employer, Stage, Next action, and Due date
     must use readable content-led tracks no smaller than 180, 140, 108, 150,
     and 104 pt respectively, before inner padding and column gaps;
   - below 1220 pt, render the defined compact *dense table* (Role,
     location/work arrangement, and exact Stage), omitting the other desktop
     columns rather than squeezing, clipping, scrolling, or turning rows into
     cards; show the existing in-place trailing right drawer only after a row
     is selected.
3. `RekonPursuitUITests/RekonPursuitUITests.swift` — add only assertions for
   the 1600×1000 wide fixture and both deliberate Table regimes, including
   concrete geometry/readability proof for desktop headings and representative
   values, and compact Table/right-drawer proof. Existing assertions, named
   captures, and retained controls must not be weakened or deleted.
4. This delivery record;
   `docs/delivery/dashboard-status.json`; generated dashboard projections;
   `docs/delivery/roadmap.md`; and the Visual Design v2 SDD progress ledger —
   delivery-status records only.

### Explicit non-authorizations

Board markup, Board lane mapping use, drag/drop, card relocation, stage
movement, models, stores, persistence, filters, activity/audit, routing,
Import CSV, sidebar behavior, signing/configuration, fixture data, production
minimum window policy, and all VD2-05 work remain out of scope. The compact
drawer must remain an in-place trailing overlay — never a sheet, modal, or
below-list panel. No Board implementation begins from this Table repair.

### Required return evidence before Task 3 can be reconsidered

1. A clean, UUID-qualified, signed focused Table run records the actual
   1600×1000 fixture before evaluating the five-column desktop state. Its
   selected-row attachment visibly shows all five headers and representative
   values fully readable beside the persistent inspector.
2. A signed 860×640 compact run proves the compact aligned columns, no
   radio/checkbox row control, and selected in-place right drawer with aligned
   trailing edges; it must not show a sheet/modal or a below-list inspector.
3. New assertions prove geometry/readability rather than only accessibility
   identifier existence. The existing Task 2 Board fidelity contract remains
   intentional RED until Task 4 is independently released.
4. Every retained VD2-04 UI control remains green in finalized signed result
   bundles under the existing one-command-per-bundle evidence rule. The
   separate compact-drawer and retained-filter corrections remain independently
   validated; this release does not weaken or replace them.
5. Fresh Code Review and QA independently inspect the signed wide Table
   attachment against controlling mock #1 and validate the compact drawer.
   Only then may Delivery reconsider Task 3. Task 4 remains withheld unless
   Task 3 is accepted by those gates.

### Delivery state

`VD2-04` remains **in progress** with Task 3 rejected pending this repair.
`VD2-05` remains **backlog and dependency-blocked** by renewed explicit
product-owner acceptance of completed VD2-04. No successor task is eligible.

## Task 3 responsive repair acceptance and Task 4 release

**Date:** 2026-07-30  
**Role:** Independent Delivery Manager  
**Decision:** **Task 3 is accepted. Release Task 4 only — Board fidelity
implementation, visual proof, and its required final gates.**

### Acceptance evidence inspected

| Gate | Evidence inspected | Delivery finding |
| --- | --- | --- |
| Architecture policy | `docs/delivery/architecture/ADR-VD2-04-table-responsive-width-policy.md` | The implementation uses the accepted 1600×1000 evidence fixture, 1220-pt available-content boundary, readable five-column desktop tracks, persistent inspector, and the retained compact dense-Table/right-drawer policy. |
| Focused signed responsive contract | `/private/tmp/rekon-vd204-responsive-table-green-final.xcresult` | Finalized **Passed**: 1 passed, 0 failed, 0 skipped. This bundle proves the approved desktop and compact Table regimes, including visible desktop headers and representative content beside the inspector. |
| Retained signed control suite | The ten `/private/tmp/rekon-vd204-responsive-retained-*.xcresult` bundles named below | Every bundle finalized **Passed** with 1 passed, 0 failed, and 0 skipped. The one-command-per-finalized-bundle rule is satisfied. |
| Fresh independent Code Review | Final responsive repair review supplied to Delivery | **Accepted.** The reviewer visually inspected the signed 1600×1000 Table and compact drawer captures, found the responsive policy implemented faithfully, and found no Board, workflow, model, storage, routing, or configuration drift. |
| Fresh independent QA | Final responsive repair QA verdict supplied to Delivery | **Accepted.** QA inspected both signed Table captures and verified all ten retained controls. The Task 2 Board contract remains intentionally RED and is not counted as a Task 3 defect. |
| Repository hygiene | `git diff --check` at this Delivery review | Passed. The shared worktree remains intentionally dirty; this decision accepts only the bounded Task 3 responsive repair and does not reclassify historical changes. |

The finalized retained bundles are:

1. `rekon-vd204-responsive-retained-testVD204PipelineTableSelectsAnEphemeralInspectorAndOnlyOpenDetailsRoutes.xcresult`
2. `rekon-vd204-responsive-retained-testVD204PipelineTableSelectionHasNoRadioChildControl.xcresult`
3. `rekon-vd204-responsive-retained-testVD204PipelineCompactWindowUsesAnInPlaceRightDrawer.xcresult`
4. `rekon-vd204-responsive-retained-testVD204PipelineCompactToolbarKeepsTheViewSwitcherOnOneLine.xcresult`
5. `rekon-vd204-responsive-retained-testVD204PipelineControlsRemainKeyboardDiscoverableAndStyled.xcresult`
6. `rekon-vd204-responsive-retained-testVD204PipelineNavySurfaceControlsRemainSemanticallyOperableInTableAndBoard.xcresult`
7. `rekon-vd204-responsive-retained-testVD204ShellExposesOnlyTheAppOwnedSidebarToggle.xcresult`
8. `rekon-vd204-responsive-retained-testVD204PipelineOpenDetailsSavesAndRelaunchesCanonicalEditWithActivityEvidence.xcresult`
9. `rekon-vd204-responsive-retained-testVD204PipelineFiltersUseOnlyTheSessionLocalControlsAndExposeTruthfulNoResults.xcresult`
10. `rekon-vd204-responsive-retained-testVD204DeletingASelectedTableRowUsesTheExistingConfirmationAndClearsTheInspector.xcresult`

### Sole authorized Task 4 boundary

A fresh implementer may now modify only the Task 4 surfaces named in
`docs/delivery/task-briefs/VD2-04-pipeline-fidelity-rebuild.md`:

1. `RekonPursuit/PipelineView.swift` — replace the six equal rendered Board
   columns with the accepted view-local four-primary/fifth-conditional mapping
   and rich navy/cyan Board cards. Use the already-tested `PipelineBoardLane`
   seam; retain exact opportunity stages and existing card-open route/anchor
   behavior. Add lane icon/label/count/menu visual, add affordance, and
   intentional empty-lane states. Do not add drag/drop or mutate workflow.
2. `RekonPursuit/RekonVisualTheme.swift` — only if strictly required by the
   existing Task 2 presentation seam; no fixture, model, store, persistence,
   import, routing, activity, filter, signing, or sidebar change is allowed.
3. `RekonPursuitUITests/RekonPursuitUITests.swift` — Board-contract completion
   and named wide/compact Board capture proof only; retain the Table contracts
   and every retained VD2-04 control.
4. `docs/delivery/evidence/visual-design-v2/VD2-04-owner-handoff-2026-07-30.md`
   — owner handoff evidence only after Task 4's independent gates approve.

Task 4 must begin by rerunning the intentional Board RED contract. Its Board
proof must cover four primary lanes with Include closed off; Closed only as a
fifth secondary lane with the existing filter on; exact-stage chips; employer
identity; location/work arrangement; next action; due date; existing owner or
avatar data when present; and the no-drag/drop boundary. Before any owner
handoff, fresh Code Review and QA must independently approve Task 3–4, the
Architect must verify the lane decision or record a deviation ADR, TPM must
confirm scope, and Security/Privacy must confirm high-risk paths were untouched.

### Explicit non-authorizations and dependency state

- `VD2-04` remains **in progress** and **not product-owner accepted**. This
  Task 3 acceptance neither closes the card nor substitutes for the Task 4
  visual proof, final independent gates, or explicit renewed owner acceptance.
- `VD2-05` remains **backlog and dependency-blocked**. It is not released for
  planning, implementation, review, or dashboard advancement until the owner
  explicitly accepts the completed VD2-04 card.
- No persistent stage movement, drag/drop, model/store/persistence mutation,
  import change, activity/audit change, data fixture change, route change,
  sidebar change, signing/configuration change, or successor VD2 work is
  authorized by this release.

---

## Task 4 Board-contract accessibility-query repair release

**Date:** 2026-07-30  
**Role:** Independent Delivery Manager  
**Decision:** **Release one test-only Task 4 repair. Board implementation and
all non-test sources remain frozen; Task 4 is not accepted.**

### Independent diagnosis

| Evidence inspected | Finding |
| --- | --- |
| `/private/tmp/rekon-vd204-task4-board-green-retry.xcresult` | The signed focused Board run reaches the intended grouped Board, but fails at `RekonPursuitUITests.swift:408–411` when XCTest evaluates a card/metadata query scoped below `pipeline-board-lane-applied`. The result does not report a build, launch, fixture, signing, or lane-mapping failure. |
| AX diagnostic from the failed Board run | The `Product Designer` fixture card is exposed beneath the rendered Applied lane in the accessibility tree. XCTest's lane-scoped descendant query is the unreliable boundary; it is not evidence that the Board put the Screening record in the wrong presentation lane. |
| Current pure mapping coverage and Task 4 source review | `PipelineBoardLane.includes(_:)` still maps both precise `Applied` and `Screening` stages into the Applied presentation lane. The existing Board uses that seam, retains the exact `Screening` chip, lane identifiers, counts, and add affordances. No workflow/model/store change is implicated. |

This release corrects only the test's unreliable AX scoping. It does not
reinterpret a failing Board contract as passing, weaken the required rich-card
facts, or accept Task 4.

### Sole authorized repair boundary

A fresh implementer may modify **only**
`RekonPursuitUITests/RekonPursuitUITests.swift`, within
`testVD204PipelineFidelityBoardContract`'s post-capture assertions:

1. Find the known `Product Designer` opportunity card through a global Board
   card query rather than through the lane's XCTest descendant collection.
2. Keep the Applied lane's existing identifier, count, and add-affordance
   assertions; retain the pure mapping contract unchanged.
3. Assert the card's company, exact `Screening` chip, locality/work
   arrangement, next action, and due-date facts using stable global card
   metadata queries.
4. Prove visual membership with the live Applied-lane and card frames: the
   card must lie within the lane frame, allowing only a small explicit
   accessibility-frame tolerance for border/shadow rounding. The repair may
   not merely find the card globally and omit lane containment.
5. Retain the four-primary-lane checks, default absence and toggle-enabled
   presence of the Closed lane, both named Board captures, and all other
   fidelity and retained VD2-04 tests. No test may be deleted, relaxed into a
   screenshot-only claim, or reordered to evade a failure.

### Explicit non-authorizations

`RekonPursuit/PipelineView.swift`, `RekonVisualTheme.swift`, all model/store,
persistence, fixture, route, import, activity/audit, signing/configuration,
sidebar, Table, and dashboard behavior sources are frozen. This release does
not authorize drag/drop, persisted stage movement, card relocation, fake
Board data, VD2-05 work, owner handoff, or a Task 4 acceptance decision.

### Required return evidence and next gate

1. Run the focused Board contract in a fresh isolated signed Debug build and
   UUID-qualified result bundle. It must finalize `Passed` with one passed,
   zero failed, and zero skipped tests; an interrupted or malformed bundle is
   invalid evidence.
2. Preserve and inspect `vd204-fidelity-wide-board` and
   `vd204-fidelity-compact-board`. The wide capture must show four primary
   lanes and the rich Screening card in the Applied lane. The compact capture
   must show the filter-enabled secondary Closed lane.
3. Reconfirm the production mapping unit contract unchanged and run the
   applicable retained VD2-04 controls in finalized signed bundles.
4. Fresh independent Code Review and QA must inspect the repair, result
   bundles, attachments, lane-frame containment assertion, and source-boundary
   evidence. Architecture, TPM, and Security/Privacy final gates remain
   required before a later owner handoff.

### Delivery state

`VD2-04` remains **in progress**, with Task 4 in implementation/repair and
not accepted. `VD2-05` remains **backlog and dependency-blocked**. The
dashboard records this repair release only; it does not advertise a completed
Board or request product-owner action.

---

## Task 4 Board-contract atomic-card accessibility-query repair release

**Date:** 2026-07-30  
**Role:** Independent Delivery Manager  
**Decision:** **Release one stricter test-only repair. Task 4 is not
accepted; all production Board and workflow sources remain frozen.**

### Independent diagnosis and evidence boundary

The fresh accessibility diagnosis supersedes the prior assumption that the
rich card's visual metadata can be queried as nested XCTest elements. The
rendered `Product Designer` card has the expected UUID-qualified global
`pipeline-opportunity-…` identity and is exposed by AppKit as one atomic
`Button`. AppKit therefore suppresses the child metadata identifiers from the
XCTest accessibility projection. That is an accessibility-query boundary, not
evidence that the Board omitted the visible metadata or placed the Screening
record in the wrong lane.

| Evidence inspected | Delivery finding |
| --- | --- |
| Fresh AX diagnosis and signed Board capture | The known `Product Designer` card is a globally discoverable atomic Button and its live frame is contained by the Applied lane. The wide capture visibly shows the rich card facts. |
| `RekonPursuit/RekonVisualTheme.swift` test-host fixture | The Board fixture defines the opportunity as **Product Designer**, employer **Northstar Labs**, precise stage **Screening**, and its locality, next action, and due-date facts. |
| `RekonPursuitTests/RekonPursuitTests.swift` mapping contract | `PipelineBoardLane.applied.includes(.screening)` is independently proven, while the exact canonical stage remains `.screening`. |
| Existing focused Board contract | It already proves the four default lanes, lane identifiers/counts/add affordances, Closed's default absence and filter-enabled presence, live Applied-frame containment, and both required signed captures. |

The visual facts remain required for final visual QA. They are not to be
misrepresented as independently addressable child AX elements when the real
AppKit accessibility object is an atomic card button.

### Sole authorized repair boundary

A fresh implementer may modify **only**
`RekonPursuitUITests/RekonPursuitUITests.swift`, within
`testVD204PipelineFidelityBoardContract`'s post-capture checks:

1. Retain the global UUID-qualified `Product Designer` card identity and the
   live Applied-lane/card-frame containment assertion, including its explicit
   small frame tolerance.
2. Retain every four-primary-lane identifier/count/add-affordance check,
   Closed's default absence and Include-closed enabled presence, and the named
   `vd204-fidelity-wide-board` and `vd204-fidelity-compact-board` captures.
3. Remove only the impossible nested card-metadata identifier assertions for
   company, stage chip, locality, next action, and due date. Do not replace
   them with a weaker global text search or change card/lane accessibility
   implementation to make a test pass.
4. Record in the test's rationale that rich metadata is independently covered
   by the deterministic fixture and mapping contract, and is subject to fresh
   signed-capture visual QA. The repair must not make a screenshot-only claim:
   global card identity plus lane-frame containment remain executable UI
   assertions.

### Explicit non-authorizations

`RekonPursuit/PipelineView.swift`, `RekonPursuit/RekonVisualTheme.swift`, all
fixtures, models, stores, persistence, routing, Import CSV, activity/audit,
filters, signing/configuration, sidebar, Table, dashboard behavior, drag/drop,
and persisted stage movement are frozen. This release authorizes no new
accessibility production seam, hidden duplicate element, non-atomic card
wrapper, or Board behavior change. It does not release VD2-05, owner handoff,
or Task 4 acceptance.

### Required return evidence and next gate

1. A fresh isolated signed Debug focused Board run finalizes `Passed` with one
   passed, zero failed, and zero skipped tests. An interrupted, malformed, or
   unsigned bundle is invalid.
2. A reviewer and QA verifier inspect both named Board captures against the
   approved mock: four rich primary lanes by default, the Screening card in
   Applied, visible employer/stage/location/next-action/due-date information,
   and filter-enabled Closed as the secondary lane.
3. The fixture and pure lane-mapping tests are rerun unchanged, and retained
   VD2-04 controls remain finalized green. Final Architecture, TPM, and
   Security/Privacy gates are still mandatory before a later owner handoff.

### Delivery state

`VD2-04` remains **in progress**. Task 4 is a test-only atomic-card AX repair
and is **not accepted**. `VD2-05` remains **backlog and dependency-blocked**;
no product-owner action is requested.

---

## Task 4 compact Closed-lane capture repair release

**Date:** 2026-07-30  
**Role:** Independent Delivery Manager  
**Decision:** **Release one capture-only UI-test repair. Task 4 remains
unaccepted; all product sources remain frozen.**

### Reconciled independent gate findings

| Gate | Finding | Delivery disposition |
| --- | --- | --- |
| Visual QA | The signed Board captures are visually credible: wide Board shows the four rich primary lanes and the Screening card in Applied. | Useful but insufficient final evidence. |
| Code review | The compact Board attachment is made after Include closed is enabled, but it does not prove that the horizontally off-screen Closed lane/card was brought into the captured viewport. | Reject final proof; authorize this narrow repair only. |
| Architecture | The lane projection, canonical stage boundary, and no-workflow-change scope conform to the accepted ADR. Architecture withholds its final evidence acceptance until a post-repair signed passing Board contract exists. | No production architectural change is authorized. |

The defect is in evidence framing, not Board behavior: the current compact
test establishes that a Closed header exists somewhere in the accessibility
tree, then captures the initial horizontal viewport. That cannot substantiate
the required compact Closed-lane visual proof.

### Sole authorized repair boundary

A fresh implementer may modify **only**
`RekonPursuitUITests/RekonPursuitUITests.swift`, inside
`testVD204PipelineFidelityBoardContract`'s compact Board path, and must:

1. Keep the existing Include closed value transition from `0` to `1`.
2. After that transition, horizontally scroll `pipeline-board-region` toward
   the end until the `pipeline-board-lane-closed` frame is inside the visible
   Board-region/window viewport. Use bounded, explicit gestures/retries; do
   not alter production scroll behavior or add a test-only production anchor.
3. Assert both the Closed lane and its known `Closed opportunity` card exist,
   have non-zero frames, and are visibly framed in that compact viewport
   before creating `vd204-fidelity-compact-board`. A mere accessibility-tree
   existence check is insufficient.
4. Preserve the current wide capture, compact capture name, four-primary
   default-lane checks, default Closed absence, filter-enabled Closed
   assertion, global atomic-card identity, Applied-lane frame containment,
   all retained VD2-04 tests, and every production source unchanged.

No `PipelineView`, theme, model/store, fixture, route, persistence, import,
activity, signing, dashboard behavior, drag/drop, stage movement, or VD2-05
change is authorized. The repair may neither change the capture size nor
replace visual framing proof with screenshots alone.

### Required return evidence before final gates

1. A new isolated signed Debug focused Board bundle finalizing **Passed**:
   one passed, zero failed, zero skipped, with no interrupted/malformed
   result. It must include the unchanged named wide Board attachment and the
   new compact capture visibly framing the Closed lane/card.
2. The unchanged pure lane-mapping proof must pass, including four default
   primary lanes and filter-enabled fifth Closed lane.
3. Fresh independent Code Review and QA must inspect the test-only diff, the
   signed bundle, viewport/frame assertions, and both captures. Fresh final
   Architecture, TPM, and Security/Privacy gates then remain required before
   any owner handoff.

### Delivery state

`VD2-04` remains **in progress** and **not product-owner accepted**. Task 4
is in a capture-only evidence repair, not accepted. `VD2-05` remains
**backlog and dependency-blocked**; no successor work or owner action is
released.
