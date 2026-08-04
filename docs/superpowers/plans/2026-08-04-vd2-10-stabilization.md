# VD2-10 Pipeline Stabilization Plan

**Goal:** Reconcile and independently verify the in-progress Pipeline visual-parity branch without broadening its data or routing contracts.

**Baseline:** `3a7e541..c3e8f20` on `vd2-10-pipeline-visual-parity`.

## Reconciled scope

The original brief covered Pipeline controls, Table, and Board presentation. Owner feedback subsequently and explicitly added the Table inspector action model: an ellipsis below the close control exposes stage movement and destructive deletion, while the prior Table right-click menu is removed. These actions must reuse the existing `WorkspaceViewModel` persistence/audit path and the `ContentView` deletion confirmation; no new model, store, schema, network, or Board-delete behavior is authorized.

VD2-10 remains **In progress**. The Board visual-parity slice is not yet complete and must not be represented as accepted.

## Validated repair slices

1. Restore the accepted 1220pt Table/inspector responsive breakpoint, retaining its documented guard band.
2. Route inspector stage-move outcomes through the existing Board-equivalent presentation contract so rejected, unavailable, no-op, reconciliation-blocked, and persistence-failure outcomes are not silent.
3. Remove superseded Pipeline presentation code and reconcile stale UI selectors/tests after right-click deletion was intentionally removed.
4. Add focused UI coverage for search clearing, full view-toggle targets, inspector stage movement and delete confirmation, wide/compact selection, and compact drawer dismissal. Reuse existing ViewModel tests for persistence/audit outcome coverage.
5. Complete or explicitly defer the remaining Board visual-parity slice only through a separately recorded owner decision; do not silently redefine completion.

## Execution and review order

1. Fresh implementer writes failing focused tests for a repair slice, performs the minimum implementation, then runs that slice.
2. Separate code reviewer and QA verifier inspect the slice; architect rechecks contract effects; security/privacy verifier inspects the stage/delete action path.
3. Record evidence in the delivery ledger, then run the scoped UI/model suite, macOS build, coverage collection, and wide/compact visual review.
4. If the same repair cannot be completed in three attempts, file a GitHub issue, record the deferral, and continue unless it blocks the Pipeline contract.

## Acceptance conditions

- Empty search shows only the magnifier; typing hides it, the clear control clears the binding, and the table restores.
- Table/Board view controls respond across their complete visible button targets.
- Desktop honors the accepted 1220pt policy; compact inspector overlays above the table and dismisses smoothly, including reduced-motion behavior.
- Inspector has close then ellipsis vertically, changes stages only through the existing persisted/audited transaction path, and deletion reaches the existing confirmation before mutation.
- No Table context menu or obsolete `pipeline-delete-*` contract remains.
- No unrelated persistence, schema, routing, Board action, or untracked profiler artifact enters the delivery.
