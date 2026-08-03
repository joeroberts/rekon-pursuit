# VD2-07x Protected-export Destination Feedback Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Truthfully distinguish an invalid protected-export filename from a
safely unusable selected folder without weakening filesystem safeguards.

**Architecture:** `ProtectedExportWorker` remains the only filesystem-outcome
classifier. It adds two controlled pre-write errors and the view-model's
existing controlled-error mapper publishes the retained owner copy. The
architecture-gated immutable internal fault mode makes each state boundary
deterministic without changing production Darwin calls.

**Tech Stack:** Swift, Swift Concurrency actors, Foundation/Darwin, XCTest,
Xcode/macOS.

## QA amendment — 2026-08-01

This amendment incorporates every REQUIRED RED/GREEN gate in the independent
QA verdict **NEEDS CHANGE** at
`docs/delivery/reviews/VD2-07x-protected-export-feedback-qa-gate-2026-08-01.md`
and its four corrective requirements at
`docs/delivery/reviews/VD2-07x-protected-export-feedback-qa-regate-2026-08-01.md`.
The accepted Architecture gate remains controlling: use its immutable internal
`ProtectedExportWorkerFaultMode`, its default `.none` initializer, and its
exact placements. This amendment does not change the approved design or scope.

## Global Constraints

- Preserve `NSSavePanel` `.rekonexport` filtering and default filename.
- Invalid-name copy is exactly `Choose a new file name ending in .rekonexport.`
- Folder/pre-create copy is exactly `Rekon Pursuit can’t use that folder. Choose another local folder and review the export again.`
- Preserve `O_DIRECTORY | O_NOFOLLOW`, `O_EXCL | O_NOFOLLOW`, no overwrite,
  parent identity binding, read-back verification, and may-remain behavior.
- Do not disclose path, `errno`, scope state, recovery material, or internal
  keys; do not change Settings, accessibility, project files, or persistence.
- Use `RekonPursuitTests`, not source-group name `RekonPursuitCoreTests`, in
  every `xcodebuild -only-testing` selector.

---

## File structure

| Path | Responsibility |
| --- | --- |
| `RekonPursuitCore/Workspace/ProtectedExportWorker.swift` | Split errors and implement only the architecture-gated fault enum/placements. |
| `RekonPursuitCoreTests/ProtectedExportTests.swift` | Deterministic state-boundary, no-evidence, real-write audit, and security tests. |
| `RekonPursuit/WorkspaceViewModel.swift` | Exhaustive controlled-error mapping only if compilation requires it. |
| `RekonPursuitTests/WorkspaceViewModelTests.swift` | Retained review/error/status/root-presentation feedback contracts. |
| `RekonPursuit/ContentView.swift` | Inspect only; its retained `protected-export-error` rendering is unchanged. |

### Task 1: Classify protected-export failures and prove their owner feedback

**Files:**

- Modify: `RekonPursuitCore/Workspace/ProtectedExportWorker.swift:26-43, 140-149, 180-187, 216-242`.
- Modify: `RekonPursuitCoreTests/ProtectedExportTests.swift`.
- Modify: `RekonPursuit/WorkspaceViewModel.swift:1318-1367, 1449-1453` only if compiler exhaustiveness requires it.
- Modify: `RekonPursuitTests/WorkspaceViewModelTests.swift`.
- Inspect-only: `RekonPursuit/ContentView.swift:205-244`.

**Consumes:** Existing injected-worker `WorkspaceStore`, reviewed export
binding, retained correction state, and verified-export transaction.

**Produces:** Exact pre-write controlled errors and retained feedback, with
unchanged no-overwrite and post-create conservative behavior.

