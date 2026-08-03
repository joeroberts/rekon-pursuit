# VD2-07x protected-export destination feedback — hunk-isolation release

**Date:** 2026-08-01  
**Role:** Fresh independent integration / hunk-isolation review  
**Verdict:** **SAFE TO RELEASE**

## Release decision

The Delivery HOLD can be cleared for one fresh implementer if the task follows
the exact boundaries below. The two core task files are currently clean. The
dirty `WorkspaceViewModel.swift` does not require a feedback-task edit because
its existing mapper already returns
`ProtectedExportWorkerError.errorDescription`. The dirty model-test file has a
separate, untouched protected-export insertion seam that is well outside the
existing success-dialog, operation-token, worker-injection, and helper hunks.

This is a hunk-scoped release, not permission to stage or replace any complete
source file. Any edit outside the specified hunks, any change to
`WorkspaceViewModel.swift`, or any whole-file staging changes this verdict to
**HOLD** pending a fresh Delivery isolation review.

## Current worktree ownership map

All line numbers below are from the current worktree at this review.

| Path | Current state | Isolation decision |
| --- | --- | --- |
| `RekonPursuitCore/Workspace/ProtectedExportWorker.swift` | Clean against `HEAD`; 211 lines. Current classification is at lines 30–45, the production initializer at 47–52, parent handling at 140–148, and the exclusive-create state machine at 180–205. | Feedback task owns only the explicit worker hunks listed below. |
| `RekonPursuitCoreTests/ProtectedExportTests.swift` | Clean against `HEAD`; 108 lines; none of the six planned feedback tests exists. | Feedback task may append one test/helper block immediately before the current class-closing brace at line 108. |
| `RekonPursuit/WorkspaceViewModel.swift` | Dirty: 91 insertions and 23 deletions. Existing protected-export success/token/injection work occupies current lines 158–165, 301, 318, 333, 356–358, 375, 1319–1404, 1833, and 1889. | **Inspection only; do not edit or stage.** |
| `RekonPursuitTests/WorkspaceViewModelTests.swift` | Dirty: 1,542 insertions and 22 deletions. The earlier success/token tests and their helpers are inside the existing large diff hunk based at `@@ -1890,11 +2734,650`, including current lines 2818–3309; `GatedProtectedExportCreate` is a separate current hunk at 3409–3442. | Add the feedback contracts only at the untouched seam after current line 690 and before current line 692. Do not reuse or modify the later dirty helpers. |

There are currently no staged paths. The only dirty authorized-path files are
the two pre-existing ViewModel files above; both core feedback files are clean.

## Safe source and test hunks

### 1. `ProtectedExportWorker.swift`

The file is clean, so these task-owned changes cannot overwrite earlier VD2-07x
work:

1. Current lines 30–45: replace the overloaded `invalidDestination` case/copy
   with only `invalidDestinationName` and `destinationUnavailable`, including
   the exact approved descriptions.
2. Immediately before current line 47, and within current lines 47–52: add only
   the immutable internal `ProtectedExportWorkerFaultMode`, private `let
   faultMode`, default-`.none` initializer argument, and assignment required by
   Step 0.
3. Current call sites 57, 78, and 101: thread the immutable mode only to the
   worker's existing parent-open and exclusive-copy helpers. Do not add a
   `WorkspaceStore` or ViewModel parameter; the store already accepts an
   injected worker for tests.
4. Current lines 140–148: retain the filename predicate and unchanged
   `O_RDONLY | O_DIRECTORY | O_NOFOLLOW` call. Place parent-open and
   parent-inspection faults at the architecture-approved boundaries; close the
   opened descriptor before throwing the inspection fault.
5. Current lines 180–205: retain the parent-identity guard, unchanged
   `O_RDWR | O_CREAT | O_EXCL | O_NOFOLLOW` flags and mode, descriptor handling,
   and `created` catch state. Place the pre-create fault immediately before
   `openat`; place the post-create fault only after descriptor assignment and
   `created = true`. Capture a real `openat` failure's `errno` immediately so
   `EEXIST` remains `destinationExists` and only other pre-create failures map
   to `destinationUnavailable`.

No service, store, persistence, project, Settings, ContentView, dashboard,
roadmap, or accessibility file is in source scope.

### 2. `ProtectedExportTests.swift`

Append one distinct block immediately before the current line-108 closing
brace. Add the six exact worker contracts from the approved plan:

- `testInvalidDestinationNameUsesDedicatedControlledError`
- `testParentOpenUnavailableWithValidSuffixUsesDestinationUnavailableWithoutReview`
- `testParentInspectionUnavailableWithValidSuffixUsesDestinationUnavailableWithoutReview`
- `testExclusiveCreateFailureBeforeOutputUsesDestinationUnavailableWithoutActivity`
- `testPostCreateFailureRemainsOutputMayRemainAfterFailure`
- `testVerifiedProtectedExportCreatesExactlyOneVerifiedEventAndActivity`

Keep all worker/store fixtures used by those tests inside the same appended
block. Existing tests at current lines 6–107 remain byte-for-byte unchanged.

### 3. `WorkspaceViewModelTests.swift`

Use exactly one new insertion hunk between these stable anchors:

```swift
    func testCancellingReviewedProtectedExportClearsReviewWithoutWritingOrChangingActiveWorkspace() async throws {
        // Existing test ends at current line 690.
    }

    // Insert the complete feedback-test block and its feedback-only helpers here.

    func testExternalFolderLeaseIsRetainedForTheOpenedStoreThenReleasedOnClose() throws {
        // Existing test begins at current line 692.
    }
```

