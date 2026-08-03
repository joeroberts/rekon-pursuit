# VD2-07x Save-panel leaf authority — final code review

- **Date:** 2026-08-01
- **Reviewer:** Fresh independent final code reviewer
- **Review range:** `84a99a3df374ceb133b00175cd61285677224e1e..3dc7395752a87bee3a3e61384d36e3416e844db5`
- **Primary review package:** `.superpowers/sdd/2026-08-01-vd207x-save-panel-leaf-authority/review-84a99a3..3dc7395.diff`
- **Controlling artifacts:** Task 1 brief, ADR-005, and Task 1 implementation report
- **Scope:** The three files changed in the selected range only

## Verdict

**Code review approved; not ready to merge or close the delivery task until the mandatory signed owner-native `NSSavePanel` smoke passes.**

No Critical, Important, or Minor code issue was found in the selected range. The outstanding owner-native smoke is an explicit completion blocker required by ADR-005 and the task brief, not a code defect.

## Strengths

- `ProtectedExportReview` now binds only the transient selected leaf URL, source revision, canonical-leaf digest, and confirmation fingerprint. The former parent device/inode type and all parent descriptor, `fstatat`, and `openat` operations are removed.
- Review and confirm derive the v2 digest from the lexically standardized, NFC leaf path with the required domain separator. Confirm independently recomputes both the digest and the fingerprint before any final write, so retained-digest locator substitution, digest substitution, and fingerprint substitution reject as `destinationChanged`.
- The leaf-only `lstat` probe has the correct three-way classification: a successful probe is an occupied leaf, `ENOENT` is absent, and every other failure—including `ENOTDIR`—is unavailable. Both review and confirm use this classification.
- Final creation uses the exact selected path with `O_RDWR | O_CREAT | O_EXCL | O_NOFOLLOW` and mode `0600`. `errno` is captured directly in the failed-open branch, preserving `EEXIST` as the no-overwrite result and mapping other pre-descriptor failures to `destinationUnavailable`.
- Once the final descriptor exists, every failure is conservatively converted to `outputMayRemainAfterFailure`; the worker closes the descriptor but never retries, overwrites, or path-deletes the final leaf.
- Streaming, `fsync`, same-descriptor reset/read-back, independent cryptographic verification, and receipt comparison all precede the evidence transaction. The `beforeEvidenceCommit` seam is immutable, defaults to `.none`, has no production selection mechanism, and proves that independently verifiable bytes can remain while both evidence tables remain empty.
- The focused tests cover canonical NFC binding, source-revision rejection, existing-leaf and terminal-symlink protection, confirm-time collision, exact `ENOTDIR` classification, three distinct review-tamper cases, pre- and post-descriptor failures, verified-only evidence ordering, and the retained ViewModel feedback contract.
- The selected range changes exactly the three released files. `RekonPursuit/WorkspaceViewModel.swift` and Save-panel production behavior are unchanged, and no parent continuity or broader directory authority is reintroduced.

## Findings

### Critical

None.

### Important

None.

### Minor

None.

## Verification evidence reviewed

No suite was rerun for this review because no concrete doubt required it. The preserved result bundles were inspected read-only and corroborate the implementation report:

- Original behavior RED: 14 executed, 13 passed, 1 failed, 0 skipped, 0 expected failures; the only failure was the canonical selected-leaf digest assertion.
- Original focused GREEN and regression: 19 executed and passed in each bundle, with 0 failures, skips, or expected failures.
- `ENOTDIR` correction RED: 1 executed and failed with actual `destinationExists` versus expected `destinationUnavailable`.
- `ENOTDIR` correction GREEN: 1 executed and passed.
- Fresh post-correction focused GREEN: 20 executed and passed, with 0 failures, skips, or expected failures. The resolved test list contains the new `ENOTDIR` regression, the canonical/tamper/evidence tests, and all three required ViewModel feedback selectors.

The implementation report also records a successful signed Debug build and signature verification with the existing App Sandbox and user-selected read/write entitlement, and no task-related entitlement addition.

## Completion blocker

The designated owner must still perform the signed, owner-native smoke through the real `NSSavePanel` using a fresh local workspace and an unshared recovery key. The smoke must demonstrate that a fresh `.rekonexport` selection in a newly created Documents child folder reaches review, confirms to exactly one nonempty export, and shows the filename-only success dialog without retaining the key, raw path, output, or database in review evidence.

Until that succeeds and is recorded in redacted form, this task is **not ready to merge or close**, despite the approved code review.
