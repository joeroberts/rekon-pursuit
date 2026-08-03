# VD2-04 navy-surface correction — Delivery Manager Task 0 release

**Date:** 2026-07-30  
**Role:** Independent Delivery Manager  
**Card status:** `VD2-04` remains **in progress** — not accepted  
**Release decision:** **Release Task 1 only (test-first RED contract).**

## Evidence reviewed

| Required Task 0 gate | Evidence | Delivery finding |
| --- | --- | --- |
| Owner-approved visual direction | `docs/superpowers/specs/2026-07-30-vd204-pipeline-navy-surface-correction-design.md` | Deep-navy Pipeline surfaces and cyan/blue secondary chrome are the correction baseline. Board behavior is expressly out of scope. |
| Planning | `docs/delivery/task-briefs/VD2-04-pipeline-navy-surface-correction.md`; `docs/superpowers/plans/2026-07-30-vd204-pipeline-navy-surface-correction.md` | Dependency-safe Task 0–4 sequence, file boundary, intentional RED evidence, and signed-Debug verification are defined. |
| Architecture | `docs/delivery/architecture/ADR-VD2-04-pipeline-navy-control-seam.md` | Accepted Pipeline-local AppKit seam keeps the native controls as the accessibility and keyboard owners while Rekon owns visual rendering. Global appearance changes and hidden-control/button duplication are rejected. |
| QA/test | `docs/delivery/evidence/visual-design-v2/VD2-04-navy-surface-qa-strategy.md` | Approved with conditions: retain intentional RED evidence, capture all four signed-product layout/mode states, and manually reject visible gray chrome even if AX tests pass. |
| TPM | `docs/delivery/evidence/visual-design-v2/VD2-04-navy-surface-tpm-gate.md` | Scope approved. The corrective work remains VD2-04; Board workflow and VD2-05+ work are not released. |
| Current delivery state | `docs/delivery/dashboard-status.json`; `docs/delivery/roadmap.md`; `docs/delivery/evidence/visual-design-v2/VD2-04-owner-handoff-2026-07-30.md`; `.superpowers/sdd/2026-07-30-vd204-pipeline-feedback-correction/progress.md` | VD2-04 is already `in_progress`; VD2-05 is `backlog` with VD2-04 as its required dependency. Earlier VD2-04 correction evidence is historical only and does not constitute renewed owner acceptance. |

## Release scope

The only eligible implementation work is **Task 1 — establish the
navy-surface RED contract** in the two authorized test files. The implementer
may add the pure presentation-contract test, the semantic-operation/capture
test, and retain an intentional signed-Debug RED result bundle. No production
source, dashboard status, Board workflow, data, persistence, routing, import
behavior, or VD2-05 file is authorized by this release.

The release does not treat a passing test as visual acceptance. The four named
captures and later signed-product visual inspection are required evidence.

## Architecture follow-up boundary

The accepted ADR establishes the control ownership seam, but does not yet name
the exact semantic fill/outline/width/opacity mapping for the **selected**
interaction state. The Task 1 test author may create the RED contract for the
fully specified states and leave the selected assertion pending, as allowed by
the plan. **Task 2 is not eligible** until Architecture records the selected
state mapping in the ADR (or a successor ADR); neither the test implementer
nor Delivery Manager may choose that visual token.

This is a bounded design-decision dependency, not permission to broaden the
implementation or weaken the all-state test requirement.

## Dependency controls

- `VD2-04` remains **in progress**. No product-owner acceptance is claimed or
  requested at this release point.
- `VD2-05` remains **blocked/backlog**, dependent on renewed owner acceptance
  of VD2-04. It is not next eligible.
- The dashboard's current `VD2-04` and `VD2-05` state is already consistent
  with this decision; no acceptance or eligibility transition is made here.
- Task 1 must preserve every prior VD2-04 regression: right drawer, no row
  radio glyph, nonwrapping/omitted compact View label, one app-owned sidebar
  action, and native control discoverability/activation.
- Any source/test change outside Task 1's two authorized test files requires
  a fresh delivery release. No commit is authorized by this record.

## Required gates after Task 1 and implementation

1. Preserve clean intentional Task 1 RED unit and UI bundles; their failures
   must be missing/invalid navy-presentation contract evidence, not signing,
   fixture, or unrelated failures.
