# VD2-07x protected-export feedback diagnosis

**Date:** 2026-08-01  
**Role:** Fresh independent planning/diagnosis review  
**Scope:** Source-only trace of protected-export review feedback. No production,
test, project, dashboard, or existing delivery artifact was modified.

## Finding

**Root cause (high confidence):** `ProtectedExportWorkerError.invalidDestination`
conflates an invalid output filename with failure to open or inspect the selected
parent folder (and, later, a non-`EEXIST` exclusive-create failure). The UI
publishes that controlled error unchanged. Therefore a save-panel result whose
visible name already ends in `.rekonexport` can be rejected because its folder
cannot be opened/inspected, while the sheet inaccurately tells the owner to
rename the file.

The unobserved low-level reason is unknown from source alone: the code drops
`errno`, so this review cannot distinguish an inaccessible/sandbox-denied,
unavailable, non-directory, or other parent-folder failure. The reported
symptom rules out the filename predicate *if* the returned URL's actual last
path component matches the visible panel name; direct runtime URL/errno evidence
would be needed to prove that predicate for the incident.

## Evidence and trace

| Stage | Evidence | Current result |
| --- | --- | --- |
| Save selection | `RekonPursuit/WorkspaceViewModel.swift:349-354` configures `NSSavePanel` for `.rekonexport` and returns `panel.url` on OK. | A filename filter/default exists, but no normalized destination result or diagnostic category is returned to the view model. |
| Review dispatch | `RekonPursuit/WorkspaceViewModel.swift:1318-1350`; `RekonPursuitCore/Workspace/WorkspaceStore.swift:1242-1244`. | The chosen URL reaches the worker unchanged. Any thrown controlled error is rendered as its `errorDescription`. |
| Filename validation | `RekonPursuitCore/Workspace/ProtectedExportWorker.swift:140-143`. | A wrong extension, empty/special filename, or slash in the final component throws `.invalidDestination`. |
| Parent access | `ProtectedExportWorker.swift:143-146`. | Failure of `open(parent, O_DIRECTORY | O_NOFOLLOW)` or `fstat` also throws the same `.invalidDestination`, even after a valid extension passed. |
| Confirm-time creation | `ProtectedExportWorker.swift:180-187`. | A non-`EEXIST` `openat(... O_EXCL | O_NOFOLLOW ...)` failure is likewise mapped to `.invalidDestination`; it can occur only after review, not in the reported review failure. |
| Copy and retained sheet | `WorkspaceViewModel.swift:1343-1350`; `RekonPursuit/ContentView.swift:205-244`. | The existing sheet is not dismissed. With no review it displays its choose-destination form and the red `protected-export-error` message, so it appears to reopen. |
| Misleading copy | `ProtectedExportWorker.swift:30-43`, especially line 35. | All three categories above become: “Choose a new file named with the .rekonexport extension.” |
| Test coverage gap | `RekonPursuitCoreTests/ProtectedExportTests.swift:91-106`; `RekonPursuitTests/WorkspaceViewModelTests.swift:637-658`, `2867-3028`. | Tests cover normal valid names, existing-target protection, and generic non-success behavior. They do not assert invalid-name feedback, an unopenable parent, non-`EEXIST` create failure, or correct message distinction. |

## Expected versus actual UI behavior

| Situation | Expected | Actual |
| --- | --- | --- |
| A panel-selected filename has a valid `.rekonexport` suffix, but the parent folder cannot be safely used. | Keep the export sheet open for correction and explain that the selected folder cannot be used; direct the owner to choose another local folder. | Keep the sheet open, but state that the filename extension is wrong. This incorrectly directs a rename and looks like a rejected valid panel choice. |
| The filename itself is invalid. | Keep the sheet open and direct the owner to use the required suffix. | This is the one case accurately described by the current message. |
| A file already exists. | Keep the sheet open and refuse overwrite with a filename correction. | Already distinct and correctly handled (`ProtectedExportWorker.swift:59`, `85`; existing view-model assertion at `WorkspaceViewModelTests.swift:657`). |

