# R7b-1 Automatic Portable Archive Expiry Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove a verified portable recovery archive only after its fixed 30-day retention period, at a bounded app-run service opportunity, without touching active workspace data.

**Architecture:** Add a constrained, durable archive-lifecycle state to the local catalogue and a focused expiry worker separate from archive creation. The worker resolves the existing security-scoped bookmark only for an attempt, verifies the file's readable public header and its catalogue binding, rechecks file identity immediately before unlinking, and records only redacted outcomes. Workspace opening invokes the service once after a successful open; it is not a background daemon and makes no exact-clock promise while the app is closed.

**Tech Stack:** Swift 6, SwiftUI, Foundation, CryptoKit, Darwin POSIX file descriptors, encrypted SQLite via the existing `EncryptedDatabase`, XCTest.

## Global Constraints

- R7b-1 depends on accepted RP-R7a-4 and the approved R7b expiry/purge design in `docs/superpowers/specs/2026-07-27-r7b-expiry-and-purge-design.md`.
- Process only portable archive catalogue entries at or after `expires_at`; do not expire, purge, rewrite, or alter active workspace data.
- Deletion requires security-scoped bookmark access, a regular no-follow file, readable v1 header/signature/checksum validation, a catalogue ID/fingerprint/checksum match, and a final device/inode recheck before unlink.
- Persist no recovery key, raw bookmark, resolved path, payload, or free-form filesystem error in lifecycle state or activity.
- Do not modify v1 archive encoding, full recovery-key verification, restore, protected export, or R7b-2 purge/rewrite behavior.
- A failed, missing, inaccessible, replaced, symlinked, nonregular, or mismatched target must remain non-destructively represented in the catalogue; it is never a successful deletion.
- Run only the focused material tests defined below plus the relevant signed Debug build. No daemon, network, new dependency, hosted CI test suite, or coverage gate.

---

## File structure

| File | Responsibility |
| --- | --- |
| `RekonPursuitCore/Workspace/WorkspaceModels.swift` | Constrained lifecycle state and redacted expiry outcome exposed by catalogue reads. |
| `RekonPursuitCore/Workspace/Migrations.swift` | Rollback-safe migration from catalogue v25/26 to durable expiry state and last outcome category. |
| `RekonPursuitCore/Workspace/PortableArchiveService.swift` | Readable, recovery-key-free v1 archive-header verifier used only to bind a file to a catalogue row. |
| `RekonPursuitCore/Workspace/PortableArchiveExpiryWorker.swift` | Isolated serial expiry attempt: bookmark scope, no-follow open, header verification, identity recheck, unlink, durable redacted state/activity. |
| `RekonPursuitCore/Workspace/WorkspaceStore.swift` | Injected expiry seam, catalogue queries, and one bounded service-opportunity entry point. |
| `RekonPursuit/WorkspaceViewModel.swift` | Calls the store service after a successful workspace open and refreshes published catalogue state without blocking UI. |
| `RekonPursuit/ContentView.swift` | Presents existing catalogue state truthfully; no new destructive control. |
| `RekonPursuitCoreTests/PortableArchiveTests.swift` | Deterministic expiry, failure, identity, and redaction regression tests. |

### Task 1: Durable catalogue lifecycle contract

**Files:**
- Modify: `RekonPursuitCore/Workspace/WorkspaceModels.swift`
- Modify: `RekonPursuitCore/Workspace/Migrations.swift`
- Modify: `RekonPursuitCore/Workspace/WorkspaceStore.swift:827-845`
- Test: `RekonPursuitCoreTests/PortableArchiveTests.swift`

**Interfaces:**
- Consumes: the existing `portable_archive_catalogue` v25 columns and migration-snapshot convention.
- Produces:
  ```swift
  nonisolated enum PortableArchiveLifecycleState: String, Equatable, Sendable {
      case verified = "Verified"
      case expiredPendingRemoval = "expired_pending_removal"
      case expiredRetryable = "expired_retryable"
      case expiredBlocked = "expired_blocked"
      case expiredMissing = "expired_missing"
  }

  nonisolated enum PortableArchiveExpiryOutcome: String, Equatable, Sendable {
      case none, scopeUnavailable, targetMissing, targetUnsafe, identityMismatch,
           archiveMismatch, ioFailure, removed
  }
  ```
  `PortableArchiveCatalogueRow` gains `lifecycleState` and `lastExpiryOutcome`; `WorkspaceStore` gains internal catalogue read/update helpers used by Task 2.

