# VD2-07x — save-panel leaf-authority post-implementation security/privacy review

**Verdict: NEEDS CHANGE — release completion is blocked only by the required owner-native signed `NSSavePanel` smoke.**

Independent, read-only security/privacy review of exactly
`84a99a3df374ceb133b00175cd61285677224e1e..3dc7395752a87bee3a3e61384d36e3416e844db5`.
No implementation security/privacy defect was identified in this range. This
verdict is not an acceptance of the pending native-authority check.

## Evidence reviewed

- ADR-005 and the task brief require exact transient selected-leaf authority,
  no parent/folder authority, exclusive non-following leaf creation, and
  verified-only evidence.
- The reviewed range changes only `ProtectedExportWorker.swift`,
  `ProtectedExportTests.swift`, and the released feedback-test hunk; it has no
  entitlement, bookmark, schema/migration, persistent-storage, or production
  ViewModel change. `git diff --check 84a99a3 3dc7395` is clean.
- The independent post-QA record reports its focused selectors passed 20/20
  (zero failures, skips, or expected failures). This reviewer did not rerun
  tests and treats that record as supporting, not replacement, evidence.

## Security and privacy result

1. **Selected-leaf least privilege and scope lifecycle — pass.** Review and
   create each call `startAccessingSecurityScopedResource()` on the selected
   leaf URL and conditionally stop it with `defer`. The former parent open,
   parent device/inode binding, `fstatat`, `openat`, and parent-identity
   continuity checks are removed. The in-memory v2 SHA-256 binding is over the
   standardized, NFC selected-leaf pathname; confirm recomputes both the
   digest and fingerprint before staging/output.
2. **No overwrite, symlink, or selected-path cleanup — pass.** `lstat` treats
   every existing terminal leaf, including a symlink, as occupied. Final
   creation is direct selected-leaf `open(..., O_RDWR | O_CREAT | O_EXCL |
   O_NOFOLLOW, 0600)`; `EEXIST` maps to the no-overwrite rejection. The only
   `removeItem` is for the worker-created temporary staging file, never the
   selected pathname. The focused tests cover terminal symlink sentinel bytes,
   post-review collision, and `ENOTDIR` unavailable handling.
3. **Error boundaries and verified-only evidence — pass.** A failed direct
   leaf open before a descriptor returns `destinationUnavailable` (or
   `destinationExists` for `EEXIST`). Once a descriptor was created, failures
   return the conservative `outputMayRemainAfterFailure`; there is no retry,
   overwrite, or selected-name deletion. Final-FD `fstat`, `fsync`, same-FD
   read-back, and cryptographic verification occur before the sole evidence
   transaction. The `beforeEvidenceCommit` test exercises verified output with
   zero protected-export/activity evidence on failure.
4. **Persistence and audit privacy — pass.** The only new authoritative
   locator material is transient `ProtectedExportReview.destinationURL` plus
   an in-memory digest/fingerprint. The evidence transaction records IDs,
   fixed category/destination class, hashed confirmation fingerprint, outcome,
   and timestamp; it does not insert a raw destination URL/path or recovery
   key. The range introduces no bookmark, entitlement, schema, or recovery-key
   persistence change.

## Required completion condition — pending, not passed

The designated owner must build and verify the signed Debug app, then in a
fresh local workspace use the real `NSSavePanel` to choose a fresh
`.rekonexport` name in a newly created Documents child folder. Required
redacted evidence is limited to: (1) App Sandbox and the existing
user-selected read/write entitlement are present, with no task-related
entitlement added; (2) review succeeds without folder-unavailable feedback;
(3) confirm creates one nonempty export and presents the filename-only success
state. Do not record/share a recovery key, full path, export contents, or
database. Until that owner run is supplied and independently reviewed,
VD2-07x must remain **NEEDS CHANGE** and incomplete.
