# M1-1a Local Record Spine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` or `superpowers:executing-plans` to implement this plan task-by-task.

**Goal:** Deliver the smallest usable local Rekon Pursuit workspace: an encrypted workspace can be created and reopened, one opportunity can be added, and exactly one redacted activity event is committed with it.

**Architecture:** Keep the production boundary narrow: a `WorkspaceStore` owns a serialized SQLCipher connection, schema/migrations, and atomic writes; a Keychain adapter supplies the workspace key; SwiftUI consumes view models and never issues SQL. This is M1-1a only: backup/export/recovery lifecycle commands are M1-1b, not a reason to delay a real local record spine.

**Tech Stack:** Swift 6 / SwiftUI / XCTest; SQLCipher 4.17 candidate statically integrated after a macOS-14 universal feasibility check; Apple Security framework for Keychain access; no network entitlement or third-party Swift ORM.

## Global Constraints

- macOS 14.0, universal `arm64` and `x86_64`, App Sandbox, Hardened Runtime.
- Local-only: no network, Gmail, Calendar, AI, research, telemetry, or live service.
- CI remains build/archive/macOS-smoke only; focused behavior tests run locally.
- Tests use synthetic data, fixed UTC time, deterministic IDs, a fake Keychain, and a unique temporary workspace root.
- Every create mutation writes its opportunity and one redacted activity event in the same database transaction.
- No plaintext fallback; locked, denied, missing-key, corrupt-database, and failed-migration states show recovery guidance.

## Task 1: Prove and integrate the encrypted SQLite dependency

**Files:**
- Create: `Dependencies/SQLCipher/README.md`
- Create: `RekonPursuitCore/Database/EncryptedDatabase.swift`
- Modify: `RekonPursuit.xcodeproj/project.pbxproj`
- Test: `RekonPursuitCoreTests/EncryptedDatabaseTests.swift`

- [ ] Write failing tests for correct-key open, wrong-key rejection, and stock SQLite unreadability using a synthetic temporary database.
- [ ] Build SQLCipher 4.17.0 from the M0-selected immutable source revision as a static universal library; record source hash, build commands, license, and architecture evidence in `Dependencies/SQLCipher/README.md`.
- [ ] Implement `EncryptedDatabase.open(url:key:) throws` with parameterized SQL only, foreign keys enabled, WAL enabled, and no key/pragmas logged.
- [ ] Run the focused database tests on an isolated temporary root; commit `build: add verified SQLCipher dependency`.

## Task 2: Implement workspace schema, migration, and atomic create command

**Files:**
- Create: `RekonPursuitCore/Workspace/WorkspaceStore.swift`
- Create: `RekonPursuitCore/Workspace/WorkspaceModels.swift`
- Create: `RekonPursuitCore/Workspace/Migrations.swift`
- Test: `RekonPursuitCoreTests/WorkspaceStoreTests.swift`

- [ ] Write failing tests for empty workspace creation, schema version recording, one `CreateOpportunity` result, one matching activity event, and injected failure rollback.
- [ ] Define `Opportunity`, `ActivityEvent`, `CreateOpportunity`, and `WorkspaceStore` with explicit actor and correlation IDs.
- [ ] Implement schema version 1 and a serialized transaction that inserts the opportunity and redacted `opportunity_created` event together.
- [ ] Run focused workspace tests; commit `feat: add local opportunity record spine`.

## Task 3: Add Keychain abstraction, safe-open states, and relaunch

**Files:**
- Create: `RekonPursuitCore/Security/WorkspaceKeyStore.swift`
- Create: `RekonPursuitCore/Workspace/WorkspaceOpenState.swift`
- Test: `RekonPursuitCoreTests/WorkspaceOpenTests.swift`

- [ ] Write failing tests for available, locked, denied, and missing key states; verify no blank replacement workspace or plaintext fallback.
- [ ] Implement a production Keychain adapter and test fake behind `WorkspaceKeyStore`.
- [ ] Implement workspace reopen using the same stored key and verify stable opportunity/event IDs and timestamps after relaunch.
- [ ] Run focused open/relaunch tests; commit `feat: add local workspace key handling`.

## Task 4: Expose the minimal local UI and verify the vertical slice

**Files:**
- Modify: `RekonPursuit/BootstrapApp.swift`
- Modify: `RekonPursuit/ContentView.swift`
- Create: `RekonPursuit/WorkspaceViewModel.swift`
- Test: `RekonPursuitTests/WorkspaceViewModelTests.swift`

- [ ] Write failing view-model tests for create validation, successful local create, and locked/corrupt recovery state.
- [ ] Replace the bootstrap placeholder with a local workspace screen: open/create, job title/company inputs, Create, visible success/activity count, and accessible recovery message.
- [ ] Verify keyboard operation and non-color error/status text; no network request is possible.
- [ ] Run focused local tests, build/archive, secret/entitlement checks, and macOS-14 smoke; update the delivery ledger and M1-1a evidence; commit `feat: deliver M1-1a local record spine`.

## Scope deliberately deferred to M1-1b

Portable backup/recovery enrollment, restore, retention/purge, logical deletion, and export confirmation remain governed by ADR-001 but are not implemented in M1-1a. They must be completed before releasing broader local tracker slices.
