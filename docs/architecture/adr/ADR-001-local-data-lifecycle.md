# ADR-001: Local data lifecycle

- **Status:** Accepted
- **Date:** 2026-07-23
- **Decision owners:** Product owner and Architect
- **Scope:** Workspace records, encrypted blobs, audit events, backups, exports, caches, and associated Keychain material.

## Decision

Rekon Pursuit retains workspace data indefinitely by default, until the user explicitly deletes it. Deletion removes the record immediately from normal views, local search, and active workflows through a logical deletion state. The application records an immutable, privacy-minimized deletion event and tombstone for integrity and audit purposes.

Recoverable backups are opt-in. They require a user-held recovery key and have no product, support, or password-reset recovery path. Backups retain deleted data for 30 days by default, measured from the backup creation time. The UI must show the user the applicable backup expiry date. The user may explicitly purge deleted data from every retained backup; this is a destructive operation and requires a dedicated confirmation.

The app permits unencrypted exports only after an explicit warning and a final filename/location review. Encrypted export remains available as the safer default. OAuth tokens, database keys, and recovery secrets are never exported.

## Rationale

The application is a private, local-first job-search workspace. Indefinite retention avoids surprising loss of career history and supports long-running searches. Immediate logical deletion protects the user's day-to-day experience and prevents deleted records from appearing in search or workflow decisions, while audit tombstones preserve reliable activity history without retaining unnecessary content.

Backups provide recoverability, but deleted content can remain in a prior backup. A fixed 30-day default makes that limitation visible and bounded. Recovery material remains solely with the user so a lost device or Keychain cannot become a provider-controlled data-recovery channel. An unencrypted export can be appropriate for a user-directed handoff or archival workflow, but it moves data outside application encryption and deletion controls; it must therefore be an explicit, informed decision.

## Data-state rules

| State | Visibility and behavior |
| --- | --- |
| Active | Available to authorized local views, search, workflows, and backups according to its retention reason. |
| Logically deleted | `deleted_at` is set; removed immediately from normal views, search indexes, needs-attention queries, and all new AI/provider workflow inputs. It cannot be restored by ordinary editing. |
| Audit tombstone | Retains only the minimum integrity metadata: stable ID, subject type, deletion time, deletion actor, reason/category where supplied, and redacted display snapshot. It contains no deleted content, credentials, recovery material, or raw sensitive payload. |
| Backup-retained deletion | The deleted record may remain only in encrypted backups created before a purge or expiry. The UI identifies this state and the expiry date. It is never surfaced in the active workspace. |
| Purged | Content and searchable projections are removed from the active workspace and eligible retained backups. Minimum audit tombstones remain only where required for ledger integrity. |

Logical deletion cascades only through user-visible availability, never by silently destroying immutable audit history. Linked records must either be independently deleted, re-associated by an explicit user command, or retain a redacted/null subject reference as defined by the schema. Any local full-text index and cache derived from deleted content must be removed or invalidated as part of the deletion transaction/process.

## Backup semantics

1. The application creates portable/recoverable backups only after the user completes recovery-key enrollment, re-enters the key for verification, and acknowledges that the key cannot be reset or recovered by RekonLabs.
2. Recoverable backup archives and manifests remain encrypted and authenticated. They do not contain plaintext recovery secrets, database keys, or OAuth tokens.
3. A recoverable backup expires 30 days after creation unless the user changes the policy through a future, explicitly documented setting. The app displays each backup's creation time, expiry time, recoverability status, and verification result.
4. Before expiry, a deleted item can still be present in a backup made before its deletion. This condition is disclosed at deletion time and in storage/backup status.
5. **Purge deleted data from retained backups** identifies all retained backups containing logically deleted material, regenerates eligible backup archives without that material, verifies each replacement, then securely removes the old backup archives/envelopes where technically possible. The operation must state that it cannot be undone and may make old records unrecoverable. Failure leaves the prior backup intact and reports the failure; it must not claim completion partially.
6. Expired backups are removed according to the same verified, best-effort deletion process. APFS/SSD media prevents a guarantee of physical overwrite; the product must describe physical secure deletion as best effort.
7. Restore always creates a new workspace after all signature, envelope, archive, checksum, and compatibility checks pass. It must not overwrite the active workspace in place.

## Delete semantics

