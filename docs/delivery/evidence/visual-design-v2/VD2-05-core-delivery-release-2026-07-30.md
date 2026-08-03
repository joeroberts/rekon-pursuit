# VD2-05 — Transactional Core + view-model result delivery release

**Date:** 2026-07-30  
**Role:** Fresh independent Delivery Manager  
**Decision:** **Planning gates accepted. Release only the Transactional Core +
view-model result slice.**

## Gate evidence inspected

| Gate | Evidence | Delivery finding |
| --- | --- | --- |
| Planning | `docs/delivery/task-briefs/VD2-05-persisted-pipeline-stage-movement.md`; `docs/superpowers/plans/2026-07-30-vd205-persisted-pipeline-stage-movement.md` | The package gives one shared dependency sequence, test-first contracts, explicit persistence/recovery semantics, and a bounded initial slice. |
| Architecture | `docs/delivery/architecture/ADR-VD2-05-stage-move-transaction.md`; `docs/delivery/evidence/visual-design-v2/VD2-05-architecture-rereview.md` | Accepted the typed Core outcome, in-transaction committed projection, rollback seams, and one VM command boundary. |
| QA/test | `docs/delivery/evidence/visual-design-v2/VD2-05-qa-strategy.md` | Fresh re-review accepted the amended deterministic fixture/failure, atomic projection, accessibility, motion, audit, capture, and retained-regression contracts. |
| TPM | `docs/delivery/evidence/visual-design-v2/VD2-05-tpm-gate.md` | Fresh re-review accepted the named sequence and explicitly withholds Board interaction until this slice has fresh independent acceptance. |
| Predecessor | `docs/delivery/evidence/visual-design-v2/VD2-04-owner-handoff-2026-07-30.md` | VD2-04 has explicit product-owner acceptance, satisfying VD2-05's recorded dependency. |

All five planning gates are now recorded. This is the first implementation
release; it is not acceptance of the slice or of VD2-05.

## Authorized implementation boundary

A **fresh Implementer** may modify only the following files for the named
**Transactional Core + view-model result** slice:

1. `RekonPursuitCore/Workspace/WorkspaceModels.swift` — the approved typed
   `StageMoveStoreOutcome`, `PipelineStageMoveCommit`, and
   `PipelineStageMoveProjection` contracts only.
2. `RekonPursuitCore/Workspace/WorkspaceStore.swift` — one sole-writer,
   typed stage-move command; private in-transaction projection reads; and the
   internal test-only failure dependency specified by ADR-VD2-05.
3. `RekonPursuitCoreTests/WorkspaceStoreTests.swift` — the seven test-first
   Core transaction, rollback-after-reopen, unavailable/no-op/blocked, and
   committed-reopen contracts.
4. `RekonPursuit/WorkspaceViewModel.swift` — `StageMoveResult` and the single
   command mapping/apply path from a committed Core projection.
5. `RekonPursuitTests/WorkspaceViewModelTests.swift` — all five result cases,
   selected-history, count/projection, no-optimism, and thrown-error contracts.

The implementer must establish valid RED evidence before production changes,
then provide signed Debug GREEN bundles. A valid RED fails only because the
new named contract is absent; build, signing, database setup, fixture, cache,
or AX failures are not accepted as RED evidence. The release retains all
accepted VD2-04 presentation behavior.

## Non-authorizations and holds

- `PipelineView.swift`, any Board interaction surface, drag/drop, keyboard
  move control, accessibility/live outcome UI, card relocation, motion,
  filter behavior, Table/inspector, routes, import, navigation, and fixture
  routing are **not** released.
- There is no schema/data/migration, network, cloud, undo, bulk move,
  fabricated data, Contacts, Settings, or VD2-06–08 work.
- The Board may not call the store or alter local card position. It remains
  presentation-only until fresh independent Code Review, QA, Architecture,
  TPM, and Delivery acceptance of this Core + VM slice.
- No owner handoff, dashboard advancement beyond `VD2-05: in_progress`, or
  successor release is implied by this record.

## Required return and next dependency gate

Before Board interaction may be considered, a fresh Implementer must return
the exact transaction/reopen and VM result evidence, including proof that a
successful move yields one committed stage/activity/history transition and
the returned projection; every non-persisted result leaves the in-memory Board
projection and selection unchanged. Fresh Code Review, QA, Architecture, TPM,
and Delivery must accept that result. Security/privacy review remains required
before any VD2-05 owner handoff.

## Delivery state

- `VD2-05` is **In progress** for the Transactional Core + view-model result
  slice only.
- `VD2-06`, `VD2-07`, and `VD2-08` remain **Backlog**.
- `DESIGN-V2` remains **Backlog** until all child cards through VD2-08 receive
  their own independent gates and explicit product-owner acceptance.
