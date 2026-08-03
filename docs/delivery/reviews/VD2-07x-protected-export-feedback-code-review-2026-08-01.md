# VD2-07x protected-export destination feedback — Task 1 code review

**Date:** 2026-08-01
**Role:** Fresh independent code reviewer
**Review range:** `776f7b18e33a3c3e336a77bc65de7fdc8c6566a4..84a99a3df374ceb133b00175cd61285677224e1e`

## Verdicts

- **Specification compliance: PASS**
- **Code quality: PASS**
- **Recommended disposition: ACCEPT commit `84a99a3` and advance it to the remaining independent postimplementation QA, Architecture, Security/privacy, TPM, and Delivery gates.**

## Findings

No blocking or non-blocking code findings.

## Review evidence

### Scope and hunk isolation

- `84a99a3` is the sole commit after base `776f7b18`; the base is its merge base.
- The frozen review package exactly matches `git diff --unified=10 776f7b18..84a99a3`.
- The commit changes only the three authorized paths: `RekonPursuitCore/Workspace/ProtectedExportWorker.swift`, `RekonPursuitCoreTests/ProtectedExportTests.swift`, and `RekonPursuitTests/WorkspaceViewModelTests.swift`.
- The model-test change is one insertion at the released seam between the cancellation test and `testExternalFolderLeaseIsRetainedForTheOpenedStoreThenReleasedOnClose`. The original core tests remain unchanged and the new core contracts/helpers are appended before the class close. `WorkspaceViewModel.swift`, `ContentView.swift`, `ProtectedExportService`, `WorkspaceStore`, project files, dashboard, plan/brief, Settings, persistence, and accessibility receive no commit-range hunk.

### Worker behavior and security invariants

- The exact owner copy is present: `Choose a new file name ending in .rekonexport.` and `Rekon Pursuit can’t use that folder. Choose another local folder and review the export again.`
- Only the existing final-component predicate maps to `invalidDestinationName`. Valid-suffix parent `open`/`fstat` failures and non-`EEXIST` pre-output `openat` failures map to `destinationUnavailable`; `EEXIST` remains `destinationExists`.
- The real `openat` call is immediately followed by `let openError = errno`, and classification uses that captured value. No raw numeric error is retained or exposed.
- Parent `O_RDONLY | O_DIRECTORY | O_NOFOLLOW`, final `O_RDWR | O_CREAT | O_EXCL | O_NOFOLLOW`, `S_IRUSR | S_IWUSR`, `AT_SYMLINK_NOFOLLOW`, the conservative existence predicate, parent identity comparison, digest/fingerprint inputs, scoped-access lifetime, and operation order are unchanged.
- `exclusiveCreateUnavailable` follows the unchanged current-parent-identity guard and precedes `openat`. `afterOutputCreation` follows successful descriptor assignment and `created = true`; the existing catch therefore conservatively returns `outputMayRemainAfterFailure` while allowing the created path to remain.
- Final read-back receipt verification still precedes the atomic insertion of the verified export row and filtered activity row. No failure path inserts either row or returns success.
- `ProtectedExportWorkerFaultMode` is one immutable internal `Sendable` enum held in a `private let`, defaults to `.none`, and is threaded only to the two worker helpers. Repository-wide search at `84a99a3` finds the production `WorkspaceStore` construction using `ProtectedExportWorker(configuration: ...)` with no fault argument; explicit non-default modes occur only in the two focused test files. No environment, settings, serialization, logging, persistence, store/view-model parameter, or UI selector was added.

### Deterministic state and owner-feedback tests

- The worker tests prove invalid-name, parent-open, parent-inspection, and exclusive-pre-create failures leave no final path and zero protected-export/filtered verified-activity evidence.
- The pre-create test first obtains a real bound review. The post-create test proves the final path exists, returns only the exact may-remain copy, and leaves zero verified evidence.
- The ordinary default-worker test verifies final bytes against the receipt before asserting exactly one verified export row and one filtered verified activity row.
- The five model tests prove exact error and status copy, nil success, false root-success presentation, retained root error presentation, nil review for review-stage failures, and retained review for confirm-stage failures. Regression evidence retains byte-for-byte no-overwrite, parent binding, source-revision no-file, non-success presentation, and real-write success behavior.

### Preserved result-bundle inspection and RED assessment

No test command was rerun during this review. The preserved bundles were inspected directly:

| Bundle | Independently observed result |
| --- | --- |
| Scaffold | 7 passed, 0 failed/skipped/expected failures |
| Preliminary RED | Build failed before execution with the reported main-actor isolation error; 0 tests ran |
| Executable RED (`red-fixed`) | All 10 selected tests ran once and failed; 0 passed/skipped/expected failures |
| Final GREEN | 10 passed, 0 failed/skipped/expected failures |
| Regression | 8 passed, 0 failed/skipped/expected failures |

The preliminary RED bundle does not itself satisfy the executable-RED requirement. It is nevertheless a non-blocking preliminary test-fixture defect because it was preserved and disclosed, the correction was confined to the test helper, and the subsequent fresh `red-fixed` bundle demonstrates the required pre-GREEN state: the old filename copy remains, all four fault modes are inert, successful operations occur where failures are required, and every selected test fails through executable assertions rather than missing symbols, skips, expected failures, or production compilation errors. The later GREEN/regression bundles and the final commit diff close the loop. The executable assertion RED therefore satisfies the substantive TDD gate; the compile-only attempt should remain recorded as process history, not be represented as the qualifying RED artifact.

## Checks

- `git diff --check 776f7b18..84a99a3`: clean.
- Frozen review package versus `git diff --unified=10 776f7b18..84a99a3`: exact match.
- Changed-path and zero-context hunk inspection: authorized paths and released insertion seams only.