- [ ] **Step 1: Write the failing migration and model tests**

  Add tests that create a v26 database, open it through `WorkspaceStore`, and assert that existing verified rows decode as `.verified` / `.none`. Add a direct invalid-state fixture asserting `WorkspaceStoreError.unexpectedDatabaseValue`, so unknown database text never becomes a silently accepted lifecycle state.

  ```swift
  func testPortableArchiveCatalogueMigrationDefaultsExistingRowsToVerified() throws {
      let store = try makeStoreAtVersion26(withArchiveCatalogueRow: true)
      XCTAssertEqual(try store.portableArchiveCatalogue().single().lifecycleState, .verified)
      XCTAssertEqual(try store.portableArchiveCatalogue().single().lastExpiryOutcome, .none)
  }
  ```

- [ ] **Step 2: Run the focused test to verify it fails**

  Run:
  ```bash
  xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit -destination 'platform=macOS,arch=arm64' -only-testing:RekonPursuitCoreTests/PortableArchiveTests/testPortableArchiveCatalogueMigrationDefaultsExistingRowsToVerified
  ```
  Expected: FAIL because the model fields and catalogue columns do not exist.

- [ ] **Step 3: Add the constrained model and migration**

  Add a single migration after v26 with a checksum matching its exact schema string. Add non-null `lifecycle_state TEXT NOT NULL DEFAULT 'Verified'` and `last_expiry_outcome TEXT NOT NULL DEFAULT 'none'`; do not add a path, key, payload, or free-form error column. Update the catalogue SELECT and initializer to decode the two values through the enums above.

  ```swift
  guard let lifecycleState = PortableArchiveLifecycleState(rawValue: state),
        let lastExpiryOutcome = PortableArchiveExpiryOutcome(rawValue: outcome) else {
      throw WorkspaceStoreError.unexpectedDatabaseValue
  }
  ```

- [ ] **Step 4: Run the focused test to verify it passes**

  Run the command from Step 2, then run the existing portable archive test class:
  ```bash
  xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit -destination 'platform=macOS,arch=arm64' -only-testing:RekonPursuitCoreTests/PortableArchiveTests
  ```
  Expected: PASS; existing rows remain visible as verified and unknown lifecycle data fails closed.

- [ ] **Step 5: Commit the independently reviewable migration/model contract**

  ```bash
  git add RekonPursuitCore/Workspace/WorkspaceModels.swift RekonPursuitCore/Workspace/Migrations.swift RekonPursuitCore/Workspace/WorkspaceStore.swift RekonPursuitCoreTests/PortableArchiveTests.swift
  git commit -m "feat: add portable archive expiry state"
  ```

### Task 2: Header-only verification and safe expiry worker

**Files:**
- Modify: `RekonPursuitCore/Workspace/PortableArchiveService.swift`
- Create: `RekonPursuitCore/Workspace/PortableArchiveExpiryWorker.swift`
- Modify: `RekonPursuitCore/Workspace/WorkspaceStore.swift`
- Test: `RekonPursuitCoreTests/PortableArchiveTests.swift`

**Interfaces:**
- Consumes: `PortableArchiveCatalogueRow`, `PortableArchiveLifecycleState`, `PortableArchiveExpiryOutcome`, and the existing archive v1 framing constants.
- Produces:
  ```swift
  nonisolated struct PortableArchivePublicBinding: Equatable, Sendable {
      let archiveID: UUID
      let expiresAt: Date
      let ciphertextChecksum: Data
      let signingKeyFingerprint: Data
  }

  static func verifyPublicBinding(data: Data) throws -> PortableArchivePublicBinding
  func runPortableArchiveExpiryServiceOpportunity() async throws -> [PortableArchiveCatalogueRow]
  ```
  The store method returns the refreshed catalogue; it must not accept or read a recovery key.

