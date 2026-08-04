# VD2-10 Pipeline Stabilization Plan

**Goal:** Reconcile and independently verify the in-progress Pipeline visual-parity branch without broadening its data or routing contracts.

**Baseline:** `3a7e541..c3e8f20` on `vd2-10-pipeline-visual-parity`.

## Reconciled scope

The original brief covered Pipeline controls, Table, and Board presentation. Owner feedback subsequently and explicitly added the Table inspector action model: an ellipsis below the close control exposes stage movement and destructive deletion, while the prior Table right-click menu is removed. These actions must reuse the existing `WorkspaceViewModel` persistence/audit path and the `ContentView` deletion confirmation; no new model, store, schema, network, or Board-delete behavior is authorized.

VD2-10 remains **In progress** pending owner acceptance. The Pipeline Table and
Board visual-parity work is implemented and covered by targeted checks, but it
must not be represented as accepted until the owner completes the visual and
workflow comparison.

## Validated repair slices

1. Restore the accepted 1220pt Table/inspector responsive breakpoint, retaining its documented guard band.
2. Route inspector stage-move outcomes through the existing Board-equivalent presentation contract so rejected, unavailable, no-op, reconciliation-blocked, and persistence-failure outcomes are not silent.
3. Remove superseded Pipeline presentation code and reconcile stale UI selectors/tests after right-click deletion was intentionally removed.
4. Add focused UI coverage for search clearing, full view-toggle targets, inspector stage movement and delete confirmation, wide/compact selection, and compact drawer dismissal. Reuse existing ViewModel tests for persistence/audit outcome coverage.
5. Complete or explicitly defer the remaining Board visual-parity slice only through a separately recorded owner decision; do not silently redefine completion.

### Final-review repair amendment

The final independent review added two serial, bounded repairs before the
verification gate. They do not change model, store, routing, audit, filtering,
or Board workflow behavior.

1. **Filtered Table move notice.** Write a failing unit test for a pure
   `PipelineTableInspectorStageMovePresentation` resolver, then add a Pipeline-level live
   outcome notice outside both the inspector and the empty-state branch. It
   appears only when a persisted inspector stage move leaves the selected
   record outside the real post-action Table projection. It must preserve the
   existing selection-clearing/filter behavior, cover every filter that can
   hide the record, and retain the inspector-local result when the record
   remains visible.
2. **Native Table/Board owner.** Write a failing unit test for the native
   owner, then restore the ADR-required Pipeline-local
   `NSSegmentedControl` representable as the sole Table/Board input,
   accessibility, keyboard, and action owner. Remove the SwiftUI button
   proxy. The control keeps the existing navy renderer, 44pt visible target,
   `pipeline-view-mode` group, and Table/Board radio descendants. Add a
   focused UI regression that taps the non-text portion of each full segment
   in wide and compact fixtures.

The second repair restores the accepted ADR rather than amending it. The
inspector-ellipsis automation limitation remains deferred in GitHub issue
#24; this repair must not make a fourth attempt to change that accessibility
containment.

### Final visual-repair amendment

Manual macOS review found that the Pipeline row still received AppKit's opaque
blue `NSTableView` selection fill, masking the intentionally subdued SwiftUI
highlight. The original selection owner can be mounted by SwiftUI as a
background sibling before the List finishes constructing its native table.

Write a failing sibling-mount test, then resolve the table first from an
enclosing scroll view and, only if necessary, from the nearest ancestor with
exactly one table descendant. Retry this bounded discovery during layout so it
can observe SwiftUI's completed List hierarchy. Preserve the existing
replacement/restoration ownership guard; ambiguous multi-table containers must
remain untouched. This is a visual-only native bridge repair: no model, store,
routing, audit, filter, or Board behavior may change.

## Execution and review order

1. Fresh implementer writes failing focused tests for a repair slice, performs the minimum implementation, then runs that slice.
2. Separate code reviewer and QA verifier inspect the slice; architect rechecks contract effects; security/privacy verifier inspects the stage/delete action path.
3. Record evidence in the delivery ledger, then run the scoped UI/model suite, macOS build, coverage collection, and wide/compact visual review.
4. If the same repair cannot be completed in three attempts, file a GitHub issue, record the deferral, and continue unless it blocks the Pipeline contract.

For the final-review amendment, release the filtered Table notice first,
review it independently, then restore the shared view-mode owner. The tasks
share Pipeline presentation files and must not be implemented in parallel.

## Acceptance conditions

- Empty search shows only the magnifier; typing hides it, the clear control clears the binding, and the table restores.
- Table/Board view controls respond across their complete visible button targets.
- Desktop honors the accepted 1220pt policy; compact inspector overlays above the table and dismisses smoothly, including reduced-motion behavior.
- Inspector has close then ellipsis vertically, changes stages only through the existing persisted/audited transaction path, and deletion reaches the existing confirmation before mutation.
- A persisted inspector stage move that filters its selected record from
  Table leaves a visible Pipeline-level live outcome; no-op, unavailable,
  rejected, and failed outcomes remain visible in the selected inspector.
- Table/Board is one native, navy-rendered exclusive segmented control whose
  complete Table and Board segments are independently pointer and keyboard
  operable in wide and compact layouts.
- No Table context menu or obsolete `pipeline-delete-*` contract remains.
- No unrelated persistence, schema, routing, Board action, or untracked profiler artifact enters the delivery.
