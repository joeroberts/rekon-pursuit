# VD2-05 Architecture gate — persisted stage movement

**Date:** 2026-07-30  
**Role:** Fresh independent Architect  
**Decision:** **ACCEPTED, with the ADR contract mandatory before Task 1 code is released.**

## Materials reviewed

- [VD2-05 persisted pipeline stage movement brief](../../task-briefs/VD2-05-persisted-pipeline-stage-movement.md)
- [VD2-05 implementation plan](../../../superpowers/plans/2026-07-30-vd205-persisted-pipeline-stage-movement.md)
- Current `WorkspaceStore.changeStage`, `WorkspaceViewModel.changeStage`,
  `refreshCounts`, SQL transaction helper, encrypted-store models, and
  existing stage/audit/reconciliation tests.

## Decision

The plan correctly retains `WorkspaceStore` as the only writer and identifies
the unsafe post-write refresh. It is accepted only with
[ADR-VD2-05-stage-move-transaction](../../architecture/ADR-VD2-05-stage-move-transaction.md)
as the binding Task 1 contract.

In particular, the implementer must use a typed Core outcome plus a
post-transition projection read within the same SQL transaction; map it once
to the public `StageMoveResult`; and apply no further throwing refresh after
a commit. A `.persisted` result therefore means stage, one activity event, one
history row, and the returned Board projection committed together. No-op,
reconciliation-blocked, unavailable, and failed outcomes must leave the Board
source projection in place.

## Required implementation amendments

1. Use the ADR's `stageHistoryForTransition` name rather than a Core
   `selectedStageHistory` field. Selection stays in `WorkspaceViewModel`.
2. Include `opportunities`, `activityEvents`, and `needsAttention` in the
   committed projection, so all cached data affected by a move (including a
   move to Closed) is updated from the same committed read. Derive their
   counts locally.
3. Make same-stage detection precede the Close reconciliation guard; precise
   same-stage requests are no-ops and must not create audit/history evidence.
4. Use private, non-lock-taking queries from inside the existing transaction;
   calling public `opportunities()`, `activityEvents()`, or `needsAttention()`
   there would re-enter the non-recursive workspace lock.
5. Provide distinct, internal, test-only failure points before the first write
   and immediately before projection reads. No launch flag, preference,
   persisted data, or product control may activate either.
6. Add a test that a database/projection exception maps to `.failed`, not
   `.unavailable`, with unchanged model arrays and baseline storage. Add a
   test for a no-op request to an already Closed opportunity if the fixture can
   carry an unconfirmed reconciliation review.

## Architecture boundary confirmation

- No migration/schema/data-field change is needed.
- `WorkspaceViewModel` is the only UI command boundary; the Board receives
  neither a database object nor a second writer.
- Core does not own Board lanes, UI selection, drag payloads, localized status,
  accessibility copy, or filters.
- A later Board interaction task must use only an opportunity-ID payload and
  wait for `.persisted` before relocation.

## Gate effect

Architecture has accepted the bounded transactional contract. This is not an
implementation or product-owner release: QA, TPM, and Delivery must still
independently approve the plan and issue the dependency-safe Task 1 release.
