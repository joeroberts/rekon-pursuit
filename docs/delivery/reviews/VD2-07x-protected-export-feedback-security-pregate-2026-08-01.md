# VD2-07x protected-export destination feedback — Security/privacy preimplementation gate

**Date:** 2026-08-01

**Role:** Fresh independent Security/privacy verifier

**Verdict:** **ACCEPT**, subject to the non-negotiable implementation and verification constraints below.

## Security conclusion

The amended error split and exact immutable worker fault seam preserve the
existing protected-export local-file safety and privacy model. The change can
remain a classification-and-testability slice: it introduces no new write,
retry, overwrite, destination-normalization, security-scope, cryptographic, or
activity path.

The proposed seam does add an internal constructor choice capable of forcing
failure at sensitive filesystem states. That is acceptable only because the
mode is immutable, defaults to `.none`, has no runtime input, and is consumed
only at fixed worker decision points. It must not become owner-selectable,
environment/configuration driven, persisted, mutable, global, or reachable
through a production factory/API. Postimplementation review must prove every
explicit non-`.none` construction is confined to test code and production
still constructs `ProtectedExportWorker(configuration: ...)` without a fault
argument.

## Boundary assessment

| Security/privacy property | Assessment of planned change | Required implementation result |
| --- | --- | --- |
| Security-scoped access | Safe. Both review and create currently begin scoped access before parent work and conditionally stop it with `defer`. | Evaluate every injected fault after scope acquisition and inside the existing defer lifetime. Do not branch owner copy on the Boolean scope result or expose that result. |
| Parent traversal and identity | Safe. Parent open remains descriptor-relative and protected by `O_DIRECTORY | O_NOFOLLOW`; review binds device/inode, normalized filename digest, and confirmation fingerprint; create recomputes them before final work. | Do not change the parent open flags, identity type/comparison, digest/fingerprint domains, inputs, versions, or comparison order. `parentOpenUnavailable` occurs immediately before the real open. `parentInspectionUnavailable` occurs only after successful open, closes that descriptor, and then throws. |
| No overwrite / symlink resistance | Safe. The real final create remains `openat` with `O_CREAT | O_EXCL | O_NOFOLLOW` and owner-only mode, following existence and current-parent checks. | Preserve the flags, mode, descriptor-relative filename, and order. Keep `fstatat(..., AT_SYMLINK_NOFOLLOW)` conservative: anything other than proven `ENOENT` blocks creation. Capture real `openat` `errno` immediately; retain `EEXIST -> destinationExists`, discard the numeric value, and map another pre-create failure only to `destinationUnavailable`. |
| Review binding | Safe. The fault mode is not part of the reviewed destination or persisted security evidence. | Never store, serialize, hash, fingerprint, log, or expose fault mode. Do not add it to `ProtectedExportReview`, `ProtectedExportRequest`, `ProtectedExportReceipt`, the database, or activity records. The parent-identity guard before `openat` remains `destinationChanged`. |
| Pre-output versus possible-output state | Safe only with the exact placements. A fault before `openat` cannot create an output; a fault after a successful `openat` must conservatively acknowledge that a file may remain. | `exclusiveCreateUnavailable` runs after the unchanged parent-identity guard and immediately before `openat`, without calling it. `afterOutputCreation` runs only after `openat >= 0`, descriptor assignment, and `created = true`, and must flow through the existing catch to `outputMayRemainAfterFailure`. No post-create error may become `destinationUnavailable`. |
| Verified-write-only evidence | Safe. Staging is encrypted and verified, the final descriptor is exclusively created and read back, that data is verified against the receipt, and only then are export and activity rows inserted atomically. | Do not move or split the transaction or insert either row earlier. Invalid-name, parent, pre-create, post-create, verification, or transaction failure returns no receipt and produces no success presentation. Only a real verified final write may create exactly one `protected_export_events` verified row and one `protected_export_verified` activity row. |
| Owner-visible disclosure | Safe. The two new messages are static, controlled copy and the model falls back generically for uncontrolled errors. Success remains filename-only. | Use only the approved exact messages. Never interpolate or log a raw/normalized path, `errno`, scope state, device/inode, digest/fingerprint, export/database identifiers, receipt/manifests, recovery-key data, internal database key, or fault mode. Leave `ProtectedExportService` and its errors unchanged. |

## Error-classification requirements

1. Only failure of the existing final-component predicate becomes
   `.invalidDestinationName`, with exactly
   `Choose a new file name ending in .rekonexport.`
2. A valid-suffix parent `open` or `fstat` failure becomes
   `.destinationUnavailable`, with exactly
   `Rekon Pursuit can’t use that folder. Choose another local folder and review the export again.`
