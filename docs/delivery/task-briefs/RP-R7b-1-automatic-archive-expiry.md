# RP-R7b-1 — Automatic portable archive expiry

## User-visible outcome

At the next successful workspace-open or inactive-to-active app opportunity after a fixed 30-day expiry, Rekon Pursuit safely removes an archive only when both catalogue predicates hold: `storage_class == "managed"` and `managed_relative_path` is the generated canonical `<lowercase archive UUID>.rekonarchive` leaf beneath the workspace-private `portable-archives` root. It must still exactly match the verified catalogue. Every other row is retained: pre-v28 migrated rows are `external` (not a third class), and external/user-selected, missing-locator, or noncanonical-locator rows are never destructive targets. Expiry never resolves an external bookmark, opens, renames, or deletes those rows; it records the durable manual-removal-required or blocked outcome. Settings reflects the durable redacted outcome and no active workspace data is affected.

## Release boundary

This is R7b-1 only. It does not purge deleted records from retained archives, rebuild archives, request a recovery key, alter archive encoding, or run as a daemon. R7b-2 remains unreleased.

## Depends on

- RP-R7a-4 accepted.
- Approved `docs/superpowers/specs/2026-07-27-r7b-expiry-and-purge-design.md`.
- Plan `docs/superpowers/plans/2026-07-27-r7b-1-automatic-archive-expiry.md`.

## Acceptance evidence

- Focused `PortableArchiveTests` cover managed-archive creation, the exact expiry boundary while a future archive remains untouched, durable retry, external-archive no-delete/manual-removal behavior, missing/unsafe/mismatch paths, redaction, and no active-workspace mutation.
- Relevant signed Debug build succeeds.
- Independent Architect/Security, QA, code review, TPM, and Delivery Manager approve completion.
- Product owner accepted the final Debug-app protected-export verification on 2026-07-27. The later export-success confirmation window is deferred as `UX-D10` and does not reopen the accepted reliability work.

## Material risk and handling

Only an archive satisfying both managed predicates is a destructive target. The worker must use the canonical workspace-relative locator beneath `portable-archives`, verify a regular no-follow file and public v1 binding, preserve the durable `expired_prepared` → `expired_quarantined` sequence across non-success paths, and retain the catalogue on every non-success path. All other rows are never destructive targets: no external bookmark resolution, open, rename, or deletion is permitted. Activity records categories only, never paths, bookmark bytes, payloads, or recovery material.
