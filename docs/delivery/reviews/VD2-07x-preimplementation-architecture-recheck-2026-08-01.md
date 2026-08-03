# VD2-07x pre-implementation architecture recheck

**Date:** 2026-08-01  
**Role:** Fresh independent Architect  
**Verdict:** **ACCEPT** — the amended controlling design, implementation plan,
and Task 1 brief resolve every architecture blocker recorded in the original
pre-implementation review. This is an architecture gate only; it does not
replace the required independent QA, Security/privacy, TPM, or Delivery gates.

## Scope and method

Rechecked the approved VD2-07x design, amended plan, amended Task 1 brief, and
the original Architecture, QA, and Security/privacy pre-implementation reviews.
This was a document-contract review before Task 1 release. No source, test,
project, index, generated artifact, or commit was changed.

## Resolution of prior architecture findings

| Prior finding | Amended contract evidence | Architecture result |
| --- | --- | --- |
| A confirmed export could publish success after cancellation or a later stale completion. | The plan defines a private opaque `ProtectedExportOperationToken`, captures it before confirmation, invalidates it for each new review, invalid input, destination cancellation, terminal error/catch, stale return, cancellation, workspace-derived-state clear, and every applicable store transition; publication requires both current-token equality and current-store identity (`docs/superpowers/plans/2026-08-01-vd207-reference-faithful-recovery-screen.md:150-179`). The brief repeats the same invalidation and sole publication guard (`docs/delivery/task-briefs/VD2-07x-reference-faithful-settings.md:170-179`). | Resolved. The token is model-private, and the deterministic gated cancellation contract waits for an in-flight confirmation, cancels it, releases it, then requires no event or root presentation (`plan:145`; `brief:156`). |
| The completion event could widen the presentation boundary. | The approved design permits only a boolean, display filename, and dismiss callback at the success boundary (`docs/superpowers/specs/2026-08-01-vd207-reference-faithful-recovery-screen-design.md:139-149`). The plan and brief specify `ProtectedExportSuccess` with exactly `displayFilename: String` and prohibit a review, URL, identity, key, bookmark, receipt, fingerprint, checksum, archive/document value, store identity, or token (`plan:13-17,150-173`; `brief:162-181`). | Resolved. The safe payload remains filename-only and is not persisted or transported to Settings. |
| A success associated with an earlier store could survive a workspace transition. | The plan requires invalidation at the start of `clearWorkspaceDerivedState()` and in `apply` before replacing or leaving the store (`plan:162-168`). Its transition test creates a real event before every case and requires no event/root presentation for normal replacement, creation, separate-workspace entry/return, successful and failed restore, external-folder replacement/cancellation, close, and teardown (`plan:144-148`). The brief states the same exhaustive route list (`brief:158`). | Resolved. Success is explicitly store-scoped and reset on every public route through `apply` or `clearWorkspaceDerivedState`. |
| The old contract lacked a positive, root-owned success and Done proof. | The model test requires a real verified write, then proves the root projection exposes only the filename and `Selected local folder`; Done calls only `dismissProtectedExportSuccess` and leaves the output and active IDs unchanged (`plan:129`; `brief:138`). Task 2 keeps the dialog at `ContentView` root, closes only the existing export sheet and re-entry text before the overlay, and makes Done dismiss only the transient success event (`plan:238-251`). | Resolved. The positive case, safe root projection, close order, and non-mutating Done behavior are specified before rendering. |
| Ownership and navigation could drift into Settings-owned modal state, a global route, or a persisted selector. | The approved design retains the five-destination global rail and makes all four sections local, non-persisted presentation state (`design:19-42`), while reserving model, global route, sheets/alerts, destination selection, dialog binding, and action dispatch for `ContentView` (`design:130-149`). The plan assigns `SettingsView` only local tab/focus state and safe values/callbacks (`plan:7-9,19-28`) and preserves all four semantic labeled tabs at compact width without rerouting (`plan:91-103,194-207`). The brief repeats the four boundaries and explicitly forbids Settings model, route, persistence, URL, key, review, file-panel, sheet, or invented-success ownership (`brief:16-27`). | Resolved. The local-tab/four-section presentation boundary is narrow and compatible with the established root ownership. |

## ADR / deviation decision

**No ADR is required.** The amended contract implements the original review's
allowed correction: an ephemeral, store-scoped model event projected by the
existing root, without adding store identity to its payload, persistence, a
Settings route/preference, a new Core/storage contract, or Settings-owned
modal/action flow. This matches the original review's stated no-ADR outcome
after these amendments (`docs/delivery/reviews/VD2-07x-preimplementation-architecture-2026-08-01.md:83-88`).

## Gate outcome

The original architecture blockers are closed in the approved documents. From
the architecture perspective, **Task 1 may proceed once the separately required
fresh QA, Security/privacy, TPM, and Delivery approvals are recorded**. Any
implementation deviation that persists success/selection, carries non-filename
data, changes root ownership, or omits a listed invalidation path requires a
new architectural review before release.
