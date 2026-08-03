# VD2-07x Save-panel leaf authority — post-implementation architecture verification

**Date:** 2026-08-01  
**Role:** Fresh independent post-implementation Architect verifier  
**Verdict:** **ACCEPT — the scoped implementation conforms to ADR-005.**

This is architecture acceptance of commit range
`84a99a3df374ceb133b00175cd61285677224e1e..3dc7395752a87bee3a3e61384d36e3416e844db5`,
not completion acceptance for V2-07x. The mandatory signed owner-native
`NSSavePanel` smoke remains pending and must not be reported as passed or
complete.

## Scope and evidence reviewed

- ADR-005, the released Task 1 brief, the independent post-implementation QA
  result, and the supplied range review package.
- The exact Git range, which changes only
  `RekonPursuitCore/Workspace/ProtectedExportWorker.swift`,
  `RekonPursuitCoreTests/ProtectedExportTests.swift`, and the released
  protected-export feedback-test hunk in
  `RekonPursuitTests/WorkspaceViewModelTests.swift`.
- The production worker at `3dc7395`; the current worker and core test file
  match that commit. `RekonPursuit/WorkspaceViewModel.swift` is unchanged by
  the reviewed range.
- The existing post-QA result bundle was independently inspected through both
  xcresult summary and resolved-test views: 20 of 20 selected tests passed,
  with zero failures, skips, or expected failures. No new test suite was run by
  this architecture review. Range `git diff --check` reported no whitespace
  error.

No source, test, index, branch, or delivery record other than this independent
architecture review was modified.

## Architectural verification

| Required contract | Evidence in the scoped implementation | Result |
| --- | --- | --- |
| Exact selected-leaf authority | Review and confirm call `startAccessingSecurityScopedResource()` on the exact selected URL. Production removes `ProtectedExportParentIdentity`, parent descriptor acquisition, ancestor `fstat`, `fstatat`, parent comparison, `currentIdentity`, and `openat`. The only destination probe is terminal-leaf `lstat`, and the only final external creation uses the reviewed leaf path directly. Sandbox-temporary staging remains internal and does not broaden final external-write authority. | **Accept** |
| Canonical digest and fingerprint binding | `destinationIdentityDigest(for:)` hashes the UTF-8 bytes of `RekonPursuit/export/leaf-destination/v2\0` followed by `standardizedFileURL.path.precomposedStringWithCanonicalMapping`. The separately bound filename is NFC. Confirm recomputes the digest and the existing fingerprint inputs—format/export type, fixed category, filename, digest, and captured revision—before destination probing, snapshot staging, or final creation. Locator-only, digest-only, and fingerprint-only substitutions resolve as `destinationChanged`; source revision remains a separate pre-write `sourceChanged` check. | **Accept** |
| No parent identity, operation, or continuity claim | No parent device/inode value, parent descriptor, ancestor identity check, or parent-continuity success condition remains in the production protected-export path. The unchanged user-facing folder wording and fixed `selected_local_folder` audit classification do not encode an ancestor identity or continuity assertion. The implementation truthfully promises only a newly and exclusively created selected leaf at confirmation time. | **Accept** |
| Direct no-overwrite contract | The final open is exactly `O_RDWR | O_CREAT | O_EXCL | O_NOFOLLOW` with `S_IRUSR | S_IWUSR` (`0600`). `errno` is captured immediately after failure; `EEXIST` maps to collision and every other pre-descriptor open failure maps to unavailable destination. The terminal `lstat` probe distinguishes existing, absent, and unavailable leaves; the final exclusive open remains the race-safe authority. After descriptor creation, all failures collapse to the conservative may-remain result. No retry, overwrite, or selected-path deletion was added. | **Accept** |
| Verification and evidence ordering | After exclusive creation, the worker retains final-FD `fstat`, streaming write, `fsync`, second final-FD `fstat`, descriptor rewind, and same-FD read-back. It then runs `ProtectedExportService.verify` on those read-back bytes and requires the receipt to match. The `beforeEvidenceCommit` seam fires only after that verification and before the single export/activity transaction. Only after successful verification does the transaction write one verified export row and one verified activity row; the destination URL/raw path and recovery-key material are not inserted. | **Accept** |
| No architectural expansion | The range adds no folder chooser, bookmark, persisted locator, entitlement, signing, schema, Store API, production ViewModel, panel workflow, network/provider, or broader file-authority change. The immutable default-`.none` worker fault is test-only in selection and introduces no production configuration surface. | **Accept** |

## Findings and ADR disposition

No architectural defect was found in the reviewed range. The P2 correction
that maps non-`ENOENT` terminal-leaf lookup failures, including `ENOTDIR`, to
unavailable destination is consistent with ADR-005 and avoids falsely calling
an inaccessible locator an occupied leaf.

No new ADR amendment is required. The implementation is the direct execution
of accepted ADR-005 and does not introduce a new authority, persistence,
interaction, privacy, or evidence decision. A future folder chooser, bookmark,
recursive authority, entitlement change, parent identity/continuity claim, or
different digest/fingerprint contract would require a new amendment and fresh
architecture review.

## Remaining completion blocker

The designated owner must still build and use the correctly signed Debug app
with a fresh local workspace and the actual `NSSavePanel`, select a fresh name
inside a newly created Documents child folder, and record redacted evidence
that review appears and confirmation creates one nonempty export with the
existing filename-only success dialog. This owner-native smoke is mandatory
because unit tests cannot mint macOS Save-panel authorization. Until that
evidence is supplied and independently reviewed, V2-07x remains incomplete
despite this architecture acceptance.
