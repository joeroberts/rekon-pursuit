# VD2-07x protected-export destination feedback — QA gate

**Date:** 2026-08-01  
**Role:** Independent pre-implementation QA/test review  
**Scope:** RED/GREEN test strategy and focused evidence only; no source or test
changes were made.

## Verdict: NEEDS CHANGE

The proposed internal, default-`.none` fault seam is the right deterministic
test boundary. It avoids permission, sandbox, mount, and host-`errno`
dependencies, and the documented selectors name the real test target:
`RekonPursuitTests`. `xcodebuild -list` confirms that this target exists and
contains the source-group files `RekonPursuitCoreTests/ProtectedExportTests.swift`
and `RekonPursuitTests/WorkspaceViewModelTests.swift`; there is no separate
`RekonPursuitCoreTests` target. The plan must add the gates below before a
fresh implementer is released.

## Evidence reviewed

- The design and brief require distinct invalid-name, pre-write unavailable,
  and post-create-may-remain outcomes, without output/event/success before a
  safe write.
- Current `openParent` maps a bad filename, failed parent `open`, and failed
  `fstat` to `.invalidDestination`; non-`EEXIST` `openat` does the same.
  `copyExclusivelyAndReadBack` changes every failure after `created = true` to
  `.outputMayRemainAfterFailure`. See
  `RekonPursuitCore/Workspace/ProtectedExportWorker.swift:140-204`.
- Review failures clear the operation success and publish retained error copy;
  confirm failures retain the review while publishing the error. See
  `RekonPursuit/WorkspaceViewModel.swift:1318-1387`.
- The current success UI test proves a file and filename-only root presentation,
  but it does not query the verified-export or activity rows. See
  `RekonPursuitTests/WorkspaceViewModelTests.swift:2818-2864`.

## Required RED/GREEN gates

1. **Make each forced mode prove its exact decision point.** The injected
   worker must use a real temporary, enrolled store and a valid `.rekonexport`
   URL for `parentUnavailable`, `exclusiveCreateUnavailable`, and
   `afterOutputCreation`. The parent mode must fail before parent
   open/inspection; the exclusive-create mode must fail before `openat` can
   create the final filename; the after-output mode must run only after the
   exclusive final file exists. Production construction must default to `.none`
   and retain the live Darwin calls and flags. Do not use chmod, unavailable
   volumes, sandbox denial, sleeps, polling timeouts, or raw `errno` checks.

2. **Strengthen no-output/no-evidence assertions.** For invalid name,
   unavailable parent, and unavailable pre-create confirmation, assert the
   final URL does not exist, `protected_export_events` has zero rows, and
   `activity_events` has zero rows whose kind is `protected_export_verified`.
   Query the latter by kind (or compare a filtered baseline), not as zero total
   activity rows: enrollment/fixture setup may legitimately create unrelated
   activity. The pre-create case must first complete a real review, then call
   `createProtectedExport`, so it proves the confirm-time classification rather
   than a review-time short circuit.

3. **Specify retained correction state at both model boundaries.** The two
   failed-review model tests must assert `protectedExportReview == nil`, false
   root success presentation, exact error *and* status copy, and a retained
   root error presentation. The pre-create confirm test must assert that its
   successful review is still retained after the controlled error (the current
   behavior), `protectedExportSuccess == nil`, false root success presentation,
   exact folder-unavailable error/status copy, and retained root error
   presentation. This removes the present ambiguity in the plan's
   `protectedExportReview == nil after failed review` wording and prevents a
   future change from clearing or silently dismissing the correction state.

4. **Prove the post-create boundary rather than only its enum case.** The
   post-create worker test must assert
   `.outputMayRemainAfterFailure`, the final URL exists after the forced fault,
   zero verified-export/activity rows, and never
   `.destinationUnavailable`. Add a model-level confirm test (or extend the
   selected confirm test) that asserts the unchanged exact may-remain message,
   retained error state, and no success presentation. The current focused RED
   command has no view-model selector for this branch, so an enum-only test
   could pass while owner feedback regresses.

5. **Close the real-success/audit evidence gap.** Retain the existing
   encryption/read-back and root-presentation regressions, and add an explicit
   assertion after an ordinary default-worker export that the final bytes verify
   to its receipt, `protected_export_events` contains exactly one `verified`
   row, and `activity_events` contains exactly one
   `protected_export_verified` row. The current selected success tests prove
   the output and presentation separately but do not prove the required audit
   writes.

6. **Keep existing-target evidence exact and isolated.** The selected existing
   target tests must assert byte-for-byte preservation and the literal
   no-overwrite message. The test must use a pre-existing valid
   `.rekonexport` file, not a seam mode, and must verify no success event or
   root success presentation. This remains a regression, not a new failure
   classification.

7. **Update the two commands and result-bundle procedure.** Include selectors
   for the post-create model feedback test and for the verified-event/activity
   assertion in the RED/GREEN and regression commands as applicable. Execute
   RED only after the new tests compile; it must fail only because the new
   classifications/copy are absent, with no skips or expected failures. For
   GREEN and regression, use fresh non-existing DerivedData/result-bundle paths
   (or preserve and explicitly inspect prior evidence before replacement),
   record the resolved test list and result summary, and require every selected
   test to execute once and pass with zero skipped/expected-failure tests.
   Inspect the result bundles, not only the process exit code.

## Release evidence required after implementation

- A RED bundle demonstrating the intended missing-classification failures only.
- A GREEN bundle containing all four worker branches plus the invalid-name,
  review-unavailable, pre-create-confirm-unavailable, and post-create-confirm
  retained-feedback tests.
- A regression bundle proving encryption/read-back, parent identity binding,
  source-change no-file behavior, existing-target bytes/copy, no-success
  branches, verified event/activity rows, and filename-only root success after
  a real write.
- `git diff --check` clean, a changed-path review limited to the four allowed
  implementation/test files, and no Save-panel, Settings, accessibility,
  persistence-schema, project, or diagnostic-disclosure change.

## Check performed

`git diff --check` completed cleanly in the assigned worktree. The worktree
contains unrelated pre-existing changes; they were not modified or used as
evidence for this gate.
