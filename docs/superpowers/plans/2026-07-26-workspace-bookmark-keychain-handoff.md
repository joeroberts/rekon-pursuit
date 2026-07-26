# Workspace Bookmark and Keychain Handoff Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reopen the preserved external workspace in the sandboxed app without copying it, then perform a separately proven one-time Keychain handoff.

**Architecture:** The recovery UI obtains one user-selected folder bookmark with read/write security scope and keeps its lease alive while the current workspace is open. A true read-only SQLCipher verifier and a disposable signed cross-build Keychain proof must pass before the live handoff is released.

**Tech Stack:** Swift 6, AppKit `NSOpenPanel`, security-scoped bookmarks, Security.framework, SQLCipher, XCTest.

## Global Constraints

- The selected external folder remains authoritative; no database, WAL/SHM sidecar, journal, or legacy Keychain item is copied, moved, updated, or deleted.
- Replace the existing user-selected read-only entitlement with user-selected **read/write** only; do not add broad file access, App Groups, or disable sandboxing.
- Bookmark bytes and Keychain key data never enter logs, activity, backup, export, UI, or arguments.
- A stale bookmark returns to the chooser; it never silently creates a workspace in a new location.
- Before persisting/replacing a bookmark, a temporary scope must verify the selected directory directly contains `workspace.sqlite`; wrong, empty, stale, inaccessible, or cancelled selections retain the prior bookmark and remain recovery-only.
- `WorkspaceViewModel` strongly owns the successful `WorkspaceAccessLease` before calling open, retains it for the external store lifetime, and releases it exactly once on open failure, re-selection, store close, and teardown.
- Live migration is a separately released task after all synthetic and independent review gates pass.

---

## Task 1: External workspace access, isolated from Keychain migration

**Files:**

- Create: `RekonPursuitCore/Workspace/WorkspaceLocationBookmark.swift`
- Modify: `RekonPursuit/RekonPursuit.entitlements`
- Modify: `RekonPursuit/WorkspaceViewModel.swift`
- Modify: `RekonPursuit/ContentView.swift`
- Test: `RekonPursuitTests/WorkspaceLocationBookmarkTests.swift`

**Produces:** `WorkspaceLocationBookmarkStore`, `WorkspaceAccessLease`, and a recovery-only “Choose existing workspace folder…” flow.

- [ ] **Step 1: Write focused failing bookmark tests.**

  Test opaque bookmark persistence, resolving a valid temporary directory,
  stale/missing bookmark recovery, cancellation, and a lease that balances
  `startAccessingSecurityScopedResource` / `stopAccessingSecurityScopedResource`.
  Include selected-empty-directory and selected-wrong-folder cases: both must
  preserve the prior bookmark and emit recovery rather than creation. Tests use
  injected URL/bookmark resolvers; no live user folder.

- [ ] **Step 2: Implement the bookmark store and lease.**

  `validateAndSave(url:)` starts a temporary security scope, requires a direct
  `workspace.sqlite` child, creates the opaque bookmark, and atomically replaces
  the stored bookmark only after success. `resolve()` returns
  `.available(WorkspaceAccessLease)`, `.missing`, or `.stale`. The lease owns
  the scoped resource and calls `stopAccessing…` exactly once on explicit close;
  deinit is a final safeguard only. No path or bookmark data is logged.

- [ ] **Step 3: Change only the entitlement needed for selected-folder writes.**

  Remove `com.apple.security.files.user-selected.read-only`; add `com.apple.security.files.user-selected.read-write`. Retain the app sandbox and every other entitlement.

- [ ] **Step 4: Add recovery UI and view-model flow.**

  When a bookmarked workspace is missing/stale or legacy material needs recovery,
  present `NSOpenPanel` configured for exactly one directory. On selection,
  validate and save the bookmark, retain `WorkspaceAccessLease` strongly before
  opening, and release it only after the external store closes/switches or an
  open fails. Until Task 2 supplies the DP key, this flow is expected to return
  recovery—not creation. The normal first-run create path remains available only
  at the sandbox-local default root and only after explicit Create confirmation.

