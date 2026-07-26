# UX-R1-W1 — Separate local workspace escape hatch

**Goal:** Let a recovery-blocked user start a new local workspace without
altering the preserved recovery workspace.

## Scope

- From recovery onboarding, offer **Create separate local workspace**.
- Generate and persist one validated UUID-backed active-local workspace identity
  before creation begins.
- Derive its path and Keychain service/accounts only in compiled code:
  `Application Support/RekonLabs/RekonPursuitLocalWorkspaces/<UUID>` and a
  distinct local-workspace Keychain namespace.
- On later launch, reopen that selected local identity before considering the
  preserved recovery bookmark.
- Provide a Settings route back to the preserved recovery state. It closes the
  active store first and changes only the active selector.

## Non-negotiable boundaries

- Never read, write, clear, replace, copy, move, rename, or delete the
  preserved workspace, its sidecars, or its opaque bookmark.
- Never query, update, or delete legacy/production Keychain items while
  creating the separate workspace.
- Do not accept a path, Keychain service, or account from preferences or UI.
- A failed creation reopens the same local identity's safe state; it must not
  allocate another identity or fall back to the preserved workspace.
- No recovery handoff, Task 2b harness, UX-R2, or R6 work is included.

## Focused evidence

1. Recovery state → separate local create → ready → save opportunity.
2. Relaunch reopens the same local workspace and opportunity.
3. Recovery bookmark, preserved-root manifest, and production/legacy key-store
   spies remain unchanged/no-call during the flow.
4. Failure/cancel remains recoverable at the same local identity.
5. Return to preserved recovery does not mutate either workspace.
