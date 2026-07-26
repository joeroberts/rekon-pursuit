# ADR-002: One-time legacy Keychain migration

- **Status:** Superseded pending a storage-access architecture decision
- **Date:** 2026-07-26
- **Decision owners:** Product owner, Architect, Security/Privacy

## Context

Early identity-free development builds created the encrypted workspace key as a
legacy macOS Keychain item and stored the workspace outside the later app
sandbox. A later Personal-Team-signed sandboxed build cannot read that key and
does not have writable access to the preserved external workspace folder, even
though the database remains intact. Creating a new workspace, copying a key
through a file, or permanently disabling the sandbox would risk data loss or
weaken the approved local-data boundary.

## Decision

The former same-bundle temporary migration decision is not released. Its
preflight revealed two invalid assumptions: the current normal app lacks a
write-capable security-scoped path to the legacy workspace, and its existing
database open helper is not read-only because it opens read/write and enables
WAL.

Before a revised Keychain decision can be accepted, the product owner must
select either (a) a persistent user-selected **read/write** security-scoped
bookmark to the existing workspace folder, with no data copy, or (b) a new,
verified copy-into-sandbox migration that keeps the original source intact.
The recommended option is (a): it preserves one authoritative workspace and
uses the platform's explicit permission model.

Any future Keychain handoff must first prove an actual signed, cross-build
synthetic transfer—not merely compare entitlements—and must use a dedicated
`SQLITE_OPEN_READONLY` verification path that executes only a schema `SELECT`.
It must never overwrite or delete the database, sidecars, legacy item, or an
existing destination item.

## Consequences

The original database and legacy Keychain item remain in place. No migration is
currently authorized. A future failed migration must report only a redacted
outcome and make no recovery claim; it may not weaken the product sandbox.
