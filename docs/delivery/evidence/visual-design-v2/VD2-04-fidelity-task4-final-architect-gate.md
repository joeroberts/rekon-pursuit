# VD2-04 Task 4 — final architecture gate

**Date:** 2026-07-30  
**Role:** Independent Architect  
**Decision:** **Accepted — Task 4 architecture final gate.**

## Evidence inspected

| Surface | Evidence | Finding |
| --- | --- | --- |
| Presentation projection | `RekonPursuit/PipelineView.swift:5-30` | `PipelineBoardLane` is module-internal, pure, and view-local. It maps `Saved` to Saved; `Applied` and `Screening` to Applied; `Interviewing` to Interviewing; `Offer` to Offer; and `Closed` to Closed. `displayedLanes(includesClosed:)` exposes exactly the four primary lanes by default and appends only the conditional secondary Closed lane. |
| Canonical state | `RekonPursuitCore/Workspace/WorkspaceModels.swift:203-235,576-583`; `RekonPursuit/WorkspaceViewModel.swift:631-651` | `Opportunity.stage` and the six canonical `PipelineStage` values are unchanged. The existing filter still controls Closed visibility. Board rendering reads `visibleOpportunities`; it does not write a stage or create a Board-specific copy of opportunity state. |
| Board composition and navigation | `RekonPursuit/PipelineView.swift:253-330,630-721` | The Board consumes the approved projection, preserves the existing `open(opportunity)` and `anchorID` path, retains all lane count/add affordances, and presents exact stage chips on the cards. Search found no drag/drop, `onDrop`, `onDrag`, or stage-mutation path in the Board surface. |
| Mapping executable coverage | `RekonPursuitTests/RekonPursuitTests.swift:8-26`; `/tmp/rekon-vd204-pipeline-fidelity-mapping-green-retry.xcresult` | The direct production seam—not a test-only oracle—covers the precise Screening-to-Applied presentation mapping and default/Include-closed lane sequences. |
| Signed visual evidence | `/private/tmp/rekon-vd204-task4-closed-capture-attachments/8C53C6B0-6354-4179-BFE5-C7416D6E0523.png`; `/private/tmp/rekon-vd204-task4-closed-capture-attachments/E1A86CFA-F8DA-44B7-BF9C-278E29938FF3.png` | The wide capture shows exactly four primary lanes, with the `Product Designer` record visibly in Applied and retaining its `Screening` chip, company, locality, next action, and due date. The compact capture shows the enabled secondary Closed lane and its `Closed opportunity` card visibly framed in the Board viewport. |
| Focused Board result | `/private/tmp/rekon-vd204-task4-closed-capture-green.xcresult` | Finalized `Passed`: 1 passed, 0 failed, 0 skipped. The result identifies `testVD204PipelineFidelityBoardContract()` and retains both named Board attachments. The isolated Debug host at `/private/tmp/rekon-vd204-task4-closed-capture-green-derived/Build/Products/Debug/RekonPursuitUITestHost.app` verifies as Apple Development signed; signing was not disabled. |
| Mapping executable coverage, post-repair | `/private/tmp/rekon-vd204-task4-closed-capture-mapping-green.xcresult` | Finalized `Passed`: 1 passed, 0 failed, 0 skipped for `testVD204PipelineBoardLaneMappingRetainsPreciseStages()`, retaining the direct production-seam proof of four default lanes, filter-enabled Closed, and Screening-in-Applied mapping. |

## Architecture decision

The implemented Board remains within the accepted ADR:

- Lane grouping is a reversible presentation projection, not a persisted-stage change.
- `Screening` retains its exact stage on the rendered card and uses the existing open route.
- Closed is governed solely by the existing Include closed control.
- No drag/drop, card relocation, workflow mutation, persistence, routing, import, activity, or model/store boundary has been introduced.

Accordingly, **no deviation ADR is required**. The Board architecture is accepted as conforming to `ADR-VD2-04-pipeline-fidelity-lane-mapping.md`.

## Final architecture acceptance

The post-repair contract performs the required bounded horizontal viewport movement only after Include closed changes from `0` to `1`; it asserts that both the Closed lane and its known Closed card have non-zero, Board- and window-contained frames before recording the compact attachment. The same test retains default Closed absence, four default primary-lane assertions, the global atomic Screening-card identity, and live Applied-lane containment. No production source changed for this capture repair.

Therefore the Board remains within the accepted ADR and the previously held architecture evidence condition is satisfied. **Task 4's architecture final gate is accepted.** No deviation ADR is required.

This decision is limited to the architecture gate. `VD2-04` remains in progress until the remaining independent gates, delivery recording, and product-owner acceptance are complete; `VD2-05` remains dependency-blocked.
