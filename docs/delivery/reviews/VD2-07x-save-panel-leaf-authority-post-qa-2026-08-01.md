# VD2-07x — save-panel leaf-authority post-implementation QA

**Verdict: NEEDS CHANGE — completion blocked only by the required owner-native NSSavePanel smoke.**

This is an independent, read-only QA review of commit range
`84a99a3df374ceb133b00175cd61285677224e1e..3dc7395752a87bee3a3e61384d36e3416e844db5`.
The range changes only `ProtectedExportWorker.swift`, `ProtectedExportTests.swift`,
and the released feedback-island hunk in `WorkspaceViewModelTests.swift`. Unrelated
dirty-worktree changes were not included in the range review. The scoped core
production/test files currently match `3dc7395`; the checked feedback tests are
unchanged from that commit, although the broader view-model test file has unrelated
working-tree edits.

## Independent result

No implementation defect was found in the reviewed range. The code obtains a
canonical selected-leaf path digest using the v2 domain separator, validates the
review digest/fingerprint before any output, probes the leaf with `lstat`, and makes
the final write with exclusive `O_NOFOLLOW` creation. It reads the saved bytes back
through the final FD and independently verifies them before the sole evidence
transaction. The P2 correction correctly treats a non-`ENOENT` leaf lookup (including
`ENOTDIR`) as unavailable instead of collision.

The one remaining release blocker is not testable by this verifier: the designated
owner must run the signed app in a fresh local workspace, use the actual
`NSSavePanel` to select a new name in a newly created Documents child folder, and
record redacted evidence that review and confirm succeed. It remains **pending**, not
passed. No recovery key, user path, export, or database was exposed in this review.

## Historical RED/GREEN evidence inspected

All bundle views below were inspected with both `xcrun xcresulttool get test-results
summary` and `xcrun xcresulttool get test-results tests`.

| Bundle | Result | Evidence |
| --- | --- | --- |
| `/private/tmp/rekon-vd207x-save-panel-leaf-red.xcresult` | Expected RED | 14 executed: 13 passed, 1 failed, 0 skipped, 0 expected failures. The sole failure was `testSelectedLeafDigestUsesCanonicalLeafLocator`, the intended old parent-v1 versus canonical leaf-v2 digest assertion. |
| `/private/tmp/rekon-vd207x-save-panel-leaf-green.xcresult` | GREEN | 19 passed of 19; 0 failures, skips, or expected failures. The resolved list includes the canonical digest, collision/symlink, tamper, source-change, direct-leaf, post-create, before-evidence, and three feedback tests. |
| `/private/tmp/rekon-vd207x-save-panel-leaf-regression.xcresult` | Regression GREEN | 19 passed of 19; 0 failures, skips, or expected failures. |
| `/private/tmp/rekon-vd207x-leaf-probe-red.xcresult` | Expected P2 RED | 1 executed, 1 failed, 0 skipped/expected failures. `testLeafProbeENOTDIRBeforeOutputUsesDestinationUnavailableWithoutEvidence` observed `destinationExists` before the correction. |
| `/private/tmp/rekon-vd207x-leaf-probe-green.xcresult` | P2 GREEN | The exact ENOTDIR test passed: 1 of 1, zero failures/skips/expected failures. |
| `/private/tmp/rekon-vd207x-leaf-probe-focused-green.xcresult` | P2 focused regression | 20 passed of 20; 0 failures, skips, or expected failures, with the full core suite and all three feedback tests resolved. |

## Fresh independent test evidence

Ran the required focused suite with unique post-QA output paths:

```sh
xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit \
  -configuration Debug -destination 'platform=macOS,arch=arm64' \
  -only-testing:RekonPursuitTests/ProtectedExportTests \
  -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testProtectedExportInvalidFilenameUsesExactCorrectionMessage \
  -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testProtectedExportUnavailableSelectedLeafConfirmUsesExactCorrectionMessage \
  -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testProtectedExportPostCreateFailureRetainsMayRemainFeedback \
  -derivedDataPath /private/tmp/rekon-vd207x-postqa-dd \
  -resultBundlePath /private/tmp/rekon-vd207x-postqa.xcresult
```

`/private/tmp/rekon-vd207x-postqa.xcresult` was then inspected with both xcresulttool
summary and tests views. Result: **20/20 passed**, 0 failed, 0 skipped, 0 expected
failures. This is 17 `ProtectedExportTests` plus all three specified
`WorkspaceViewModelTests` feedback cases. `git diff --check` completed cleanly for
the worktree, and `git diff --check` on the reviewed range was also clean.

## Acceptance-edge verification

| Acceptance edge | Independent verification |
| --- | --- |
| Unicode canonical selected-leaf digest | `testSelectedLeafDigestUsesCanonicalLeafLocator` passed in fresh test, and the worker uses `standardizedFileURL.path.precomposedStringWithCanonicalMapping` with `RekonPursuit/export/leaf-destination/v2\\0`. |
| Invalid final name | Passed test asserts the exact correction message, no file, and no verified evidence. |
| Existing leaf and terminal symlink bytes | Existing-target and terminal-symlink tests passed; both retain sentinel bytes and assert zero verified evidence. `lstat` marks any extant terminal leaf as collision. |
| Post-review collision bytes | Passed sentinel-after-review test preserves the sentinel, reports `destinationExists`, and records no evidence. The final `O_CREAT | O_EXCL | O_NOFOLLOW` open remains the race defense. |
| Leaf, digest, fingerprint tamper | All three reconstruction/tamper tests passed; each returns `destinationChanged` before output and before verified evidence. |
| Source revision change | Passed test returns `sourceChanged`, leaves no output, and asserts zero export/event evidence. |
| Direct pre-FD unavailable, including ENOTDIR | Direct selected-leaf fault and ViewModel feedback test passed with the existing unavailable message and retained review. The dedicated P2 RED/GREEN/focused bundles and fresh test show `ENOTDIR` maps to `destinationUnavailable`, with no output/evidence. |
| Post-FD conservative handling | `afterOutputCreation` test passed: output may remain, the conservative message is retained, and there is no verified evidence. |
| Post-verification/pre-evidence ordering | `beforeEvidenceCommit` test passed: saved bytes independently verify, result is `outputMayRemainAfterFailure`, and both `protected_export_events` and filtered verified activity rows remain zero. The worker executes this fault after final-FD read-back verification and before the transaction. |
| Success evidence ordering/count | Successful export test passed: final bytes verify and exactly one verified export row plus one filtered activity row are present. |
| Audit privacy | Static range inspection shows the only protected-export event values are UUID/export ID, fixed category and destination class, hashed confirmation fingerprint, outcome, and timestamp; the activity row contains IDs/timestamp. Neither raw destination URL/path nor recovery-key material is inserted into audit evidence. |

## Release blocker

The owner-native smoke described in the task brief remains an explicit completion
blocker. Do not mark VD2-07x accepted or complete until the designated owner supplies
redacted evidence for the real signed-app `NSSavePanel` flow. This QA verdict may be
upgraded after that evidence is independently reviewed.
