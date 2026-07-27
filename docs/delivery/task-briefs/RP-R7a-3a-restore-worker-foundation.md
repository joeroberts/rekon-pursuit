# RP-R7a-3a — Restore worker foundation

**State:** Planning complete — the `RP-R7a-3` parent remains **In progress**.
After required gates approve this brief, `RP-R7a-3a` is the sole released
corrective sub-slice.  
**Depends on:** `RP-R7a-2` accepted, the in-progress `RP-R7a-3` parent restore
scope, [ADR-001](../../architecture/adr/ADR-001-local-data-lifecycle.md), and
the [local-data lifecycle contract](../../architecture/local-data-lifecycle-contract.md)  
**Blocks:** `RP-R7a-3b` restore UI/owner smoke, workspace activation or
switching, and all export work. `RP-R7a-3b` is unreleased and
dependency-blocked until `RP-R7a-3a` is accepted and its own plan and gate are
approved.

## Outcome

Provide a dedicated, non-UI restore execution boundary that can verify one
R7a-2 archive and create one **inactive, fully checked** restore candidate.
The boundary returns only a redacted candidate-ready outcome or typed failure.
It does not activate, list, switch to, export from, or otherwise open a
restored workspace.

## Fixed implementation boundary

- Extract a `nonisolated` staged-workspace bootstrap primitive from
  `WorkspaceStore`/`WorkspaceSession`. It may create a new encrypted database,
  apply the normal migrations, expose the archive snapshot importer, checkpoint,
  close, and reopen. It must not expose the active workspace selector or any
  ordinary mutable `WorkspaceStore` API.
- A dedicated `PortableArchiveRestoreWorker` actor owns all heavy and mutable
  restore work: archive file read and package verification; candidate-registry
  reconciliation and reservation; candidate database/signing-key lifecycle;
  staged-root bootstrap; exact snapshot import; bookmark scrub; checkpoint,
  close, reopen, root promotion; and sealed-registry transition to `ready`.
  It receives Sendable request values only.
- `@MainActor` UI/view-model code is limited to native panel presentation,
  short-lived security-scoped archive access, recovery-key entry, clean-Mac
  identity confirmation, and progress/result presentation. It must await the
  worker; it must not synchronously read archives, run cryptography, create a
  candidate, import SQLite rows, checkpoint, or reopen a database.
- Keep the existing R7a-2 package verifier as the sole v1 authentication
  authority. Verification completes before candidate reservation. A matching
  local catalogue row requires the archive ID and signing fingerprint to match;
  an absent row is clean-Mac v1 and requires the caller-supplied explicit
  confirmation of verified ID, creation time, and fingerprint.
- The worker serializes restore attempts. Before every attempt, it reconciles
  only non-ready registry records. A cleanup-pending result fails closed and
  prevents another candidate from being created.
- The sealed metadata-only candidate registry remains at the approved
  application-support location. Its record has candidate UUID, archive ID,
  state, timestamps, bounded cleanup attempts, and a redacted failure category
  only. Writes use canonical encoding, a dedicated Data Protection Keychain
  registry key, exclusive temp-file creation, file `fsync`, atomic rename, and
  parent-directory `fsync`. Initial durable `reserved` precedes every candidate
  root or candidate Keychain item.
- Candidate paths and Keychain accounts are derived from candidate UUID only.
  A successful candidate has a fresh database key **and** fresh archive-signing
  identity, no recovery enrollment or archive catalogue, and document-reference
  `bookmark_data = NULL` with availability `relink_required`. Import never
  copies a bookmark blob even from an authenticated malformed snapshot.
- The importer consumes only `PortableArchiveSnapshotRegistry.tables` in
  declared order through exact table/column mappings and prepared statements.
  It rejects invalid row widths, duplicate primary keys, missing parents, and
  schema/constraint failures; it does not use `SELECT *`, arbitrary SQL, raw
  database files, or inferred mappings. Logically deleted content remains
  unavailable after restore.
- On every error after reservation, record only a redacted category and either
  verify removal of the derived candidate root/key/signing identity before
  `unavailable`, or persist `cleanup_retry`. The active selector, active
  workspace, selected archive, and source keys/catalogue remain unchanged.

## Explicit exclusions

- No Settings/ContentView flow, `NSOpenPanel`, key-entry field, confirmation
  sheet, candidate list, or switch/open command is released in this task. This
  task defines the worker-facing Sendable request/result contract those UI
  pieces will consume in `RP-R7a-3b`.
- No archive creation or export modification; no backup expiry, deletion, or
  purge work; no current-workspace mutation or recovery enrollment.

## Required file-level shape

