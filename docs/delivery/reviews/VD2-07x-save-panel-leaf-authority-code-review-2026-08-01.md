# VD2-07x Save-panel leaf authority — Task 1 code review

**Date:** 2026-08-01  
**Role:** Fresh independent task-scoped code reviewer  
**Review range:** `84a99a3df374ceb133b00175cd61285677224e1e..3b7da8d95677fccb60b8fde3b416ea3a700efade`  
**Primary review input:** frozen `review-84a99a3..3b7da8d.diff`; no Git commands or broad working-tree review were used.

## Verdicts

- **Specification compliance: REJECT — one bounded correction is required.**
- **Task quality: NEEDS REVISION.**
- **Recommended disposition: HOLD commit `3b7da8d` at the task gate until the pre-FD leaf-probe error classification is corrected and regression-tested.**

## Findings

### P2 — The leaf collision probe misclassifies non-`ENOENT` lookup failures as an existing destination

`destinationExists(at:)` returns `true` whenever `lstat` fails with any errno other than `ENOENT`. Both review and confirm then convert that Boolean into `destinationExists`. Consequently, an inaccessible selected leaf (`EACCES`), a locator whose intermediate component became a non-directory (`ENOTDIR`), or another non-collision lookup failure receives the no-overwrite message even though no existing terminal leaf was established. That violates the binding requirement that a direct failure before the final descriptor exists map to `destinationUnavailable`; only an actual existing leaf/terminal symlink or `open(... O_EXCL ...)` returning `EEXIST` should map to `destinationExists`.

The final `open` path itself correctly captures `errno` and maps `EEXIST` versus other failures, but the earlier Boolean guard prevents those non-`ENOENT` cases from reaching it. The focused direct-leaf test injects failure immediately before `open`, so it does not exercise the real failing `lstat` branch.

**Locations:**

- `RekonPursuitCore/Workspace/ProtectedExportWorker.swift:63`
- `RekonPursuitCore/Workspace/ProtectedExportWorker.swift:95`
- `RekonPursuitCore/Workspace/ProtectedExportWorker.swift:160-164`
- `RekonPursuitCore/Workspace/ProtectedExportWorker.swift:192-197`
- `RekonPursuitCoreTests/ProtectedExportTests.swift:219-232`

**Required correction:** Replace the Boolean probe with a result that distinguishes `exists`, `absent`, and `unavailable` while remaining leaf-only. Preserve terminal-symlink rejection and the exclusive `open` race defense. Add a regression that obtains a valid review, makes the same locator fail before final-FD creation (for example, by replacing an intermediate directory with a regular file so `lstat`/`open` encounters `ENOTDIR`), and asserts `destinationUnavailable`, no final output, and zero verified evidence.

No P0 or P1 findings were identified.

## Confirmed compliance outside the finding

### Scope and authority boundary

- The frozen package contains exactly the three allowed files: `RekonPursuitCore/Workspace/ProtectedExportWorker.swift`, `RekonPursuitCoreTests/ProtectedExportTests.swift`, and the released protected-export feedback island in `RekonPursuitTests/WorkspaceViewModelTests.swift:692-740`.
- `ProtectedExportReview` contains the selected URL, source revision, digest, and fingerprint only; the parent identity type and parent open/stat/bind/continuity path are gone (`ProtectedExportWorker.swift:5-12`).
- The canonical leaf v2 digest is SHA-256 over the required domain separator plus the standardized, precomposed selected path (`ProtectedExportWorker.swift:166-170`). The confirmation fingerprint binds the canonical destination digest, normalized display filename, and source revision (`ProtectedExportWorker.swift:173-184`).
- The implementation adds no entitlement, UI, bookmark, schema, or persisted path/key change in the supplied task range.

### Final-leaf write and evidence boundary

- Final creation is a direct `open(destination.path, O_RDWR | O_CREAT | O_EXCL | O_NOFOLLOW, S_IRUSR | S_IWUSR)` with no overwrite, retry, or final-path cleanup (`ProtectedExportWorker.swift:187-213`). Once creation succeeds, every failure is conservatively converted to `outputMayRemainAfterFailure` (`ProtectedExportWorker.swift:198-213`).
- Streaming write, `fsync`, same-FD seek/readback, cryptographic verification against the expected receipt, and only-then evidence transaction remain ordered correctly (`ProtectedExportWorker.swift:200-209`, `116-137`). The `beforeEvidenceCommit` seam is immediately after verification and before the transaction (`ProtectedExportWorker.swift:116-124`).
- The added tests cover canonical digest/display normalization, source-change rejection, existing leaf and terminal symlink protection, post-review collision, independent leaf/digest/fingerprint tampering, injected pre-FD and post-FD failures, verified output before evidence failure, and exactly-one success evidence (`ProtectedExportTests.swift:53-274`).
- The ViewModel island preserves review on direct selected-leaf confirm failure and retains the conservative post-create feedback without modifying production ViewModel source (`WorkspaceViewModelTests.swift:692-740`).

## Verification evidence

No test suite was rerun for this review. The preserved result-bundle summaries were inspected directly:

| Bundle | Observed result |
| --- | --- |
| RED | 14 executed; 13 passed, 1 failed, 0 skipped/expected failures. The sole failure is `testSelectedLeafDigestUsesCanonicalLeafLocator`. |
| GREEN | 19 executed; 19 passed, 0 failed/skipped/expected failures. |
| Regression | 19 executed; 19 passed, 0 failed/skipped/expected failures. |

The implementation report also records a successful signed Debug build, signature verification, the existing App Sandbox and user-selected read/write entitlements, and no task-related entitlement addition. Those build/signing commands were not repeated in this task-scoped review.

## Cannot verify

The required owner-native `NSSavePanel` smoke is still pending. This review cannot verify that a fresh real Save-panel selection in a new Documents child folder reviews successfully, creates one nonempty export, and presents the existing filename-only success dialog. It must remain an outstanding owner action and must not be treated as completed evidence.
