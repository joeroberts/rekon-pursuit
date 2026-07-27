# RP-R7a-2 — Portable archive snapshot and authenticated package

**State:** In progress — released for portable archive package implementation only
**Depends on:** `RP-R7a-1` accepted; [ADR-001](../../architecture/adr/ADR-001-local-data-lifecycle.md), the [lifecycle contract](../../architecture/local-data-lifecycle-contract.md), and the [R7a recovery design](../../superpowers/specs/2026-07-27-r7a-portable-recovery-design.md)  
**Blocks:** Restore-as-new-workspace and both export flows  
**Implementation release requires:** Independent Planning, Architect,
Security/Privacy, TPM, QA, and Delivery Manager approval.

## Outcome

An enrolled user can choose a new local destination and create one **portable
encrypted recovery archive**. Rekon Pursuit asks for the recovery key for that
operation, creates and verifies an authenticated logical snapshot package, and
shows a safe local catalogue row: filename, creation time, fixed 30-day expiry,
and `Verified` state. A failed or cancelled operation leaves the active
workspace and every prior catalogue row unchanged.

This task creates and catalogues an archive only. It does not open, restore,
switch to, export from, purge, rewrite, or remove an archive.

## Fixed boundaries

- Operate only on a ready active workspace with an existing recovery
  enrollment. The recovery key must be re-entered for this operation and held
  only in operation memory. No key, plaintext archive key, database key,
  OAuth token, raw user content, full path, or document bookmark may enter a
  header, manifest, catalogue, activity event, diagnostic, or fixture.
- Capture a **versioned logical snapshot**, never `workspace.sqlite`, a WAL,
  SQLCipher ciphertext, or a database key. It contains active workspace data
  and only the privacy-minimized audit/tombstone metadata needed for future
  import. Content already logically deleted at snapshot time is excluded.
  An archive made before a later deletion can still retain the then-active
  content; R7b owns expiry removal and purge.
- Document-reference metadata may be present, but bookmark bytes are omitted
  and every snapshot document reference is marked relink-required. No source
  document is copied or opened.
- Use only `SecRandomCopyBytes` and CryptoKit SHA-256, HKDF-SHA256, AES-GCM,
  and Curve25519 signing. No dependency, cloud service, network entitlement,
  or custom cryptographic primitive is introduced.
- The existing same-Mac backup, restore-in-place, and direct CSV-export routes
  remain unreachable. Do not invoke or migrate their files or database logic.

## Package and catalogue contract

1. Generate a random 32-byte content key and a random 32-byte per-archive
   salt with `SecRandomCopyBytes`. AES-GCM seals the versioned snapshot.
   HKDF-SHA256 derives a 32-byte wrapping key from the operation recovery key,
   salt, and the exact UTF-8 info value
   `RekonPursuit/portable-archive/wrapping-key/v1`. AES-GCM seals the content
   key in the recovery envelope. The content, wrapping, and supplied recovery
   keys exist only for the operation and are discarded on every exit path.
2. A portable archive is one new regular file with the `.rekonarchive`
   extension. Its application-owned **v1 package framing** is specified below;
   this is a versioned container boundary, not a new cipher, KDF, or ambiguous
   serialization. The parser accepts exactly one v1 framing and rejects an
   unknown suite/version, a noncanonical length, duplicate/trailing bytes, or
   any field above its stated bound.
3. The readable outer header contains only archive ID, format version,
   created/expiry timestamps, salt, manifest hash, ciphertext checksum,
   recovery envelope, signing public key/fingerprint, and signature. It
   contains no user content, full local path, recovery key, database key, or
   plaintext content key.
4. The encrypted manifest contains only IDs, versions, timestamps, checksums,
   recovery-envelope hash, signing-key fingerprint, and privacy-minimized
   retained-deletion inventory summary. The signing key signs the manifest hash
   plus the defined signature preimage. The public key travels in the header.
