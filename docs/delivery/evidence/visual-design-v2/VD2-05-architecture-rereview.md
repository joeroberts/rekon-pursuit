# VD2-05 Architecture re-review — amended persisted stage movement contract

**Date:** 2026-07-30  
**Role:** Fresh independent Architect  
**Decision:** **ACCEPT — authorize only the named Transactional Core + view-model result slice after the remaining independent QA, TPM, and Delivery gates accept.**

## Materials re-reviewed

- `docs/delivery/architecture/ADR-VD2-05-stage-move-transaction.md`
- `docs/delivery/task-briefs/VD2-05-persisted-pipeline-stage-movement.md`
- `docs/superpowers/plans/2026-07-30-vd205-persisted-pipeline-stage-movement.md`
- Current `WorkspaceStore.changeStage`, `WorkspaceViewModel.changeStage`, and
  `EncryptedDatabase.transaction` implementation.

## Resolution of the prior architecture requirements

| Required property | Amended binding contract | Architecture finding |
| --- | --- | --- |
| Truthful typed outcome and projection | `StageMoveStoreOutcome` carries a `PipelineStageMoveCommit` with opportunities, activity events, attention tasks, and transition history. `StageMoveResult.persisted` can originate only from that outcome. | Satisfied. Core remains presentation-agnostic; selected history stays in the view model. |
| One rollback boundary | Availability, exact current stage, no-op precedence, and real-Close guard precede one existing `BEGIN IMMEDIATE` transaction. The stage, one activity event, one history row, and private committed reads occur within it. | Satisfied. The current transaction helper rolls back on a body or `COMMIT` error, so no commit result may be formed on either failure. |
| Same-stage/no-op precedence | Precise same-stage detection is explicitly before the Close reconciliation guard, including a request to an already Closed opportunity. | Satisfied. It prevents audit/history writes and prevents a stale reconciliation guard from converting a no-op into a block. |
| Error and outcome mapping | Missing/inactive maps to `.unavailable`; a real blocked Close maps to `.reconciliationBlocked`; any read/write/projection/commit exception maps to `.failed`; no error crosses the view-model command boundary. | Satisfied. The explicit distinction prevents a post-commit reader failure from being falsely reported as an unavailable item. |
| Projection application | The view model replaces only the three returned published arrays, derives counts from them, conditionally replaces selected history by matching ID, and performs no post-commit `refreshCounts()` or other throwing read. | Satisfied. A non-persisted outcome leaves Board projection and selection unchanged; there is no optimistic relocation path. |
| Test-only failure seam | Fixed `beforeWrite` and `beforeProjectionRead` points execute inside the transaction. The production default is `nil`; test-host scenarios are sealed enum cases and fixed dependencies, not arbitrary launch data. | Satisfied, with the host-boundary requirement below. |

## Host-boundary confirmation

The project compiles the app sources, including `WorkspaceStore.swift` and
`RekonVisualTheme.swift`, into the dedicated `RekonPursuitUITestHost` target
with `REKON_UI_TEST_HOST`; the ordinary product target does not set that
condition. Thus the host-only factory may construct the fixed injected store
dependency without exposing an input surface in the shipping product. The
implementation must keep both the fixture routing and any access used solely
for it within that compile-time condition. It must not add a normal-product
launch argument, preference, persisted setting, public free-form factory, or
second stage writer.

## Implementation invariants released with this decision

1. `WorkspaceStore` is the sole stage writer; the Board calls only the
   view-model command and moves no card locally before `.persisted`.
2. Private query helpers, rather than synchronized public readers, are used
   while the store lock and SQL transaction are held.
3. A projection-read failure is injected before `COMMIT`; tests compare the
   exact encrypted-store baseline after close/reopen, not only an in-memory
   model.
4. The Core projection contains only persistence data. Board groups, filters,
   drag payloads, selection, accessibility text, and localized result copy
   remain outside Core.
5. The first implementation release is **Transactional Core + view-model
   result** only. Board interaction stays blocked until that slice receives
   fresh review and QA acceptance.

## Gate scope

This decision accepts the amended architectural contract, not implementation,
Board interaction, a dashboard transition, or product-owner acceptance. The
remaining independent QA, TPM, and Delivery gates retain their authority to
withhold the Core slice. VD2-06 through VD2-08 remain out of scope.
