# VD2-05 — Board owner-feedback corrections

## Outcome and hold

Deliver separate Applied/Screening lanes and exact drops, origin-correct Add Cancel/Escape with zero writes, and one compact two-action card menu. Source/test implementation is held until a successor ADR and fresh Architecture, QA, TPM, and Delivery gates accept the corrected package. The signed Debug owner preview is the stop; no broad regression, final gates, dashboard/roadmap/evidence/status change, or later release occurs before owner approval.

## Prerequisite sequence

1. Architect creates `docs/delivery/architecture/ADR-VD2-05-board-owner-feedback-lane-projection.md`, superseding only VD2-04 grouped-lane/inert-drop clauses while preserving Table/right drawer and unrelated contracts.
2. Architecture, QA, and TPM re-review the ADR plus corrected plan/brief.
3. Delivery reconciles the already-held Board repair and may release Task 2 only after all three accept.
4. Pure origin/lane/reset slice → independent review/QA → Board/menu slice → independent review/QA → signed UI/manual preview → owner stop.

This revision does not edit the ADR, spec, source, or tests.

## Binding presentation contracts

`PipelineBoardLane` is Hashable and one-to-one in canonical order. `dropTarget` is exactly `stage`; production delegates consume it. Default lanes are Saved, Applied, Screening, Interviewing, Offer; Include closed appends Closed. Screening never maps/drops through Applied.

`ContentView` owns live query, stage filter, Include closed, Board/Table mode, anchor, horizontal lane, and:

```swift
enum AddOpportunityOrigin: Equatable {
  case home
  case pipelineTable
  case pipelineBoard(PipelineBoardReturnContext)
}
```

Every Add entry synchronously replaces the token. Home Cancel/Escape returns Home; Table returns Pipeline/Table; Board restores its exact context then returns Pipeline/Board. Both invocations share one callback and clear the token after applying values. Non-cancel departure clears stale origin. Successful save does not consume/reinterpret origin.

A non-nil restored horizontal lane wins over an anchor-derived lane; only nil horizontal state derives from anchor. Anchor remains for card/lane-local vertical restoration. Board AX value is `Horizontal lane: <title>`; anchored card value is `Anchored`.

`discardNewOpportunityDraft()` resets all Add text, stage, compensation/pay period, location/work arrangement, application/response/stage dates, response/action fields, due-date fields/toggles, and `addOpportunitySaveError` to new-form defaults. It changes no store/projection/count/selection/readiness/status and calls no store/refresh path.

Production menu builder consumes one tested `PipelineCardActionsConfiguration.canonical`: exactly Edit opportunity and Move to stage…, with canonical six-stage submenu/current state. `pipeline-card-actions-<id>` is top-right, menu-button role, labelled/tooltipped `Actions for <title>`, focusable, and sufficient hit size. Card body/Edit use existing details; Move uses existing typed request/sole writer. Stage pill/full-width move/destructive items are absent.

## Authority

After re-gates, writable paths are only `PipelineView.swift`, `PipelineBoardView.swift`, `ContentView.swift`, `WorkspaceViewModel.swift` for pure reset, `RekonPursuitTests.swift`, and `RekonPursuitUITests.swift`.

Core/store/schema/migrations/Core tests/VM tests, project/scheme, `AppShellView.swift`, theme, test host/fixtures, dashboard, roadmap, evidence, and status are read-only. Any need outside the writable set stops and re-gates.

## Executable acceptance

Pure signed selectors cover one-to-one `stage/dropTarget`, all three Add origins/exact context, exhaustive write-free reset, Applied/Screening presentation, horizontal-over-anchor precedence, and the production-consumed menu builder. Unit RED/GREEN commands must include the origin/context selector. The discard test sets title/company plus malformed URL, snapshots store/projections, explicitly calls `createOpportunity()`, and relies on the pre-store validation proved by `WorkspaceViewModelTests.testInvalidJobURLShowsAddOpportunitySaveErrorWithoutWriting` to require a non-nil `addOpportunitySaveError` with unchanged store/activity. It then snapshots the validation `statusMessage`, discards, and proves the save error/draft clear while that status and every persisted/projection value remain unchanged.

Signed lane proof asserts all five default/count IDs, conditional Closed, Senior Product Manager only in Applied, Product Designer only in Screening, and separate fresh-session native Saved → Applied/Screening moves with exact outcome, containment, relaunch, and +1 subject activity/history.

Signed actions proof establishes the rendered card/button before absence assertions; checks role, label, hover tooltip, keyboard focus, top-right frame, ordered two-item menu, ordered six-stage submenu/current state, and independent card-body/Edit routing.

Cancel and Escape each assert the same exact search/filter/closed/anchor/Offer-scroll restoration; computed `jobURLWarning` at `add-opportunity-url-warning` before and absence after; cleared next-action/due-date draft; and equal before/after-relaunch Board count, subject history/activity, Home attention-card count, and active-opportunity metric. Neither signed UI test clicks Save or treats that derived warning as `addOpportunitySaveError`. Cancel clicks the enabled control; Escape sends Escape while it remains enabled.

Retain, with only identifier retargeting: keyboard move, exact menu/current state, no-op/blocked/unavailable/write/projection/invalid/cancelled/outside source retention, Closed locality, exactly-one relaunch transition, and Reduce Motion focus/text selectors.

## Manual-first stop

After focused signed GREEN and the six-selector retained matrix pass with signatures and `git diff --check`, inspect wide/compact behavior including Home/Table/Board destinations and Offer-over-Screening scroll precedence. Hand the signed preview to the owner and stop.
