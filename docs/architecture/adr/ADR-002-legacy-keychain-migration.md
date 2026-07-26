# ADR-002: One-time legacy Keychain migration

- **Status:** Accepted for the UX-R1 corrective task
- **Date:** 2026-07-26
- **Decision owners:** Product owner, Architect, Security/Privacy

## Context

Early identity-free development builds created the encrypted workspace key as a
legacy macOS Keychain item. A later Personal-Team-signed sandboxed build cannot
read that item, even though the database remains intact. Creating a new
workspace, copying a key through a file, or permanently disabling the sandbox
would risk data loss or weaken the approved local-data boundary.

## Decision

Use a temporary, non-shipped build with the same bundle ID and Personal Team to
copy the verified legacy key directly in memory into a new data-protection
Keychain item in the app's proven default app-identity group. The normal
sandboxed app thereafter queries only the data-protection item.

The migration runs only after both builds prove the same app-identity Keychain
group. It verifies the legacy key opens the existing database read-only before
creating the destination item, then verifies the destination item opens that
same database. It never overwrites or deletes the database, sidecars, legacy
item, or an existing destination item.

## Consequences

The user retains a safe rollback artifact: the original database and legacy
Keychain item remain in place. A failed migration reports only a redacted
outcome and makes no recovery claim. If entitlement proof cannot establish a
shared app identity, this approach is rejected and requires a new approved
shared-Keychain architecture decision; the product sandbox is not disabled.
