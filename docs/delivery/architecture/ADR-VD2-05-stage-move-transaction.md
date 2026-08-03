# ADR-VD2-05 — Atomic persisted stage-move projection

**Date:** 2026-07-30  
**Status:** Accepted for VD2-05 Task 1 implementation release  
**Decision owner:** Independent Architecture

## Context

`WorkspaceStore.changeStage(opportunityID:to:)` currently performs the
opportunity-stage, activity-event, and stage-history writes in one SQL
transaction. `WorkspaceViewModel.changeStage(_:to:)` then invokes the broad
`refreshCounts()` reader. That reader performs many independent reads. It can
fail after the mutation has committed, which would report an unsuccessful
Board move even though the local stage and audit trail changed. It also makes
an optimistic in-memory card relocation tempting.

VD2-05 requires a Board card to relocate only from a confirmed local
projection and requires every reported failure to leave the persisted
stage/activity/history at its command baseline.

## Decision

### Single Core command and outcome seam

`WorkspaceStore` remains the sole stage writer. Replace the UI-facing use of
the `Void` stage command with one Core-owned command whose return has these
semantics:

```swift
enum StageMoveStoreOutcome: Equatable {
    case persisted(PipelineStageMoveCommit)
    case noOp(opportunityID: String, stage: PipelineStage)
    case reconciliationBlocked(opportunityID: String, target: PipelineStage)
    case unavailable(opportunityID: String)
}

struct PipelineStageMoveCommit: Equatable {
    let opportunityID: String
    let from: PipelineStage
    let to: PipelineStage
    let projection: PipelineStageMoveProjection
}

struct PipelineStageMoveProjection: Equatable {
    let opportunities: [Opportunity]
    let activityEvents: [ActivityEvent]
    let needsAttention: [TaskReminder]
    let stageHistoryForTransition: [StageHistoryEntry]
}
```

Spelling may vary only where Swift module access requires it; the ownership,
data, and semantics above are mandatory. `selectedStageHistory` is expressly
not a Core projection field: selection is a UI concern. The projection carries
the transition record's history, which the view model applies only when its
currently selected opportunity has the same ID.

`WorkspaceViewModel` owns a non-localized `StageMoveResult` with the approved
five cases. It maps `StageMoveStoreOutcome` without exposing errors. The only
`StageMoveResult.persisted` path is a `.persisted` Core outcome. A missing
ready store maps to `.unavailable`; a store/database/projection exception maps
to `.failed`.

### Transaction boundary

Under the existing workspace lock, the Core command must:

1. verify that the ID refers to an active record;
2. read the current precise stage;
3. return `.noOp` before the Close guard when that stage already equals the
   target;
4. apply the existing unconfirmed-reconciliation guard only for a real
   transition to `Closed`, returning `.reconciliationBlocked`;
5. inside one `BEGIN IMMEDIATE` transaction, write the opportunity stage,
   exactly one `opportunity_stage_changed` event, and exactly one history row;
6. before `COMMIT`, query the four projection fields above using private query
   helpers (never public lock-taking store readers); and
7. return the commit object only after the transaction call has successfully
   committed.

The existing database transaction API need not be made generic. A local
non-optional projection captured inside its transaction closure is permitted
only after that closure returns successfully; a `COMMIT` error must still
throw and must not produce a `.persisted` outcome.

This establishes a small, truthful Board/UI cache update. The view model
derives `opportunityCount`, `activityCount`, and `needsAttentionCount` from
the returned arrays; replaces those published arrays; updates the selected
opportunity's displayed stage from the returned opportunity; and conditionally
replaces selected stage history. It must not call `refreshCounts()`,
`loadSelectedOpportunity()`, or any other throwing store reader after a
committed stage transition. Unaffected cached detail remains unchanged.

### Failure and recovery semantics

The Core method throws only for failed reads/writes/transaction completion;
the view model maps that to `.failed` and does not alter its current Board
projection. Because the pre-commit projection query is inside the SQL
transaction, its failure triggers rollback of all three writes. No work that
can throw is allowed between successful commit and construction/application of
the persisted result.

The ordering above intentionally makes a same-stage target `.noOp`, including
when the target is `Closed`; it writes neither audit nor history. A missing,
deleted, or inactive ID is `.unavailable`. Database corruption or any other
store error is `.failed`, not `.unavailable`.

### Test-only failure injection

Use an internal Core test dependency, e.g.
`StageMoveFailurePoint.beforeWrite` and
`StageMoveFailurePoint.beforeProjectionRead`, supplied only through an
`@testable` initializer/constructor parameter that defaults to `nil` in the
live store. It must be consulted inside the same SQL transaction. It may not
be wired to launch arguments, defaults, persisted workspace data, a UI
control, or a production route. Existing unrelated `failBeforeActivityInsert`
does not substitute for the projection-read seam.

## Consequences

- The Board never moves a card optimistically. It renders the returned
  `opportunities` projection only after `.persisted`.
- A successful move updates the cached activity and attention data consistently
  with the same committed database snapshot, including a close that removes a
  task from the attention projection.
- The Core layer does not learn UI selection, Board lane grouping, filter
  state, drag payloads, accessibility strings, or presentation status.
- VD2-05 Task 2 tests must prove no-op precedence, the exact no-write baseline
  for unavailable/blocked/failure, and rollback on the injected
  pre-projection-read failure. They must also prove a committed projection has
  the stage/history/event together before the view model presents success.

## Rejected alternatives

- **Write, then call `refreshCounts()`:** can report failure after commit.
- **Optimistically mutate a card and retry a reader:** can show an uncommitted
  or failed move as successful.
- **Separate stage/activity/history writers:** breaks single-writer audit
  atomicity.
- **Return a UI-selected-history field from Core:** couples persistence to a
  presentation-only selection.