1. Deletion is an explicit confirmation flow. The user may be offered an export or backup option before confirming, but declining it does not block deletion.
2. On confirmation, the service atomically marks the entity logically deleted, appends the audit event/tombstone, removes its projections from normal search and views, and invalidates dependent active workflow inputs.
3. Blobs, caches, and derived previews that are no longer referenced by an active or retention-required record are queued for removal. Database rows and filesystem payload removal are retried safely and recorded; no operation may silently leave an active searchable copy.
4. Keychain items are deleted only after dependent filesystem/database removal succeeds. Integration revocation is separately confirmed and is not implied by deleting a workspace record.
5. Deleted content must not be submitted to AI, Gmail, Calendar, research, or reconciliation operations. Queued operations referencing deleted content are canceled or moved to a visible blocked state and audited.

## Export semantics

1. The export flow presents encrypted export first and explains that it preserves application-level protection for the exported archive.
2. Choosing unencrypted export displays a distinct warning: the copy may be readable by other apps, accounts, backup services, or users with access to the selected location; it is outside Rekon Pursuit encryption, lifecycle, and deletion controls.
3. The final step requires the user to review and explicitly confirm the exact export type, included categories, filename, and destination. A filename or location change invalidates the confirmation and returns to review.
4. Unencrypted exports are recorded in the local activity ledger with safe metadata only (type, destination class if available, selected categories, and result); never store exported content or full paths in the ledger by default.
5. Exports exclude OAuth access/refresh tokens, database keys, file-encryption keys, recovery secrets, and other credentials. Canonical external-mutation artifacts are included only in an explicitly selected encrypted audit-evidence export.

## Acceptance criteria

- A new workspace has no automatic content-expiry job; active records remain until explicitly deleted.
- Deleting an opportunity, contact, document, or other supported entity immediately removes it from all normal views and local search results, including FTS/index projections.
- A deletion generates an append-only audit event and a privacy-minimized tombstone; normal queries cannot retrieve the deleted content.
- New AI runs, provider operations, reconciliation, and workflow suggestions reject or block logically deleted source records.
- Recovery backup setup is unavailable until the user opts in, receives/records a recovery key, and successfully verifies it. The product provides no reset, escrow, or support override.
- Backup UI displays creation time, recoverability state, and a default expiry exactly 30 days after creation.
- Deletion UI states that prior encrypted backups may retain deleted data until their shown expiry or an explicit purge.
- A destructive purge flow can identify, regenerate, verify, and remove all eligible retained backups containing deleted data; it reports incomplete work truthfully and never silently treats a failed purge as complete.
- The export flow defaults to encrypted export. Unencrypted export cannot complete without an explicit warning plus filename/location review and confirmation.
- Neither backups nor exports contain OAuth tokens, database keys, recovery secrets, or plaintext backup encryption keys.
- Restore verifies recovery trust binding, manifest/authentication/checksums, and compatibility in a newly created workspace before any switch-workspace action becomes available.

## Consequences

### Positive

- Preserves the user's job-search history without retention surprises.
- Makes normal deletion immediate while offering a clear, bounded recovery window through encrypted backups.
- Maintains auditability without keeping deleted content searchable or operational.
- Makes data leaving the protected workspace an explicit user decision.

### Costs and constraints

- Storage can grow indefinitely until the user deletes data; the application needs a Storage view that reports workspace size, backup count, and most recent backup date.
- Logical deletion and backup rewrite/purge require schema support, index invalidation, background work, progress reporting, and failure-safe recovery tests.
- A 30-day backup window means deletion is not an immediate guarantee of removal from every historical backup unless the user runs the destructive purge.
- User-held recovery keys improve privacy but create an intentional unrecoverable-loss case if both the key and local Keychain material are lost.
- Unencrypted exports introduce user-managed privacy risk and must be surfaced as such rather than treated as protected workspace data.

## Implementation notes

- Use `deleted_at` tombstones and versioned deletion commands; preserve immutable audit rows with redacted/null subject references as needed.
- Treat backup rewrite/purge as an idempotent job with a durable progress record, per-backup verification, and no destructive removal of the predecessor until its replacement verifies.
- Keep retention policy, destructive confirmations, and export disclosures as versioned settings/consent records so activity evidence can identify the rule in effect.
- Define detailed schemas, migration behavior, test fixtures, and UI copy in the M0 readiness package and implementation task briefs.