2. Architecture records the selected-state mapping; Delivery then releases
   Task 2 only. Task 2 must pass the pure mapping test and `git diff --check`.
3. Delivery releases Task 3 only after Task 2 is green. Task 3 must run the
   full signed-Debug focused suite and create four named Table/Board,
   wide/compact attachments before the Import dialog.
4. Fresh independent code review, QA visual verification, Architecture
   conformance review, TPM scope closeout, and security/privacy diff review
   must all pass. QA must inspect the attachments and actual signed-product
   captures against the owner references, including focus and hover states.
5. Delivery records those results and issues a fresh owner handoff. VD2-04
   remains in progress until the product owner explicitly accepts the corrected
   signed product; VD2-05 remains blocked until then.

## Task 1 closeout and Task 2 release

**Date:** 2026-07-30  
**Delivery decision:** Task 1 is **complete only as an intentional RED
test-contract gate**. Task 2 is now **released**, with the boundary below.

### Task 1 evidence rechecked

| Gate | Evidence | Delivery finding |
| --- | --- | --- |
| Baseline/scope control | `VD2-04-navy-task1-baseline-attestation.md` | Only the named unit and UI contract methods are attributable to Task 1. The accumulated shared-worktree diff is not reclassified, reset, or accepted. |
| Architecture | `ADR-VD2-04-pipeline-navy-control-seam.md` | The accepted seam and selected mapping are sufficiently specific for the pure semantic implementation: selected is `elevatedSurface`/`accent`/1 pt/1.00 and keyboard focus is `violet`/2 pt. |
| Independent code review | `VD2-04-navy-task1-code-review.md` | Accepted as a RED-contract gate. It confirms the two tests preserve the intended accessibility, normal-operation, compact/wide, and capture requirements without opening production or workflow scope. |
| Independent QA | Fresh Task 1 QA verdict recorded for this release | Accepted the red-first contract: Table and Board independently exercise the closed-filter state, and the only intended red condition is the absent presentation seam. |
| Signed-Debug RED evidence | `/tmp/rekon-vd204-navy-surface-task1-final-red.xcresult` | Build cancellation is attributable to the absent `PipelineNavySurfacePresentation` at `RekonPursuitTests.swift:137-155`. The resulting contextual diagnostics are consequences of that missing seam; inspection found no signing, fixture, UI-runtime, or unrelated product failure. |

The red unit result is deliberately retained; it is not a test pass and it
does not demonstrate that gray chrome has been corrected. Because the absent
unit seam stops the test build before UI execution, Task 1's semantic UI
operation/capture test is **deferred until the seam is green**. The later Task
3 signed-Debug run remains responsible for executing it and preserving all
four attachments.

### Task 2 authorization — no broader work

The next eligible implementer may modify **only**
`RekonPursuit/RekonVisualTheme.swift` and run the corresponding pure unit
presentation contract green. The implementer must:

1. add the ADR-defined nonisolated semantic interaction/presentation mapping
   and use only existing Rekon navy/border/accent/violet tokens;
2. make `testVD204PipelineNavySurfacePresentationContract` green, retain the
   Task 1 RED bundle, and run `git diff --check`; and
3. avoid any `PipelineView.swift`, UI-test, model/store, import, activity,
   routing, Board-workflow, dashboard, or VD2-05 change.

This release does **not** authorize a Task 3 renderer/application change, UI
test run, visual acceptance, dashboard completion, owner handoff, or commit.
The dashboard remains unchanged: `VD2-04` is **in progress/not accepted**;
`VD2-05` remains **blocked/backlog** on renewed VD2-04 product-owner
acceptance. Task 2 green evidence is a prerequisite for—not evidence of—the
remaining independent visual, security/privacy, architecture, TPM, delivery,
and owner gates.

## Task 2 repair release — prior Task 2 is not accepted

**Date:** 2026-07-30  
**Delivery decision:** The initial Task 2 implementation is **not accepted**.
Release one narrow repair only; do not release Task 3.

### Independent rejection evidence

