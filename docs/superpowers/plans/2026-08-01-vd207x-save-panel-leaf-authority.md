# V2-07x Save-panel leaf authority implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a signed sandboxed macOS build create a verified protected export through the exact new file URL selected in the native Save panel, without broadening filesystem authority.

**Architecture:** `ADR-005-save-panel-leaf-export-authority.md` replaces the unusable parent-directory binding with an in-memory canonical selected-leaf digest. The worker continues to produce an encrypted app-owned temporary file, creates the exact selected leaf exclusively with no-follow semantics, reads and verifies it through the same descriptor, and records successful evidence only after verification.

**Tech Stack:** Swift, AppKit `NSSavePanel`, Foundation URL security scope, Darwin file descriptors, CryptoKit, XCTest, encrypted SQLite workspace store.

## Global constraints

- Preserve the existing one-step native Save panel, `.rekonexport` content-type filter, default filename, and ability to create folders.
- Retain the current app-sandbox and `com.apple.security.files.user-selected.read-write` entitlement; do not add an entitlement, security-scoped bookmark, persistent path, dependency, or new preference.
- Never persist or display a destination path, POSIX error, security-scope result, recovery key, or export content.
- Do not overwrite, retry, or pathname-delete a selected destination after final-file creation begins.
- Do not change Settings visual design or V2-08 accessibility scope; dashboard state remains in progress until owner-native verification succeeds.

---

### Task 1: Implement leaf-authorized protected-export write

**Files:**

- Modify: `RekonPursuitCore/Workspace/ProtectedExportWorker.swift`
- Modify: `RekonPursuitCoreTests/ProtectedExportTests.swift`
- Modify only the clean protected-export feedback island: `RekonPursuitTests/WorkspaceViewModelTests.swift:706-860`
- Verify unchanged: `RekonPursuit/WorkspaceViewModel.swift`
- Record: `docs/delivery/reviews/` and `.superpowers/sdd/` progress ledger

**Interfaces:**

- Consumes: `ProtectedExportReview.destinationURL`, `sourceRevision`,
  `destinationIdentityDigest`, `confirmationFingerprint`, and the existing
  `ProtectedExportRequest`.
- Produces: a `ProtectedExportReview` bound to a canonical selected leaf rather
  than parent device/inode, then a verified `ProtectedExportReceipt` only after
  successful final-FD read-back verification.
- Preserves: `ProtectedExportWorkerError`, `WorkspaceStore` async seams,
  ViewModel protected-export state publication, and no-success evidence before
  verification.

- [ ] **Step 1: Write executable RED tests for leaf authority and its observable protections.**

  Add `import CryptoKit` to the test file and add focused core tests with real
  temporary enrolled stores and generated recovery keys. The canonical-binding
  RED is this exact executable test, replacing the current parent-identity
  review test:

  ```swift
  func testSelectedLeafDigestUsesCanonicalLeafLocator() async throws {
      let fixture = try makeProtectedExportFeedbackFixture(
          faultMode: .none,
          destinationName: "Cafe\u{301}.rekonexport"
      )
      defer { fixture.close() }

      let review = try await fixture.store.reviewProtectedExport(
          recoveryKey: fixture.recoveryKey,
          at: fixture.destination
      )
      let canonicalLeaf = fixture.destination.standardizedFileURL.path
          .precomposedStringWithCanonicalMapping
      var input = Data("RekonPursuit/export/leaf-destination/v2\0".utf8)
      input.append(contentsOf: canonicalLeaf.utf8)
      XCTAssertEqual(review.destinationIdentityDigest, Data(SHA256.hash(data: input)))
      XCTAssertEqual(review.displayFilename, fixture.destination.lastPathComponent.precomposedStringWithCanonicalMapping)
      XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.destination.path))
  }
  ```

  Add the test-local immutable reconstruction helper only after the production
  `ProtectedExportReview` initializer no longer has `parentIdentity`:

  ```swift
  private func reconstructReview(
      _ review: ProtectedExportReview,
      destinationURL: URL? = nil,
      destinationIdentityDigest: Data? = nil,
      confirmationFingerprint: String? = nil
  ) -> ProtectedExportReview {
      .init(
          destinationURL: destinationURL ?? review.destinationURL,
          sourceRevision: review.sourceRevision,
          destinationIdentityDigest: destinationIdentityDigest ?? review.destinationIdentityDigest,
          confirmationFingerprint: confirmationFingerprint ?? review.confirmationFingerprint
      )
  }
  ```

  Add distinct tests that use literal filenames and sentinel bytes to prove:

  - invalid `.txt` final names return the existing filename message and write no file/evidence;
  - an existing `.rekonexport` leaf or a terminal symlink is rejected without changing bytes and without verified evidence;
  - a sentinel created after review makes confirm return the no-overwrite error without changing bytes or recording evidence;
  - changed leaf locator with retained digest/fingerprint, changed digest only,
    and changed fingerprint only each use `reconstructReview`, return
    `destinationChanged` before output, and add no verified evidence;
  - a source revision change returns `sourceChanged` before output and records no verified evidence;
  - an injected pre-descriptor direct-leaf failure returns the existing unavailable-destination message with no output/evidence;
  - a post-descriptor failure leaves the conservative may-remain result and no verified evidence;
  - a `beforeEvidenceCommit` fault, injected after same-FD read-back and a
    successful independent `ProtectedExportService.verify` but before the
    database transaction, leaves an independently verified output, returns
    `outputMayRemainAfterFailure`, and leaves zero `protected_export_events`
    rows and zero `protected_export_verified` activity rows; and
  - successful output produces exactly one protected-export row and one filtered verified activity only after read-back verification.

  The only added worker seam is an immutable default-`.none`
  `ProtectedExportWorkerFaultMode.beforeEvidenceCommit`, alongside the
  direct-leaf pre-descriptor and existing post-descriptor modes. It has no
  production selection, persistence, environment input, Store injection, or
  ViewModel API.

  In `WorkspaceViewModelTests.swift`, replace only the two obsolete
  parent-authority review tests in the clean feedback island. Rename/reassert
  the pre-descriptor confirm test as a direct selected-leaf failure—review
  succeeds, confirm retains it and shows the existing unavailable message—and
  retain the post-descriptor may-remain assertion. Do not touch ViewModel
  production source or any dirty test hunk.

