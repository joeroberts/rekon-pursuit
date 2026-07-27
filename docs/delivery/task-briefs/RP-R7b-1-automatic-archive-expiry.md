# RP-R7b-1 — Automatic portable archive expiry

## User-visible outcome

At the next successful workspace-open opportunity after an archive's fixed 30-day expiry, Rekon Pursuit safely removes that archive only when it still exactly matches the verified, catalogued archive. Settings reflects the durable redacted outcome; no active workspace data is affected.

## Release boundary

This is R7b-1 only. It does not purge deleted records from retained archives, rebuild archives, request a recovery key, alter archive encoding, or run as a daemon. R7b-2 remains unreleased.

## Depends on

- RP-R7a-4 accepted.
- Approved `docs/superpowers/specs/2026-07-27-r7b-expiry-and-purge-design.md`.
- Plan `docs/superpowers/plans/2026-07-27-r7b-1-automatic-archive-expiry.md`.

## Acceptance evidence

- Focused `PortableArchiveTests` cover the exact expiry boundary, retry/idempotence, missing/unavailable target, symlink/replacement/identity mismatch, header/signature/catalogue mismatch, and redaction.
- Relevant signed Debug build succeeds.
- Independent Architect/Security, QA, code review, TPM, and Delivery Manager approve completion.

## Material risk and handling

An expired archive is a destructive target. The worker must acquire its scoped bookmark only for an attempt, verify a regular no-follow file and public v1 binding, recheck device/inode immediately before unlink, and retain the catalogue on every non-success path. It records categories only, never paths, bookmark bytes, payloads, or recovery material.
