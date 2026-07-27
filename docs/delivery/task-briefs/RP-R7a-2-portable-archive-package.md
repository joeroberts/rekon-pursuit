# RP-R7a-2 — Portable archive snapshot and authenticated package

**State:** Next up — planning and high-risk gate only  
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

1. Generate a random content key and per-archive salt. AES-GCM seals the
   versioned snapshot. HKDF-SHA256 derives a wrapping key from the operation
   recovery key and salt; AES-GCM seals the content key in the recovery
   envelope.
2. The readable outer header contains only archive ID, format version,
   created/expiry timestamps, salt, manifest hash, archive checksum, recovery
   envelope, signing public key/fingerprint, and signature. It contains no
   user content, full local path, recovery key, database key, or plaintext
   content key.
3. Define one canonical header commitment before implementation. It includes
   archive ID, format version, salt, manifest hash, signing-key fingerprint,
   archive checksum, creation/expiry timestamps, and all other fixed header
   fields; it excludes envelope and signature. It is the recovery-envelope
   AAD. The signature preimage includes the finalized envelope and canonical
   header fields but excludes only the signature.
4. The encrypted manifest contains only IDs, versions, timestamps, checksums,
   recovery-envelope hash, signing-key fingerprint, and privacy-minimized
   retained-deletion inventory summary. The signing key signs the manifest hash
   plus the defined signature preimage. The public key travels in the header.
5. A workspace-scoped Curve25519 signing key is created on first archive and
   retained in the Data Protection Keychain. It is not a recovery key and is
   never exported. If a catalogue exists and its signing key is missing, the
   app fails closed rather than silently replacing that identity. The exact
   Keychain account namespace and test seam require Architect/Security signoff.
6. Persist a catalogue migration with an opaque security-scoped destination
   bookmark (not a path), display filename, archive ID, format version,
   created/expires timestamps, verification state, archive checksum, and
   signing-key fingerprint. The archive is written to a new selected
   destination only; no existing target is overwritten.
7. Write a temporary sibling package, read it back in the same operation, and
   verify header structure, signature, checksum, recovery envelope unwrap, and
   in-memory snapshot decode before atomically promoting the file and its
   catalogue row. Store only a redacted `portable_backup_created` or failure
   outcome activity event with archive ID and outcome category.

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
