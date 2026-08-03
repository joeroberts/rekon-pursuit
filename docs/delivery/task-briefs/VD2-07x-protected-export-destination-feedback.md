# VD2-07x — Protected-export destination feedback task brief

**Status:** DRAFT — planning only. Do not release implementation until fresh
independent Architect, TPM, QA, Delivery Manager, reviewer, and Security/privacy
approvals are recorded.

## QA amendment — 2026-08-01

This brief now incorporates every REQUIRED RED/GREEN gate in
`docs/delivery/reviews/VD2-07x-protected-export-feedback-qa-gate-2026-08-01.md`.
It also incorporates the four corrective requirements in
`docs/delivery/reviews/VD2-07x-protected-export-feedback-qa-regate-2026-08-01.md`.
The accepted Architecture gate controls the immutable internal enum and all
four fault placements. A fresh QA re-gate is required before release.

## Single bounded TDD task

Correct feedback when a valid `.rekonexport` filename has an unusable selected
folder, while preserving native Save-panel behavior and the protected-export
security contract.

## Controlling artifacts

- `docs/superpowers/specs/2026-08-01-vd207x-protected-export-destination-feedback-design.md`
- `docs/superpowers/plans/2026-08-01-vd207x-protected-export-destination-feedback.md`
- `docs/delivery/reviews/VD2-07x-protected-export-feedback-architecture-gate-2026-08-01.md`
- `docs/delivery/reviews/VD2-07x-protected-export-feedback-tpm-gate-2026-08-01.md`
- `docs/delivery/reviews/VD2-07x-protected-export-feedback-qa-gate-2026-08-01.md`
- `docs/delivery/reviews/VD2-07x-protected-export-feedback-qa-regate-2026-08-01.md`

## Allowed implementation paths

| Path | Permitted change |
| --- | --- |
| `RekonPursuitCore/Workspace/ProtectedExportWorker.swift` | Dedicated errors, classification, and only the approved immutable fault seam. |
| `RekonPursuitCoreTests/ProtectedExportTests.swift` | Deterministic worker/store contracts and protected-export regressions. |
| `RekonPursuit/WorkspaceViewModel.swift` | Compiler-required exhaustive controlled-error mapping only. |
| `RekonPursuitTests/WorkspaceViewModelTests.swift` | Exact retained feedback, state, root-presentation, and no-success tests. |

`RekonPursuit/ContentView.swift` is inspection-only. Settings, accessibility,
service/store APIs, project files, persistence/schema, dashboard, and roadmap
changes are unauthorized.

## Required contract

- Invalid final component only becomes `.invalidDestinationName` with exactly
  `Choose a new file name ending in .rekonexport.`
- Valid-suffix parent `open`/`fstat` failure and pre-create non-`EEXIST`
  `openat` failure become `.destinationUnavailable` with exactly
  `Rekon Pursuit can’t use that folder. Choose another local folder and review the export again.`
- Preserve `.destinationExists`, `.destinationChanged`, `.sourceChanged`, and
  `.outputMayRemainAfterFailure`. Once final output could exist, classify only
  may-remain, never folder-unavailable.
- Preserve Save-panel filtering/default, `O_DIRECTORY | O_NOFOLLOW`,
  `O_EXCL | O_NOFOLLOW`, no overwrite, parent binding, review-before-write,
  verified-write-only event/activity, and safe owner copy.
- Never disclose path, POSIX error, scope state, recovery material, or keys.

## Immutable deterministic test seam and exact placements

Use only the architecture-approved, worker-only seam:

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

Production remains `ProtectedExportWorker(configuration: ...)`; tests inject an
immutable non-default mode. The fault cannot be global, mutable, serialized,
environment-driven, owner-selectable, or return raw `errno`; no filesystem
adapter is authorized without fresh architecture review.

- `parentOpenUnavailable`: after successful filename predicate, immediately
  before unchanged parent Darwin `open`.
- `parentInspectionUnavailable`: after successful parent open, immediately
  before `fstat`; close the descriptor before throwing.
- `exclusiveCreateUnavailable`: after unchanged current-parent-identity guard,
  immediately before Darwin `openat`; do not call `openat`.