In `HEAD` this is the corresponding seam between the closing brace at line 548
and `testExternalFolderLeaseIsRetainedForTheOpenedStoreThenReleasedOnClose` at
line 550. It is separated from the nearest existing model-test diff hunks: the
current file's top insertion ends at line 149 and the next pre-existing hunk is
near line 1014. Therefore the feedback insertion remains independently
selectable with ordinary zero- or three-context Git hunks.

The insertion contains only these five model tests:

- `testProtectedExportInvalidFilenameUsesExactCorrectionMessage`
- `testProtectedExportUnavailableParentOpenReviewUsesExactCorrectionMessage`
- `testProtectedExportUnavailableParentInspectionReviewUsesExactCorrectionMessage`
- `testProtectedExportUnavailableFolderConfirmUsesExactCorrectionMessage`
- `testProtectedExportPostCreateFailureRetainsMayRemainFeedback`

Add new, uniquely named feedback-only helpers in that same insertion block,
for example:

- `makeProtectedExportFeedbackStore(faultMode:)`, which opens its own temporary
  database, constructs `ProtectedExportWorker(configuration:faultMode:)`, and
  uses the existing `WorkspaceStore(... protectedExportWorker:)` test seam;
- `makeProtectedExportFeedbackModel(faultMode:destination:)`;
- `waitForProtectedExportFeedbackOperation(on:)`;
- `assertProtectedExportFeedback(on:message:retainedReview:)`, which checks the
  exact error/status copy, nil success, false root-success presentation, root
  error retention, and nil-versus-retained review contract.

Do not extend or edit `protectedExportReadyStore` (current line 3264),
`temporaryProtectedExportDestination` (3272),
`createVerifiedProtectedExport` (3277), `protectedExportRootPresentation`
(3289), `assertNoProtectedExportSuccess` (3299), or
`GatedProtectedExportCreate` (3409). Those symbols and surrounding hunks belong
to the earlier uncommitted success-dialog/token work. Do not move existing
tests to make room.

### 4. `WorkspaceViewModel.swift`

No change is required or permitted. Current lines 1449–1453 already implement:

```swift
if let controlled = error as? ProtectedExportWorkerError {
    return controlled.errorDescription ?? fallback
}
```

The only exhaustive switch affected by the new worker cases is the worker
error's own `errorDescription` switch, which is inside the clean core worker
file. If compilation unexpectedly appears to require a ViewModel edit, stop;
do not touch the dirty protected-export flow or mapper, and return to Delivery
for a new isolation decision.

## TDD and evidence sequence

1. Add only the inert fault-mode scaffold to the clean worker file. Before any
   new test source, run and inspect the approved scaffold result bundle. Every
   selected existing test must execute once and pass with zero skips and zero
   expected failures.
2. Add the core-test append block and the isolated model-test insertion block.
   Until GREEN, tests assert the proposed exact `LocalizedError.errorDescription`
   strings and must not name the not-yet-added worker cases. Run the approved
   RED command and preserve a bundle proving executable assertion failures only.
3. Add only the two worker errors/copy and four fixed placements in the worker
   hunks above. Do not edit `WorkspaceViewModel.swift`.
4. Run and inspect fresh GREEN and regression bundles. Verify every selected
   test ran once with zero skips/expected failures and the required output,
   retained-review, audit-row, and existing-byte boundaries.
5. Run `git diff --check`, inspect `git diff --unified=0` for all three changed
   source/test paths, and independently confirm the pre-existing ViewModel and
   success-dialog/token test hunks are unchanged.

The current worktree's unrelated changes are part of the test environment, so
test evidence must name the exact dirty commit/worktree state. Passing tests do
not authorize incorporating those earlier changes into this task's staged
patch.

## Changed-path and staging controls

The implementation may change only:

1. `RekonPursuitCore/Workspace/ProtectedExportWorker.swift`
2. `RekonPursuitCoreTests/ProtectedExportTests.swift`
3. the single feedback insertion hunk in
   `RekonPursuitTests/WorkspaceViewModelTests.swift`

`RekonPursuit/WorkspaceViewModel.swift` is removed from the effective changed
path set for this isolated implementation. It must remain dirty only with its
pre-existing diff and must produce no staged diff.

Source must never be staged in whole-file form. The implementer must not use
`git add .`, `git add -A`, `git add -u`, `git commit -a`, or `git add <source
path>`. After GREEN/regression acceptance, use interactive patch staging only:

```bash
git add -p -- RekonPursuitCore/Workspace/ProtectedExportWorker.swift
git add -p -- RekonPursuitCoreTests/ProtectedExportTests.swift
git add -p -- RekonPursuitTests/WorkspaceViewModelTests.swift
```

Split hunks if Git combines context, accept only the task-owned hunks described
above, and then require all of the following before a commit boundary:

```bash
git diff --cached --name-only
git diff --cached --unified=3
git diff --cached -- RekonPursuit/WorkspaceViewModel.swift
git diff --check
```

The cached path list must contain exactly the three paths above; the cached
ViewModel diff must be empty; and the cached model-test diff must contain only
the insertion between the line-690/692 anchors. No documentation, project,
dashboard, roadmap, Settings, ContentView, or earlier VD2-07x hunk may enter the
implementation commit.

## Release condition

**SAFE TO RELEASE** one fresh implementer for the single approved TDD task under
this plan. Release automatically returns to **HOLD** if the safe insertion seam
changes before implementation, another agent edits either clean core file or
the specified model-test seam, `WorkspaceViewModel.swift` is changed by this
task, or patch-only staging cannot isolate the three authorized task hunks.
