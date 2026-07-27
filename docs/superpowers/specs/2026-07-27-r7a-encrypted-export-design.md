# R7a encrypted-default logical export design

## Decision

`RP-R7a-4` will add one local, encrypted-by-default export of **Tracker
workspace data**. It reuses the already enrolled, user-held recovery key only
at the operation boundary; it does not add a second passphrase, escrow, or
persistent export-key path.

The export is a new versioned `.rekonexport` container. It is not a portable
recovery archive, is never added to the recovery catalogue, and has no expiry,
restore, purge, or workspace-switch behavior. Unencrypted export remains
unreleased in this slice.

## User flow

1. In Settings, the user chooses **Export protected copy**.
2. The app shows the fixed included category, `Tracker workspace data`, and
   asks the user to re-enter the recovery key.
3. A native save panel selects a new `.rekonexport` destination.
4. A review screen shows protected type, included category, exact filename,
   and destination. The confirmation binds all four values.
5. On confirmation, the app writes and read-back verifies the encrypted
   export. It reports success without claiming it is a recovery archive.

Cancellation, malformed/wrong key, a changed review input, an occupied or
unsafe destination, or write/read-back failure produces no successful export
event. A failed user-visible final file is never silently deleted; the result
states that it may need manual removal.

## Data and cryptographic boundary

The export contains a canonical logical projection of active tracker data:
opportunities, tasks/history/responses, contacts and links/interactions,
import/reconciliation records, and document-reference metadata with bookmark
bytes removed and relinking required. It excludes logically deleted payloads,
credentials, OAuth tokens, database/signing/recovery keys, portable archive
catalogue material, document bookmarks, raw full paths, cache/FTS data, and
source files.

For each export, generate a random content key and salt. Derive a wrapping key
from the re-entered recovery key using a dedicated
`RekonPursuit/export/wrapping-key/v1` domain string; protect the content and
envelope with AES-GCM. The container has its own v1 schema, type, ID namespace,
manifest, and authentication binding. It must not reuse the portable archive
salt, envelope, signing account, or archive ID namespace.

## Filesystem and confirmation safety

The worker captures an immutable read-transaction snapshot. It stages only in
app-owned temporary storage, validates its own output, then writes to a new
regular final file with exclusive/no-follow semantics and identity checks.
Read-back decryption, authentication, manifest validation, and snapshot decode
must complete before a success result. The app stores no destination path,
payload, or recovery key; activity stores only type, fixed category identifier,
destination class, confirmation fingerprint, and outcome.

The confirmation fingerprint is SHA-256 over canonical export type, category,
exact final filename, canonical destination identity, and captured source
revision. Any change invalidates review and requires a new confirmation.

## Explicit exclusions

- Portable archive creation, catalogue, restore, activation, or workspace
  switching.
- Unencrypted/CSV export, including revival of the unreachable legacy direct
  CSV path.
- Multiple category selection or encrypted audit-evidence export.
- Backup expiry, retained-data purge, deletion-flow changes, networking, AI,
  or new dependencies.

## Proportionate evidence

Focused checks cover successful deterministic encrypted export/read-back;
wrong/malformed/cancelled recovery key; confirmation invalidation; cancellation;
destination collision/symlink/race; staging/final/read-back/activity failure;
source preservation; and redaction across container, events, and diagnostics.
A signed Debug build plus one product-owner smoke verifies the visible flow.
No coverage target, CI expansion, or unencrypted-export work is part of this
slice.
