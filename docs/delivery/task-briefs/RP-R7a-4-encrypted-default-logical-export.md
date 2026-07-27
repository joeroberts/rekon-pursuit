# RP-R7a-4 — Encrypted-default logical export

**State:** Planning — implementation is not released.
**Depends on:** `RP-R7a-1`, `RP-R7a-2`, `RP-R7a-3`, `RP-R7a-3a`, and
`RP-R7a-3b` accepted; [ADR-001](../../architecture/adr/ADR-001-local-data-lifecycle.md);
and the [local-data lifecycle contract](../../architecture/local-data-lifecycle-contract.md).
**Blocks:** Completion of the wider `RP-R7a` milestone and `RP-R7b`.

## Outcome

The user can create one protected `.rekonexport` copy of the fixed
**Tracker workspace data** category. The app requires re-entry of the existing
recovery key, binds review to the exact protected type/category/filename/
destination/source revision, and verifies the final output before reporting
success.

## Fixed scope and safety boundary

- Reuse the user-held recovery key only in operation memory. Derive a per-export
  wrapping key using a distinct `RekonPursuit/export/wrapping-key/v1` domain
  string, random salt, random content key, and AES-GCM envelope/content.
  There is no export-key enrollment, escrow, reset, or reuse of the portable
  archive's salt/envelope/signing account/ID namespace.
- Use a new versioned `.rekonexport` logical container. It is not an archive,
  never enters the recovery catalogue, and cannot be restored, opened, or used
  to switch workspaces in this task.
- Export active opportunities, tasks/history/responses, contacts/links/
  interactions, import/reconciliation records, and document-reference metadata
  only after bookmark stripping/relink-required conversion. Exclude deleted
  payloads, credentials, OAuth/database/signing/recovery keys, archive
  catalogue data, bookmarks, raw paths, cache/FTS, and source files.
- Implement `StartExport → ReviewExport → ConfirmExport → Write/Verify →
  RecordOutcome`. The review fingerprint covers type, the fixed category,
  exact filename, canonical destination, and source revision. Any mutation
  invalidates confirmation.
- Use an `NSSavePanel` destination. Stage only in app-owned temporary storage;
  create a new final regular file exclusively/no-follow with identity checks;
  read-back decrypt/authenticate/validate/decode before success. Never silently
  delete a user-visible final file after failure.
- Safe activity contains only export type, fixed category ID, destination class,
  confirmation fingerprint, and outcome. It contains no path, payload, key,
  bookmark, or raw error.

## Explicit exclusions

- Unencrypted/CSV export and the legacy direct CSV helper.
- Recovery archive creation/catalogue/restore, candidate activation/switching,
  backup expiry, purge, deletion changes, audit-evidence selection, networking,
  AI, and dependencies.

## Focused evidence

- `EXPORT-ENCRYPTED-001`: deterministic successful export/read-back preserves
  canonical active data/order and excludes sensitive/deleted fields.
- Wrong, malformed, or cancelled recovery-key entry writes no file or success
  event.
- Filename, destination, category, type, or source-revision change invalidates
  confirmation; user cancellation writes no file/event.
- Existing destination, symlink/race, staging/final/read-back/activity failure
  never reports success and preserves the source workspace.
- Redaction fixtures prove container, event, and diagnostics omit secrets,
  full paths, bookmarks, and raw content.
- Signed Debug product-owner smoke: select protected export, re-enter recovery
  key, select fresh destination, review/confirm, and observe verified success.

## Release rule

Planning, Architect/Security, TPM, QA, and Delivery Manager must approve this
brief before implementation. A fresh implementer, separate Code Review,
QA/Architecture-Security verification, and product-owner smoke are required
before `RP-R7a-4` can be accepted. `RP-R7b` remains unreleased.
