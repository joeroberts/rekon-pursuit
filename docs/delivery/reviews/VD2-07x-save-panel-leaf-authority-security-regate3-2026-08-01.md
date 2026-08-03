# VD2-07x Save-panel leaf authority — Security/privacy release re-gate

**Date:** 2026-08-01  
**Role:** Fresh independent Security/privacy verifier  
**Scope:** ADR-005, the amended leaf-authority plan and task brief, the
current protected-export worker/test seams, effective-source entitlement
configuration, and the three-file implementation boundary. No source or test
code was changed by this review.

## Verdict: ACCEPT

The approved repair removes an authority mismatch: the current pre-repair
worker opens, identifies, and creates through a parent directory even though a
signed native `NSSavePanel` save grants the selected file target. The plan and
task brief now constrain the repair to that exact transient leaf and preserve
the existing encrypted, verified-only export contract. This is a
pre-implementation release gate, not a claim that the current parent-based
worker is already fixed.

## Security and privacy findings

| Boundary | Evidence and required implementation result |
| --- | --- |
| Least-privilege native authority | ADR-005 and both delivery artifacts prescribe the exact Save-panel leaf as the sole external-write authority. The current `RekonPursuit/WorkspaceViewModel.swift` retains the same one-step `.rekonexport` `NSSavePanel`, default filename, and directory-creation setting. The worker change must remove `open(parent)`, parent device/inode binding, `fstatat`, parent revalidation, and `openat`; it must not add a folder chooser or recursive directory authority. |
| Destination binding without a path record | Review computes the v2 SHA-256 digest from the domain-separated, lexically standardized NFC leaf path, while the confirmation fingerprint separately includes the NFC filename, digest, category/type, and source revision. Confirmation recomputes both before output creation. The review object holds the URL only in memory; the existing evidence insert records fixed metadata and the fingerprint, not the URL/path. Tests require independent locator-only, digest-only, and fingerprint-only tamper rejection before output/evidence. |
| No overwrite and safe failure boundaries | The specified direct create is `O_RDWR | O_CREAT | O_EXCL | O_NOFOLLOW`, mode `0600`, with immediate `errno` capture. Occupied and terminal-symlink leaves are `EEXIST` no-overwrite failures. A non-`EEXIST` failure before descriptor assignment is unavailable-destination feedback. Once the descriptor exists, all later failure paths are the conservative may-remain result: no retry, overwrite, or selected-path cleanup. Required sentinel, symlink, pre-descriptor, and post-descriptor tests cover these transitions. |
| Verification before audit evidence | The current worker already verifies same-descriptor read-back before its evidence transaction. The amended artifacts further require the immutable default-`.none` `beforeEvidenceCommit` test fault after successful package verification and immediately before that transaction. Its test must independently verify the retained output and prove zero `protected_export_events` plus zero `protected_export_verified` activity. This avoids both a premature success record and an unverifiable final file being presented as success. |
| Persistence and secret hygiene | The source boundary forbids bookmarks, persistent security-scoped material, preferences, schema/activity changes, raw paths, POSIX failures, security-scope results, recovery keys, and export contents. The only new fault cases remain worker-local and immutable, with no runtime setting, environment input, production selection, or new owner-facing API. Existing test-only worker construction does not authorize a new production Store/ViewModel injection. |
| Entitlement discipline and owner proof | `RekonPursuit/RekonPursuit.entitlements` declares App Sandbox plus the existing user-selected read/write entitlement. The task excludes entitlement/signing edits and requires a signed Debug build, strict signature verification, and effective-entitlement readback. The owner smoke must record only a redacted assertion of those existing capabilities and no task-related entitlement addition; raw entitlement output, path, key, database, and export data are prohibited from retained evidence. |

## Required security evidence after implementation

1. Inspect all three distinct RED, GREEN, and regression result bundles and
   their resolved test lists. RED must be a real canonical-leaf binding
   assertion failure only; GREEN and regression must execute the selected tests
   once with zero skips and expected failures.
2. Verify the final diff is restricted to exactly
   `ProtectedExportWorker.swift`, `ProtectedExportTests.swift`, and the clean
   protected-export feedback island in `WorkspaceViewModelTests.swift`; run
   `git diff --check`. Do not accept a ViewModel, entitlement, project,
   bookmark, preference, schema, or dashboard change as part of this repair.
3. Recheck the completed worker for direct leaf-only creation, no parent
   traversal/identity operations, no pathname deletion after output creation,
   NFC/digest/fingerprint revalidation, and conservative no-evidence handling
   after descriptor assignment.
4. Complete the signed owner-native smoke through the actual `NSSavePanel` in
   a new local Documents child folder. It must reach filename-safe review and
   produce one nonempty export without the former folder rejection. Preserve
   only redacted evidence; no recovery key, full path, entitlement dump,
   package data, or workspace database may be retained.

## Residual limitation

This one-step file-selection contract intentionally cannot prove parent
device/inode continuity between review and confirmation. A replaced parent or
permission change must fail truthfully at the selected leaf. That limitation
does not permit restoring parent traversal, storing a bookmark, adding an
entitlement, broadening filesystem authority, or deleting/retrying the chosen
name.

## Release disposition

**ACCEPT.** A fresh implementer may be released for the single three-path TDD
slice after the independent TPM, QA/test, and Delivery Manager release gates
also accept it. Any deviation from ADR-005 or this boundary requires a fresh
architecture and Security/privacy review before implementation.