- `afterOutputCreation`: only after nonnegative `openat`, descriptor assignment,
  and `created = true`; flow through the current catch to may-remain.

Fault tests use a real temporary enrolled store and valid `.rekonexport` URL;
they never use chmod, unavailable volumes, sandbox denial, sleeps, polling, or
raw-`errno` assertions.

## Required implementation sequence

0. Before any new tests, add exactly the architecture-approved immutable
   `ProtectedExportWorkerFaultMode`, `private let faultMode`, and default-`.none`
   initializer assignment shown above. This is a compilation scaffold only:
   it has no decision-point branches, error cases, copy, behavioral effect,
   Store/ViewModel production injection, adapter, or runtime-selectable seam.
   Production construction remains `ProtectedExportWorker(configuration: ...)`.
   This step alone must leave the existing focused regression suite green.
1. After the scaffold compiles, add the focused executable tests. Until GREEN
   adds the two worker error cases, core tests must not name
   `.invalidDestinationName` or `.destinationUnavailable`; they capture the
   thrown error and assert the exact proposed `LocalizedError.errorDescription`.
   Model tests assert exact owner error and status strings. The current ordinary
   behavior must therefore reach assertion RED for old copy, ignored injected
   modes, or missing placements—not a compilation error, skip, or expected
   failure. User-facing classification behavior remains test-first; Step 0 is
   non-behavioral testability scaffolding only.
2. GREEN adds only the two error cases with exact copy and the four approved
   checks: parent-open immediately before `open`; parent-inspection immediately
   after successful `open` and before `fstat`, closing its descriptor; exclusive
   create after the current-parent-identity guard and before `openat`; and
   post-create after descriptor assignment and `created = true`. Preserve the
   existing Darwin flags/order, binding, and `created` catch state machine.
3. Run fresh GREEN and regression bundles, inspect resolved lists and summaries,
   and record one execution per selected test with zero skips and zero expected
   failures. The implementation commit boundary follows this evidence; this
   planning task does not commit.

## RED/GREEN acceptance tests

Add and run focused worker tests for invalid-name, parent-open, parent-
inspection, pre-create confirmation, post-create, and ordinary audit success.
For invalid-name, both parent modes, and pre-create confirmation, assert final
URL absent, zero `protected_export_events`, and zero `activity_events` filtered
to `kind = 'protected_export_verified'`; do not assert zero total activity.
The pre-create case must first obtain a real successful review, then call
`createProtectedExport`. For post-create assert may-remain, final URL exists,
zero verified export/activity rows, and never folder-unavailable. Ordinary
default-worker write verifies final bytes against receipt and exactly one
verified export row plus one filtered verified activity row.

Model tests must prove both failed-review parent modes retain root error state,
exact error/status copy, no review, no success, and false root-success
presentation. Pre-create confirm retains its successful review and then has
  exact folder error/status, retained root error, nil success, and false root
  success. Post-create confirm has exactly `Final export writing or verification
  failed. The selected file may remain; treat it as unusable and remove it
  yourself.` as both error and status, retained root error, and no success.
  Existing-target regression uses a
pre-existing valid file, preserves original bytes exactly, proves exact
no-overwrite copy, no success event, and false root-success presentation.

First, after Step 0 and before adding the new RED tests, run the existing
focused regression suite. It must remain green because the scaffold has no
behavioral branches:

```bash
xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit -configuration Debug -destination 'platform=macOS,arch=arm64' -only-testing:RekonPursuitTests/ProtectedExportTests/testProtectedExportIsEncryptedAndVerifiableWithRecoveryKey -only-testing:RekonPursuitTests/ProtectedExportTests/testReviewBindsDestinationParentIdentity -only-testing:RekonPursuitTests/ProtectedExportTests/testSourceRevisionChangeRejectsReviewedExportWithoutCreatingAFile -only-testing:RekonPursuitTests/ProtectedExportTests/testExistingTargetIsRejectedWithoutOverwritingIt -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testProtectedExportReviewFailureRemainsVisibleForCorrection -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testProtectedExportSuccessRemainsNilForEveryNonSuccessBranch -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testVerifiedProtectedExportPublishesSafeSuccessAndRootPresentationOnlyAfterRealWriting -derivedDataPath /private/tmp/rekon-vd207x-export-feedback-scaffold-dd -resultBundlePath /private/tmp/rekon-vd207x-export-feedback-scaffold.xcresult
```