- [ ] **Step 1: Write failing material safety tests**

  Add deterministic tests using an injected clock, temporary archive, bookmark resolver, file-operation seam, and one synthetic valid v1 archive. Cover exactly:

  ```swift
  func testExpiryAtBoundaryRemovesOnlyVerifiedMatchingRegularArchive() async throws
  func testExpiryRetryAfterIOFailureIsIdempotentAndRecordsNoDuplicateRemoval() async throws
  func testExpiryNeverUnlinksSymlinkReplacementOrIdentityChangedTarget() async throws
  func testExpiryMissingOrUnavailableTargetKeepsCatalogueWithoutRemovalActivity() async throws
  func testExpiryMismatchOfSignatureArchiveIDFingerprintOrChecksumNeverUnlinks() async throws
  func testExpiryStateAndActivityRemainRedacted() async throws
  ```

  The boundary test must assert no work at `expiresAt - 0.001`, then at `expiresAt` assert the row first transitions through `expired_pending_removal`, the file is unlinked, the row is absent after refresh, and exactly one `portable_backup_expired_removed` activity exists. The redaction test must assert activity/category fields do not contain a filesystem path, bookmark bytes, recovery-key text, or archive payload.

- [ ] **Step 2: Run the focused test group to verify it fails**

  Run:
  ```bash
  xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit -destination 'platform=macOS,arch=arm64' -only-testing:RekonPursuitCoreTests/PortableArchiveTests
  ```
  Expected: FAIL because `verifyPublicBinding` and the expiry service do not exist.

- [ ] **Step 3: Implement a recovery-key-free public binding verifier**

  Refactor only the existing parsing needed to validate v1 magic/version/header length, public-key fingerprint, header commitment/signature, payload length, and payload SHA-256. Return `PortableArchivePublicBinding`; do not open the encrypted envelope or payload, and leave `verify(data:recoveryKey:)` unchanged.

  ```swift
  let binding = try PortableArchiveService.verifyPublicBinding(data: archiveData)
  guard binding.archiveID == catalogue.archiveID,
        binding.ciphertextChecksum == catalogue.ciphertextChecksum,
        binding.signingKeyFingerprint == catalogue.signingKeyFingerprint else {
      throw PortableArchiveExpiryError.archiveMismatch
  }
  ```

- [ ] **Step 4: Implement the expiry worker with identity-safe unlink**

  Create `PortableArchiveExpiryWorker` with injected `now`, bookmark resolver, read/open, metadata, unlink, and activity seams. For each due row only:

  1. Persist `expired_pending_removal` before any destructive attempt.
  2. Resolve/start scope once, and always stop it with `defer`.
  3. Reject non-regular/symlink targets through an `O_NOFOLLOW` read descriptor and `fstat` mode check.
  4. Capture `(st_dev, st_ino)`, read the archive from that descriptor, and verify its public binding against the row.
  5. Re-read target identity immediately before `unlink`; unlink only on an exact match.
  6. On success, transactionally delete the catalogue row and insert one redacted `portable_backup_expired_removed` event correlated only to the opaque archive UUID.
  7. On missing target persist `.expiredMissing/.targetMissing`; on scope/I-O failure persist `.expiredRetryable` with category only; on unsafe/mismatch/replacement persist `.expiredBlocked` with category only. Never claim removal for these branches.

- [ ] **Step 5: Wire one bounded store service opportunity**

  Instantiate the expiry worker with the encrypted database configuration already used by `PortableArchiveWorker`. Query only rows with `expires_at <= now` and nonterminal lifecycle states. Ensure the service is serialized with the store synchronization boundary and returns a freshly queried catalogue; it must not alter current opportunities, contacts, workspace metadata, recovery enrollment, or protected-export records.

- [ ] **Step 6: Run focused material verification**

  Run the command from Step 2. Expected: PASS for the six named tests and existing portable archive tests. Also run:
  ```bash
  rg -n "operationBytes|displayValue|destination_bookmark|\.path" RekonPursuitCore/Workspace/PortableArchiveExpiryWorker.swift RekonPursuitCoreTests/PortableArchiveTests.swift
  ```
  Expected: no recovery-key values or path/bookmark values are persisted into expiry state/activity; test-only temporary-path setup is acceptable.