| Gate | Evidence | Delivery finding |
| --- | --- | --- |
| QA/test verification | Fresh independent Task 2 QA verdict | The intentional RED bundle failed only because the presentation seam was absent, and the focused green unit bundle passed. However, the contract does not assert the complete fill/outline/width/opacity tuple for every ADR state. Hover, pressed, and disabled widths plus idle, hover, and keyboard-focus opacity are unproved. |
| Code review | Fresh independent Task 2 code-review verdict | The implementation uses separate static mapping functions rather than the ADR-required Equatable presentation value. More importantly, `RekonSecondaryButtonStyle` now consumes the Pipeline mapping globally, leaking Pipeline-only styling to unrelated consumers. |
| Architecture conformance | `docs/delivery/architecture/ADR-VD2-04-pipeline-navy-control-seam.md` | The ADR requires one Equatable semantic presentation value and a Pipeline-local secondary-button consumer. The existing Task 2 implementation does not meet either ownership boundary. |

The prior Task 2 unit green result is therefore insufficient. It is retained as
diagnostic evidence only and does not permit Task 3, visual review, dashboard
completion, owner handoff, or a commit.

### Authorized repair boundary

The next fresh implementer may modify **only** these files:

- `RekonPursuit/RekonVisualTheme.swift`
- `RekonPursuitTests/RekonPursuitTests.swift`

The repair must:

1. Replace the split static mapping with an **Equatable presentation value**
   containing fill, outline, outline width, and opacity. Delegating accessors
   are allowed only when they return fields from that one value.
2. Extend the pure unit contract to assert the complete tuple for each of the
   six states: idle, pointer hover, keyboard focus, pressed, selected, and
   disabled. The values must remain the ADR-defined navy-token mapping.
3. Leave global `RekonSecondaryButtonStyle` unchanged for all non-Pipeline
   consumers. Add a **Pipeline-specific** secondary button style that consumes
   the semantic Pipeline presentation value, but do not apply it yet; applying
   it belongs exclusively to the later Task 3 release.
4. Preserve the existing token-only resolver, paint-only primitive, no-global-
   appearance rule, and all prior VD2-04 contracts.
5. Run the focused Task 2 unit contract and `git diff --check`, retaining the
   original Task 1 RED evidence and the Task 2 repair green evidence.

No `PipelineView.swift`, UI-test, dashboard, delivery-status, model/store,
import, routing, Board-workflow, activity/audit, or VD2-05 edit is authorized.
No commit is authorized. A fresh independent code reviewer and QA verifier
must both accept the repair before Delivery may consider a Task 3 release.

### Dependency state after this release

- `VD2-04` remains **in progress** and **not owner accepted**.
- Task 2 remains **open for repair**; Task 3 is **not eligible**.
- `VD2-05` remains **blocked/backlog** on completed VD2-04 independent gates
  and renewed product-owner acceptance.
- The delivery dashboard is intentionally unchanged by this repair-release
  record; no milestone or card state has advanced.

## Task 2 repair closeout and Task 3 release

**Date:** 2026-07-30  
**Delivery decision:** **Task 2 repair is accepted. Release Task 3 only.**

### Independent closeout evidence

| Gate | Evidence | Delivery finding |
| --- | --- | --- |
| Repair scope | Current `RekonPursuit/RekonVisualTheme.swift` and `RekonPursuitTests/RekonPursuitTests.swift` | The repair supplies one nonisolated, Equatable `PipelineNavySurfacePresentationValue` with fill, outline, width, and opacity, and the static accessors delegate to that one value. The Pipeline-only secondary style is distinct from `RekonSecondaryButtonStyle`; it is not yet applied. |
| Contract coverage | `testVD204PipelineNavySurfacePresentationContract` | The unit contract now asserts the complete tuple for idle, pointer hover, keyboard focus, pressed, selected, and disabled states. The values match the accepted ADR: navy tiers only, cyan/accent selection, violet two-point focus, and the required pressed/disabled opacity. |
| Intentional RED retained | `/tmp/rekon-vd204-navy-surface-task1-final-red.xcresult` | The prior red result remains a valid missing-presentation-seam gate. It was not caused by signing, fixture setup, or unrelated product behavior. |
| Independent code review | Fresh Task 2 repair reviewer verdict | Accepted. The reviewer found the prior split-mapping and global-secondary-style defects corrected within the authorized two-file boundary; no Task 3 rendering or workflow change is included. |
| Independent QA | Fresh Task 2 repair QA verdict | Accepted narrowly. QA independently confirmed six-state tuple coverage, valid retained RED evidence, focused signed-Debug green evidence, and a clean `git diff --check`. Its duplicate rerun was invalidated by a concurrent DerivedData linker permission collision and is not treated as a product/test failure. |
| Signed-Debug green evidence | `/tmp/rekon-vd204-navy-task2-repair-final-green.xcresult` | `xcresulttool` reports **Passed**, 1 total / 1 passed / 0 failed test on macOS arm64. The validated target is `testVD204PipelineNavySurfacePresentationContract`; the associated Debug app carries the configured Apple Development signature. |
| Repository hygiene | `git diff --check` | Passed at delivery review. The shared worktree remains intentionally dirty with prior VD2 work; this finding accepts only the named Task 2 repair, not the accumulated historical diff. |

