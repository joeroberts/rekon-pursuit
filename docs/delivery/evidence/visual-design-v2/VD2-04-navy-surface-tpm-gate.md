# VD2-04 navy-surface correction — TPM Task 0 gate

**Date:** 2026-07-30  
**Role:** Independent TPM  
**Verdict:** **Scope approved; Task 1 conditionally eligible after the remaining Task 0 gates are recorded.**

## Decision basis

I reviewed the owner-approved [navy-surface design](../../../superpowers/specs/2026-07-30-vd204-pipeline-navy-surface-correction-design.md), the [Task 0–4 brief](../../task-briefs/VD2-04-pipeline-navy-surface-correction.md), the corresponding [implementation plan](../../../superpowers/plans/2026-07-30-vd204-pipeline-navy-surface-correction.md), the Visual Design v2 roadmap, the delivery dashboard, and the existing VD2-04 handoff record.

The dashboard correctly records `VD2-04` as `in_progress` and `VD2-05` as `backlog` with `VD2-04` as its sole dependency. `VD2-02` and `VD2-03`, the only recorded prerequisites for VD2-04, are accepted. The corrective work therefore belongs to the existing VD2-04 card; it is not a release of VD2-05 or a new Board-workflow card.

## Scope boundary confirmed

The release is limited to visual presentation of the existing Pipeline in both Table and Board:

- replace generic neutral-gray Pipeline control/content surfaces with the existing layered navy tiers and semantic cyan/violet outlines;
- retain `Add opportunity` as the only gradient primary action and make Import CSV a visibly interactive outlined secondary action;
- preserve the current right drawer, no-radio row selection, nonwrapping/omitted compact View label, and app-owned single sidebar action;
- preserve the existing IDs, roles, labels, keyboard operation, data, import behavior, routing, activity/audit evidence, persistence, Board columns, and Board drag/drop behavior.

This gate does **not** authorize changes to Board stage movement, card placement, opportunity models/stores, navigation, import semantics, or any VD2-05+ work.

## Dependencies and release condition

The prior VD2-04 corrective contracts are implementation dependencies and must remain green. The specific prerequisite for Task 1 is completion of all independent Task 0 gates:

1. Architect records a control-rendering decision that can eliminate native gray overlay without losing the required control semantics, identifiers, or keyboard activation; an ADR is required for any deviation.
2. QA records the red-first, signed-Debug visual-evidence protocol: wide/compact Table and Board captures plus an explicit manual rejection criterion for gray chrome.
3. Delivery Manager records the correction in the durable ledger/dashboard and releases Task 1 only after the architect, QA, and TPM gates are present.

**TPM release ruling:** From sequencing and scope-control perspectives, Task 1 is eligible *only once* items 1–3 are recorded. This record alone does not open implementation. No product-owner response is needed during the corrective implementation; renewed owner visual/workflow acceptance is required only after the independent implementation gates complete.

## Risks and required controls

| Risk | Required control |
| --- | --- |
| Custom chrome could break native accessibility or keyboard activation. | Architect-approved seam, red semantic-operation tests, and retained stable IDs/roles. |
| A test pass could mask remaining gray rendered chrome. | Four signed-product attachments and independent manual visual QA against the supplied references. |
| Restyling shared Pipeline components could alter Board workflow. | Limit source boundary to presentation primitives and Pipeline views; code review rejects any data, drag/drop, routing, import, persistence, or activity change. |
| Earlier VD2-04 green results might be mistaken for current acceptance. | Treat them as historical only; require fresh code review, QA, architecture, TPM, security/privacy, delivery, and owner gates. |
| Delivery sequencing could prematurely open Board persistence work. | Keep `VD2-05` backlog/blocked until VD2-04 is accepted after renewed owner acceptance. |

## Status

`VD2-04` remains **in progress**. `VD2-05` remains **blocked/backlog and not eligible**. No dashboard transition or owner-action flag is authorized by this TPM gate.
