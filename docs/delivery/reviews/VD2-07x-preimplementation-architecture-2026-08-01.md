# VD2-07x pre-implementation architecture review

**Date:** 2026-08-01  
**Role:** Independent Architect  
**Verdict:** **NEEDS CHANGE**

## Decision

The target composition is architecturally compatible with the existing app:
the five-destination rail and `DailyRoute.settings` remain global, the four
Settings sections are correctly local non-persisted `@State`, and the existing
root owns the model, file-panel/export flow, sheets, alerts, and action
dispatch. A filename-only success event is also the right narrow model seam.

Task 1 is not yet safe to release because the proposed event lacks two
explicitly verified lifecycle invariants. Without them, a successful export
can leave a stale success presentation associated with a prior workspace, and
the required no-success-on-failure rule is not fully exercised by the named
Task-1 contract. These are narrow amendments within the approved ownership
boundary; they do not require a route, storage, Core, or visual-design change.

## Evidence reviewed

| Area | Evidence | Assessment |
| --- | --- | --- |
| Global and local navigation | The design requires the unchanged global rail and non-persisted local selection (design §§ Shell and local navigation, lines 30-45). Current `SettingsView` keeps `selectedSection` as local `@State`, defaults it to `.recoveryArchives`, and changes only its selected panel (`RekonPursuit/SettingsView.swift:146-236`). `ContentView` supplies Settings only for the existing `.settings` route (`RekonPursuit/ContentView.swift:331-372`). | Compatible. No new `DailyRoute`, `AppDestination`, or preference is warranted. |
| Bounded display data | `ContentView` maps archive rows to `SettingsArchiveSummary` and passes only `DocumentReferenceSummary` into Settings (`RekonPursuit/ContentView.swift:510-528`). The document summary has only available/relink totals (`RekonPursuitCore/Workspace/WorkspaceModels.swift:537-540`). The proposed Workspace, Document, and AI sections use those facts and existing callbacks only. | Compatible, provided Task 2 does not widen the values or add actionable Document/AI descendants. |
| Protected-export write boundary | The current review flow obtains the URL privately, creates `ProtectedExportReview`, and the confirmation path writes through `store.createProtectedExport(review:recoveryKey:)` before it clears the review (`RekonPursuit/WorkspaceViewModel.swift:1303-1360`). `ProtectedExportReview.displayFilename` is derived as `destinationURL.lastPathComponent` (`RekonPursuitCore/Workspace/ProtectedExportWorker.swift:5-12`). | Compatible only if the new event retains exactly that filename and is assigned after the write and the existing store-identity guard. |
| Root modal/overlay ownership | The existing protected-export sheet is attached at `ContentView` root and remains presented after a success unless root state changes it (`RekonPursuit/ContentView.swift:186-226`). The plan correctly requires the root overlay to close this sheet only after a non-`nil` success event (plan Task 2, lines 214-227). | Compatible. Keep the Task-2 close-on-success order; a `SettingsView`-owned sheet or dialog would violate the boundary. |
| Workspace lifetime | `WorkspaceViewModel` can close or replace its store through startup, external/separate-workspace transitions, restore, and `apply(_:)` (`RekonPursuit/WorkspaceViewModel.swift:376-410, 467-487, 1789-1803, 1844-1874`). The proposed event is a model-held optional, so it otherwise survives a store replacement until manually dismissed. | Blocking lifecycle gap; amend below. |
| Task-1 failure proof | The brief requires `nil` before review and after cancellation, review error, and write error (brief lines 141-163), while the plan's Task-1 unit prescription only explicitly calls out cancellation and review error (plan lines 90-103). The lower-layer stale/no-overwrite tests do not observe the new view-model event. | Blocking coverage gap; amend below. |

## Required amendments before Task 1 release

1. Make the event store-scoped in lifetime, without adding store identity to
   its payload. Clear `protectedExportSuccess` when `apply(_:)` replaces or
   leaves a workspace and when `clearWorkspaceDerivedState()` runs. The
   clearing must cover normal/external/separate/recovery/restore transitions,
   not just `cancelProtectedExport()` and a new review. Add a focused model
   assertion that an event created for one workspace cannot present after a
   workspace transition. The payload remains exactly
   `ProtectedExportSuccess(displayFilename: String)`.

2. Amend the Task-1 model test (or split bounded model tests) to observe
   `protectedExportSuccess == nil` after every specified non-success branch:
   invalid confirm re-entry, destination cancellation, review failure, stale
   review/source-revision rejection, and create/write failure such as a
   destination that becomes occupied after review. Preserve the existing
   real-success/no-workspace-mutation assertion. The model implementation
   must clear a prior event before a fresh review/cancel and assign it only
   after `createProtectedExport` succeeds and `self.store === store` still
   holds; every catch/early-return path must leave it absent.

3. Retain the plan's Task-2 root-only presentation mechanics verbatim in
   substance: observe the non-`nil` root projection, then dismiss only
   `isPresentingProtectedExport` and clear its re-entry text before rendering
   `SettingsProtectedExportSuccessDialog`. `Done` may call only the root
   helper that clears the transient event. The dialog must take a string and
   callback, never a review, URL, key, bookmark, receipt, fingerprint, archive
   row, document value, or model.

## Constraints for the released implementation

- `SettingsView` may keep only local selected/focused section state. It must
  not own `WorkspaceViewModel`, route, persistence, file panel, modal state,
  recovery-key text, URL, or success invention.
- The Recovery action cards call the existing closures and preserve their
  disabled/busy/cancel/error contracts. The all-four-section recomposition is
  presentation-only; it must not alter recovery/archive/export/purge/restore,
  separate-workspace, document, AI, cloud, fixture, signing, or store code.
- `SettingsArchiveSummary` is the archive display boundary; no new card may
  consume checksum, fingerprint, bookmark, raw path, or document metadata.
  Document references remain aggregate-only and AI cards remain informational
  without controls.
- The Task-1 and Task-2 matrices must remain signed Debug runs. Task 1 may
  classify only the three declared unrendered visual selector/panel failures as
  RED; all event, cancellation, failure, route, fixture, and lower-layer
  safety assertions must be green.

## ADR / deviation outcome

**No ADR is required after the amendments.** The event is an ephemeral
presentation result owned by the existing view model and projected by the
existing `ContentView` root. Clearing it on workspace transition restores the
current model/store boundary rather than changing it. An ADR is required only
if a later change adds store identity, a URL/key/metadata field, persistence,
a Settings route/preference, or Settings-owned modal/action ownership.

## Release outcome

**Do not release Task 1 yet.** After the three amendments are incorporated,
a fresh architecture recheck may accept the task; the separate QA,
Security/privacy, TPM, and Delivery approvals remain required before release.