- [ ] **Step 7: Commit the safe worker**

  ```bash
  git add RekonPursuitCore/Workspace/PortableArchiveService.swift RekonPursuitCore/Workspace/PortableArchiveExpiryWorker.swift RekonPursuitCore/Workspace/WorkspaceStore.swift RekonPursuitCoreTests/PortableArchiveTests.swift
  git commit -m "feat: remove expired portable archives safely"
  ```

### Task 3: Bounded app-run integration and truthful catalogue state

**Files:**
- Modify: `RekonPursuit/WorkspaceViewModel.swift:1721-1794`
- Modify: `RekonPursuit/ContentView.swift:996-1034`
- Test: `RekonPursuitTests/WorkspaceViewModelTests.swift` (create only if no existing view-model test target covers the seam)

**Interfaces:**
- Consumes: `WorkspaceStore.runPortableArchiveExpiryServiceOpportunity() async throws -> [PortableArchiveCatalogueRow]`.
- Produces: a non-blocking post-open task that refreshes `portableArchiveCatalogue` and user-facing copy that describes actual retained/removal states without a destructive button.

- [ ] **Step 1: Write the narrow lifecycle integration test**

  Add one view-model seam test only if a test target exists for it. It must prove that a successfully opened workspace schedules the service opportunity and publishes the returned catalogue without blocking the initial usable UI state.

  ```swift
  func testSuccessfulWorkspaceOpenSchedulesPortableArchiveExpiryRefresh() async throws {
      let model = makeModel(expiryService: { [.expiredFixture] })
      model.openWorkspaceForTesting()
      await eventually { model.portableArchiveCatalogue == [.expiredFixture] }
  }
  ```

- [ ] **Step 2: Run the integration test to verify it fails**

  Run the exact test target created in Step 1. Expected: FAIL because post-open expiry refresh has not been scheduled.

- [ ] **Step 3: Schedule the bounded opportunity after successful open**

  In the existing successful workspace-open path, launch one structured task after the store is assigned and the initial catalogue is available. It must capture the current store identity, return to `MainActor` before publishing, ignore stale-store completion, and make failure non-blocking while retaining the durable state from Task 2. Do not introduce a timer, background task, periodic daemon, or an exact timing claim.

- [ ] **Step 4: Present catalogue truth, not inferred success**

  Keep Settings as the archive surface. List only current catalogue rows, with copy derived from `lifecycleState` and category-only `lastExpiryOutcome`; a successfully removed archive disappears after refresh. Do not add an auto-delete control, confirmation, manual purge action, or raw error/path details.

- [ ] **Step 5: Run focused verification and signed build**

  Run:
  ```bash
  xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit -destination 'platform=macOS,arch=arm64' -only-testing:RekonPursuitCoreTests/PortableArchiveTests
  xcodebuild build -project RekonPursuit.xcodeproj -scheme RekonPursuit -destination 'platform=macOS,arch=arm64'
  ```
  Expected: focused portable-archive tests pass and the signed Debug build succeeds.

- [ ] **Step 6: Commit the bounded integration**

  ```bash
  git add RekonPursuit/WorkspaceViewModel.swift RekonPursuit/ContentView.swift RekonPursuitTests/WorkspaceViewModelTests.swift
  git commit -m "feat: process archive expiry on workspace open"
  ```

## Acceptance gate

- The Architect/Security verifier confirms no recovery key, active workspace content, or raw filesystem data enters R7b-1 expiry state/activity.
- QA confirms the six material expiry tests, including before-expiry, exact-boundary, retry, missing, replacement/unsafe target, mismatch, and redaction behavior.
- Code review confirms R7b-2 purge/rewrite remains absent.
- TPM and Delivery Manager confirm R7b-1 only is accepted before releasing R7b-2 planning. No implementation task beyond R7b-1 is opened by this plan.

## Self-review

- **Spec coverage:** Task 1 covers durable state; Task 2 covers automatic expiry, scope, public verification, identity checks, deletion and redaction; Task 3 covers bounded app-run invocation and truthful UI. The plan explicitly excludes purge/rewrite, active-data expiry, daemon timing, and archive-format changes.
- **Placeholder scan:** no `TODO`/`TBD`/"implement later" placeholders are present.
- **Type consistency:** Task 1 defines the state/outcome types used by Tasks 2–3; Task 2 defines the verifier and store service consumed by Task 3.
