# Legacy Keychain Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Status:** Superseded before implementation. Independent Architect and QA review found that the current Keychain-only design cannot give the sandboxed app writable access to the legacy external workspace, and the planned database verification was not truly read-only. A revised plan requires an approved storage-access architecture first.

**Goal:** Let the signed, sandboxed app reopen the existing encrypted workspace by performing one proven, one-time legacy-Keychain-to-Data-Protection-Keychain handoff without modifying user data.

**Architecture:** A future revised plan must first establish persistent writable access to the existing workspace folder through a user-selected security-scoped bookmark (recommended) or a separately approved verified-copy design. It must use a dedicated `SQLITE_OPEN_READONLY` verification API and an actual signed cross-build synthetic Keychain transfer. The migration is unavailable in normal builds.

**Tech Stack:** Swift 6, Security.framework, SQLCipher, SwiftUI/Xcode, XCTest.

## Global Constraints

- Bundle ID: `com.rekonlabs.RekonPursuit`; development Team: `2UA854NLX4`.
- Production Debug/Release remains sandboxed. The migration build is temporary, compile-time-only, and never shipped.
- No key value may enter a file, log, argument, UI, activity record, backup, export, or network request.
- Do not update or delete a source key, destination key, workspace database, WAL/SHM sidecar, or journal.
- Do not use the real user workspace in automated checks. The user workspace is touched only after synthetic preflight succeeds and only through the separately approved revised migration operation.
- If entitlement identity/group equivalence cannot be proved, stop before migration and record the blocker; do not weaken the production sandbox.

---

## File map

| File | Responsibility |
| --- | --- |
| `RekonPursuitCore/Security/WorkspaceKeyStore.swift` | Encapsulates legacy and Data Protection Keychain queries without exposing key material. |
| `RekonPursuitCore/Security/LegacyWorkspaceKeyMigration.swift` | One-time, read-only-verified legacy-to-DP copy state machine. |
| `RekonPursuitCore/Workspace/WorkspaceOpenState.swift` | Exposes a read-only workspace key verification seam for the migration. |
| `RekonPursuit/BootstrapApp.swift` | Selects the migration-only entry point behind a compile-time flag; normal build remains unchanged. |
| `RekonPursuit.xcodeproj/project.pbxproj` | Adds a temporary migration build configuration with same bundle/team and no sandbox. |
| `RekonPursuitCoreTests/LegacyWorkspaceKeyMigrationTests.swift` | Deterministic source/destination and failure-path fixtures; no real Keychain or user workspace. |
| `docs/architecture/adr/ADR-002-legacy-keychain-migration.md` | Durable security decision. |
| `docs/delivery/remediation-ledger.md` and `docs/delivery/dashboard-status.json` | Meaningful release/verification/acceptance transitions only. |

## Task 1: Prove the entitlement and synthetic handoff boundary

**Files:**

- Create: `RekonPursuitCoreTests/LegacyWorkspaceKeyMigrationTests.swift`
- Modify: `RekonPursuitCore/Security/WorkspaceKeyStore.swift`
- Modify: `RekonPursuitCore/Workspace/WorkspaceOpenState.swift`
- Modify: `RekonPursuit.xcodeproj/project.pbxproj`

**Consumes:** Existing `WorkspaceSession`, `EncryptedDatabase`, and `WorkspaceKeyStore` protocol.

**Produces:** A testable `WorkspaceKeyNamespace` query mode, `WorkspaceKeyMigrationPreflight`, and a temporary build configuration whose signed entitlements can be compared with the production Debug build.

- [ ] **Step 1: Add an in-memory fake key namespace and a failing fixture.**

  The fixture must create a disposable encrypted database, make only the legacy namespace contain its 32-byte key, and assert the Data Protection namespace cannot open it before migration. It must not call `SecItem*` APIs.

  ```swift
  func testDataProtectionNamespaceCannotOpenLegacyFixtureBeforeMigration() throws {
      let fixture = try LegacyWorkspaceFixture.make()
      XCTAssertNil(try fixture.destination.readWorkspaceKey())
      XCTAssertThrowsError(try fixture.session(using: fixture.destination).openVerifiedReadOnly())
  }
  ```

- [ ] **Step 2: Run the fixture and verify the expected failure.**

  Run: `xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit -destination 'platform=macOS,arch=arm64' -only-testing:RekonPursuitCoreTests/LegacyWorkspaceKeyMigrationTests/testDataProtectionNamespaceCannotOpenLegacyFixtureBeforeMigration`

  Expected: compile failure until the narrowly scoped test seam exists, then a passing assertion that destination access is absent.

- [ ] **Step 3: Implement explicit legacy and Data Protection query modes.**

  `KeychainWorkspaceKeyStore` must use Data Protection mode for its normal primary and pending reads/writes/deletes. Add a separate internal `LegacyWorkspaceKeyStore` that uses the old query only. Both use the exact same fixed service/account; neither exposes raw query results outside `Data`. Destination writes use `SecItemAdd` only and return a conflict rather than `SecItemUpdate`.

  ```swift
  enum WorkspaceKeyNamespace { case legacyFile, dataProtection }
  enum WorkspaceKeyMigrationError: Error { case destinationAlreadyExists, sourceMissing }
  ```

- [ ] **Step 4: Add the read-only verification seam.**

  Add an internal method that opens the exact existing `workspace.sqlite` with a supplied key using `createIfMissing: false`, performs a read-only schema query, closes the database, and returns only success/failure. It must not instantiate `WorkspaceStore`, run migrations, or append an activity event.

- [ ] **Step 5: Create a temporary `LegacyKeyMigration` build configuration.**

  It uses bundle ID `com.rekonlabs.RekonPursuit`, Team `2UA854NLX4`, `ENABLE_APP_SANDBOX = NO`, and a single Swift compilation condition such as `LEGACY_KEY_MIGRATION`. It is not the normal Debug or Release configuration and is not archived/released. The normal Debug entitlements remain unchanged.