3. A non-`EEXIST` real `openat` failure may become
   `.destinationUnavailable` only while no final descriptor/file was created.
   `EEXIST` remains `.destinationExists`, with byte-preserving no-overwrite
   behavior and its existing copy.
4. `.destinationChanged`, `.sourceChanged`, `.verificationFailed`, and
   `.outputMayRemainAfterFailure` retain their existing meanings. In
   particular, any failure after `created = true`, including final read-back,
   verification, or activity transaction failure, remains may-remain.
5. The worker remains the filesystem-outcome classifier. No raw syscall error
   crosses into `WorkspaceViewModel`; uncontrolled errors retain generic
   fallback copy.

## Fault-seam attack-surface constraints

- Use exactly one internal `Sendable` enum and one `private let faultMode`, with
  the initializer default `.none`. Do not use a closure/syscall adapter,
  protocol abstraction, global/static switch, mutable property, process
  environment, launch argument, preference, persisted value, panel input, or
  other runtime selector.
- Keep production `WorkspaceStore` construction at
  `ProtectedExportWorker(configuration: ...)`; do not add a new store/view-model
  fault parameter or production convenience factory.
- The four checks may only short-circuit their named decision points. They must
  not replace, wrap, reorder, or alter Darwin flags, security-scope acquisition,
  destination existence checks, parent identity/digest/fingerprint work,
  staging/cryptographic verification, database transactions, or message
  mapping.
- `parentInspectionUnavailable` must close the already-open parent descriptor
  exactly once. `afterOutputCreation` must allow the existing descriptor defer
  to close the output and the existing `created` catch to classify may-remain.
- No non-default fault mode may be used by production source. Any explicit
  non-`.none` construction outside focused tests is a release-blocking
  attack-surface expansion requiring fresh Architecture and Security/privacy
  review.

## Required postimplementation security/privacy verification

1. Inspect the exact diff, not only test outcomes, and confirm unchanged
   security-scope lifetime, `O_DIRECTORY | O_NOFOLLOW`, `O_EXCL | O_NOFOLLOW`,
   `AT_SYMLINK_NOFOLLOW`, `S_IRUSR | S_IWUSR`, descriptor closes, parent
   identity/digest/fingerprint code, `created` catch, final read-back
   verification, and verified-event transaction order.
2. Search all Swift production and test sources for
   `ProtectedExportWorkerFaultMode`, `faultMode`, and
   `ProtectedExportWorker(`. Confirm production has only the default
   construction and every explicit non-`.none` mode is test-only. Confirm no
   environment, settings, serialization, logging, or UI route reaches it.
3. Verify deterministic invalid-name and both parent fault cases produce no
   review, final file, verified export row, filtered verified activity, or
   success; both owner messages and status copy are exact and path/diagnostic
   free.
4. Verify the deterministic pre-create case first completes a real bound
   review, then creates no final path/evidence/success and retains the review
   with exact folder-unavailable feedback.
5. Verify the deterministic post-create case leaves the final path present,
   returns only `.outputMayRemainAfterFailure`, records no verified export or
   verified activity, retains may-remain feedback, and never presents success
   or folder-unavailable retry copy.
6. Verify a real pre-existing `.rekonexport` target remains byte-for-byte
   unchanged, receives the exact no-overwrite message, and creates no verified
   evidence/success. Retain parent-binding and source-revision no-file
   regressions.
7. Verify an ordinary default-worker export reads back and cryptographically
   verifies to the returned receipt, then and only then produces exactly one
   verified export row, exactly one filtered verified activity row, and
   filename-only success. Query activity by kind rather than assuming the
   database has no other activity.
8. Inspect the focused GREEN and regression result bundles: every selected test
   executed once and passed with zero skips or expected failures. Confirm the
   changed implementation paths are limited to the four authorized files and
   `ProtectedExportService`, `WorkspaceStore`, `ContentView`, project files,
   persistence/schema, Settings, accessibility, dashboards, and roadmap are
   unchanged by the implementation.
9. Run `git diff --check`. Any changed placement, runtime-selectable seam,
   weakened flag/binding, post-create misclassification, premature activity,
   raw diagnostic disclosure, or scope expansion changes this verdict to
   **NEEDS CHANGE** and blocks delivery.

## Verdict

**ACCEPT.** The amended bounded slice may proceed through the remaining
Delivery/QA release gate and a fresh implementer, provided all constraints
above remain controlling. This verdict approves the exact immutable seam and
error split only; it does not approve an alternate filesystem adapter or any
production-selectable fault mechanism.
