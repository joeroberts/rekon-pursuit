# VD2-07x protected-export destination feedback — postimplementation QA verification

**Date:** 2026-08-01  
**Role:** Fresh independent QA postimplementation verifier  
**Implementation under review:** `84a99a3 fix: distinguish protected export destination failures` against `776f7b18`  
**Verdict:** **ACCEPT**

## Scope and method

Independently inspected the controlling task brief, implementer report, all
three QA gate records, and the Delivery hunk-isolation release. Reviewed the
three-path commit diff, the committed assertions, the inspection-only
`WorkspaceViewModel` mapper, and the preserved result bundles with
`xcrun xcresulttool get test-results summary/tests`. No source, test, project,
dashboard, plan/brief, or pre-existing delivery record was changed. Focused
test commands were not repeated because their preserved, inspectable result
bundles are complete and non-conflicting.

## Result-bundle evidence

| Stage | Bundle | Independently observed result |
| --- | --- | --- |
| Step 0 baseline | `/private/tmp/rekon-vd207x-export-feedback-scaffold.xcresult` | **7/7 passed**, 0 failed, skipped, or expected failures. The resolved list contains the existing encryption/read-back, parent binding, source-change/no-file, no-overwrite, retained-correction, non-success, and real-write presentation regressions. |
| Executable RED | `/private/tmp/rekon-vd207x-export-feedback-red-fixed.xcresult` | **10/10 executed and failed**, 0 passed, skipped, or expected failures. The resolved list contains all five new core selectors and five model-feedback selectors exactly once. The recorded failures are assertion failures for the old invalid-name copy or absent fault placements/classification; no unresolved-symbol, skip, or expected-failure result appears. |
| Final focused GREEN | `/private/tmp/rekon-vd207x-export-feedback-green-final.xcresult` | **10/10 passed**, 0 failed, skipped, or expected failures. The resolved list exactly matches the executable RED list. |
| Regression | `/private/tmp/rekon-vd207x-export-feedback-regression.xcresult` | **8/8 passed**, 0 failed, skipped, or expected failures: four existing core regressions, the new verified-event/activity contract, and three existing model regressions. |

The earlier `/private/tmp/rekon-vd207x-export-feedback-red.xcresult` is a
**preliminary compile-only failure**, not valid RED acceptance evidence: its
summary is `unknown`, with 0 total executed tests and an empty test list. This
is fully accounted for by the implementer report's fixture actor-isolation
correction. It does not satisfy the final QA gate's executable-RED condition
and is therefore excluded from acceptance; the immediately subsequent,
separately preserved `red-fixed` bundle does satisfy that condition. No change
to production classification/copy is attributed to resolving the fixture
annotation.

## Acceptance checks

| Requirement | Independent verification |
| --- | --- |
| Distinct owner feedback | The commit replaces overloaded `invalidDestination` with `invalidDestinationName` (`Choose a new file name ending in .rekonexport.`) and `destinationUnavailable` (`Rekon Pursuit can’t use that folder. Choose another local folder and review the export again.`). Both core and model contracts assert the exact messages; model contracts assert both `protectedExportErrorMessage` and `statusMessage`. |
| Exact fault boundaries | The immutable default-`.none` fault mode is internal to the worker. `parentOpenUnavailable` follows the filename predicate and precedes `open`; `parentInspectionUnavailable` follows a successful open, closes the descriptor, and precedes `fstat`; pre-create unavailable follows the unchanged identity guard and precedes `openat`; post-create fault follows descriptor assignment and `created = true`. |
| No output/evidence before a write | The new core contracts for invalid name, both parent failures, and exclusive-create failure assert absent final URL, zero `protected_export_events`, and zero filtered `protected_export_verified` activity. The focused final GREEN resolves all five core contracts as passed. |
| Post-create conservative state | The post-create core contract asserts output exists yet zero verified export/activity evidence and the existing may-remain copy. The model contract asserts the same exact owner feedback, nil success, false root-success presentation, and retained error/review. |
| Review and root-feedback retention | Failed reviews assert no retained review; failed confirmation retains a real prior review. Shared model assertion verifies exact error/status copy, nil success, false root-success presentation, and the root presentation’s retained error message. The existing ViewModel mapper remains inspection-only and maps `ProtectedExportWorkerError.errorDescription` directly. |
| Verified success audit | The new core contract verifies final bytes against the returned receipt and asserts exactly one `verified` export row and exactly one `protected_export_verified` activity row. It passed in the regression bundle. |
| No-overwrite regression | The selected existing-target core regression uses an existing valid `.rekonexport` file, preserves its bytes byte-for-byte, and retains `.destinationExists`; the selected model regression includes the literal “will not replace a file” owner copy and non-success/root-presentation protection. Both relevant selectors passed in recorded baseline/regression evidence. |
| Security and production invariants | Diff inspection shows the parent flags remain `O_RDONLY | O_DIRECTORY | O_NOFOLLOW`; final output flags remain `O_RDWR | O_CREAT | O_EXCL | O_NOFOLLOW`; the parent identity guard, scoped-access lifetime, destination digest, `EEXIST -> destinationExists`, audit timing, and post-`created` may-remain boundary remain intact. Fault mode is neither persisted nor exposed through Store/ViewModel production construction. |
| Isolated hunk/path compliance | `git diff --name-status 776f7b18 84a99a3` contains exactly `ProtectedExportWorker.swift`, `ProtectedExportTests.swift`, and `WorkspaceViewModelTests.swift`. `WorkspaceViewModel.swift` has no commit diff. The model-test addition is one insertion at the approved parent anchors after line 548 and before line 550 (the hunk record’s later 690/692 coordinates reflect the pre-existing dirty worktree). Existing core tests remain before the appended block. |

## Local check

`git diff --check 776f7b18 84a99a3` completed with no output. The assigned
worktree still contains unrelated pre-existing modifications and untracked
delivery material; none is part of `84a99a3` or used to expand this verdict.

## Disposition

**ACCEPT.** The required executable RED evidence, final GREEN evidence,
regression evidence, exact feedback/state assertions, audit/no-output
boundaries, no-overwrite protection, review retention, and hunk isolation are
present. The preliminary compile-only RED bundle remains retained as a
non-gating historical artifact; the executable `red-fixed` bundle is the
valid RED proof for this release.
