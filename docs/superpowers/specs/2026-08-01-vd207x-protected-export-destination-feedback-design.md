# VD2-07x protected-export destination feedback design

**Date:** 2026-08-01  
**Status:** Owner-approved implementation contract  
**Scope:** One bounded protected-export error-classification and feedback slice.

## Decision

Keep the native `NSSavePanel` contract unchanged: it filters to
`.rekonexport`, defaults to `Rekon Pursuit Export.rekonexport`, permits
directory creation, and returns its selected URL unchanged. The export sheet
continues to retain its correction state after a controlled error.

Split the worker's current overloaded `invalidDestination` result into:

| Condition | Controlled result | Exact owner copy |
| --- | --- | --- |
| Final path component fails the filename predicate | `invalidDestinationName` | `Choose a new file name ending in .rekonexport.` |
| A valid-suffix destination's parent cannot safely be opened or inspected before writing | `destinationUnavailable` | `Rekon Pursuit can’t use that folder. Choose another local folder and review the export again.` |
| A non-`EEXIST` exclusive create fails before a final output exists | `destinationUnavailable` | `Rekon Pursuit can’t use that folder. Choose another local folder and review the export again.` |

`destinationExists`, `destinationChanged`, `sourceChanged`, and
`outputMayRemainAfterFailure` retain their current distinct meanings and copy.
Once `openat` has created a final file, every subsequent failure remains
`outputMayRemainAfterFailure`; it must never be reclassified as safe folder
correction.

## Required implementation boundary

Change only the controlled worker error classification and the messages that
`WorkspaceViewModel.protectedExportMessage(for:fallback:)` already publishes.
`ContentView` needs no behavioral or accessibility change: it already renders
the model's controlled message in the retained `protected-export-error` state.

Use a deterministic internal worker seam for focused tests. The recommended
shape is an internal, default-`.none` fault mode supplied to
`ProtectedExportWorker` only by tests, with separate pre-write modes for parent
open/inspection and exclusive-create failure. It must trigger before an output
is created and cannot alter production defaults. A separate post-create mode
may be used only to prove the existing conservative `outputMayRemainAfterFailure`
branch. An equivalent injected filesystem-operation adapter is acceptable if
it preserves the same default Darwin calls and permits no raw error to cross
the worker boundary. Do not base acceptance on chmod, sandbox denial, absent
mounts, or host-specific `errno` behavior.

## Invariants

- Preserve `O_DIRECTORY | O_NOFOLLOW` for parent opening and `O_EXCL |
  O_NOFOLLOW` for final creation; do not add overwrite, retry, or automatic
  destination creation behavior.
- Preserve parent device/inode identity binding, destination digest, review
  fingerprint, staging, read-back verification, and success/activity creation
  only after a verified final write.
- Never disclose a selected path, raw POSIX `errno`, security-scope state,
  recovery key/material, or database/internal key in owner-visible copy.
- A pre-write folder failure creates no final file, protected-export event, or
  `protected_export_verified` activity, and does not present success.
- Settings IA, UI accessibility, panels other than the existing protected
  export flow, project configuration, and persistence schema are out of scope.

## Acceptance evidence

1. Invalid filename publishes the exact filename copy and creates no review or
   output.
2. A valid `.rekonexport` name with deterministic parent failure publishes the
   exact folder copy, not filename copy, with no review/output/event.
3. A successful review followed by deterministic non-`EEXIST` create failure
   publishes the exact folder copy, creates no output/event, and never shows
   success.
4. Existing targets remain byte-for-byte unchanged and keep the existing
   no-overwrite message.
5. A deterministic post-create failure remains the existing may-remain result.
6. An ordinary fresh local `.rekonexport` URL still reviews, writes, verifies,
   records activity, and presents filename-only success after real writing.