- [ ] **Step 5: Run focused tests and signed Debug smoke.**

  Build signed Debug and inspect final entitlements: sandbox true plus only
  user-selected read/write access, with no broad file access. In an isolated
  temporary folder fixture, select the folder through recovery, relaunch, and
  confirm the bookmark resolves without a second chooser but remains recovery
  until Task 2. Exercise cancel, stale, wrong-folder, and reselection paths and
  prove no selected-folder writes/key changes. Do not use the user workspace.

## Task 2: True read-only verification and signed synthetic handoff

**Files:**

- Modify: `RekonPursuitCore/Database/EncryptedDatabase.swift`
- Modify: `RekonPursuitCore/Security/WorkspaceKeyStore.swift`
- Create: `RekonPursuitCore/Security/LegacyWorkspaceKeyMigration.swift`
- Modify: `RekonPursuitCore/Workspace/WorkspaceOpenState.swift`
- Modify: `RekonPursuit/BootstrapApp.swift`
- Modify: `RekonPursuit.xcodeproj/project.pbxproj`
- Test: `RekonPursuitCoreTests/LegacyWorkspaceKeyMigrationTests.swift`

**Produces:** `EncryptedDatabase.verifyReadOnly(url:key:)` and an add-only legacy-to-DP state machine, proven on a disposable signed cross-build fixture.

- [ ] **Step 1: Write failing read-only and handoff tests.**

  Assert `verifyReadOnly` uses `SQLITE_OPEN_READONLY`, only runs `SELECT count(*) FROM sqlite_master`, and leaves database/WAL/SHM hashes unchanged. Assert missing source, source/key mismatch, destination conflict, destination write failure, and target verification failure never delete/update keys or workspace files.

- [ ] **Step 2: Implement `verifyReadOnly`.**

  Open with `SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX`, apply `sqlite3_key`, prepare/step the one schema `SELECT`, then close. Do not use `EncryptedDatabase.open`, migrations, `WorkspaceStore`, foreign-key settings, or WAL pragmas.

- [ ] **Step 3: Implement explicit Keychain namespaces.**

  The production key store uses `kSecUseDataProtectionKeychain = true`. The migration-only source store uses the legacy query. Destination creation uses `SecItemAdd` and returns conflict on any existing item; it never calls update/delete.

- [ ] **Step 4: Add temporary same-bundle migration configuration.**

  Same bundle ID and Team, no sandbox, compile-time `LEGACY_KEY_MIGRATION` entry point, not shipped. Its only UI produces a redacted result. It cannot create a workspace or expose data.

- [ ] **Step 5: Run an actual signed cross-build synthetic transfer.**

  Use a randomized disposable service/account/root: migration build verifies a synthetic legacy-key DB and adds DP key; signed normal Debug build resolves a disposable folder bookmark and opens the same fixture through the DP key. Record redacted build identity, success/failure, and hashes only. If this fails, stop and do not release a live migration.

## Task 3: Independently gated live handoff

**Files:**

- Modify: `docs/delivery/dashboard-status.json`
- Modify: `docs/delivery/remediation-ledger.md`
- Generate: `docs/delivery/dashboard/index.html`
- Generate: `docs/delivery/dashboard/remediation.html`

- [ ] **Step 1: Obtain a separate Delivery release after code review, QA, Architect, and Security approval of Tasks 1–2.**

  Do not run this task because a build or synthetic test passes.

- [ ] **Step 2: Ask the user to select the preserved workspace folder.**

  The app stores the read/write bookmark; the original database stays in place. If selection/copy of the bookmark fails, stop without Keychain work.

- [ ] **Step 3: Run the temporary migration once.**

  It must verify source DB read-only, add only an absent DP destination, reverify destination read-only, and stop at the first non-success outcome. Do not retry a live failure.

- [ ] **Step 4: Launch signed normal Debug and request hands-on verification.**

  Confirm recognizable original opportunities appear and no replacement workspace was created. Retain source key and all database artifacts after success.

## Plan self-review

- The selected folder permission, true read-only verifier, actual Keychain boundary proof, and live migration are separate gates.
- No task releases UX-R2, R6, backup/export, or broad storage access.
- The only live action is separately released after independent review and user folder selection.