### Task 3 authorization — Pipeline rendering only

The next fresh implementer may change only:

- `RekonPursuit/PipelineView.swift`;
- `RekonPursuit/RekonVisualTheme.swift`, only where needed to expose or consume
  the already-approved Task 2 Pipeline-local primitives; and
- `RekonPursuitUITests/RekonPursuitUITests.swift`, only for test stabilization
  required by the actual control seam, never to relax a semantic, behavior, or
  visual requirement.

Task 3 must use the accepted semantic mapping to remove generic gray native
chrome in Pipeline Search, Stage, Include closed, Table/Board selection, and
Import CSV; apply the same layered navy hierarchy to Pipeline content surfaces
in both Table and Board; and retain all existing behavior, IDs, roles, labels,
keyboard activation, data, import behavior, routing, activity/audit behavior,
persistence, Board columns, and Board drag/drop. `Add opportunity` remains
the sole gradient primary action.

Before independent review, the Task 3 implementer must run the full signed
Debug focused command in `VD2-04-pipeline-navy-surface-correction.md`, retain
the result bundle, and inspect the four required pre-import attachments:
wide Table, wide Board, compact Table, and compact Board. The visual capture
review must reject generic gray wells/tracks/checkbox chrome and large neutral
gray content surfaces, as well as any regression of the right drawer,
no-radio row selection, nonwrapping/omitted compact View label, or single
app-owned sidebar action. This delivery release does not substitute a
semantic-unit pass for that visual evidence.

### Dependency state after Task 3 release

- `VD2-04` remains **in progress** and is **not owner accepted**.
- Task 3 is the sole eligible implementation task. Task 4 independent
  code-review, QA visual verification, architecture conformance, TPM scope
  closeout, and security/privacy diff review are not yet released.
- The delivery dashboard is intentionally unchanged. `VD2-05` remains
  **blocked/backlog**, dependent on VD2-04's completed independent gates and
  renewed product-owner acceptance.
- No commit, dashboard acceptance transition, or owner handoff is authorized
  by this release.

## Task 3 technical closeout and Task 4 final-gate release

**Date:** 2026-07-30
**Delivery decision:** **Task 3 is technically complete. Release Task 4
final review and acceptance gates only.** This is not a release of new
implementation work, a dashboard transition, or product-owner acceptance.

### Evidence independently reconciled

| Gate | Evidence | Delivery finding |
| --- | --- | --- |
| Task 3 independent code review | Accepted Task 3 reviewer verdict supplied to Delivery | Accepted. The renderer correction is within the authorized Pipeline/navy-surface boundary and does not open Board workflow, data, import, routing, persistence, or VD2-05 scope. |
| Fresh signed-Debug recovery suite | `/tmp/rekon-vd204-recovery-qa-20260730-1.xcresult` | `xcresulttool` reports **Passed**, 7 total / 7 passed / 0 failed / 0 skipped on arm64 macOS. This replaces the earlier infrastructure-stalled combined-run gap; it does not alter any prior intentional-RED history. |
| Presentation contract | `RekonPursuitTests/testVD204PipelineNavySurfacePresentationContract()` in the recovery bundle | Passed. The approved six-state navy-surface mapping is exercised in the recovered signed suite. |
| Corrected Pipeline behavior | Six VD2-04 UI tests in the recovery bundle | Passed: compact View control, compact in-place right drawer, keyboard-discoverable/styled controls, Table/Board semantic operation, no radio child control, and one app-owned sidebar toggle. |
| Required visual-capture set | Recovery bundle attachment export manifest: `/tmp/vd204-delivery-attachments.YmQ4n6/manifest.json` | Present and non-failure-associated: `VD204 navy surface — wide Table`, `wide Board`, `compact Table`, and `compact Board`. The manifest also retains the focused controls, drawer, selection, toolbar, and HSplit evidence. |
| Build result | Recovery bundle build result | Succeeded with zero build errors. Seven pre-existing Swift-concurrency compiler warnings in Core test files are recorded by Xcode but are outside this Task 3 delivery boundary and do not invalidate the passing targeted suite. |

