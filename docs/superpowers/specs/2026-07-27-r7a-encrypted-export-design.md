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

## Frozen v1 implementation contract

> **Amendment (2026-08-01):** `ADR-005-save-panel-leaf-export-authority.md`
> supersedes only the destination-identity and final-creation paragraph below
> for outputs selected through the signed macOS `NSSavePanel`. All other v1
> format, encryption, staging, verification, and evidence requirements remain
> unchanged.

- Migration 26 adds `tracker_export_revision (id INTEGER PRIMARY KEY CHECK
  (id = 1), revision INTEGER NOT NULL CHECK (revision >= 0))`, seeded with
  `(1, 0)`. SQLite `AFTER INSERT`, `UPDATE`, and `DELETE` triggers increment
  it once per statement on: `opportunities`, `task_reminders`,
  `opportunity_stage_history`, `opportunity_response_history`, `contacts`,
  `contact_opportunities`, `interactions`, `import_reports`,
  `import_report_rows`, `posting_checks`, `reconciliation_reviews`,
  `reconciliation_results`, `reconciliation_check_operations`,
  `document_references`, `activity_events`, and `deletion_tombstones`.
  Recovery enrollment, archive catalogue, migration history, and export
  outcomes are excluded. Reject revision overflow; the store must not rely on
  manually remembered revision bumps.
- Review captures that revision. Confirm obtains an immutable logical snapshot
  in one deferred read transaction, rejecting before final writing if its
  current revision differs from review. Mutations before confirm return the
  user to review without a final file or completion event; mutations after
  capture cannot alter the immutable staged snapshot.
- Framing is exactly `RPEXPT01` (8 ASCII bytes), `UInt16BE(1)`,
  `UInt32BE(182)`, the 182-byte header, `UInt64BE(payloadLength)`, payload,
  then EOF. Reject unknown version/suite/category/header length, trailing
  bytes, length mismatch, payload under 28 bytes, or payload over 512 MiB.
  Header order is: raw RFC-4122 export UUID (16), Unix milliseconds
  `Int64BE` (8), suite `UInt8(1)`, category `UInt8(1)`, salt (32), SHA-256
  manifest hash (32), SHA-256 payload checksum (32), and AES-GCM combined
  recovery envelope (60).
- Generate a fresh 32-byte content key and 32-byte salt with
  `SecRandomCopyBytes`. HKDF-SHA256 derives a 32-byte wrapping key from the
  operation-memory recovery key, salt, and exact UTF-8 info
  `RekonPursuit/export/wrapping-key/v1`. The envelope is AES-GCM combined
  bytes (12-byte nonce + 32-byte ciphertext + 16-byte tag) over the content
  key with AAD equal to UTF-8 `RekonPursuit/export/header-commitment/v1\0`
  followed by magic, version, header length, export ID, creation time, suite,
  category, salt, manifest hash, and payload checksum. Payload AAD is UTF-8
  `RekonPursuit/export/payload/v1\0`, export ID, version, and manifest hash.
  This format has no signing identity and does not reuse portable-archive
  crypto/framing.
- Payload plaintext is `RPEPAY01` (8 ASCII bytes), `UInt32BE(manifestLength)`,
  `UInt64BE(snapshotLength)`, manifest, and snapshot. The manifest is exactly
  `RPEMAN01` (8 ASCII bytes), raw export UUID (16), `Int64BE(createdAt)`,
  category `UInt8(1)`, `UInt64BE(sourceRevision)`, and SHA-256(snapshot) (32):
  73 bytes total. SHA-256 covers those exact manifest bytes; its fields must
  match the header and immutable capture. The snapshot uses separately named
  `RPEXSNP1` framing, not the archive codec; it excludes deleted material,
  bookmarks/raw local paths, credentials/keys, catalogue data, cache/FTS, and
  source files. Document references have bookmarks stripped and availability
  `relink_required`.
- Destination identity is SHA-256 of UTF-8
  `RekonPursuit/export/destination/v1\0`, parent `st_dev UInt64BE`, parent
  `st_ino UInt64BE`, NFC filename `UInt32BE(length)`, and filename bytes.
  The review fingerprint is SHA-256 of UTF-8
  `RekonPursuit/export/review/v1\0`, version, protected type, category,
  NFC filename length/value, destination identity, and source revision.
  Confirm opens the parent using `O_DIRECTORY|O_NOFOLLOW`, requires matching
  `fstat` device/inode, and creates only with
  `openat(parentFD, filename, O_WRONLY|O_CREAT|O_EXCL|O_NOFOLLOW, 0600)`.
  It verifies final identity during read-back. User-visible output is never
  silently deleted after a later failure.

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
