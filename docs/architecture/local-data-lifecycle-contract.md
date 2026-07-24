# Local-data lifecycle contract

**Status:** Accepted M0-2 contract draft — pending independent M0-2 acceptance  
**Authority:** ADR-001 (Accepted, 2026-07-23) is controlling. This document makes its implementation and test obligations explicit; it does not change product behavior.  
**Applies to:** workspace, supported entities, encrypted blobs/caches, activity/audit records, recoverable backups, Keychain material, and exports.

## 1. Non-negotiable policy and backup taxonomy

| Rule | Contract |
| --- | --- |
| Active retention | Active workspace data has no automatic expiry. It remains until the user deletes it. |
| Backup class | M1 supports exactly one retained class: an opt-in portable/recoverable encrypted backup. It has `created_at`, `expires_at = created_at + 30 × 24 hours`, verification state, and a recovery envelope. |
| Pre-enrollment protection | A migration may use a transaction-scoped verified rollback snapshot only. It is not a user backup, is unavailable for independent restore/export, is destroyed after successful migration, and preserves a failed migration recovery path only. It is not subject to the 30-day backup policy. M1 has no app-quit, scheduled, or local-Keychain-only retained resilience backup. |
| Expiry/disclosure | The deletion disclosure and backup status identify every retained recoverable backup that can contain deleted content and show its fixed `expires_at`. Expiry is measured from backup creation, not deletion time. A backup created before deletion remains eligible until its own expiry or verified purge. |
| Secret boundary | Database keys, OAuth tokens, recovery secrets, plaintext backup keys, full paths, and raw export payloads never enter backup manifests/envelopes, exports, activity records, ledger entries, diagnostics, or test fixtures. Raw deleted payloads never enter those metadata/diagnostic/export surfaces. An encrypted recoverable archive created **before** deletion may retain its original deleted payload until its displayed expiry or verified purge, as ADR-001 requires; a replacement created by purge excludes it. Recovery enrollment performs one user-mediated display/re-entry; it is not an app-written export or clipboard/file handoff. |

## 2. Command and state contracts

### Workspace and Keychain

| Operation | Success state | Negative state / required response |
| --- | --- | --- |
| `OpenWorkspace` | Decrypt/open existing workspace or create the explicitly requested fresh workspace. | `locked`, `denied`, `missing`, or `corrupt` Keychain/workspace states block mutation, retain the existing workspace, and show recovery guidance. Never create a blank replacement or plaintext fallback. |
| `CreateWorkspace` | Generates workspace/database material in Keychain and encrypted storage atomically enough that a crash leaves no usable partial workspace. | Disk or Keychain failure removes only newly created temporary material and reports retry; no secret is logged. |
| `EnrollRecoveryKey` | One-time user-mediated reveal, re-entry verification, recovery envelope/trust binding, then enables portable backup creation. | Cancel, mismatch, Keychain failure, or disk interruption creates no recoverable backup and leaves enrollment disabled. There is no reset, escrow, support override, file export, or clipboard write. |
| `CloseWorkspace` | Closes database and releases scoped handles. | Failure records a redacted error and retains an inaccessible-safe state; no key material is emitted. |
| `MigrateWorkspace` | Takes a verified transaction-scoped rollback snapshot before an exclusive, forward-only migration. On success, commits the migration/checksum/history and destroys the snapshot. | The snapshot is not a retained/recoverable backup and cannot be independently restored/exported. Injected migration failure rolls back the database, preserves only the snapshot needed for retry/recovery, records a redacted failure, and on relaunch presents retry/keep-current-workspace guidance without an empty replacement. Portable-backup restore is offered only if a separately existing enrolled recoverable backup is available. Disk interruption or corrupt snapshot blocks promotion and preserves the pre-migration workspace. |

### Logical deletion

`DeleteEntity` has one database transaction boundary. It commits all of the following together or commits none:

1. `deleted_at`, deleter, deletion reason/category (if supplied), and version change on the subject;
2. a redacted append-only deletion activity event and the minimum audit tombstone (stable subject ID/type, deletion time/actor, optional reason/category, redacted display snapshot);
3. removal/invalidation of every normal-view, needs-attention, FTS/search, cache-key, and active-workflow projection for the subject; and
4. cancellation of queued external/AI/provider/reconciliation work referencing the subject, or a durable visible `blocked_deleted_source` state plus an audit reference.

