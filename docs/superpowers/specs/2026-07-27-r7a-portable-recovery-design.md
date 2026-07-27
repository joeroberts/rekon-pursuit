# R7a portable recovery and encrypted export design

**Status:** Proposed for independent R7a gate review  
**Scope:** Recovery-key enrollment, encrypted portable backup/archive creation,
restore to a new local workspace, encrypted-default export, and warned
unencrypted export. R7a also shows per-backup creation, recoverability, and
fixed 30-day expiry, plus the retained-backup deletion disclosure. Expiry
removal and purge are explicitly R7b.

## Decision

R7a uses an app-generated, user-held 256-bit recovery key. Rekon Pursuit shows
the key once as grouped Base32 text plus a checksum, and requires the user to
re-enter it before enrollment completes. The app never writes the key to a
file, clipboard, database, manifest, activity event, diagnostics, or backup;
there is no reset, escrow, support override, or cloud recovery path. A
verified enrollment stores only a versioned, one-way key fingerprint so the
app can reject a different key later; it does not retain the key itself.

This implements the accepted ADR-001 and lifecycle contract without changing
their retention, deletion, or export rules.

## User workflow

1. In Settings, the user selects **Set up recovery key**.
2. The app generates the key with the platform cryptographic RNG and displays
   it once with copy explaining that RekonLabs cannot recover it. The user must
   record it outside the app.
3. The user re-enters the complete key. A mismatch or cancellation leaves
   enrollment disabled and creates neither an archive nor a secret record.
4. **Create encrypted recovery backup** asks for the enrolled recovery key
   again. The key is held only for that operation, then discarded. After a
   matching re-entry, the app writes a temporary archive/envelope/manifest,
   verifies all artifacts, then atomically promotes the backup catalogue entry.
   The catalogue shows its creation time, fixed expiry, and verification/
   recoverability status.
5. **Restore encrypted backup** always opens a restore wizard. It asks for the
   recovery key, validates the archive, and creates a new workspace directory
   with fresh database and signing keys. It never replaces the current
   workspace; switching to the restored workspace is a separate final action.
6. **Export** starts on encrypted export. It requires recovery enrollment and
   operation-time key re-entry, then writes a selected-category logical export
   sealed with the same recovery-key envelope format. It is an encrypted export
   artifact, not a backup catalogue entry and not a workspace-restore command.
   A user who selects unencrypted export sees the accepted disclosure and must
   review exact categories, filename, and destination. Any change returns the
   flow to review.
7. When deleting an item, the app states that existing encrypted recovery
   backups may retain it until the displayed expiry or a future purge. R7b owns
   expiry removal and purge, not this truthful visibility.

## Archive and trust boundary

- Use only Apple platform cryptography: `SecRandomCopyBytes`, CryptoKit
  HKDF-SHA256, AES-GCM, SHA-256, and Curve25519 signing. No custom cipher,
  KDF, file format, or third-party crypto dependency is introduced.
- Each archive receives a random content key. The source workspace is read
  while open and serialized into a versioned logical snapshot; the raw
  SQLCipher database file and its database key are never archived. The archive
  package AES-GCM seals that snapshot plus only the selected document metadata
  allowed by current MVP boundaries. Restore imports the logical snapshot into
  a freshly keyed destination SQLCipher workspace.
- A minimal outer header is readable before decryption and contains only the
  archive ID, format version, per-archive salt, manifest hash, envelope,
  manifest signature, signing public key, archive checksum, and versioned
  metadata needed to validate the package. It contains no raw user data,
  recovery secret, database key, or full local path. The full manifest remains
  inside the encrypted package and must hash to the authenticated header value.
- The recovery key is combined with a per-backup random salt through
  HKDF-SHA256 to derive a wrapping key. A recovery envelope AES-GCM seals the
  content key and binds it to the backup ID, archive format version, and
  outer-header manifest hash as authenticated associated data.
- The manifest contains only IDs, versions, creation/expiry timestamps,
  checksums, deleted-material inventory summary, recovery-envelope hash, and
  signing-public-key fingerprint. It contains no recovery secret, database
  key, OAuth token, plaintext backup key, full local path, or raw user data.
- A workspace-held Curve25519 signing key signs the manifest hash plus the
  canonical outer-header fields (excluding the signature field itself). The
  complete signing public key travels in the authenticated outer header; its
  fingerprint is duplicated in the encrypted manifest. On the
  source Mac, the archive ID and public-key fingerprint must match the local
  backup catalogue before restore. A complete archive/envelope pair from a
  different workspace is never silently treated as the current workspace.
  On a clean Mac, the app verifies the signature with the header public key,
  validates the recovery envelope, then presents backup ID, creation time, and
  fingerprint for explicit user confirmation before importing. Substituting
  any header, envelope, archive, signature, or verification key breaks a
  binding and is rejected. A restored workspace immediately creates fresh
  database and signing keys and requires new recovery enrollment for future
  portable backups.

## Failure and safety behavior

- The app creates archives only after the recovery key is re-entered and
  matched to the enrollment fingerprint for that operation. Temporary files
  are removed on cancellation/failure; a failure never replaces an existing
  backup catalogue entry.
- Restore rejects a wrong key, stale/tampered envelope, substituted archive,
  manifest signature failure, checksum mismatch, unsupported format, or disk
  failure before any active-workspace switch. The current workspace remains
  untouched.
- The archive does not include OAuth tokens, database keys, recovery secrets,
  plaintext archive keys, or security-scoped document bookmarks. Restored
  document references remain relink-required under ADR-004.
- Unencrypted export records safe metadata only: export type, selected
  categories, destination class, confirmation fingerprint, and outcome. It
  records neither exported contents nor a full path.
- R7a does not implement automatic expiry removal, backup rewriting, or purge.
  Those remain R7b. R7a does persist and display the truthful 30-day expiry
  and retained-backup deletion disclosure required by ADR-001.
- Existing same-Mac backup/restore and direct CSV-export routes are contained
  before the new recovery flow is exposed. They are not presented as portable
  recovery and must not replace an active workspace. R7a operates only on a
  ready active workspace and never changes the preserved legacy folder.

## Focused acceptance evidence

- Enrollment success, cancellation, malformed/checksum-invalid re-entry,
  per-backup re-entry, and no-reset behavior.
- Encrypted archive round trip into a distinct workspace with fresh keys;
  active workspace unchanged until an explicit switch.
- Wrong recovery key, tampered envelope, archive swap, manifest mutation,
  checksum mismatch, and interrupted write each leave the original workspace
  and prior backup catalogue unchanged.
- Encrypted export is the default; unencrypted export requires the approved
  disclosure and a final review fingerprint invalidated by category, filename,
  or destination change.
- Redaction inspection proves that secrets, keys, raw content, and full paths
  do not enter archives' visible metadata, activity, diagnostics, or fixtures.
- Header-before-unwrapping verification covers malformed/tampered headers,
  archive-envelope swaps, substituted signing keys, and header/manifest-hash
  disagreement. Same-Mac mismatches reject; a clean-Mac valid but different
  archive requires explicit confirmation.

## Explicitly out of scope

- R7b expiry removal, backup purge/rewrite, and physical-deletion claims.
- Gmail, Calendar, AI, cloud sync, document editing, and a release/notarized
  distribution workflow.
