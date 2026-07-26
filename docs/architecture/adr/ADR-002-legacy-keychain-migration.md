# ADR-002: One-time legacy Keychain migration

- **Status:** Accepted for disposable synthetic proof only
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
preflight revealed two invalid assumptions: the current normal app lacked a
write-capable security-scoped path to the legacy workspace, and its existing
database open helper is not read-only because it opens read/write and enables
WAL. ADR-003 resolves the first issue with a user-selected read/write folder
bookmark; this ADR now governs only the safe synthetic proof needed before a
separate live-handoff decision.

The approved storage choice is a persistent user-selected **read/write**
security-scoped bookmark to the existing workspace folder, with no data copy.
The database remains authoritative in that selected folder.

The next released work is a disposable synthetic proof only. Every synthetic
run receives randomized, test-only Keychain service and account values,
bookmark preference key, and workspace root. It must never use the production
service/account, the production bookmark preference, the default application
support root, a user-selected folder, or user workspace data.
`SyntheticMigrationConfiguration.validate()` must throw before any filesystem,
bookmark, or Keychain adapter call when a production/default value is supplied.

The normal Debug half of that proof uses a fixture inside its isolated app
container. The harness creates one fresh, canonical `mkdtemp` fixture root
below a named non-default synthetic base inside that container, then passes
that exact URL and a nonce-bound configuration to the seeder, migrator, and
normal app. Each phase verifies the same nonce sentinel and redacted nonce
digest plus identical manifest identity; no copy, move, reseed, or recreation
is permitted between phases. The normal app does not obtain or resolve a real
security-scoped bookmark. An injected, non-security-scoped fixture location
may exercise the Keychain handoff boundary only. Task 3 remains the first
separately released work that may ask the user to select an external folder.

The verifier must open only a percent-encoded `file:` URI with
`mode=ro&immutable=1` and `SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX |
SQLITE_OPEN_URI | SQLITE_OPEN_NOFOLLOW`. It may apply `sqlite3_key` and run
exactly one `SELECT count(*) FROM sqlite_master`, then finalize and close. It
must not use the normal database opener, migrations, stores, pragmas, or WAL
configuration. Before and after verification, the proof compares presence,
file type, inode/size/modification time/SHA-256, and parent-directory contents
for the database and any WAL, SHM, or journal sidecars. Immutable verification
proves the key and schema only; it does not claim a current WAL-consistent
snapshot.

The proof uses three distinct signed artifacts/runs: a legacy seeder creates
only the synthetic database, nonce-bearing sentinel, and legacy item; a
separate migrator reads that existing source, immutable-verifies it, and adds
the DP item; the normal sandboxed build proves its expected pre-handoff failure
and post-handoff DP open. The migrator contains no seeding or workspace-create
path. It reads the legacy key without Data Protection, adds an absent
Data-Protection destination using `SecItemAdd`, re-reads that destination, and
never updates or deletes either item. A destination conflict is terminal.

The seeder and migrator are minimal source-excluded targets/configurations:
they compile only the verifier, narrow Keychain interfaces, sentinel checking,
and redacted result handling—not `WorkspaceSession`, `WorkspaceStore`,
restore/backup, normal bookmark defaults, or networking implementation. Each
uses a fresh harness-owned `mkdtemp` root below a dedicated synthetic base and
requires a matching nonce-bearing sentinel before any Keychain read. Roots are
canonicalized and rejected outside that base. The unsandboxed helpers have no
network calls or broad-file entitlements, while retaining the unavoidable
OS-granted capability of an unsandboxed process.

An actual signed cross-build synthetic transfer—not entitlement comparison—must
pass before any separate live-handoff decision. The seeder, migrator, and
normal Debug proof must meet strict Apple Development signature evidence:
non-ad-hoc Apple Development authority, expected identifier, the same
nonempty TeamIdentifier, hardened runtime, and strict signature verification.
Evidence must record both `codesign -dvv` and `codesign -d --entitlements :-`
for all three binaries: expected identifier, effective application identifier,
default Keychain group, the same designated requirement and nonempty Team ID,
normal sandbox plus its existing `network.client` and selected read/write
file-access entitlements only, and seeder/migrator unsandboxed without
unexpected entitlements.

## Consequences

The original database and legacy Keychain item remain in place. No live
migration is currently authorized. A future failed migration must report only
a redacted outcome and make no recovery claim; it may not weaken the product
sandbox. The temporary seeder and migrator are unsandboxed and therefore retain
normal OS-granted filesystem/network capability, but their compiled product
paths are fail-closed to a fresh synthetic root and have no network calls or
broad-file entitlements. The normal proof keeps sandboxing and its existing
`network.client` plus selected read/write file-access entitlement; the proof
does not perform a network call.