This applies to every supported deletable entity (opportunity, contact, document/version/blob, interaction, task, interview/transcript, offer, employer, research item, and attachment). Linked records are independently deleted, explicitly re-associated, or retain a nullable/redacted subject reference; immutable audit history never cascades raw content.

After transaction commit, `DeleteDerivedContent` is a durable idempotent job for unreferenced encrypted blobs, previews, cache files, and filesystem artifacts. Its states are `queued`, `running`, `retryable_failure`, `blocked`, and `completed`. It may not leave an active searchable copy. A failed job is visible and retriable; it never changes logical deletion back to active. Keychain material is removed only after dependent database/filesystem removal succeeds. Integration revocation remains separately confirmed.

### Backup, purge, and restore

| Operation | Required contract |
| --- | --- |
| `CreateRecoverableBackup` | Requires verified enrollment. Writes an authenticated archive, manifest, and recovery envelope to temporary names; verifies the complete replacement before atomic promotion. A manifest records backup/workspace IDs, `created_at`, calculated `expires_at`, format/schema/app/encryption versions, archive and blob checksums, recovery-envelope hash, verification-key ID, and deleted-material inventory summary. It never records a secret or plaintext key. |
| `ExpireBackup` | At `now >= expires_at`, queues removal by the same verify/remove discipline. User-visible status remains `expired_pending_removal` until removal finishes; physical overwrite is best-effort only. |
| `PurgeDeletedBackups` | On confirmation, captures an immutable scope of eligible backup IDs and their manifest versions (`scope_cutoff`). It blocks/queues new backup creation and manifest mutation until completion, cancellation, or failure. For each scoped backup, it regenerates a replacement excluding eligible logically deleted content, verifies replacement/authentication/bindings, atomically promotes it, then removes its predecessor. A predecessor is never removed before its replacement verifies. |
| Purge result | Durable job states: `awaiting_confirmation`, `preparing_scope`, `rewriting`, `verifying`, `removing_predecessors`, `completed`, `cancelled`, `incomplete_retryable`, `blocked`. `completed` is legal only if every scoped backup has a verified replacement **and its predecessor is successfully logically removed**. Any predecessor-removal failure is `incomplete_retryable` or `blocked`, retains that predecessor, and prevents an overall `completed` result; physical overwrite remains best-effort only. A failure/interruption leaves every unfinished predecessor intact, records per-backup state, displays `incomplete`, and resumes/retries idempotently from durable state. Cancellation before first replacement promotes no changes; after promotions it reports completed per-backup replacements and incomplete overall, never a false all-or-nothing completion. |
| `RestoreBackup` | Always restores to a new workspace directory. It verifies recovery-secret trust binding (when clean-Mac), local verification-key fingerprint (when same-Mac), envelope binding, manifest signature, archive authentication, checksums, and compatibility before a switch-workspace action is offered. Corrupt archive/envelope/manifest, swapped archive/envelope, or substituted verification key rejects without partial restore/overwrite. |
| Post-clean-Mac restore | Re-wraps to a fresh workspace root/database key and fresh backup-signing keypair; it does not import OAuth tokens or reuse the recovery secret as an operating key. It requires new recovery enrollment before future recoverable backups. |

### Export confirmation

The `StartExport` → `ReviewExport` → `ConfirmExport` state machine defaults to encrypted export. The confirmation fingerprint is a canonical hash of export type, selected categories, exact filename, and canonical destination. Any change to those values invalidates the prior confirmation and returns to review. Unencrypted export requires a distinct warning that it is outside Rekon Pursuit encryption/deletion controls. Cancellation writes no file and no completion event. A completion event contains only export type, selected categories, destination class, confirmation fingerprint, and outcome—not full paths or contents.

## 3. Deterministic traceability matrix

