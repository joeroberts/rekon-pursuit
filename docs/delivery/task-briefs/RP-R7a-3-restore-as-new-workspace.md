# RP-R7a-3 — Restore authenticated archive as a new workspace

**State:** Accepted — restore-as-new-workspace completed; activation/switch and export remain separate unreleased work.
**Depends on:** `RP-R7a-1` and `RP-R7a-2` accepted; [ADR-001](../../architecture/adr/ADR-001-local-data-lifecycle.md), the [lifecycle contract](../../architecture/local-data-lifecycle-contract.md), and [ADR-004](../../architecture/adr/ADR-004-durable-document-reference-bookmarks.md)  
**Blocks:** Any workspace activation/switch and both export flows

## User-visible outcome

The user selects a `.rekonarchive`, re-enters its recovery key, and gets a
verified **new local workspace** containing the archive data. Rekon Pursuit
does not replace, close, or activate the current workspace. It reports that
the restored workspace is ready for a later explicit open/switch action.

## Strict scope and safety boundary

- Restore accepts only the R7a-2 v1 authenticated logical archive. It verifies
  header/signature, signing-key fingerprint, envelope, recovery-key unwrap,
  manifest, payload checksum, and canonical snapshot before writing a target.
  Wrong key, tampering, unsupported format, malformed snapshot, or checksum
  mismatch writes no target workspace.
- The archive is selected through `NSOpenPanel` under a short-lived user scope.
  If the current workspace has a matching catalogue row, both archive ID and
  signing-key fingerprint must match. Without a local row, clean-Mac restore
  uses recovery-key possession plus authenticated v1 package verification as
  its authority; it requires explicit confirmation of the verified archive ID,
  creation time, and signing-key fingerprint before target creation. V1 does
  not claim independent source-provenance trust.
- The target is a newly generated UUID-backed, compiled Application Support
  root with a distinct Keychain namespace. It is created through a staging
  directory and promoted only after database open, import, document-bookmark
  scrub, checkpoint, close, and reopen all succeed. No active, external,
  preserved, legacy, or existing local workspace is overwritten or changed.
- Import uses an explicit v1 snapshot table/column registry and prepared
  statements. It never imports a raw SQLCipher file, database key, OAuth token,
  recovery key/enrollment, archive catalogue, signing key, or document bookmark
  bytes. A restored workspace receives fresh database/signing keys, has
  recovery enrollment disabled, and marks every document reference
  `relinkRequired`. The importer must consume
  `PortableArchiveSnapshotRegistry.tables` in declared order and use a paired
  explicit importer mapping with exact column count/type, current schema
  constraint, required-default, primary-key uniqueness, and parent-existence
  rules. It may not infer columns, use `SELECT *`, replay arbitrary SQL, or
  resurrect logically deleted rows.
- Restore uses one app-global, metadata-only candidate registry at
  `Application Support/com.rekonlabs.RekonPursuit/restore-candidates.v1`.
  The registry is a canonical AES-GCM-sealed file, atomically replaced through
  an app-container temporary file, `fsync`, and rename. Its random 256-bit
  sealing key is stored only in the Data Protection Keychain under service
  `com.rekonlabs.RekonPursuit.restore-candidate-registry.v1`, account
  `registry-key`, with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.
  A record contains only candidate UUID, archive ID, lifecycle state,
  timestamps, bounded cleanup-attempt count, and a redacted failure category;
  it never contains a path, database/signing key, archive bookmark, recovery
  key, or source-workspace identifier. The candidate root and candidate
  Keychain account names are derived from the UUID, not stored: respectively
  `Application Support/com.rekonlabs.RekonPursuit/RestoredWorkspaces/<UUID>`
  and service `com.rekonlabs.RekonPursuit.restore-candidate.v1`, accounts
  `<UUID>.database` and `<UUID>.signing`.
- Candidate creation is serialized by one restore coordinator and uses this
  durable order: (1) acquire the app-global registry key and atomically persist
  `reserved`; (2) create only the candidate Keychain items and staging/root
  material derived from that UUID; (3) atomically persist `key_root_created`;
  (4) validate/import/checkpoint/close/reopen and promote the new root; then
  (5) atomically persist `ready`. No root or candidate Keychain item may be
  created if the initial reservation cannot be durably written. A crash or
  registry-write failure after reservation leaves a durable non-ready record;
  launch and every restore attempt reconcile it before creating another
  candidate.
- Registry states are `reserved`, `key_root_created`, `ready`,
  `cleanup_retry`, and `unavailable`. Only `ready` is eligible for a later,
  separately released workspace-open/switch action. `reserved`,
  `key_root_created`, and `cleanup_retry` are cleanup-only states: the app
  deterministically derives the candidate root/key accounts, removes only
  those newly created items, verifies both are absent, and then records
  `unavailable`. If either removal or its verification fails, it atomically
  records `cleanup_retry` and returns a visible `candidate_cleanup_pending`
  result; it neither activates the candidate nor starts another restore. If a
  registry rewrite itself cannot be persisted, the already durable
  `reserved`/`key_root_created` record remains the retry instruction and the
  operation fails closed. Staging cleanup is best effort and never touches a
  source/current root, source Keychain item, or catalogue. The active selector
  is never changed in any state of this task.
