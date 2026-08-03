# VD2-07x Save-panel leaf authority — Task 1 code re-review 1

**Date:** 2026-08-01  
**Role:** Fresh independent task-scoped code re-reviewer  
**Review range:** `3b7da8d95677fccb60b8fde3b416ea3a700efade..3dc7395752a87bee3a3e61384d36e3416e844db5`  
**Review input:** task brief, implementation report, and frozen `review-3b7da8d..3dc7395.diff`; no Git commands or broad working-tree review were used.

## Verdicts

- **Finding disposition: RESOLVED.**
- **Fix-diff quality: ACCEPT.**
- **Recommended disposition: accept commit `3dc7395` for the bounded P2 correction.**

## Verification

`DestinationLeafProbe` now has distinct `exists`, `absent`, and `unavailable`
states (`RekonPursuitCore/Workspace/ProtectedExportWorker.swift:50-54`). Both
review and confirm map only a successful `lstat` leaf probe to
`destinationExists`, map an `unavailable` probe to `destinationUnavailable`,
and continue only for `absent` (`RekonPursuitCore/Workspace/ProtectedExportWorker.swift:69-73`,
`105-109`). The probe returns `exists` only for `lstat == 0`, `absent` only for
`ENOENT`, and `unavailable` for every other lookup error
(`RekonPursuitCore/Workspace/ProtectedExportWorker.swift:174-179`). This
preserves terminal-symlink collision rejection while classifying `EACCES`,
`ENOTDIR`, and comparable pre-FD lookup failures as unavailable.

The new regression first obtains a valid review, replaces the immediate parent
with a regular file, then confirms the selected leaf. That makes the actual
leaf `lstat` encounter `ENOTDIR`; it asserts `destinationUnavailable`, no
output, and zero verified evidence
(`RekonPursuitCoreTests/ProtectedExportTests.swift:167-185`). The fixture
returns the nested path without creating its parent, so the initial review
correctly observes `ENOENT`; writing the parent file after review creates the
intended transition (`RekonPursuitCoreTests/ProtectedExportTests.swift:301-324`).

No new breakage is evident in the supplied fix diff: the final exclusive-open
race defense is untouched, and both review and confirm use the same
leaf-only classification.

## Verification evidence

No tests were rerun for this scoped re-review. The implementation report
records the exact new regression as RED (one expected assertion failure) and
GREEN (one passing test), plus a fresh focused suite with 20 passing tests and
zero skips or expected failures.

## Outstanding owner action

The owner-native `NSSavePanel` smoke remains pending and is outside this
re-review verdict.