- [ ] **Step 0: Add only the testability compilation scaffold, then prove it is behavior-neutral.**

  Before adding any test source, make this exact, minimal production edit in
  `ProtectedExportWorker.swift`:

  ```swift
  nonisolated enum ProtectedExportWorkerFaultMode: Sendable {
      case none
      case parentOpenUnavailable
      case parentInspectionUnavailable
      case exclusiveCreateUnavailable
      case afterOutputCreation
  }

  actor ProtectedExportWorker {
      private let faultMode: ProtectedExportWorkerFaultMode

      init(configuration: PortableArchiveDatabaseConfiguration,
           faultMode: ProtectedExportWorkerFaultMode = .none) {
          self.configuration = configuration
          self.faultMode = faultMode
      }
  }
  ```

  This scaffold consists exactly of the immutable internal enum, the private
  `let faultMode`, and the default-`.none` initializer assignment. It adds no
  decision-point branch, error case, copy, behavioral change, service/store
  injection, view-model injection, filesystem adapter, mutable/global/
  environment seam, or production constructor argument. Production continues
  to use `ProtectedExportWorker(configuration: ...)`.

  Run the existing focused regression suite before adding the new RED tests;
  Step 0 alone must leave every selected existing regression green:

  ```bash
  xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit -configuration Debug -destination 'platform=macOS,arch=arm64' -only-testing:RekonPursuitTests/ProtectedExportTests/testProtectedExportIsEncryptedAndVerifiableWithRecoveryKey -only-testing:RekonPursuitTests/ProtectedExportTests/testReviewBindsDestinationParentIdentity -only-testing:RekonPursuitTests/ProtectedExportTests/testSourceRevisionChangeRejectsReviewedExportWithoutCreatingAFile -only-testing:RekonPursuitTests/ProtectedExportTests/testExistingTargetIsRejectedWithoutOverwritingIt -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testProtectedExportReviewFailureRemainsVisibleForCorrection -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testProtectedExportSuccessRemainsNilForEveryNonSuccessBranch -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testVerifiedProtectedExportPublishesSafeSuccessAndRootPresentationOnlyAfterRealWriting -derivedDataPath /private/tmp/rekon-vd207x-export-feedback-scaffold-dd -resultBundlePath /private/tmp/rekon-vd207x-export-feedback-scaffold.xcresult
  ```

  Inspect the scaffold bundle's resolved test list and summary. Every selected
  test must run once and pass with zero skips and zero expected failures. Keep
  this bundle; later commands use fresh, non-existing paths.

