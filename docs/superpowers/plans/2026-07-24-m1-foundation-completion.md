# M1 Foundation Completion Implementation Plan

> **For agentic workers:** Use `superpowers:executing-plans` task-by-task. This is the approved correction to the earlier M1-1a/M1-1b split.

**Goal:** Complete the smallest trustworthy local-data foundation before any already-committed M2/M3/M4 work is released.

**Architecture:** The existing encrypted SQLCipher workspace remains the only source of job data. A final schema migration adds durable migration records and logical deletion; SwiftUI presents a local activity timeline and safe read-only/corrupt guidance. It does not add recovery-key backup, restore, purge, actual export, or new tracker features.

**Tech Stack:** Swift 6, SwiftUI, XCTest, SQLCipher 4.17, Keychain; local-only.

## Scope boundary

- M1 includes: migration history/checksums with a verified temporary rollback snapshot, safe corrupt/open guidance, a visible redacted activity timeline, logical opportunity deletion that suppresses queued work, and the visible MVP export limitation.
- M5 includes: recovery-key enrollment, portable encrypted backup/restore, retention/purge, encrypted export, and the warning/confirmation required for an unencrypted export. Do not ship a fake export action before then.
- Existing commits for pipeline/tasks (M2), contacts/interactions (M3), and CSV import (M4) are retained as **unreleased candidate work**. Hide their UI and prevent their commands from being reachable in the M1 archive; do not revert or extend them before M1 is independently accepted.
- No network, AI, Gmail, Calendar, research, signing, notarization, or distribution work.

### Task 1: Make schema migration auditable and fail safely

**Files:**
- Modify: `RekonPursuitCore/Workspace/Migrations.swift`
- Modify: `RekonPursuitCore/Workspace/WorkspaceStore.swift`
- Modify: `RekonPursuitTests/RekonPursuitTests.swift`

- [ ] Write a failing test that opens a synthetic version-4 workspace, runs the version-5 migration, and asserts its existing opportunity/event identifiers and timestamps remain unchanged while `migration_history` contains an immutable v1–v4 baseline record and one immutable version-5 checksum record.
- [ ] Write failing tests that inject a migration failure, an interrupted promotion, and a corrupt snapshot. Each asserts the version-4 workspace remains usable after relaunch, no partial column/history record is visible, and retry/keep-current guidance is available.
- [ ] Add one exclusive, forward-only version-5 migration. Before it runs, create and verify an encrypted temporary snapshot with the same SQLCipher key; keep it only while migration is in progress, destroy it after a verified history/checksum commit, and retain it only for failed-migration recovery. The canonical manifest is the ordered migration version plus normalized SQL text; its SHA-256 is stored with each history record. The test-only failure seam is unavailable from production UI code.
- [ ] Run the focused migration tests, then commit the migration-safety slice.

### Task 2: Add logical deletion and redacted activity visibility

**Files:**
- Modify: `RekonPursuitCore/Workspace/WorkspaceModels.swift`
- Modify: `RekonPursuitCore/Workspace/WorkspaceStore.swift`
- Modify: `RekonPursuit/WorkspaceViewModel.swift`
- Modify: `RekonPursuit/ContentView.swift`
- Modify: `RekonPursuitTests/RekonPursuitTests.swift`
- Modify: `RekonPursuitTests/WorkspaceViewModelTests.swift`

- [ ] Write a failing store test: deleting an opportunity removes it from normal opportunities and needs-attention queries, preserves both an opaque `opportunity_deleted` activity event and a tombstone with exact display value `Deleted opportunity #<first-12-hex(SHA-256(workspaceID || subjectID))>`, and leaves no scheduled work visible.
- [ ] Write a failing view-model test: a ready workspace exposes the timeline event kinds and a deletion refreshes the visible count/timeline without a network request.
- [ ] Implement `deleteOpportunity(id:)` as one database transaction: set `deleted_at`, remove active reminders, persist the opaque tombstone, and append the opaque deletion event. Normal opportunity/task queries must filter deleted opportunities; every existing opportunity-linked mutation/read (stage, interaction, contact link, reminder) must reject or suppress a deleted source; activity records remain append-only.
- [ ] Render a compact local activity timeline and an opportunity Delete action with plain-language confirmation. Do not show event payloads because the activity contract is redacted. Hide pipeline/tasks, contacts, CSV, and interactions from this M1 build; the record list must provide only title, company, and deletion.
- [ ] Run the focused local-store/view-model tests plus `M1-QA-10` redaction assertions that no deleted title/company/user-entered content appears in tombstones or activity records, then commit the deletion/timeline slice.

### Task 3: Make safe-open failure and MVP limitations explicit

**Files:**
- Modify: `RekonPursuitCore/Workspace/WorkspaceOpenState.swift`
- Modify: `RekonPursuit/WorkspaceViewModel.swift`
- Modify: `RekonPursuit/ContentView.swift`
- Modify: `RekonPursuitTests/WorkspaceViewModelTests.swift`
- Modify: `README.md`

- [ ] Write failing session/view-model tests for: (a) a fresh root with no artifacts permits explicit create, (b) missing Keychain key plus an existing database artifact blocks create and does not write a Keychain replacement, and (c) corrupt/bad-key database opens as a distinct read-only state with no enabled mutation or replacement action.
- [ ] Write a failing test that confirms the UI presents the MVP limitation: no backup, restore, purge, or export action is available; these are deferred rather than silently absent.
- [ ] Split explicit create from open-existing. `open` must require an existing database and must never pass SQLite create flags; `create` must preflight that no workspace artifacts already exist and must write temporary material before atomically promoting the new workspace/key. Distinguish corrupt/unreadable storage from generic unavailable key/service states at the session boundary. Present stable read-only guidance; disable create/delete/mutation actions until a workspace is ready.
- [ ] Add concise README setup/limitation text that local data is retained until deletion and this build has no portable recovery or export.
- [ ] Run focused tests, an unsigned archive, entitlement allowlist, and tracked-secret scan. Commit the safe-state/limitation slice.

### Task 4: Reconcile delivery state and conduct one M1 gate

**Files:**
- Modify: `docs/delivery/m0-m1-task-plan.md`
- Modify: `docs/delivery/m0-readiness-ledger.md`
- Modify: `docs/delivery/roadmap.md`
- Modify: `docs/implementation-handoff.md`

- [ ] Record this user-approved M1 scope correction, including the M5 lifecycle deferrals and the frozen/unreleased M2/M3/M4 candidate work under the canonical milestone mapping.
- [ ] Ask independent Architect, TPM, QA/Test, Security/Privacy, Code Review, and Delivery roles to review the completed M1 evidence once. Fix only P0/P1 issues found.
- [ ] Record the resulting M1 decision and release only the next eligible MVP slice.

## Verification

- Focused local XCTest only for migration rollback/preservation, logical deletion/queued-work suppression, activity visibility, and safe-open guidance.
- Build-only CI remains archive/macOS-smoke only; no coverage gate and no hosted test suite.
- Before any release claim: run the focused local tests, unsigned archive, entitlement inspection, and secret scan against the final commit.
