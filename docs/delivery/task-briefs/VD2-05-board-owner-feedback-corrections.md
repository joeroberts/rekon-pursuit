# VD2-05 — Board owner-feedback corrections

## Outcome

Before the next product-owner preview, make Applied and Screening exact separate Board lanes/drop targets; make Add Opportunity Cancel/Escape discard its transient draft and return to the same Board context with zero writes; and replace card stage pill/full-width move controls with one compact ellipsis actions menu.

The terminal result is a signed Debug manual-first preview. This brief does not authorize broad regression, delivery evidence/status/dashboard/roadmap updates, or final VD2-05 acceptance.

## Controlling inputs and sequence

- Approved design: `docs/superpowers/specs/2026-07-31-vd205-board-owner-feedback-corrections-design.md`.
- Implementation plan: `docs/superpowers/plans/2026-07-31-vd205-board-owner-feedback-corrections.md`.
- Retained VD2-05 stage-movement plan/brief: `2026-07-30-vd205-persisted-pipeline-stage-movement.md` and `VD2-05-persisted-pipeline-stage-movement.md`.
- Gate sequence: Architecture/QA/TPM/Delivery boundary approval → pure contracts → independent review/QA → Board actions → independent review/QA → signed UI/manual preview → owner stop.

## Fixed contracts

`PipelineBoardLane` is one-to-one: Saved, Applied, Screening, Interviewing, Offer, Closed. Default Board shows the first five and shows Closed only for Include closed. Each lane accepts only `lane.stage`; drag/menu movement continues through the existing `PipelineStageMoveRequest(opportunityID:target:)` and `WorkspaceViewModel.changeStage(_:to:)` transaction boundary.

`ContentView` owns only transient context above the Add route:

```swift
struct PipelineBoardReturnContext: Equatable {
  var query: String
  var stageFilter: String
  var includesClosed: Bool
  var selectedOrAnchoredOpportunityID: String?
  var horizontalScrollLane: PipelineBoardLane?
}
```

Capture it only for Board → Add. Shared Cancel/Escape clears Add draft/error, restores the context/Board immediately, and performs no workspace/refresh/activity/history/task write or confirmation. Successful save remains unchanged.

The one card control is `pipeline-card-actions-<id>`, labelled and tooltiped `Actions for <title>`. Its two top-level items are exactly `Edit opportunity` and `Move to stage…`; Move owns canonical Saved/Applied/Screening/Interviewing/Offer/Closed and exposes current stage/no-op behavior. Card body and Edit both invoke existing details. Stage pill, full-width move control, Delete, and destructive card menu actions are absent. Shift-Command-M focuses first actions control.

## Path authority

| Writable | Purpose |
| --- | --- |
| `PipelineView.swift`, `PipelineBoardView.swift`, `ContentView.swift` | Presentation, route context, exact lanes/targets/actions |
| `WorkspaceViewModel.swift` | Only the no-store `discardNewOpportunityDraft()` reset; no other view-model behavior |
| `RekonPursuitTests.swift`, `RekonPursuitUITests.swift` | Pure and signed proof |

Core/store/models/Core tests/VM tests/AppShell/project/visual theme/test host/dashboard/roadmap/evidence/status are read-only. Any need to modify one is a stop/escalation, not implicit authority.

## Required proof

- Pure selectors: `testVD205PipelineBoardLaneMappingIsOneToOneAndCanonical`, `testDiscardNewOpportunityDraftClearsOnlyTransientAddFieldsAndError`, `testPersistedResultUsesExactStageChipAndBoardLane`, `testVD205CardActionsContainOnlyEditAndCanonicalMoveSubmenu`.
- Signed UI selectors: `testVD205BoardRendersExactAppliedAndScreeningLanesAndDropTargets`, `testVD205BoardActionsMenuEditsAndMovesWithoutStageChipOrFullWidthMoveControl`, `testVD205BoardCancelReturnsToBoardWithDraftDiscardedAndNoWrites`, `testVD205BoardEscapeCancelsToSameBoardContextWithoutWrites`.
- Retain existing no-op/blocked/unavailable/failed/invalid, closed-filter, history, and Reduce Motion selectors, retargeting only old move-control identifiers.
- Every RED fails solely for absent named behavior. GREEN uses unique signed Debug DerivedData/result bundles, signature verification, result summary/detail inspection, and `git diff --check`.

## Manual-first stop

Inspect signed wide and compact preview for readable horizontal five-lane Board, distinct Applied/Screening headings/counts/drop zones, actions/card-body routes, Cancel/Escape context restoration, and Reduce Motion focus/outcome. Stop after owner preview handoff.