- [ ] **Step 1: Add executable RED contracts after the scaffold compiles.**

  Use a real temporary enrolled `WorkspaceStore` for each worker test and a
  valid `.rekonexport` final URL except the invalid-name case. Tests construct
  the immutable mode from Step 0; do not add a filesystem adapter,
  mutable/global/environment seam, or `WorkspaceStore` production parameter.

  Add these worker tests:

  ```swift
  func testInvalidDestinationNameUsesDedicatedControlledError() async throws
  func testParentOpenUnavailableWithValidSuffixUsesDestinationUnavailableWithoutReview() async throws
  func testParentInspectionUnavailableWithValidSuffixUsesDestinationUnavailableWithoutReview() async throws
  func testExclusiveCreateFailureBeforeOutputUsesDestinationUnavailableWithoutActivity() async throws
  func testPostCreateFailureRemainsOutputMayRemainAfterFailure() async throws
  func testVerifiedProtectedExportCreatesExactlyOneVerifiedEventAndActivity() async throws
  ```

  The new controlled worker error cases do not exist in this RED step. Do not
  name `.invalidDestinationName` or `.destinationUnavailable` in test source.
  Instead, every core test must capture the thrown error and assert its exact
  proposed `LocalizedError.errorDescription`:

  ```swift
  XCTAssertEqual((error as? LocalizedError)?.errorDescription,
                 "Choose a new file name ending in .rekonexport.")
  XCTAssertEqual((error as? LocalizedError)?.errorDescription,
                 "Rekon Pursuit can’t use that folder. Choose another local folder and review the export again.")
  ```

  For each injected valid-suffix mode, the ordinary current path may complete
  before GREEN; the test must fail as an assertion that the required controlled
  error/description was not produced, never because a symbol is unresolved,
  a test is skipped, or a failure is expected. Assert their exact decision
  points: invalid name fails the final-component
  predicate before parent work; `parentOpenUnavailable` runs after that
  predicate and immediately before unchanged `open(parent, O_RDONLY |
  O_DIRECTORY | O_NOFOLLOW)`; `parentInspectionUnavailable` runs after a
  successful `open` and immediately before `fstat`, closing the descriptor;
  `exclusiveCreateUnavailable` follows a real review and the unchanged
  parent-identity guard, immediately before `openat`, without calling it;
  `afterOutputCreation` runs only after nonnegative `openat`, descriptor
  assignment, and `created = true`.

  Invalid name, both parent cases, and pre-create confirmation assert final URL
  absent, zero `protected_export_events` rows, and zero `activity_events` rows
  filtered to `kind = 'protected_export_verified'`. Do not assert zero total
  activity because enrollment may create unrelated rows. The post-create test
  asserts the existing `.outputMayRemainAfterFailure`, final URL exists, zero
  verified export/activity rows, and its exact existing may-remain description;
  it must not expect folder-unavailable copy. The ordinary
  default-worker test verifies final bytes against its receipt and exactly one
  verified export row plus exactly one filtered verified activity row. The
  existing-target regression uses a pre-existing valid `.rekonexport` file,
  compares original bytes byte-for-byte, asserts exact no-overwrite copy, no
  success event, and false root-success presentation.

  Add model tests:

  ```swift
  func testProtectedExportInvalidFilenameUsesExactCorrectionMessage() async throws
  func testProtectedExportUnavailableParentOpenReviewUsesExactCorrectionMessage() async throws
  func testProtectedExportUnavailableParentInspectionReviewUsesExactCorrectionMessage() async throws
  func testProtectedExportUnavailableFolderConfirmUsesExactCorrectionMessage() async throws
  func testProtectedExportPostCreateFailureRetainsMayRemainFeedback() async throws
  ```

  Each failed-review test asserts `protectedExportReview == nil`,
  `protectedExportSuccess == nil`, false root-success presentation, exact
  error and status copy, and retained root error presentation. The
  pre-create-confirm test first creates a successful review, then asserts it
  remains retained after the error, has nil success, false root success, exact
  folder-unavailable error and status copy, and retained root error. The
  post-create-confirm test asserts this unchanged exact may-remain error and
  status copy, retained root error, and no success presentation:

  ```swift
  XCTAssertEqual(model.protectedExportErrorMessage,
                 "Final export writing or verification failed. The selected file may remain; treat it as unusable and remove it yourself.")
  XCTAssertEqual(model.statusMessage,
                 "Final export writing or verification failed. The selected file may remain; treat it as unusable and remove it yourself.")
  ```

  ```swift
  XCTAssertEqual(model.protectedExportErrorMessage,
                 "Choose a new file name ending in .rekonexport.")
  XCTAssertEqual(model.statusMessage,
                 "Choose a new file name ending in .rekonexport.")
  XCTAssertEqual(model.protectedExportErrorMessage,
                 "Rekon Pursuit can’t use that folder. Choose another local folder and review the export again.")
  XCTAssertEqual(model.statusMessage,
                 "Rekon Pursuit can’t use that folder. Choose another local folder and review the export again.")
  ```

  No chmod, unavailable volume, sandbox denial, sleeps, polling timeouts, or
  raw-`errno` assertion may be used. These are exact owner-string assertions,
  not references to the two absent worker enum cases. Compile the new tests
  against the Step 0 scaffold before RED, then run:

  ```bash
  xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit -configuration Debug -destination 'platform=macOS,arch=arm64' -only-testing:RekonPursuitTests/ProtectedExportTests/testInvalidDestinationNameUsesDedicatedControlledError -only-testing:RekonPursuitTests/ProtectedExportTests/testParentOpenUnavailableWithValidSuffixUsesDestinationUnavailableWithoutReview -only-testing:RekonPursuitTests/ProtectedExportTests/testParentInspectionUnavailableWithValidSuffixUsesDestinationUnavailableWithoutReview -only-testing:RekonPursuitTests/ProtectedExportTests/testExclusiveCreateFailureBeforeOutputUsesDestinationUnavailableWithoutActivity -only-testing:RekonPursuitTests/ProtectedExportTests/testPostCreateFailureRemainsOutputMayRemainAfterFailure -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testProtectedExportInvalidFilenameUsesExactCorrectionMessage -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testProtectedExportUnavailableParentOpenReviewUsesExactCorrectionMessage -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testProtectedExportUnavailableParentInspectionReviewUsesExactCorrectionMessage -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testProtectedExportUnavailableFolderConfirmUsesExactCorrectionMessage -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testProtectedExportPostCreateFailureRetainsMayRemainFeedback -derivedDataPath /private/tmp/rekon-vd207x-export-feedback-red-dd -resultBundlePath /private/tmp/rekon-vd207x-export-feedback-red.xcresult
  ```

  Expected: the result bundle compiles and executes every selected test once;
  failures are assertion failures solely for missing classification, copy, or
  fault placement, with zero skips and zero expected failures. Preserve and
  inspect the RED bundle's resolved test list and result summary before later
  evidence is created.