5. A workspace-scoped Curve25519 signing key is created on first archive and
   retained in the Data Protection Keychain. It is not a recovery key and is
   never exported. Its service is
   `com.rekonlabs.RekonPursuit.portable-archive-signing.v1`; its account is the
   lowercase hex SHA-256 of the byte concatenation of the exact UTF-8 domain
   `RekonPursuit/portable-archive/signing-account/v1\\0` and the UTF-8
   workspace ID. It uses `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.
   If a catalogue exists and this signing key is missing, the app fails closed
   rather than silently replacing that identity. The test double may be
   injected only through the archive-key-store protocol, never a launch
   argument or environment switch.
6. Persist a catalogue migration with an opaque security-scoped destination
   bookmark (not a path), display filename, archive ID, format version,
   created/expires timestamps, verification state, ciphertext checksum, and
   signing-key fingerprint. The archive is written to a newly selected,
   non-existing target only; no existing target is overwritten.
7. Write a temporary sibling package, read it back in the same operation, and
   verify header structure, signature, checksum, recovery-envelope unwrap, and
   in-memory snapshot decode before atomically promoting the file and its
   catalogue row. Store only a redacted `portable_backup_created` or failure
   outcome activity event with archive ID and outcome category.

## Frozen v1 archive encoding and snapshot projection

All integers below are unsigned big-endian except the explicitly signed
millisecond timestamps. `Data` fields are raw bytes; a fixed-size field must
have exactly that size. The archive ID is a UUID's 16 raw RFC-4122 bytes. The
format has no optional fields in v1.

1. The outer file is exactly: `RPARCH01` (8 ASCII bytes), format version
   `UInt16(1)`, header length `UInt32(317)`, the 317-byte header, payload
   length `UInt64`, then the payload bytes and EOF. Payload length must be at
   least 28 bytes (an AES-GCM combined nonce/tag) and no larger than 512 MiB.
2. The fixed 317-byte header is, in order: archive ID (16), created-at Unix
   milliseconds (`Int64`), expires-at Unix milliseconds (`Int64`), suite
   `UInt8(1)`, salt (32), SHA-256(manifest bytes) (32),
   SHA-256(payload combined bytes) (32), Curve25519 signing public key (32),
   SHA-256(signing public key) (32), recovery-envelope AES-GCM combined bytes
   (60), and Curve25519 signature (64). `expiresAt` must equal
   `createdAt + 30 * 24 * 60 * 60 * 1000` exactly. The archive checksum means
   SHA-256 of the payload's AES-GCM `combined` bytes only; it never includes
   the outer header or archive file itself.
3. The header commitment is exactly the concatenation of the UTF-8 domain
   `RekonPursuit/portable-archive/header-commitment/v1\\0`, outer magic,
   format version, fixed header length, then header fields through and
   including signing-key fingerprint. It excludes the envelope and signature.
   It is the AAD when sealing and opening the recovery envelope. The signature
   preimage is exactly the UTF-8 domain
   `RekonPursuit/portable-archive/signature/v1\\0`, then the header
   commitment, then the 60-byte recovery-envelope combined value. The signing
   public key verifies that signature; its SHA-256 must equal the header
   fingerprint before the signature is trusted.
4. The payload plaintext is exactly: `RPPAYLD1` (8 ASCII bytes), manifest
   length `UInt32`, snapshot length `UInt64`, manifest bytes, snapshot bytes.
   It is sealed with the content key using AES-GCM and payload AAD equal to
   the UTF-8 domain `RekonPursuit/portable-archive/payload/v1\\0`, archive ID,
   format version, and SHA-256(manifest bytes). The manifest/snapshot lengths
   are bounded to 8 MiB and 480 MiB respectively and their sum must exactly
   match the plaintext length.
5. Manifest and snapshot use the same deterministic length-prefixed value
   codec: tag (`UInt8`), byte length (`UInt32`), then raw bytes, with strings
   encoded as unnormalised UTF-8 and absent optionals represented by tag zero
   and zero length. Maps/tables are emitted in the fixed order below; rows are
   ordered by their primary-key tuple using bytewise UTF-8 comparison. Dates
   are signed Unix milliseconds. Floating compensation values are encoded as
   IEEE-754 binary64 big-endian; no textual number representation is allowed.
   This preserves entered text without locale-dependent transformation.
6. Snapshot v1 contains, in this exact table order, only rows associated with
   active opportunities or active contacts: `opportunities`,
   `task_reminders`, `opportunity_stage_history`,
   `opportunity_response_history`, `contacts`, `contact_opportunities`,
   `interactions`, `import_reports`, `import_report_rows`, `posting_checks`,
   `reconciliation_reviews`, `reconciliation_results`,
   `reconciliation_check_operations`, `document_references`, and
   `activity_events`. A linked row is omitted if any non-null opportunity or
   contact subject is absent from the snapshot. `deletion_tombstones` follows
   those tables and contains only its existing four privacy-minimized fields.
   `schema_migrations`, `migration_history`, `workspace_metadata`,
   `recovery_enrollment`, any future backup catalogue, and all
   `document_references.bookmark_data` bytes are excluded. Included document
   references encode the existing metadata with `bookmark_data` absent and
   availability fixed to `relink_required`.
7. `WorkspaceStore` captures this projection while holding its serialized
   store lock and within a new SQLite deferred read transaction that spans all
   projection queries. It must roll back/close that read transaction before
   file writing begins. No raw database file, WAL, or mutable cursor may escape
   that boundary. The implementation must add a table/column registry whose
   ordered column list is covered by one deterministic snapshot fixture; use
   of `SELECT *`, dictionary iteration, `JSONEncoder`, or locale-sensitive
   formatting is prohibited.
8. The selected destination must be accessed through a user-granted
   read/write security scope only while creating/verifying the archive. The
   temporary sibling has a generated name and is opened with exclusive-create
   semantics. On cancellation or failure it is removed best effort; a final
   archive and a catalogue/activity success record are created only after
   read-back verification succeeds. If final rename or catalogue transaction
   fails, no new catalogue row is committed and the app reports a truthful
   recoverability failure; it must not overwrite or remove an earlier archive.

## Required implementation shape

| Area | Expected responsibility |
| --- | --- |
| `RekonPursuitCore/Workspace/WorkspaceModels.swift` | Versioned snapshot, archive-header/manifest, catalogue-row, and typed archive errors. |
| `RekonPursuitCore/Workspace/PortableArchiveService.swift` (new) | Canonical encoding, key derivation, sealing, package write/read-back verification, and temporary-artifact cleanup. |
| `RekonPursuitCore/Security/ArchiveSigningKeyStore.swift` (new) | Workspace-scoped signing-key read/create policy with an injected deterministic test double. |
| `RekonPursuitCore/Workspace/Migrations.swift` | Additive catalogue migration and rollback-safe checksum/history entry. |
| `RekonPursuitCore/Workspace/WorkspaceStore.swift` | Consistent logical snapshot capture, catalogue transaction, safe activity, and catalogue read API. |
| `RekonPursuit/WorkspaceViewModel.swift`, `RekonPursuit/ContentView.swift` | Explicit create action, recovery-key re-entry, native destination choice, and read-only catalogue display. No restore/export UI. |
| `RekonPursuitTests/PortableArchiveTests.swift` (new) and focused store/view-model tests | Deterministic crypto/filesystem seams and release evidence below. |

The Architecture gate must approve the exact canonical encoding, signing-key
namespace, snapshot field list/order, and catalogue locator representation
before code is released. An implementer may not substitute an ad-hoc JSON,
database copy, or unbound Keychain account.

The same gate must name the exact byte sequence covered by `archiveChecksum`
and its encoding/version. It must exclude any self-referential checksum field.
The archive tests must compute and mutate those canonical bytes directly; a
passing round trip alone is not evidence that the binding is correct.

## Focused acceptance evidence

- A deterministic active-data fixture with opportunities, contacts, tasks,
  histories, one logical deletion/tombstone, and a document reference proves
  canonical snapshot ordering, deleted-content exclusion, and
  bookmark-stripping/relink-required behavior.
- Enrolled-key re-entry plus a fresh destination creates exactly one verified
  package/catalogue row. `expiresAt` is exactly `createdAt + 30 × 24 hours`;
  relaunch retains only the safe catalogue facts; the source workspace is
  unchanged.
- No enrollment, malformed/wrong key, cancellation, existing destination,
  snapshot/encoding/encryption failure, each temporary-write stage, read-back
  failure, and catalogue-transaction failure leave no promoted new package or
  row and preserve all prior rows/workspace state.
- Fixture mutation of header, ciphertext, envelope, manifest, checksum,
  signing public key, signature, and an archive/envelope pair causes read-back
  rejection. The operation never labels such a package `Verified`.
- Redaction inspection proves all visible package metadata, catalogue rows,
  activity, errors, and fixtures exclude secrets, raw content, full paths, and
  bookmark bytes.
- A Debug macOS build plus product-owner smoke proves: Settings → create
  recovery archive → re-enter key → choose fresh destination → see a verified
  catalogue row. The smoke must not attempt opening/restoring/exporting it.

### Deterministic QA case set

These are focused in-process test scenarios, not additions to the historical
M0 fixture manifest. They use a fixed clock, deterministic IDs, an injected
archive/crypto/file seam, and synthetic workspace records. No valid recovery
key or raw key bytes are committed to a fixture, package, activity, or log.

| Case | Required proof |
| --- | --- |
| `ARCHIVE-VALID-001` | A verified enrolled operation writes one package and one safe catalogue row; the logical snapshot is canonical, excludes pre-existing logical deletions, strips bookmark bytes, and preserves the active source workspace. |
| `ARCHIVE-RETENTION-001` | `expiresAt` is exactly `createdAt + 30 × 24 hours`; a relaunch retains only safe catalogue facts. |
| `ARCHIVE-FAIL-001` | No enrollment, wrong/malformed key, cancel, existing destination, each temporary-write failure, read-back failure, and catalogue-transaction failure leave no promoted package/row and preserve all prior rows/source state. |
| `ARCHIVE-BINDING-001` | Mutation of each bound component—canonical header field, ciphertext, envelope, manifest/hash, checksum-covered bytes, signing public key, signature, or archive/envelope pairing—rejects before catalogue promotion. |
| `ARCHIVE-REDACTION-001` | Searches of readable header/catalogue/activity/error output/test fixture artifacts find no raw recovery key, database key, OAuth token, full path, bookmark bytes, or known plaintext opportunity content. |

## Explicit exclusions

- Any archive restore, import, new-workspace creation, workspace switch, or
  archive-file relink/open flow.
- Encrypted export, unencrypted export, warnings/final export review, or CSV
  export.
- Expiry jobs/removal, backup rewrite, retained-data purge, physical-deletion
  claims, or deletion-workflow changes.
- Cloud sync, network requests, new integration permissions, AI, Gmail,
  Calendar, source-document copying, or preserved-legacy-workspace access.

## Release rule

This brief alone does not release implementation. After independent gate
approval, Delivery may move only `RP-R7a-2` from **Next up** to **In progress**
and release one fresh implementer. A separate code reviewer, QA verifier,
Architect/Security verifier, and product-owner hands-on acceptance are required
before restore planning may begin. Dashboard and ledger move only with that
actual state transition.