| ADR-001 acceptance rule | Architecture/contract anchor | Fixture and required deterministic cases | Expected / failure observable | Verifier |
| --- | --- | --- | --- | --- |
| Indefinite active retention | §1 Active retention | `WS-EMPTY-001`, `WS-CORE-001` | No automatic content-expiry job; records persist until explicit delete. | QA |
| Migration preserves a safe recovery path | §2 Workspace and Keychain `MigrateWorkspace` | `MIGRATE-NMINUS1-001`, `MIGRATE-FAIL-001` cases `success`, `transaction_failure`, `disk_interruption`, `relaunch_retry`, `corrupt_snapshot` | Success destroys the transaction-scoped snapshot after history/checksum commit. Failure rolls back, retains the pre-migration workspace/recovery path, and never exposes an independently restorable backup or blank replacement. | Architect + QA |
| Logical delete removes normal/search/workflow access and retains minimum audit | §2 Logical deletion | `DELETE-LOGICAL-001` for each supported entity; `DELETE-QUEUED-WORK-001` | Active/FTS/cache/workflow query returns no source content; tombstone/event exists; queued work is cancelled or visibly blocked. Transaction injection leaves all old or all new state. | QA + Security |
| Recovery setup has no reset/escrow | §2 Workspace and Keychain | `RECOVERY-ENROLL-001`, `RECOVERY-MISSING-001` cases `locked`, `denied`, `missing`, `reentry_mismatch`, `cancelled` | No backup/enrollment on failure; no blank workspace, plaintext fallback, secret logging, file write, or reset route. | Security + QA |
| 30-day expiry from backup creation and deletion disclosure | §1 / §2 backup | `BACKUP-RETENTION-001` cases `created_before_delete_day0`, `day29`, `day30`, `expired_pending_removal` | `expires_at` equals creation + 30 days, not deletion + 30; prior backup remains disclosed until expiry/purge. | QA |
| Purge is destructive, verified, truthful | §2 Purge | `BACKUP-PURGE-001` cases `confirm`, `cancel`, `multi_backup_failure`, `predecessor_removal_failure`, `interruption_relaunch`, `retry`, `concurrent_create` | No predecessor removal before verified replacement; predecessor-removal failure remains `incomplete_retryable`/`blocked`; per-backup durable status; no false complete result. | QA + Security |
| Restore uses new workspace and rejects tampering/substitution | §2 Restore | `BACKUP-VALID-001`, `BACKUP-CORRUPT-001` variants, `BACKUP-SWAP-001` variants, `RESTORE-KEYCHAIN-001` cases, `RESTORE-CLEANMAC-001` cases | New workspace only; no overwrite/partial promotion; correct trust-binding/re-wrap/fresh keys after clean-Mac restore. | Architect + QA + Security |
| Encrypted default / warned unencrypted export | §2 Export | `EXPORT-ENCRYPTED-001`, `EXPORT-UNENCRYPTED-001` cases `warning`, `filename_change`, `destination_change`, `category_change`, `EXPORT-CANCELLED-001` | Encryption is default. Any fingerprint input change invalidates confirmation; cancelled export has no file/event. | QA + Security |
| Sensitive material never leaves protected boundary | §1 Secret boundary; §2 all operations | `LIFECYCLE-REDACTION-001` across events, diagnostics, manifests, envelopes, export ledger metadata | Redaction scans find no key/token/secret/full path/raw export content, or raw deleted payload in metadata/diagnostics/exports. A pre-delete encrypted archive is allowed only the bounded retained payload described above. | Security |

## 4. UX-copy acceptance references

The implementation must use copy that makes these outcomes explicit and testable:

- Delete: “Removed from this workspace now. Earlier encrypted backups may retain it until the displayed expiry date or until you permanently purge it.”
- Backup expiry: display `created_at`, exact `expires_at`, verification status, and portability/recoverability status.
- Purge: “This permanently rewrites eligible backups and cannot be undone. A failed or interrupted purge remains incomplete; your prior backup is kept until a verified replacement exists.”
- Missing recovery: “This backup cannot be opened without its recovery secret. RekonLabs cannot reset or recover it. Your current workspace will not be replaced.”
- Export default: encrypted export is preselected and described as protected.
- Unencrypted export: “This copy can be read by other apps, accounts, backup services, or people with access to this location. It is outside Rekon Pursuit encryption and deletion controls.” The final review shows type, categories, filename, and destination.

## 5. M0-QA-03 evidence boundary

M0-QA-03 is satisfied only when the fixture strategy contains every stable fixture/case named above, the QA and Security reviewers accept deterministic behavior and redaction coverage, and the delivery ledger records the ADR revision (`2026-07-23`, accepted) and this contract version. M0-2 creates no storage, crypto, backup, export, or UI implementation.