- The selected archive is never deleted, modified, or catalogued by restore.
  Every failure class preserves the source/current workspace and leaves no
  candidate marked `ready`.
- Activity and error surfaces contain only an archive ID and redacted outcome
  category—never a path, key, token, bookmark, or snapshot content.

## Explicit exclusions

- Activating, switching to, listing, or otherwise opening the restored
  workspace. That is a separate follow-on action after this new workspace has
  been independently verified.
- Archive creation changes, encrypted or unencrypted export, export review,
  expiry display/removal, purge/rewrite, deletion-flow changes, cloud/network,
  document opening, and legacy-workspace access.

Restore and export are separate slices. Restore validates and imports a full
authenticated workspace into a fresh identity; export creates a user-directed
subset and requires the independent `Start → Review → Confirm` destination and
warning contract. Neither is safe to infer from the other.

## Focused test-first evidence

- `RESTORE-VALID-001`: an R7a-2 archive restores active opportunity/contact/
  history data into a distinct target root while the source workspace remains
  untouched. The test captures before/after (without logging secrets): a
  canonical digest of every source-root relative path and byte sequence
  (including the closed database, WAL, and SHM where present), an in-process
  SHA-256 identity of the source database-key bytes, a canonical digest of the
  source archive-catalogue rows, and the active-workspace selector. All four
  values must be identical after success, cancellation, and every injected
  restore failure.
- `RESTORE-SCHEMA-001`: a fresh candidate runs normal schema initialization/
  migrations, imports only `PortableArchiveSnapshotRegistry.tables` in its
  declared order through exact column/type/constraint/default mapping,
  checkpoints, closes, and reopens before `ready`; logically deleted rows are
  not resurrected into normal views or search.
- `RESTORE-FRESH-KEYS-001`: target workspace ID and database/signing-key
  identities are fresh; recovery enrollment/catalogue are absent; all restored
  document bookmarks are nil and references require relink.
- `RESTORE-TRUST-001`: wrong key, modified header/envelope/payload/signature/
  manifest/checksum, local catalogue archive-ID or signing-fingerprint
  mismatch, unknown version, duplicate row, and invalid relationship reject
  before target promotion. A clean-Mac v1 archive is not rejected merely
  because no source-local catalogue exists; recovery-key possession plus full
  v1 package verification is its authority after the explicit confirmation.
- `RESTORE-CLEANMAC-001`: a valid archive without a local catalogue requires
  confirmation; cancellation creates no candidate; confirmation creates one
  verified target without importing source-Mac trust material.
- `RESTORE-REGISTRY-001`: an injected initial registry-write failure creates no
  candidate root or candidate Keychain item. Crashes/failures after durable
  `reserved`, candidate-key creation, root creation, `key_root_created`,
  promotion, and pre-`ready` registry write are relaunched/reconciled from the
  sealed registry. Each leaves the source-root digest, source database-key
  identity, catalogue digest, and active selector unchanged; it has either no
  candidate material or a durable non-ready cleanup record. Registry fixtures
  prove the file contains no paths, key bytes, archive bookmark, recovery key,
  or source data.
- `RESTORE-ATOMIC-001`: injected failures at key creation, target database
  creation, schema migration, row import, bookmark scrub, checkpoint, reopen,
  promotion, and `ready` registry persistence leave the current workspace
  unchanged and no candidate marked ready. Candidate root/Keychain cleanup
  failure retains a durable `cleanup_retry` record; only verified absence of
  both candidate root and candidate Keychain accounts reaches `unavailable`.
- `RESTORE-REDACTION-001`: fixtures, activity, errors, and restore state omit
  keys, tokens, full paths, bookmark data, and known plaintext job content.
- Signed-Debug product-owner smoke: choose archive → enter key → on a clean
  Mac confirm the verified v1 archive ID, creation time, and signing-key
  fingerprint → see “restored workspace ready”; cancel before confirmation in
  a second run and verify no candidate; in both cases verify the current
  workspace is still open and unchanged.

## Acceptance criteria

- A valid archive restores only as a fully verified new local workspace with
  fresh operating keys and relink-required document references.
- The current workspace and selected archive stay untouched on success,
  cancellation, tampering, incompatibility, or every injected failure.
- Candidate-registry reservation is durable before any candidate root/key
  exists, and all interrupted candidates are cleanup-only until verified
  unavailable or a fully verified `ready` state.
- The task exposes no workspace switch or export control and makes no expiry or
  purge claim.

## Release rule

Planning, Architect/Security, TPM, QA, and Delivery Manager must approve this
brief before `RP-R7a-3` is placed Next up. Architecture must approve the
candidate-root/Keychain lifecycle and exact snapshot-import registry. A fresh
implementer, separate code review, QA and Architecture/Security verification,
and product-owner smoke are required before any activation/switch or export
slice can be released.
