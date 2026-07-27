# R7a portable recovery and encrypted export design

**Status:** Proposed for independent R7a gate review  
**Scope:** Recovery-key enrollment, encrypted portable backup/archive creation,
restore to a new local workspace, encrypted-default export, and warned
unencrypted export. Retention expiry and purge are explicitly R7b.

## Decision

R7a uses an app-generated, user-held 256-bit recovery key. Rekon Pursuit shows
the key once as grouped Base32 text plus a checksum, and requires the user to
re-enter it before enrollment completes. The app never writes the key to a
file, clipboard, database, manifest, activity event, diagnostics, or backup;
there is no reset, escrow, support override, or cloud recovery path.

This implements the accepted ADR-001 and lifecycle contract without changing
their retention, deletion, or export rules.

## User workflow

1. In Settings, the user selects **Set up recovery key**.
2. The app generates the key with the platform cryptographic RNG and displays
   it once with copy explaining that RekonLabs cannot recover it. The user must
   record it outside the app.
3. The user re-enters the complete key. A mismatch or cancellation leaves
   enrollment disabled and creates neither an archive nor a secret record.
4. Once verified, **Create encrypted recovery backup** becomes available. It
   writes a temporary archive/envelope/manifest, verifies all artifacts, then
   atomically promotes the backup catalogue entry.
5. **Restore encrypted backup** always opens a restore wizard. It asks for the
   recovery key, validates the archive, and creates a new workspace directory
   with fresh database and signing keys. It never replaces the current
   workspace; switching to the restored workspace is a separate final action.
6. **Export** starts on encrypted export. A user who selects unencrypted
   export sees the accepted disclosure and must review exact categories,
   filename, and destination. Any change returns the flow to review.

## Archive and trust boundary

- Use only Apple platform cryptography: `SecRandomCopyBytes`, CryptoKit
  HKDF-SHA256, AES-GCM, SHA-256, and Curve25519 signing. No custom cipher,
  KDF, file format, or third-party crypto dependency is introduced.
- Each archive receives a random backup content key. The archive package is
  AES-GCM sealed with that key; its plaintext contains the versioned manifest,
  encrypted SQLCipher workspace payload, and only the selected document
  metadata allowed by current MVP boundaries.
- The recovery key is combined with a per-backup random salt through
  HKDF-SHA256 to derive a wrapping key. A recovery envelope AES-GCM seals the
  content key and binds it to the backup ID, archive format version, and
  manifest hash as authenticated associated data.
- The manifest contains only IDs, versions, creation/expiry timestamps,
  checksums, deleted-material inventory summary, recovery-envelope hash, and
  signing-public-key fingerprint. It contains no recovery secret, database
  key, OAuth token, plaintext backup key, full local path, or raw user data.
- A workspace-held Curve25519 signing key signs the manifest. On same-Mac
  restore its public-key fingerprint must match the locally held verification
  key. On a clean Mac, successful recovery-key envelope validation is the
  portability trust root; the restored workspace immediately creates fresh
  database and signing keys and requires new recovery enrollment for future
  portable backups.

## Failure and safety behavior

- The app creates archives only after enrollment is verified. Temporary files
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
- R7a does not implement automatic expiry removal, deleted-data disclosure,
  backup rewriting, or purge. Those remain R7b and must not be implied by the
  R7a UI.

## Focused acceptance evidence

- Enrollment success, cancellation, malformed/checksum-invalid re-entry, and
  no-reset behavior.
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

## Explicitly out of scope

- R7b expiry display, retained-deletion disclosure, backup purge/rewrite, and
  physical-deletion claims.
- Gmail, Calendar, AI, cloud sync, document editing, and a release/notarized
  distribution workflow.