- [ ] **Step 6: Build both configurations and compare entitlements before any live migration.**

  Run signed `Debug` and `LegacyKeyMigration` builds to separate derived-data directories, then inspect with `codesign -d --entitlements :-`. Record only the presence/equality of application identity or default keychain group—never a key value. If the identity group cannot be proved equal, stop and do not implement/run the migration.

- [ ] **Step 7: Commit the preflight boundary.**

  ```bash
  git add RekonPursuitCore/Security/WorkspaceKeyStore.swift RekonPursuitCore/Workspace/WorkspaceOpenState.swift RekonPursuitCoreTests/LegacyWorkspaceKeyMigrationTests.swift RekonPursuit.xcodeproj/project.pbxproj
  git commit -m "feat: add legacy keychain migration preflight"
  ```

## Task 2: Implement the bounded migration state machine

**Files:**

- Create: `RekonPursuitCore/Security/LegacyWorkspaceKeyMigration.swift`
- Modify: `RekonPursuit/BootstrapApp.swift`
- Modify: `RekonPursuitCoreTests/LegacyWorkspaceKeyMigrationTests.swift`

**Consumes:** The verified identity preflight and internal legacy/destination key namespaces from Task 1.

**Produces:** `LegacyWorkspaceKeyMigration.run()` returning a redacted outcome: `.migrated`, `.sourceMissing`, `.sourceDoesNotOpenWorkspace`, `.destinationExists`, `.destinationWriteFailed`, `.destinationDoesNotOpenWorkspace`, or `.identityNotProven`.

- [ ] **Step 1: Write failing success and negative-path tests.**

  ```swift
  func testMigrationAddsDestinationOnlyAfterSourceReadOnlyVerification() throws
  func testDestinationConflictLeavesBothNamespacesAndDatabaseUnchanged() throws
  func testSourceVerificationFailureCreatesNoDestinationKey() throws
  func testDestinationVerificationFailureRetainsSourceAndDestinationForInspection() throws
  ```

  Use test fakes to record add/update/delete attempts. Every test asserts no update/delete operation and no database file modification.

- [ ] **Step 2: Run the focused tests to verify the state machine is absent.**

  Run: `xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit -destination 'platform=macOS,arch=arm64' -only-testing:RekonPursuitCoreTests/LegacyWorkspaceKeyMigrationTests`

  Expected: failure until `LegacyWorkspaceKeyMigration` exists.

- [ ] **Step 3: Implement the linear migration state machine.**

  The state machine must:

  1. Require an entitlement identity preflight success.
  2. Read the legacy source exactly once.
  3. Verify source opens the existing database read-only.
  4. Fail on any existing destination key.
  5. Add destination once, without update.
  6. Re-read destination and verify it opens the same database read-only.
  7. Return a redacted outcome; never delete either key.

- [ ] **Step 4: Add migration-build-only startup.**

  Under `#if LEGACY_KEY_MIGRATION`, show a minimal local result window with no workspace content, no key details, and no retry/create controls. The normal app code path is unchanged. The migration build never invokes `WorkspaceViewModel.createWorkspaceIfNeeded()`.

- [ ] **Step 5: Run focused tests and normal build.**

  Run the focused migration test bundle and signed normal Debug build. Confirm the normal build remains sandboxed and no migration UI is reachable there.

- [ ] **Step 6: Commit the migration state machine.**

  ```bash
  git add RekonPursuitCore/Security/LegacyWorkspaceKeyMigration.swift RekonPursuit/BootstrapApp.swift RekonPursuitCoreTests/LegacyWorkspaceKeyMigrationTests.swift
  git commit -m "feat: add one-time legacy workspace key migration"
  ```

## Task 3: Controlled live handoff and independent verification

**Files:**

- Modify: `docs/delivery/dashboard-status.json`
- Modify: `docs/delivery/remediation-ledger.md`
- Generate: `docs/delivery/dashboard/index.html`
- Generate: `docs/delivery/dashboard/remediation.html`

**Consumes:** Passing synthetic tests, matching entitlement proof, and the reviewed migration build.

**Produces:** A signed normal app that opens the preserved user workspace, followed by user hands-on confirmation.

- [ ] **Step 1: Recheck the live workspace exists without reading its key.**

  Confirm only `workspace.sqlite` presence and that no migration destination is assumed. Do not inspect or print a key.

- [ ] **Step 2: Run the migration build once.**

  It must stop safely on any non-success outcome. Do not rerun a failure or alter source/database artifacts. Capture only its redacted success/failure outcome.

- [ ] **Step 3: Launch the signed sandboxed Debug app.**

  Verify it opens the existing opportunity count rather than creating/replacing a workspace. If it remains in recovery, stop; no further repair attempt belongs in this task without an architecture review.

- [ ] **Step 4: Request user hands-on verification.**

  Ask the user to confirm recognizable original opportunities appear and that no workspace was recreated. Send exactly one Pushover notification for this verification-ready transition.

- [ ] **Step 5: Record only the real delivery transition.**

  After user confirmation, update dashboard/ledger/rendered dashboard together and retain the legacy source key. Do not mark UX-R1 accepted until its remaining UX-R1 acceptance criteria are independently approved.

## Plan self-review

- Spec coverage: source/destination identity proof, synthetic proof, non-destructive migration, real workspace evidence, user verification, and dashboard discipline each map to a task.
- Scope: one recovery correction under UX-R1; it does not release UX-R2, R6, backup, export, or unrelated UI work.
- Ambiguity resolved: target key conflict is an abort, never an overwrite; no retry after live migration failure without new architecture review.