- [ ] **Step 2: Run the focused selectors and confirm RED fails as behavior, not compilation or a skip.**

  Run:

  ```bash
  xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit \
    -configuration Debug \
    -destination 'platform=macOS,arch=arm64' \
    -only-testing:RekonPursuitTests/ProtectedExportTests \
    -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testProtectedExportInvalidFilenameUsesExactCorrectionMessage \
    -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testProtectedExportUnavailableSelectedLeafConfirmUsesExactCorrectionMessage \
    -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testProtectedExportPostCreateFailureRetainsMayRemainFeedback \
    -derivedDataPath /private/tmp/rekon-vd207x-save-panel-leaf-red-dd \
    -resultBundlePath /private/tmp/rekon-vd207x-save-panel-leaf-red.xcresult
  ```

  Expected: the canonical selected-leaf digest assertion fails because current
  review derives the v1 parent-identity digest; existing selected tests do not
  fail. This unit RED proves the replacement binding, not a simulated
  `NSSavePanel` sandbox grant.
  Inspect the resolved test list and result summary to confirm every new
  selector executed once with zero skipped/expected failures.

  ```bash
  xcrun xcresulttool get test-results summary --path /private/tmp/rekon-vd207x-save-panel-leaf-red.xcresult
  xcrun xcresulttool get test-results tests --path /private/tmp/rekon-vd207x-save-panel-leaf-red.xcresult
  ```

- [ ] **Step 3: Implement the smallest approved leaf-authorized change.**

  In `ProtectedExportWorker`:

  ```swift
  let canonicalLeaf = destination.standardizedFileURL.path.precomposedStringWithCanonicalMapping
  var digestInput = Data("RekonPursuit/export/leaf-destination/v2\0".utf8)
  digestInput.append(contentsOf: canonicalLeaf.utf8)
  let destinationDigest = Data(SHA256.hash(data: digestInput))
  ```

  Use a helper that validates the exact selected final filename and probes only
  the leaf for collision. Remove parent descriptor acquisition, parent
  device/inode storage, `fstatat`, parent identity comparison, and `openat`.
  At confirm, recompute the canonical leaf digest and review fingerprint before
  staging/final writing. Create the final output only with:

  ```swift
  outputFD = open(destination.path, O_RDWR | O_CREAT | O_EXCL | O_NOFOLLOW, S_IRUSR | S_IWUSR)
  ```

  Capture `errno` immediately after a failed open to preserve `EEXIST` as the
  existing no-overwrite error; map all other pre-descriptor direct-leaf failures
  to the existing unavailable-destination error. Keep `fstat`, streaming
  write, `fsync`, descriptor reset/read-back, cryptographic verification, and
  only-then evidence transaction unchanged. Immediately after
  `ProtectedExportService.verify` returns the expected receipt and immediately
  before the evidence transaction, make `.beforeEvidenceCommit` throw
  `outputMayRemainAfterFailure`; its test verifies the saved bytes directly and
  asserts no evidence rows. Do not alter the Save-panel setup or user-facing
  visual flow.

