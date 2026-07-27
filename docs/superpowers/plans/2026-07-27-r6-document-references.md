# RP-R6 Durable Document References Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let an opportunity safely retain, open, verify, and relink one or more local PDF/DOCX references without copying or parsing their contents.

**Architecture:** An injected security-scoped bookmark service owns opaque bookmark creation, temporary access leases, hash verification, and opening. The encrypted workspace stores only the opaque bookmark bytes, current availability state, and existing metadata. The UI exposes explicit actions in the compact Documents area and never treats a missing or mismatched file as valid.

**Tech Stack:** Swift 6, SwiftUI, AppKit/Workspace open APIs, Foundation security-scoped bookmarks, CryptoKit SHA-256, SQLCipher-backed SQLite, XCTest.

## Global Constraints

- Support PDF and DOCX only; reject other types and files larger than 25 MB.
- No source-file deletion, document copy, edit, parse, preview, text extraction, upload, external path persistence, network connection, or new dependency. Removing a stored reference clears its capability but never deletes the source file.
- The source hash and byte count define identity. Relink succeeds only on an exact match.
- Legacy and backup-restored references have bookmark bytes cleared and become `relinkRequired`; never fabricate a bookmark.
- Bookmarks and source paths never appear in activity, errors, reports, or status text.
- Use only user-selected read operations and release every temporary scope. The existing read-write entitlement is retained for already-accepted import/export/backup workflows; R6 requests no entitlement change and performs no write to a document source.

## Release Gate 0 — before Task 1

- [ ] Record independent Planning, Architect, TPM, QA, Delivery Manager, and Security/Privacy approvals for this brief, ADR-004, and the compatibility-matrix reconciliation.
- [ ] Only after those approvals are recorded, update the dashboard/ledger from `Next up` to `In progress` and begin Task 1. No R6 production code precedes this gate.

---

### Task 1: Durable reference model and migration

**Files:**
- Modify: `RekonPursuitCore/Workspace/WorkspaceModels.swift`
- Modify: `RekonPursuitCore/Workspace/Migrations.swift`
- Modify: `RekonPursuitCore/Workspace/WorkspaceStore.swift`
- Modify: `RekonPursuitCore/Workspace/WorkspaceOpenState.swift`
- Modify: `RekonPursuit.xcodeproj/project.pbxproj`
- Test: `RekonPursuitCoreTests/WorkspaceStoreTests.swift`

**Interfaces:**
- Produces `DocumentReferenceAvailability` (`available`, `relinkRequired`) and bookmark-aware `DocumentReference`/`RecordDocumentReference` fields.
- Produces store commands that persist/remove an opaque bookmark or mark a reference relink-required.

- [ ] Write migration tests proving an existing version-22 reference loads as `relinkRequired` and has no bookmark, and an injected migration failure leaves the prior schema/data intact.
- [ ] Run only those tests; verify they fail because the new columns/model are absent.
- [ ] Add one additive migration with non-secret defaults, update the model and store SQL, and preserve all existing metadata/final-sent state.
- [ ] Add tests proving a created reference persists bookmark bytes, availability, and redacted activity events; a 25 MB + 1 byte candidate fails before bookmark creation or a full-file read.
- [ ] Update the existing encrypted-backup restore boundary to open and scrub the staged database in one SQLite transaction, checkpoint and close it, then perform the existing active-workspace swap. On scrub/checkpoint failure discard staging and retain the prior workspace; test failure injection proves the active workspace is never a restored database with a non-null bookmark. Also test a same-Mac restored workspace cannot resolve or expose Open before relink.
- [ ] Add explicit reference removal and opportunity-logical-deletion handling that clears bookmark bytes before the reference leaves active use; test neither path leaves a resolvable bookmark.
- [ ] Run focused migration/store/restore tests and commit the bounded data layer.

### Task 2: Bookmark verification and open/relink service

**Files:**
- Create: `RekonPursuitCore/Workspace/DocumentReferenceBookmark.swift`
- Modify: `RekonPursuitCore/Workspace/WorkspaceStore.swift`
- Test: `RekonPursuitCoreTests/DocumentReferenceBookmarkTests.swift`

**Interfaces:**
- Consumes `DocumentReference` hash/byte count and a selected URL.
- Produces `DocumentReferenceVerification` (`verified`, `relinkRequired`) and a one-shot `openVerified(reference:)` operation.

- [ ] Add the new source and tests to their explicit Xcode project targets.
- [ ] Create isolated non-sensitive fixture files plus their expected byte counts/hashes. Write deterministic injected-dependency tests for allowed PDF/DOCX, renamed/wrong type, symlink/special file, exactly-25-MB accepted, 25-MB-plus-one rejected before full read/bookmark creation, scope balancing on success and failure, opener-called-only-under-active-lease, missing/stale/denied access, hash mismatch, and matching relink.
- [ ] Run the focused service tests; verify they fail because the service is absent.
- [ ] Implement bookmark create/resolve with `.withSecurityScope`, temporary lease balancing, type/size/hash verification, and an injected opener.
- [ ] Ensure failure returns a redacted availability outcome and never exposes source paths/bookmark bytes. On every failed or mismatched relink, preserve the old bookmark, availability, filename, hash, and byte count; replace the bookmark atomically only after matching verification succeeds.
- [ ] Run focused service/store tests, including close/reopen verification with a fresh service instance, and commit the security boundary.

### Task 3: View-model and compact-document workflow

**Files:**
- Modify: `RekonPursuit/WorkspaceViewModel.swift`
- Modify: `RekonPursuit/ContentView.swift`
- Test: `RekonPursuitTests/WorkspaceViewModelTests.swift`

**Interfaces:**
- Consumes selected document URL and per-reference commands from Task 2.
- Produces attach/open/relink status, a relink-only picker route, and refreshed compact-document state.

- [ ] Write model tests proving attach retains a bookmark, failed open marks relink-required, matching relink restores availability, and a mismatched replacement leaves the reference unchanged.
- [ ] Run the focused tests; verify the current metadata-only workflow fails them.
- [ ] Wire attach to create the bookmark after validation, wire explicit Open/Relink/Remove menu actions, and show concise available/relink-required state per reference.
- [ ] Keep Final sent intact and do not add an inline document viewer, copy, or edit behavior.
- [ ] Run focused model/UI-adjacent tests and commit the user workflow.

### Task 4: Focused acceptance and handoff

**Files:**
- Modify: `docs/delivery/remediation-ledger.md`
- Modify: `docs/delivery/dashboard-status.json`
- Generated: `docs/delivery/dashboard/index.html`
- Generated: `docs/delivery/dashboard/remediation.html`

- [ ] Run the R6 focused tests, Debug build, codesign verification, and `git diff --check`.
- [ ] Obtain independent code-review, QA-verifier, Architect, and Security/Privacy-verifier acceptance after implementation.
- [ ] Open a new signed Debug app and complete the attach → relaunch → open and moved-file → relink smoke.
- [ ] Record only material verification evidence, release state, and user acceptance in the delivery ledger/dashboard.
- [ ] Commit and push the accepted slice only after product-owner acceptance.
