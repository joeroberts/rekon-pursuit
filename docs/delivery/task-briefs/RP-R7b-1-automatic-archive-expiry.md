# RP-R7b-1 — Automatic portable archive expiry

## User-visible outcome

At the next successful workspace-open or inactive-to-active app opportunity after a workspace-managed archive's fixed 30-day expiry, Rekon Pursuit safely removes it only when it still exactly matches the verified, catalogued archive. External/user-selected archives are retained and marked for manual removal; Settings reflects the durable redacted outcome and no active workspace data is affected.

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

An expired managed archive is a destructive target. The worker must use only a validated workspace-relative locator, verify a regular no-follow file and public v1 binding, preserve durable prepared/quarantined state across non-success paths, and retain the catalogue on every non-success path. External archives are never destructive targets. Activity records categories only, never paths, bookmark bytes, payloads, or recovery material.