- [ ] **Step 4: Run focused GREEN and regression coverage.**

  Run and inspect the GREEN bundle:

  ```bash
  xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit \
    -configuration Debug \
    -destination 'platform=macOS,arch=arm64' \
    -only-testing:RekonPursuitTests/ProtectedExportTests \
    -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testProtectedExportInvalidFilenameUsesExactCorrectionMessage \
    -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testProtectedExportUnavailableSelectedLeafConfirmUsesExactCorrectionMessage \
    -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testProtectedExportPostCreateFailureRetainsMayRemainFeedback \
    -derivedDataPath /private/tmp/rekon-vd207x-save-panel-leaf-green-dd \
    -resultBundlePath /private/tmp/rekon-vd207x-save-panel-leaf-green.xcresult
  xcrun xcresulttool get test-results summary --path /private/tmp/rekon-vd207x-save-panel-leaf-green.xcresult
  xcrun xcresulttool get test-results tests --path /private/tmp/rekon-vd207x-save-panel-leaf-green.xcresult
  ```

  Then run and inspect the separate regression bundle:

  ```bash
  xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit \
    -configuration Debug \
    -destination 'platform=macOS,arch=arm64' \
    -only-testing:RekonPursuitTests/ProtectedExportTests \
    -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testProtectedExportInvalidFilenameUsesExactCorrectionMessage \
    -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testProtectedExportUnavailableSelectedLeafConfirmUsesExactCorrectionMessage \
    -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testProtectedExportPostCreateFailureRetainsMayRemainFeedback \
    -derivedDataPath /private/tmp/rekon-vd207x-save-panel-leaf-regression-dd \
    -resultBundlePath /private/tmp/rekon-vd207x-save-panel-leaf-regression.xcresult
  git diff --check
  xcrun xcresulttool get test-results summary --path /private/tmp/rekon-vd207x-save-panel-leaf-regression.xcresult
  xcrun xcresulttool get test-results tests --path /private/tmp/rekon-vd207x-save-panel-leaf-regression.xcresult
  ```

  Expected: RED, GREEN, and regression have distinct DerivedData and result
  paths. RED has only the canonical leaf-digest assertion failure; GREEN and
  regression have all selected tests passing with zero skipped/expected
  failures. Inspect both views for every bundle; `git diff --check` is an
  additional GREEN/regression check, not a bundle substitute. Preserve result
  bundles for independent verification.

- [ ] **Step 5: Build the signed Debug app and perform the owner-native smoke.**

  Run:

  ```bash
  xcodebuild build -project RekonPursuit.xcodeproj -scheme RekonPursuit \
    -configuration Debug -destination 'platform=macOS,arch=arm64' \
    -derivedDataPath /private/tmp/rekon-vd207x-save-panel-leaf-owner-dd
  codesign --verify --deep --strict /private/tmp/rekon-vd207x-save-panel-leaf-owner-dd/Build/Products/Debug/RekonPursuit.app
  codesign -d --entitlements :- /private/tmp/rekon-vd207x-save-panel-leaf-owner-dd/Build/Products/Debug/RekonPursuit.app 2>&1
  ```

  Record only the redacted assertion that App Sandbox and the existing
  user-selected read/write entitlement are present, with no task-related
  entitlement addition. The owner uses a fresh separate local workspace and a recovery key never
  entered in chat or screenshots. Through the actual `NSSavePanel`, choose a
  fresh name in a newly created Documents child folder. Review must appear with
  the filename and no folder-unavailable error. Confirm must create one
  nonempty export and show the existing filename-only success dialog. Capture
  only redacted evidence; do not retain or share the key, full path, output,
  or database.

- [ ] **Step 6: Commit only released hunk(s).**

  Capture `git diff -U0 -- RekonPursuitTests/WorkspaceViewModelTests.swift`
  before editing; if it overlaps current lines 692-863, stop for a new
  integration plan. Use `git add -p` and stage only the worker, core tests, and
  the released feedback-island hunk—excluding every pre-existing V2-07x edit
  in `WorkspaceViewModelTests.swift`. Commit message:

  ```bash
  git commit -m "fix: use selected leaf for protected export"
  ```

## Plan self-review

- **Spec coverage:** The task covers the owner-native failing valid selection,
  no-overwrite, terminal-symlink/collision handling, review binding,
  source-change rejection, post-create failure, verified-only evidence,
  existing native Save-panel UX, and a signed owner smoke.
- **Placeholder scan:** No later task requires an unnamed helper or an
  undefined behavioral outcome. The implementation helper names are left local
  to the worker to avoid a public API expansion.
- **Type consistency:** Existing `ProtectedExportReview`, request, Worker,
  Store, and ViewModel seams are retained; no new persisted type or external
  interface is introduced.

## Execution handoff

After fresh architecture, TPM, QA, security, and delivery release gates accept
this plan, dispatch one fresh implementer for Task 1. A separate fresh code
reviewer, QA verifier, architect verifier, security/privacy verifier, and
delivery manager must close it before the owner-native smoke can complete
V2-07x.