## Smallest safe corrective contract

Preserve the existing no-overwrite, `O_NOFOLLOW`, parent-identity binding,
review-before-write, and success-only presentation behavior. Change only the
error classification at the worker/view-model boundary; do not weaken the
filesystem checks or auto-retry/auto-create a destination.

1. Split the current worker error into at least two safe, controlled categories:
   - `invalidDestinationName`: only the line-142 filename predicate fails.
   - `destinationUnavailable`: the parent `open`/`fstat` fails, or a
     pre-creation `openat` failure is not `EEXIST` and no output has been
     created.
2. Retain `destinationExists`, `destinationChanged`, `sourceChanged`, and
   `outputMayRemainAfterFailure` as distinct existing outcomes. In particular,
   after a file may have been created, retain `outputMayRemainAfterFailure`;
   never recast it as a safe-to-retry folder issue.
3. Continue mapping only controlled errors to owner copy in
   `WorkspaceViewModel.protectedExportMessage` (`WorkspaceViewModel.swift:1449-1452`).
   Do not expose paths, `errno`, security-scope state, or recovery-key material.

Exact safe copy:

| Error distinction | Copy |
| --- | --- |
| Invalid filename | “Choose a new file name ending in .rekonexport.” |
| Selected folder unavailable before write | “Rekon Pursuit can’t use that folder. Choose another local folder and review the export again.” |
| Existing target (unchanged) | “That filename already exists. Choose a new filename; Rekon Pursuit will not replace a file.” |
| Destination changed after review (unchanged) | “The selected destination changed before export. Choose the destination again and review it.” |
| Output may remain after a create/write failure (unchanged) | “Final export writing or verification failed. The selected file may remain; treat it as unusable and remove it yourself.” |

## TDD acceptance cases

1. **RED: invalid filename.** Inject a destination whose final component does
   not end in `.rekonexport`; review fails without creating a file, the export
   sheet remains in correction state, and the exact invalid-filename copy is
   published.
2. **RED: valid suffix, unavailable parent.** Inject a URL with a valid
   `.rekonexport` final component whose parent cannot be opened/inspected.
   Review fails without creating a file or review record, retains the sheet,
   and publishes the exact folder-unavailable copy—not filename copy. Use a
   deterministic worker seam/fixture rather than host permission assumptions.
3. **RED: valid suffix, exclusive create unavailable.** After a successful
   review, force a non-`EEXIST` exclusive-create failure before output creation.
   Confirm publishes the folder-unavailable copy, creates no file, records no
   verified-export/activity event, and never shows success.
4. **Regression: existing target.** Preserve bytes and exact no-overwrite
   message for a pre-existing `.rekonexport` target.
5. **Regression: post-create failure.** Preserve the existing “may remain”
   outcome if failure occurs after an output file could exist; do not offer the
   folder-unavailable retry copy.
6. **Regression: valid panel-equivalent URL.** A newly empty, ordinary local
   `.rekonexport` destination reaches review, then creates a verified export
   only after recovery-key confirmation; the success presentation remains
   filename-only and follows a real write.

## Compatibility and security

- This is a copy/classification correction, not a change to the export format,
  filename suffix, persisted records, audit events, or public API. Existing
  valid exports and existing `destinationExists` behavior remain compatible.
- The folder-unavailable category must be deliberately non-diagnostic. It must
  not disclose the selected path, raw POSIX error, sandbox/security-scope state,
  or any recovery-key value.
- Keep `O_NOFOLLOW`, `O_EXCL`, parent identity checks, read-back verification,
  and the conservative “may remain” handling intact. A friendly error must not
  turn an inaccessible or changed destination into an overwrite or symlink
  traversal path.

## Approval

**User approval is not needed before implementation.** The recommended slice
does not expand product scope or alter the protected-export security contract;
it makes the already-selected destination failure truthful and testable. Normal
delivery gates still apply: the TPM/Delivery Manager must release the bounded
task, with fresh Architecture, QA, Security/privacy, and code-review checks
before implementation and acceptance.
