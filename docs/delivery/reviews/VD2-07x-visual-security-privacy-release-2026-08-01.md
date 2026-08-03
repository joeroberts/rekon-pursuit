# VD2-07x Task 2 — visual security/privacy release

**Date:** 2026-08-01  
**Role:** Independent Security/privacy verifier  
**Verdict:** **ACCEPT — release the approved visual implementation only.**

## Decision

The product-owner VD2-08 accessibility deferral permits the reference-faithful
Settings rendering to begin. It does **not** waive any local-storage, recovery,
protected-export, document-privacy, or AI-connection boundary. This is a
release to implement Task 2, not acceptance of its result or of VD2-07x.

## Evidence reviewed

- Product-approved reference design:
  `docs/superpowers/specs/2026-08-01-vd207-reference-faithful-recovery-screen-design.md`.
- Task 2 implementation and verification plan:
  `docs/superpowers/plans/2026-08-01-vd207-reference-faithful-recovery-screen.md`.
- Controlling Task 1/Task 2 brief:
  `docs/delivery/task-briefs/VD2-07x-reference-faithful-settings.md`.
- Product-owner accessibility decision:
  `docs/delivery/task-briefs/VD2-07x-vd208-accessibility-deferral-addendum.md`.
- Current seam in `RekonPursuit/WorkspaceViewModel.swift`,
  `RekonPursuit/ContentView.swift`, and `RekonPursuit/SettingsView.swift`.

Static inspection confirms the existing event is a filename-only
`ProtectedExportSuccess`; it is published only after the existing protected
export creation closure returns and only while its operation token and store
identity still match. The model clears it for invalid, cancellation, failure,
stale-completion, and workspace-transition paths. The root presentation
projects only that filename plus the fixed `Selected local folder` text. The
current Settings view owns local selection and callbacks, not a model, URL,
recovery key, review, bookmark, persistence, or success state. The fixed
fixture instant is currently `2025-05-06T12:00:00Z`.

`git diff --check -- RekonPursuit/WorkspaceViewModel.swift
RekonPursuit/ContentView.swift RekonPursuit/SettingsView.swift` completed with
no whitespace error. No production source, test, fixture, index, signing,
entitlement, or generated artifact was changed by this review; no test result
is claimed here.

## Release boundary

The Task 2 implementer may render the four approved Settings surfaces and the
root-owned export-success dialog only if all of these conditions are preserved:

1. The success dialog is driven solely by a non-nil real-write event. It must
   have no fixture default, launch argument, demo control, simulated state, or
   test-only success path. Cancellation, errors, stale completions, and
   workspace transitions must never present it.
2. `ContentView` remains the owner of model, destination selection, recovery
   key entry, export/review sheets, error/cancellation presentation, and the
   dialog binding. On valid success it may close the existing export sheet and
   clear the entry text, but it must retain the event until `Done` invokes only
   `SettingsRootModalBindings.dismissProtectedExportSuccess`.
3. The dialog may receive and display only the safe filename and `Selected
   local folder`, with a non-secret reminder and `Done`. It may not receive or
   render a URL/path, bookmark, recovery key or key-derived data, review,
   receipt, store identity, operation token, fingerprint, checksum, archive
   record, document name, hash, MIME type, or other document metadata.
4. Recovery cards consume `SettingsArchiveSummary` safe display data and the
   pre-existing action closures/disabled/busy/error/cancellation predicates;
   no recovery/archive/export/purge/restore semantics may change.
5. Document references stay aggregate-only with no document rows, paths,
   bookmarks, hashes, MIME types, filenames, or actionable controls. AI &
   connections remains informational and offline: no AI, cloud, Gmail,
   Calendar, setup, consent, budget, or network control is introduced.
6. The existing global rail, local non-persisted Settings selection, fixture
   time, route behavior, storage/persistence, signing, entitlements, and
   network behavior remain untouched.

## VD2-08 deferral boundary

Only the existing compact keyboard-focus/Tab/Space handoff and the AI
informational text's accessibility role/label/value may be carried to VD2-08.
Their tests and assertions must remain intact and execute as recorded evidence.
The deferral permits no skip, expected-failure, retry/guard workaround,
predicate weakening, fixture change, metadata disclosure, or success-state
invention. Pointer-selection coverage and the AI visual/content-boundary check
remain required in Task 2 so visual behavior and privacy do not rely on the
deferred failures.

## Required acceptance evidence

Task 2 is not accepted until an independent post-implementation review finds
the constrained diff intact and verifies the signed matrix, the eight fixture
section images, and the ordinary signed-Debug real-export dialog image. Every
artifact must be inspected for recovery keys, raw paths, chooser contents,
document metadata, hashes, bookmarks, fingerprints, checksums, and MIME types.
The real dialog proof must show only the safe filename, `Selected local folder`,
the non-secret reminder, and `Done`; dismissing it must leave the active
workspace unchanged.