| Area | Responsibility |
| --- | --- |
| `RekonPursuitCore/Workspace/WorkspaceSession.swift` and/or a new focused bootstrap type | Nonisolated staged candidate bootstrap: fresh database key/root, migrations, archive importer, checkpoint/close/reopen. |
| `RekonPursuitCore/Workspace/PortableArchiveRestore.swift` | Sendable confirmation/request/result/error types; restore actor orchestration; exact importer and bookmark scrub; no UI isolation. |
| `RekonPursuitCore/Workspace/RestoreCandidateRegistry.swift` (extract if this makes durability testable) | Sealed metadata-only registry, lifecycle transitions, durable persistence, reconciliation/cleanup protocol. |
| `RekonPursuitCore/Security/WorkspaceKeyStore.swift` and archive-signing-key storage | UUID-derived candidate database-key and signing-identity creation/read/delete seams. |
| `RekonPursuitCore/Database/EncryptedDatabase.swift` | Only the minimal nonisolated checkpoint/reopen primitive needed by bootstrap; no active-store API leak. |
| `RekonPursuitCoreTests/PortableArchiveTests.swift` and/or focused restore tests | Deterministic worker, registry, injected-failure, importer, and source-invariant evidence below. |

## Test-first task order

1. Write and run a failing worker test proving verification + confirmation
   succeeds off the UI actor and returns an inactive candidate while preserving
   the source selector/root/key/catalogue digest. Implement only the Sendable
   request/result and worker handoff needed to pass it.
2. Write and run a failing bootstrap/import test for migrations → exact import
   → document-bookmark scrub → checkpoint/close/reopen. Implement the
   nonisolated bootstrap primitive and exact importer mapping needed to pass.
3. Write and run failing durable-registry tests for `reserved` before any
   candidate material, interrupted-state relaunch cleanup, and `cleanup_retry`.
   Implement canonical sealing and file/directory durability only to pass.
4. Write and run failing negative-path tests for bad authentication, cancelled
   confirmation, local-catalogue mismatch, invalid snapshot relations, and
   failure injection. Implement fail-closed cleanup/result handling only to
   pass.
5. Run the focused restore suite and a signed Debug compile. Do not claim UI
   completion or request product-owner smoke until `RP-R7a-3b` wires the UI
   adapter.

## Focused acceptance and evidence

- **R3A-WORKER-001:** a valid R7a-2 fixture with opportunities, contacts,
  histories, a tombstone, and a document reference restores through the actor
  into a fresh inactive root. Source-root canonical digest, source database-key
  identity, source catalogue digest, and active selector are equal before and
  after.
- **R3A-BOOTSTRAP-001:** the candidate runs normal migrations; imports only
  the ordered registry; checkpoints, closes, and independently reopens before
  `ready`. A deleted source record is not visible; every restored document
  reference has nil bookmark bytes and `relink_required`.
- **R3A-KEYS-001:** database key, candidate signing identity, and candidate
  UUID differ from the source. Candidate recovery enrollment and archive
  catalogue are absent.
- **R3A-REGISTRY-001:** injected initial registry persistence failure leaves no
  root, database key, or signing key. Injected failure after `reserved`, key
  creation, root creation, import, checkpoint, reopen, promotion, or `ready`
  write relaunches into cleanup-only handling; registry records contain no
  paths, keys, bookmark bytes, or source content.
- **R3A-TRUST-001:** wrong recovery key; header, envelope, payload, signature,
  manifest, or checksum mutation; unsupported version; local catalogue
  mismatch; duplicate key; and invalid relationship all fail before `ready`.
  Every pre-verification failure—wrong key, package mutation, unsupported
  version, and same-Mac catalogue mismatch—leaves **no** registry record,
  candidate root, candidate database key, or candidate signing identity.
  Clean-Mac verification requires the matching typed confirmation; a missing or
  cancelled confirmation creates no candidate material.
- **R3A-THREAD-001:** an actor-isolation test or deterministic instrumentation
  proves file read, verification, bootstrap/import, checkpoint, and reopen run
  through the worker boundary rather than the MainActor-facing caller.
- **R3A-REDACTION-001:** returned result/error/registry fields expose only
  archive ID, candidate ID where applicable, lifecycle state, and redacted
  category—not archive path, recovery key, database key, token, bookmark, or
  snapshot/job content.

## Release rule

Planning, Architect/Security, TPM, QA, and Delivery Manager must approve this
brief before `RP-R7a-3a` becomes the sole released corrective sub-slice under
the still-in-progress `RP-R7a-3` parent. A fresh implementer then completes
this worker foundation with the focused evidence above; separate code review,
QA, and Architecture/Security review must accept it before `RP-R7a-3b` may be
planned, gated, and released for panel/key/confirmation/progress UI. Dashboard
and remediation-ledger state do not change for this planning artifact alone.
