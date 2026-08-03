# VD2-04 Pipeline fidelity rebuild — TPM Task 1 gate

**Date:** 2026-07-30  
**Role:** Independent TPM  
**Verdict:** **Accepted for scope and dependency control; Task 2 is eligible only after the Architect, QA, and Delivery Manager Task 1 records exist.**

## Evidence reviewed

- Owner-approved [fidelity-rebuild design](../../../superpowers/specs/2026-07-30-vd204-pipeline-fidelity-rebuild-design.md).
- [VD2-04 fidelity task brief](../../task-briefs/VD2-04-pipeline-fidelity-rebuild.md) and its dependency-safe sequence.
- [VD2-04 fidelity implementation plan](../../../superpowers/plans/2026-07-30-vd204-pipeline-fidelity-rebuild.md).
- Visual Design v2 section of the [delivery roadmap](../../roadmap.md) and the current [delivery dashboard status](../../dashboard-status.json).
- Existing VD2-04 correction evidence, which remains historical evidence only and cannot substitute for the fresh fidelity gates.

## Scope decision

This is a corrective **VD2-04** presentation and responsive-layout rebuild,
not a release of a later workflow card. The approved visual mapping is
acceptable because it is local and reversible:

- Saved contains only `Saved`;
- Applied visually contains `Applied` and `Screening`, while each card retains
  its exact stage label;
- Interviewing and Offer remain distinct;
- Closed appears as a secondary fifth lane only when the existing Include
  closed filter is enabled.

The approved work may replace the current stacked Table list with an
information-dense table and enrich the existing inspector and Board cards. It
must retain the current data model, opportunity stage values, filtering,
persistence, activity/audit behavior, routes, Import CSV behavior, keyboard
semantics, and existing compact right drawer.

## Explicit exclusions

The following are not authorized by this gate:

- drag/drop, persisted stage movement, card relocation, or any other Board
  workflow change;
- opportunity/store/model, persistence, activity, import, or route changes;
- changed filter semantics or fabricated fixture/user data;
- work on VD2-05 or later Visual Design v2 cards.

The mockup-style drop treatments in the design are therefore inert visual
states only. Any actual move interaction or stage mutation belongs to VD2-05
and requires its own planned and released work item.

## Dependency and release decision

The dashboard correctly records VD2-04 as `in_progress`; VD2-02 and VD2-03
are accepted prerequisites. VD2-05 is `backlog`, depends on VD2-04, and its
release condition remains **VD2-04 accepted**. Accordingly, VD2-05 remains
blocked from planning, implementation, review, and dashboard advancement.

This TPM gate does not itself release Task 2. Delivery may release the
test-only RED-contract task only after all of the following independent Task 1
records are present:

1. Architect confirms the view-local, reversible lane interface and no
   architectural/data-contract deviation.
2. QA accepts deterministic synthetic-fixture and signed-product
   wide/compact capture criteria.
3. Delivery Manager records the complete gate set and authorizes Task 2.

All retained VD2-04 control, drawer, selection, and sidebar contracts remain
mandatory regressions. The final fidelity implementation requires fresh
independent code review, QA, architecture, security/privacy, TPM, Delivery
Manager, and renewed product-owner acceptance before VD2-04 can be accepted.

## Risks and controls

| Risk | Required control |
| --- | --- |
| Visual grouping could be mistaken for stage mutation. | Pure lane-mapping tests prove the exact stage is preserved; code review rejects model/store writes. |
| Fidelity work could prematurely become VD2-05 Board work. | Reject drag/drop or persistent movement; preserve the dashboard dependency until owner acceptance. |
| A narrow test pass could conceal layout regression. | Red-first semantic contracts plus independently inspected signed-product Table and Board captures at wide and compact sizes. |
| Richer visuals could dilute existing accessibility. | Retain native IDs/roles, keyboard behavior, drawer, no-radio selection, single sidebar control, and compact View-label contracts. |

## Status

**TPM acceptance: recorded.** VD2-04 remains in progress. VD2-05 remains
blocked/backlog. No product-owner acceptance, dashboard status transition, or
later-card release is implied by this gate.

---

## Task 4 final TPM readiness gate

**Date:** 2026-07-30  
**Role:** Fresh independent TPM  
**Verdict:** **ACCEPT — VD2-04 is ready for renewed product-owner acceptance;
VD2-05 remains blocked.**

### Evidence inspected

| Gate / boundary | Evidence | TPM finding |
| --- | --- | --- |
| Final Board contract | `/private/tmp/rekon-vd204-task4-closed-capture-green.xcresult` | Finalized signed Debug result: 1 passed, 0 failed, 0 skipped for `testVD204PipelineFidelityBoardContract()`. It retains the wide and compact named Board captures. |
| Canonical lane mapping | `/private/tmp/rekon-vd204-task4-closed-capture-mapping-green.xcresult` | Finalized 1/1 mapping proof retains four default primary lanes, `Screening` in the Applied presentation lane with its precise canonical stage, and conditional Closed. |
| Compact Closed evidence | `/private/tmp/rekon-vd204-task4-closed-capture-attachments/E1A86CFA-F8DA-44B7-BF9C-278E29938FF3.png` | The filter-enabled secondary Closed lane and its `Closed opportunity` card are visibly framed in the compact Board viewport, correcting the prior off-screen-evidence defect. |
| Independent review and QA | Fresh post-capture Code Review and QA verdicts supplied with the finalized result and capture evidence | **Accepted.** Both accepted the test-only bounded horizontal viewport proof; neither released product Board/workflow changes. |
| Architecture | `VD2-04-fidelity-task4-final-architect-gate.md` | **Accepted.** The Board remains a reversible presentation projection with no model/store, persistence, route, Import CSV, activity, or stage-mutation deviation. |
| Delivery projection | `dashboard-status.json`; `roadmap.md`; fidelity delivery-release record | The prior capture-repair wording is stale once final technical gates are accepted. The corrected projection must state that owner acceptance, not technical remediation, is now the remaining VD2-04 gate. |

### Scope and dependency decision

Task 4 completes the approved VD2-04 presentation scope: a rich four-primary
Board, filter-controlled fifth Closed lane, exact-stage chips, and the existing
read-only/open route behavior. The Board did **not** gain drag/drop, persisted
stage movement, card relocation, or another workflow mutation. Those remain
strictly outside VD2-04.

The remaining decision is the renewed explicit product-owner visual/workflow
acceptance of the corrected signed Debug product. Therefore:

- `VD2-04` remains `in_progress` / awaiting product-owner acceptance.
- `VD2-05` remains `backlog` and dependency-blocked; it is not eligible for
  planning, implementation, review, or dashboard advancement.
- No successor task becomes eligible from this TPM gate.

### Residual risk and control

The only material residual risk is owner visual/workflow rejection despite the
fresh signed Table/Board evidence. The control is the renewed owner handoff and
explicit acceptance checkpoint; if rejected, corrective work must be planned
under VD2-04 rather than leaking persisted-movement work into VD2-05.
