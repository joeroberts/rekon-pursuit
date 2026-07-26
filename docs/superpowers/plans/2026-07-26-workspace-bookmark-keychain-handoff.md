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
- Task 2 is synthetic only: it must never inspect, resolve, select, bookmark,
  read, write, or open a user workspace, a production Keychain item, or the
  default application-support root.
- `SyntheticMigrationConfiguration.validate()` throws before any filesystem,
  bookmark, or Keychain adapter call for a production/default service, account,
  bookmark key, or application-support root. Focused tests prove each rejected
  configuration makes zero adapter calls.
- The normal Debug half of Task 2 uses a disposable fixture inside its isolated
  app container, not an external security-scoped folder. The harness creates
  one fresh canonical `mkdtemp` root below a named non-default synthetic base
  in that container, binds it to a nonce sentinel and redacted nonce digest,
  and passes the exact URL/configuration to seeder, migrator, and normal app.
  Each phase proves the same sentinel and manifest identity; no copy, move,
  reseed, or recreation is permitted between phases. Task 3 alone may request
  an external folder selection.

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
  user-selected read/write access, with no broad file access. Exercise cancel,
  stale, wrong-folder, re-selection, and no-write behavior through the injected
  focused model tests. The native chooser/relaunch verification is deferred to
  Task 3 because that is the first authorized live folder-selection/handoff
  step; Task 1 must not select the user's workspace or simulate a live handoff.

## Task 2: True read-only verification and signed synthetic handoff

**Files:**

- Modify: `RekonPursuitCore/Database/EncryptedDatabase.swift`
- Modify: `RekonPursuitCore/Security/WorkspaceKeyStore.swift`
- Create: `RekonPursuitCore/Security/LegacyWorkspaceKeyMigration.swift`
- Modify: `RekonPursuitCore/Workspace/WorkspaceOpenState.swift`
- Modify: `RekonPursuit/BootstrapApp.swift`
- Modify: `RekonPursuit.xcodeproj/project.pbxproj`
- Test: `RekonPursuitCoreTests/LegacyWorkspaceKeyMigrationTests.swift`

**Produces:** `EncryptedDatabase.verifyReadOnly(url:key:)` and an add-only
legacy-to-DP state machine, proven through distinct signed legacy-seeder,
minimal-migrator, and normal-app artifacts on a disposable fixture.

- [ ] **Step 1: Write failing read-only and handoff tests.**

  Assert `verifyReadOnly` uses `SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX |
  SQLITE_OPEN_URI | SQLITE_OPEN_NOFOLLOW` against a percent-encoded `file:`
  URI with `mode=ro&immutable=1`, only runs `SELECT count(*) FROM
  sqlite_master`, and leaves database/WAL/SHM/journal presence, type,
  inode/size/mtime/SHA-256, and parent-directory contents unchanged. Cover a
  valid key, wrong key, and missing fixture. Assert missing source, source/key
  mismatch, destination conflict, destination-add failure, and target
  re-verification failure never update/delete keys or workspace files.
  Include an `SQLITE_OPEN_NOFOLLOW` symlink-negative case and a fixture path
  with spaces, `?`, `#`, and `%` characters. Inject a narrow SQLite-call capture
  seam so the exact URI, flags, one 32-byte key call, one schema query, a
  `SQLITE_ROW` step result, and successful finalize/close—not merely manifest
  equality—are mechanically asserted. On target re-verification
  failure after `SecItemAdd`, retain the new DP item, source item, and all files
  and report terminal failure without rollback.

- [ ] **Step 2: Implement `verifyReadOnly`.**

  Open the percent-encoded immutable URI with `SQLITE_OPEN_READONLY |
  SQLITE_OPEN_FULLMUTEX | SQLITE_OPEN_URI | SQLITE_OPEN_NOFOLLOW`, apply
  `sqlite3_key`, prepare/step the one schema `SELECT`, finalize, then close.
  Do not use `EncryptedDatabase.open`, migrations, `WorkspaceStore`,
  foreign-key settings, or WAL pragmas. Document that immutable mode verifies
  key/schema access, not a current WAL-consistent snapshot.

- [ ] **Step 3: Implement explicit Keychain namespaces.**

  Define separate source-read and destination-add interfaces, so migration code
  cannot call `SecItemUpdate` or `SecItemDelete`. Define explicit configuration
  carrying only a randomized synthetic service,
  account, bookmark-preference key, and fixture root.
  `SyntheticMigrationConfiguration.validate()` throws before adapter creation
  for production service/account, default application-support root, or default
  bookmark key. The normal primary lifecycle uses
  `kSecUseDataProtectionKeychain = true`; the migration-only source read uses
  the legacy query. Destination creation uses `SecItemAdd`, re-reads the DP
  destination, returns terminal conflict on any existing item, and never calls
  update/delete.

- [ ] **Step 4: Add three minimal synthetic-proof configurations.**

  Build a legacy seeder, separate minimal migrator, and normal sandboxed Debug
  proof. Seeder creates only synthetic DB, nonce-bearing sentinel, and legacy
  key; migrator has no seed/create path. Seeder/migrator compile only the
  verifier, narrow Keychain interfaces, sentinel validation, and redacted
  result handling—not `WorkspaceSession`, `WorkspaceStore`, restore/backup,
  normal bookmark defaults, or networking code. The harness creates one shared
  canonical `mkdtemp` root below the normal app's dedicated synthetic base,
  then passes it to both helpers. They reject it without a matching nonce
  sentinel or when outside that base. They
  are unsandboxed, so do not claim OS-level confinement; instead verify no
  network calls or broad-file entitlements and no compiled product path outside
  the synthetic root.

- [ ] **Step 5: Run an actual signed cross-build synthetic transfer.**

  Use a randomized disposable namespace and three distinct signed builds:
  legacy seeder creates a synthetic SQLCipher database plus nonce sentinel and
  a legacy 32-byte key; minimal migrator verifies the existing source
  read-only and adds a DP key; signed normal Debug opens that same canonical
  app-container fixture through the DP key. The normal proof must fail before
  handoff with only the legacy item, then pass after handoff. Every phase
  records the same redacted nonce digest and manifest identity, with no
  copy/move/reseed/recreation between phases. It does not obtain, resolve, or
  simulate an external security-scoped bookmark.
  Record only redacted build identity, strict-signature and entitlement
  evidence, success/failure, and manifests/hashes. Require `codesign --verify
  --strict --deep`, `codesign -dvv`, and `codesign -d --entitlements :-` for
  all three binaries: non-ad-hoc Apple Development authority, expected and
  effective application identifier, default Keychain group, same designated
  requirement and nonempty TeamIdentifier, hardened runtime, normal app
  sandbox plus its existing `network.client` and selected read/write file-access
  entitlements only, and seeder/migrator unsandboxed without unexpected
  entitlements. The seeder/migrator source/build allowlist must contain no
  outbound-client code. If this fails, stop and do not release a live migration.

- [ ] **Step 6: Record the preflight exit without releasing a live handoff.**

  Update the delivery record with the redacted artifact identity, nonce digest,
  manifests, and acceptance evidence. A successful Task 2 releases no live
  Keychain action, external folder selection, or Task 3 work. Task 3 still
  requires a fresh user-facing approval and separate Architect,
  Security/Privacy, TPM, QA, Code Review, and Delivery release gate.

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