Inspect its resolved test list and summary before proceeding: every selected
test runs once and passes, with zero skips and zero expected failures. Retain
the bundle; RED/GREEN/regression use fresh non-existing paths.

Run RED only after the new test sources compile against the Step 0 scaffold:

```bash
xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit -configuration Debug -destination 'platform=macOS,arch=arm64' -only-testing:RekonPursuitTests/ProtectedExportTests/testInvalidDestinationNameUsesDedicatedControlledError -only-testing:RekonPursuitTests/ProtectedExportTests/testParentOpenUnavailableWithValidSuffixUsesDestinationUnavailableWithoutReview -only-testing:RekonPursuitTests/ProtectedExportTests/testParentInspectionUnavailableWithValidSuffixUsesDestinationUnavailableWithoutReview -only-testing:RekonPursuitTests/ProtectedExportTests/testExclusiveCreateFailureBeforeOutputUsesDestinationUnavailableWithoutActivity -only-testing:RekonPursuitTests/ProtectedExportTests/testPostCreateFailureRemainsOutputMayRemainAfterFailure -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testProtectedExportInvalidFilenameUsesExactCorrectionMessage -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testProtectedExportUnavailableParentOpenReviewUsesExactCorrectionMessage -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testProtectedExportUnavailableParentInspectionReviewUsesExactCorrectionMessage -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testProtectedExportUnavailableFolderConfirmUsesExactCorrectionMessage -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testProtectedExportPostCreateFailureRetainsMayRemainFeedback -derivedDataPath /private/tmp/rekon-vd207x-export-feedback-red-dd -resultBundlePath /private/tmp/rekon-vd207x-export-feedback-red.xcresult
```

RED fails only as executable assertions for the intended absent
classification/copy/placement behavior, with no compilation failures, skips,
or expected failures. Core tests use exact proposed `errorDescription` strings
without naming either absent new enum case; model tests use exact owner error
and status strings. Preserve and inspect this result bundle's resolved test
list and summary. GREEN repeats it with fresh non-existing `green` paths.

Run the fresh regression bundle and inspect its resolved test list/summary;
every selected test runs once and passes with zero skip/expected failure:

```bash
xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit -configuration Debug -destination 'platform=macOS,arch=arm64' -only-testing:RekonPursuitTests/ProtectedExportTests/testProtectedExportIsEncryptedAndVerifiableWithRecoveryKey -only-testing:RekonPursuitTests/ProtectedExportTests/testReviewBindsDestinationParentIdentity -only-testing:RekonPursuitTests/ProtectedExportTests/testSourceRevisionChangeRejectsReviewedExportWithoutCreatingAFile -only-testing:RekonPursuitTests/ProtectedExportTests/testExistingTargetIsRejectedWithoutOverwritingIt -only-testing:RekonPursuitTests/ProtectedExportTests/testVerifiedProtectedExportCreatesExactlyOneVerifiedEventAndActivity -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testProtectedExportReviewFailureRemainsVisibleForCorrection -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testProtectedExportSuccessRemainsNilForEveryNonSuccessBranch -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testVerifiedProtectedExportPublishesSafeSuccessAndRootPresentationOnlyAfterRealWriting -derivedDataPath /private/tmp/rekon-vd207x-export-feedback-regression-dd -resultBundlePath /private/tmp/rekon-vd207x-export-feedback-regression.xcresult
```

## Handoff and gates

The implementer records commands, result-bundle inspection, exact outcomes,
changed paths, and `git diff --check`; after GREEN/regression evidence is
accepted, the implementation commit may include only
the four authorized paths. Release order: Planning amendment; Architect and
TPM gate; fresh QA re-gate; Delivery scope/ledger gate; fresh implementer;
separate code review and QA verification; Architect deviation review;
Security/privacy verification; Delivery completion. The implementer cannot
review or verify their own work.