### Bounded release: Task 4 is governance and acceptance only

No further source or test implementation is eligible under this release. The
only open VD2-04 work is fresh, independent final review of the completed
correction:

1. **QA visual verification** must inspect the four recovered captures and
   the signed product against the approved owner references, specifically
   rejecting residual generic gray wells/tracks/checkbox chrome and neutral
   gray Pipeline content surfaces. It must also confirm the right drawer,
   no-radio selection, compact View treatment, Import affordance, and one
   app-owned sidebar action.
2. **Architectural conformance review** must confirm the delivered renderer
   still honors the ADR's native-control ownership seam, Pipeline-local
   styling boundary, and no-global-appearance decision.
3. **TPM scope closeout** must confirm the correction did not expand Board
   workflow or release a later VD2 card.
4. **Security/privacy diff review** must confirm no high-risk capability or
   data-flow regression was introduced by the visual correction.
5. Delivery may issue a renewed owner handoff only after all four independent
   gates accept. The product owner must then explicitly accept the corrected
   signed product before this card can close.

### Dependency controls after technical closeout

- `VD2-04` remains **in progress** and **not product-owner accepted**.
- The delivery dashboard remains intentionally unchanged; this record does
  not claim a card completion or acceptance transition.
- `VD2-05` remains **blocked/backlog** on the final VD2-04 independent gates
  and renewed product-owner acceptance. It is not eligible for planning,
  implementation, or review as a consequence of this Task 3 closeout.
- No commit is authorized by this delivery decision.

## Final gate reconciliation and owner-handoff release

**Date:** 2026-07-30  
**Delivery decision:** All required independent technical gates have accepted
the completed VD2-04 correction. Release **only** the renewed product-owner
acceptance handoff. This is not an acceptance, card close, or release of
VD2-05.

| Final gate | Reconciled evidence | Delivery finding |
| --- | --- | --- |
| Task 3 code review | Task 3 technical closeout above | Accepted within the authorized Pipeline presentation boundary. |
| Recovery test evidence | `/tmp/rekon-vd204-recovery-qa-20260730-1.xcresult` | Passed: 7/7, zero failed/skipped, signed Debug on arm64 macOS. |
| Fresh QA visual gate | `VD2-04-navy-final-qa-gate.md` | Accepted for owner review. The control/content surfaces are navy/cyan rather than gray, retained VD2-04 behavior passed, and the visual references were used for comparison. |
| Fresh Architecture gate | `VD2-04-navy-final-architect-gate.md` | Accepted. The Pipeline-local native-control seam, ownership boundary, and no-global-appearance decision remain intact. |
| Fresh TPM gate | `VD2-04-navy-final-tpm-gate.md` | Accepted for scope/dependency control. No Board workflow or future VD2 release is implied. |
| Fresh Security/Privacy gate | `VD2-04-navy-final-security-gate.md` | Accepted. No high-risk capability, external data flow, or persistence boundary changed. |

The retained recovery attachment manifest at
`/tmp/vd204-delivery-attachments.YmQ4n6/manifest.json` contains the required
non-failure-associated wide Table, wide Board, compact Table, and compact
Board captures. QA also inspected three configured signed-product captures at
wide size. **Limitation:** compact evidence is from the signed UI-test host;
the actual product was not newly captured at compact size. The requested
860×600 compact host renders at the established product minimum of 860×640.
The renewed owner handoff deliberately requires hands-on confirmation of that
actual compact presentation.

### Delivery state after reconciliation

- `VD2-04`: `in_progress` and **awaiting explicit product-owner acceptance**.
  The canonical owner checklist and exact reply wording are in
  [VD2-04-owner-handoff-2026-07-30.md](VD2-04-owner-handoff-2026-07-30.md).
- `VD2-05`: `backlog` and **blocked/ineligible**; do not plan, implement,
  review, or advance it until the owner explicitly accepts VD2-04.
- No implementation task, source/test edit, dashboard acceptance transition,
  or commit is authorized by this record.