- [ ] **Step 2: Make the RED contracts green with only the approved errors, copy, and four placements.**

  Replace only overloaded controlled errors with:

  ```swift
  case invalidDestinationName
  case destinationUnavailable
  ```

  The filename predicate throws `.invalidDestinationName`; parent `open` or
  `fstat` throws `.destinationUnavailable`; non-`EEXIST` `openat` before
  `created = true` throws `.destinationUnavailable`; `EEXIST` remains
  `.destinationExists`. Preserve the parent-identity guard as
  `.destinationChanged`. After `created = true`, every failure remains
  `.outputMayRemainAfterFailure`.

  Add only those two controlled error cases and their exact copy, then add the
  four fixed fault-mode checks: `parentOpenUnavailable` after the predicate and
  immediately before `open`; `parentInspectionUnavailable` after a successful
  `open`, immediately before `fstat`, closing that descriptor before throwing;
  `exclusiveCreateUnavailable` after the current-parent-identity guard and
  immediately before `openat`; and `afterOutputCreation` after a nonnegative
  `openat`, descriptor assignment, and `created = true`. Leave production Darwin
  flags/order, scoped-access lifetime, digest/fingerprint inputs, database
  timing, and generic uncontrolled-error fallback unchanged. Never serialize,
  expose, or persist fault mode.

- [ ] **Step 3: Run GREEN and regression evidence and inspect result bundles.**

  Repeat Step 1 with fresh non-existing paths named
  `/private/tmp/rekon-vd207x-export-feedback-green-dd` and
  `/private/tmp/rekon-vd207x-export-feedback-green.xcresult`. Inspect the
  resolved test list and result summary: each selected test runs once and
  passes, with zero skips/expected failures. Then run the fresh regression
  bundle:

  ```bash
  xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit -configuration Debug -destination 'platform=macOS,arch=arm64' -only-testing:RekonPursuitTests/ProtectedExportTests/testProtectedExportIsEncryptedAndVerifiableWithRecoveryKey -only-testing:RekonPursuitTests/ProtectedExportTests/testReviewBindsDestinationParentIdentity -only-testing:RekonPursuitTests/ProtectedExportTests/testSourceRevisionChangeRejectsReviewedExportWithoutCreatingAFile -only-testing:RekonPursuitTests/ProtectedExportTests/testExistingTargetIsRejectedWithoutOverwritingIt -only-testing:RekonPursuitTests/ProtectedExportTests/testVerifiedProtectedExportCreatesExactlyOneVerifiedEventAndActivity -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testProtectedExportReviewFailureRemainsVisibleForCorrection -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testProtectedExportSuccessRemainsNilForEveryNonSuccessBranch -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testVerifiedProtectedExportPublishesSafeSuccessAndRootPresentationOnlyAfterRealWriting -derivedDataPath /private/tmp/rekon-vd207x-export-feedback-regression-dd -resultBundlePath /private/tmp/rekon-vd207x-export-feedback-regression.xcresult
  ```

  Inspect this bundle's test list and summary as well. Each selected test runs
  once and passes with zero skips/expected failures. Record zero output/evidence
  for pre-write modes, remaining output/zero evidence for post-create, existing
  bytes/copy/no success, and exact-one verified rows after real writing.

- [ ] **Step 4: Review scope, record evidence, and stop at the implementation commit boundary.**

  Record commands, result-bundle inspection, exact test outcomes, changed-path
  review, and `git diff --check`. The required implementation commit boundary
  follows acceptance of the GREEN and regression evidence; this planning
  amendment must not create a commit. The fresh implementer may commit only:

  ```bash
  git add RekonPursuitCore/Workspace/ProtectedExportWorker.swift RekonPursuitCoreTests/ProtectedExportTests.swift RekonPursuit/WorkspaceViewModel.swift RekonPursuitTests/WorkspaceViewModelTests
  git commit -m "fix: distinguish protected export destination failures"
  ```

  Omit `ContentView.swift`, docs, dashboard, project files, Settings, and
  accessibility work. A fresh QA re-gate must accept the RED/GREEN bundles,
  selectors, state assertions, and audit checks before implementation release.

## Mandatory independent gates

1. Architect verifies enum/placement, parent identity, Darwin flags, and output state.
2. TPM confirms this remains one dependency-safe VD2-07x slice.
3. QA re-gates the amended RED/GREEN plan before a fresh implementer starts.
4. Delivery Manager records scope, evidence, risks, and release order.
5. Separate code reviewer assesses scope, naming, and test adequacy.
6. Security/privacy verifier checks no-follow, no-overwrite, binding, disclosure, and may-remain behavior.
