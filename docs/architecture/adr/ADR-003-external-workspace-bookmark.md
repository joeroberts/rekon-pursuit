# ADR-003: Persistent access to the existing workspace folder

- **Status:** Accepted
- **Date:** 2026-07-26
- **Decision owners:** Product owner, Architect, Security/Privacy

## Context

The preserved workspace lives outside Rekon Pursuit's sandbox. A sandboxed
SQLite/SQLCipher app must write its normal WAL/SHM files, so read-only file
selection cannot open the workspace safely. A Keychain handoff alone cannot
grant file access.

## Decision

On the recovery screen, the app presents a native directory picker. The user
selects the existing Rekon Pursuit workspace folder once. The sandboxed app
creates a security-scoped **read/write** bookmark for only that folder and
stores the opaque bookmark in its local preferences. It resolves and starts
that scope before accessing the workspace and retains the access lease only
while the workspace is open.

The selected external folder remains the single authoritative workspace. The
app does not copy, move, rename, replace, or delete the database, sidecars, or
legacy Keychain item. If the bookmark is stale or permission is unavailable,
the app returns to recovery and asks the user to select the folder again.

Before storing or replacing a bookmark, the app opens a temporary scope and
requires that the selected directory directly contain `workspace.sqlite`. A
wrong, empty, inaccessible, stale, or cancelled selection leaves the prior
bookmark intact and remains in recovery; it never offers workspace creation in
the external folder. Creation remains available only for the separate,
sandbox-local first-run path after explicit user confirmation.

`WorkspaceViewModel` owns the successful `WorkspaceAccessLease` strongly for
the full lifetime of an externally rooted session/store. It releases that lease
exactly once after the store closes, on failed open, on re-selection, and at
app teardown. The app never relies on incidental deinitialization to keep a
store operating after its security scope ends.

This decision does not itself migrate the Keychain key. A separately gated,
temporary migration build may run only after a true read-only verifier and a
disposable signed cross-build Keychain transfer prove the complete handoff.

## Consequences

The user must select the existing folder once. If it is moved later, they must
locate it again. This avoids duplicate databases and retains an explicit,
least-privilege macOS permission boundary. The previous Keychain-only decision
in ADR-002 remains superseded; this ADR supplies its required storage-access
precondition.
