# VD2-04 navy-surface correction — Task 1 independent code review

**Date:** 2026-07-30  
**Role:** Fresh independent Code Reviewer  
**Scope:** Task 1 only — the two RED-contract additions in
`RekonPursuitTests/RekonPursuitTests.swift` and
`RekonPursuitUITests/RekonPursuitUITests.swift`. This is not a review of the
future AppKit/SwiftUI implementation, visual acceptance, or the accumulated
shared-worktree diff identified by the baseline attestation.

## Verdict: accepted as a RED-contract gate

Task 1 is accepted **only** as a test-first handoff to Task 2. It is not a
green verification result and must not be used to claim that gray Pipeline
chrome has been corrected.

## Evidence reviewed

| Evidence | Review finding |
| --- | --- |
| `docs/delivery/task-briefs/VD2-04-pipeline-navy-surface-correction.md`, Task 1 | The two reviewed methods implement the required presentation mapping and wide/compact Table/Board semantic-operation plus pre-import-capture contract. No source, data, routing, persistence, Board-workflow, import, or delivery-dashboard change is included. |
| `docs/superpowers/plans/2026-07-30-vd204-pipeline-navy-surface-correction.md`, Task 1 | The unit method asserts idle, hover, keyboard-focus, selected, pressed, and disabled semantic mapping. The UI method exercises all five retained controls, records four named pre-import captures, and returns to Table. |
| `docs/delivery/architecture/ADR-VD2-04-pipeline-navy-control-seam.md` | The selected assertions agree with the ADR: selected uses `elevatedSurface`/`accent`/1 pt/1.00; keyboard focus uses `violet`/2 pt; pressed and disabled use 0.62 and 0.42 opacity. The UI assertions retain the specified native projections: editable field, popup button, checkbox, exclusive radio group, and button. |
| `RekonPursuitTests/RekonPursuitTests.swift:137-156` | `testVD204PipelineNavySurfacePresentationContract` is a precise pure-contract seam. It is intentionally uncompilable before Task 2 supplies `PipelineNavySurfacePresentation`; it introduces no production implementation or broad appearance workaround. |
| `RekonPursuitUITests/RekonPursuitUITests.swift:431-568` | `testVD204PipelineNavySurfaceControlsRemainSemanticallyOperableInTableAndBoard` covers wide and 860x640 compact fixtures, normal activation of Search, Stage, Include closed, view mode, and Import CSV, and names four captures before file-choice presentation. It retains actual role/label/ID assertions rather than accepting a decorative wrapper. |
| `docs/delivery/evidence/visual-design-v2/VD2-04-navy-task1-baseline-attestation.md` | The reviewer treated only the two named methods as the Task 1 delta. The historic 1,137-addition/387-deletion shared diff is expressly outside this review and was neither reset nor changed. |
| `/tmp/rekon-vd204-navy-surface-task1-final-red.xcresult` | The signed-Debug build is cancelled because `PipelineNavySurfacePresentation` is absent at `RekonPursuitTests.swift:137-155`; the companion contextual-member diagnostics follow from that one missing type. There is no unrelated fixture, signing, UI interaction, or product-runtime failure in the bundle. This is the expected red condition for Task 1. |

## Deferred green verification

Task 2 must introduce the ADR-approved nonisolated semantic presentation seam
and rerun the unit contract green. Task 3 must then apply the actual
Pipeline-local native-control renderer and rerun the UI method in a signed
Debug product run, preserving its four attachments. Only after the retained
VD2-04 regression suite, visual QA against the owner references, architecture,
TPM, security/privacy, and delivery gates are complete can VD2-04 return for
product-owner acceptance.

No source or test file was edited by this review.
