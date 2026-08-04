# R7b — Expiry removal and retained-data purge

## Decision

Rekon Pursuit retains active workspace data indefinitely until the user deletes
it. Automatic expiry may remove a portable recovery archive at the next app-run
service opportunity on or after `created_at + 30 × 24 hours` only when both
catalogue predicates hold: `storage_class == "managed"` and
`managed_relative_path` is the generated canonical `<lowercase archive
UUID>.rekonarchive` leaf beneath the workspace-private `portable-archives`
root. Pre-v28 migrated rows are `external`, not a third storage class. Every
other row—including external/user-selected, missing-locator, and
noncanonical-locator rows—is retained: expiry never resolves its external
bookmark, opens, renames, or deletes it, and records a durable manual-removal
or blocked outcome. A user may explicitly purge logically deleted material from
retained archives. Purge requires one recovery-key re-entry per purge job; the
key exists only in operation memory and is never persisted.

This work is two serial slices. `R7b-1` must be accepted before `R7b-2` can be
released.

## R7b-1 — Automatic archive expiry removal

At workspace open and on each transition from inactive to active while a
workspace is open, the expiry service finds catalogued archives at or past
their fixed expiry time. It may claim only a row whose `storage_class` is
`managed` and whose `managed_relative_path` is exactly the generated canonical
`<lowercase archive UUID>.rekonarchive` leaf beneath the workspace-private
`portable-archives` root. External/user-selected and pre-v28 migrated
`external` rows transition to `expired_manual_removal_required` and are left
untouched; missing or noncanonical managed locators receive a durable blocked
outcome and are also left untouched. The service never resolves an external
bookmark, opens, renames, or deletes any such non-target. For the eligible
managed archive, it first durably claims the archive, then uses the private
workspace archive store and a durable `expired_prepared` →
`expired_quarantined` → removal sequence before it:

1. resolves the managed relative locator beneath the private workspace archive
   store (it does not resolve an external bookmark);
2. opens and verifies the intended regular no-follow file;
3. validates the versioned readable archive header/signature, archive identity,
   recorded fingerprint, and payload checksum against the catalogue; and
4. rechecks device/inode identity immediately before deletion.

The managed store and its quarantine directory are created owner-only (`0700`)
under the workspace. The MVP protects against ordinary failures and replacement
races; it does not claim to defend against a malicious process running as the
same macOS user.

Successful removal deletes the verified managed file and closes/removes its
catalogue record with a redacted `portable_backup_expired_removed` activity. A
missing file records `expired_missing`; it never claims physical deletion.
Identity mismatch, replacement, permission denial, or I/O failure leaves the
archive in an explicit retryable or blocked expired state with redacted
evidence. The operation is idempotent across relaunches.

The app is not a background daemon or timer. It makes no exact-clock guarantee
while it is closed or remains active without another bounded service
opportunity. Expiry never reads, modifies, or deletes active workspace data.

## R7b-2 — Explicit purge of retained deleted data

Purge is a separately confirmed destructive action. Before work starts, the
user re-enters the recovery key; it is held only for that job and discarded on
success, cancellation, or failure. The app captures an immutable scope of
eligible archive IDs and catalogue versions, blocks conflicting archive
creation/catalogue mutation for that scope, authenticates each candidate, and
compares snapshot subject identifiers with the captured logical-deletion
tombstone set.

Only an archive containing deleted material is rebuilt. For each candidate,
the app writes a new sibling archive through a temporary file and exclusive,
no-follow final creation; verifies the replacement; adds the replacement
catalogue entry; then identity-rechecks and removes the predecessor. It never
overwrites the predecessor. Cancellation or any failure retains the
predecessor, persists precise per-archive state, and reports the overall job
as incomplete or blocked—not complete. Retrying is idempotent and requires a
new recovery-key entry.

## Boundaries

- No automatic expiry of active workspace data.
- No automatic deletion, move, or rename of an external/user-selected archive.
- No physical-overwrite guarantee; removal is best-effort and described
  truthfully.
- No unencrypted export, archive format expansion, restore activation/switch,
  external networking, AI, or deletion-flow redesign.
- No recovery key, archive path/bookmark, raw archive payload, raw deleted
  payload, or user-entered subject text in activity, logs, catalogue metadata,
  diagnostics, or fixtures.

## Focused evidence

`R7b-1` uses an injected clock for before-expiry, exact-expiry, relaunch/retry,
identity mismatch, missing/inaccessible file, and redaction cases.

`R7b-2` uses a multi-archive fixture to prove verified replacement before
predecessor removal, cancellation, replacement verification failure,
predecessor-removal failure, durable incomplete state, and active-content
preservation. These are lifecycle/data-loss tests, not a coverage target.
