# VD2-07x Save-panel leaf authority — architecture re-gate 3

**Date:** 2026-08-01
**Role:** Fresh independent Architect
**Verdict:** **ACCEPT** — pre-implementation architecture release only.

## Evidence reviewed

- ADR-005 and the amended frozen export specification.
- The current leaf-authority implementation plan and task brief.
- The current v1 worker contract in
  `RekonPursuitCore/Workspace/ProtectedExportWorker.swift`.
- The core fixture/test surface and the clean feedback-test island in
  `RekonPursuitTests/WorkspaceViewModelTests.swift:706-860`.
- The revised QA proof requirements, including executable RED, review-tamper,
  post-verification/pre-evidence, result-bundle, and signed-owner-smoke
  requirements.

No source or test code was changed by this review.

## Decision and architectural evidence

The current worker is intentionally the unrepaired v1 implementation: it
opens and identifies the parent at review and confirmation, derives its digest
from parent device/inode data, and uses `openat`. That is the diagnosed
sandbox-authority defect; it is not behavior that this task must preserve.

The revised plan and task brief now conform exactly to ADR-005:

| Contract | Required implementation result | Disposition |
| --- | --- | --- |
| Selected authority and digest | Review uses the exact transient `NSSavePanel` leaf URL, validates its NFC final filename, and hashes UTF-8 `RekonPursuit/export/leaf-destination/v2\0` plus the lexically standardized NFC leaf path. It does not resolve, open, stat, bind, or inspect an ancestor. The path itself includes the NFC filename, while the fingerprint binds the filename separately. | **Accept.** The independent decomposed-Unicode RED directly proves this v2 binding and cannot be satisfied by the existing parent-identity implementation. |
| Confirmation binding | Confirmation recomputes the leaf digest and existing fingerprint inputs—protected-export type, fixed category, NFC filename, digest, and captured revision—before staging or final creation. Locator-only, digest-only, and fingerprint-only substitution each reject as `destinationChanged`; a revision change remains `sourceChanged`. | **Accept.** The narrow, test-local immutable reconstruction helper does not make review data mutable and does not expand production or persistence interfaces. |
| Final creation and failures | Only the reviewed leaf is created with `open(path, O_RDWR | O_CREAT | O_EXCL | O_NOFOLLOW, 0600)`. `EEXIST`, including a terminal symlink or occupied leaf, remains no-overwrite; another failure before descriptor assignment is unavailable-destination; failures after descriptor assignment are conservative may-remain results. | **Accept.** The plan removes the parent descriptor, parent identity, `fstatat`, parent comparison, and `openat` from the protected-export path, with no retry, overwrite, or pathname cleanup. |
| Verification and evidence | Final-FD `fstat`, streaming, `fsync`, same-FD read-back, and encrypted-package verification remain. The single export/activity transaction follows verification. | **Accept.** The immutable default-`.none` `beforeEvidenceCommit` fault is worker-local and fires after successful verification but before evidence. Its independent output-verification/no-evidence test is sufficient architecture proof of the ordering boundary. |
| Privilege and scope | The one-step panel, filter, default filename, folder-creation capability, existing selected-file entitlement, and leaf-only `startAccessingSecurityScopedResource` usage remain. No folder authority, bookmark, persistent selected URL, raw path/key evidence, UI, Store, schema, entitlement, or signing change is authorized. | **Accept.** The mandatory signed Debug owner smoke remains the only proof of macOS-issued Save-panel authority; unit tests do not claim to mint that authority. |

## QA amendments and architectural effect

The new executable canonical-leaf RED, three immutable review-tamper cases,
post-verification/pre-evidence fault, and separately inspected RED/GREEN/
regression bundles make the proof plan more precise. They do not alter
ADR-005's authority, digest, fingerprint, direct-create, no-overwrite, or
evidence contracts. No additional ADR is required for this exact
implementation.

## Enforced source boundary

Implementation is released only as one atomic three-file slice:

1. `RekonPursuitCore/Workspace/ProtectedExportWorker.swift`
2. `RekonPursuitCoreTests/ProtectedExportTests.swift`
3. the clean protected-export feedback island and adjacent helpers only at
   current `RekonPursuitTests/WorkspaceViewModelTests.swift:706-860`

The two obsolete parent-review tests may be removed, and the pre-descriptor
model test may be renamed/reasserted as direct selected-leaf feedback, only in
that clean island. `WorkspaceViewModel.swift` remains inspection-only. The
implementer must recheck `git diff -U0 -- RekonPursuitTests/WorkspaceViewModelTests.swift`
immediately before editing and stop for an integration plan if a dirty hunk
overlaps the island; staging must retain only this slice.

## Residual limitation and postimplementation condition

This decision deliberately makes no parent-directory device/inode continuity
claim. Parent replacement or permission loss may make the selected leaf
unavailable; it must fail truthfully. A folder chooser, recursive authority,
bookmark, entitlement/signing change, parent operation, canonicalization or
fingerprint deviation, overwrite/cleanup behavior, or raw-path/key/export-data
persistence requires a new ADR and fresh architecture review.

This acceptance does not approve implementation, tests, or owner outcome. A
fresh implementer may begin only after independent TPM, QA/test,
security/privacy, and Delivery Manager release gates accept. Postimplementation
architecture verification must inspect the changed code, result bundles, and
redacted signed owner-native smoke.
