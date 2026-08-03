# VD2-07x Save-panel leaf authority — pre-implementation security/privacy gate

**Date:** 2026-08-01  
**Role:** Fresh independent security/privacy verifier  
**Verdict:** **NEEDS CHANGE** — the proposed selected-leaf authority and
verified-write contract are security-appropriate, but the two-file task
boundary conflicts with still-active model tests for the parent-authority
implementation. Release only after that conflict is resolved by a narrowly
approved test-boundary amendment and the signed entitlement check is made an
explicit smoke-evidence step.

## Scope and method

Read `ADR-005-save-panel-leaf-export-authority.md`, the V2-07x leaf-authority
plan and task brief, the local-data lifecycle contract, the current
`ProtectedExportWorker`, the protected-export Store/ViewModel seams and tests,
and the declared signing/entitlement configuration. This is a static,
pre-implementation gate. No production or test code was changed and no tests
were run.

## Security/privacy assessment

| Requirement | Evidence | Disposition |
| --- | --- | --- |
| Least-privilege external authority | ADR-005 makes the transient URL returned by `NSSavePanel` the sole external-write authority and rejects recursive parent authority. The task brief requires removal of `open(parent)`, parent device/inode binding, `fstatat`, identity comparison, and `openat`; the existing declared entitlement includes the already-present user-selected read/write grant. | **Acceptable if implemented exactly.** No entitlement, folder chooser, or parent handle may be added. |
| Leaf binding and persistence boundary | The plan binds the NFC filename, lexically standardized selected-leaf digest, fixed export/category values, and source revision. The brief requires recomputation before write and declares the URL/raw path non-persistent. The current review URL is an in-memory `ProtectedExportReview` field; the existing verified-event insert stores only fixed metadata and a confirmation fingerprint. | **Acceptable if implemented exactly.** The selected URL, raw path, bookmark, security-scope result, key, and package data must not enter a store, preference, activity, audit record, log, attachment, or owner-smoke evidence. |
| No overwrite and selected-leaf cleanup | ADR-005 and the brief require direct `O_RDWR | O_CREAT | O_EXCL | O_NOFOLLOW` creation with mode `0600`; `EEXIST`, including a terminal symlink, is no-overwrite. They further prohibit retry, overwrite, or pathname deletion of the selected leaf after final creation begins. The app-owned temporary encrypted package may still be removed by its existing temporary-file defer. | **Acceptable if implemented exactly.** Tests must preserve regular-file, symlink, and post-review sentinel bytes and prove that a post-create failure leaves any selected output for user handling. |
| Truthful error state | The brief separates a direct-leaf failure before descriptor assignment (`destinationUnavailable`) from every failure after descriptor assignment (`outputMayRemainAfterFailure`). The current worker already has a `created` state boundary and safe static owner copy; the new tests require both injected states. | **Acceptable if implemented exactly.** `errno`, a path, scope status, recovery key, fingerprint, receipt, or export data must not cross the worker/UI boundary. |
| Encryption, read-back, and evidence ordering | ADR-005 retains final-FD `fstat`, streaming, `fsync`, same-FD read-back, cryptographic verification, and then the verified export/activity transaction. The task brief requires exactly one verified event and filtered `protected_export_verified` activity only after verification; all earlier and post-create failures require none. | **Acceptable if implemented exactly.** Do not move the activity or event transaction ahead of package verification, including to report a partial output. |

## Blocking corrections

1. **Resolve the obsolete parent-mode test boundary before release.** The task
   brief both requires removal of the parent-authority flow and prohibits any
   change to `RekonPursuitTests/WorkspaceViewModelTests.swift`. That file still
   constructs `.parentOpenUnavailable` and `.parentInspectionUnavailable` and
   asserts parent-specific review failures; its helpers also accept the old
   `ProtectedExportWorkerFaultMode`. Removing the parent flow as required makes
   those regression tests stale or failing, while preserving parent-specific
   runtime branches merely to satisfy them would retain an invalid authority
   model. Amend the brief with one of these explicit, reviewable paths:

   - authorize a tightly isolated hunk that retires/replaces only those obsolete
     parent-mode model tests and helpers, with a clean-hunk review despite the
     current dirty file; or
   - complete that test migration as a dependency-safe prerequisite, then keep
     this leaf slice at its two-file boundary.

   The amended acceptance suite must prove the remaining before-descriptor
   error through the direct-leaf fault only, retain the post-descriptor
   may-remain model check, and contain no parent descriptor, ancestor probe, or
   runtime-selectable test seam.

2. **Make signed-entitlement readback an explicit owner-smoke check.** The
   task correctly forbids entitlement/signing edits and the project declares
   App Sandbox plus `com.apple.security.files.user-selected.read-write`, but
   `codesign --verify --deep --strict` proves signature validity rather than
   the effective entitlement set. Extend the mandatory signed Debug smoke to
   inspect `codesign -d --entitlements :-` for the built app and record only a
   redacted assertion that the existing user-selected read/write authority is
   present and no task-related entitlement delta occurred. Do not attach a
   path, key, export, database, or unredacted diagnostic output.

## Required re-gate evidence

- Revised controlling brief/plan resolves the model-test conflict without
  restoring a parent authority claim or widening the implementation scope.
- RED and GREEN focused suites show each selector once, with zero skips and
  expected failures, covering selected-leaf success, regular/symlink/sentinel
  no-overwrite, locator/fingerprint and source-revision rejection,
  direct-before-descriptor failure, post-descriptor may-remain, encrypted
  read-back, and verified-only evidence ordering.
- The isolated diff contains no entitlement, signing, bookmark, persistence,
  activity-schema, UI, Store, ViewModel, or selected-leaf pathname-cleanup
  change outside the explicitly re-approved test migration.
- Signed Debug smoke provides redacted build/signature/entitlement evidence and
  owner confirmation of a fresh Save-panel leaf in a Documents child folder,
  without any recovery key, raw path, package content, or database disclosure.

## Release status

**Do not release an implementer yet.** Reissue this security/privacy gate after
the two corrections are incorporated into the controlling task artifacts. The
leaf-authority architecture itself is accepted in principle; this verdict
blocks only the unresolved test/scope contradiction and incomplete signed
entitlement verification.
