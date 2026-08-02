# VD2-07x protected-export dialog unification — QA/test gate

**Date:** 2026-08-02
**Role:** Fresh independent pre-implementation QA/test gate
**Scope:** Approved design, implementation plan, and relevant existing UI and
model tests. No production or test source was changed.

## Verdict: NEEDS CHANGE

The proposed entry-state UI test is genuinely test-first: it can compile and
execute before the visual change, does not require secret material or a native
chooser interaction, and should fail solely on the current in-progress sheet.
The plan is not yet sufficient for release, however. Its cancellation assertion
does not prove that the root dialog has actually dismissed, its selected model
command omits three material protected-export regressions, and the owner-native
step does not state the observable confirmation transition needed to close the
only legitimate native-path coverage gap.

## Evidence assessed

| Required proof | Assessment |
| --- | --- |
| No stock in-progress sheet and entry/error continuity | The new RED/GREEN method checks the entry title, field, action, inline invalid-key error, absence of the success dialog, and zero sheets before cancellation. This is a sound entry-state discriminator. |
| Cancellation continuity | In its current form, the final assertion only rediscovers the underlying launch action. That element can remain discoverable while a root overlay is still present, so it does not demonstrate dismissal. |
| No invented success | The UI method checks success is absent on entry failure, and the existing model tests verify that success is produced only after a verified write and remains absent across several failure branches. |
| Unchanged non-happy model behavior | The focused command excludes the existing invalid-filename, in-flight-confirmation cancellation, and workspace-transition success-clearing tests. In particular, the omitted in-flight cancellation test is the deterministic proof that a late completion cannot invent success after Cancel. |
| Build and result evidence | The plan names a focused UI run, focused model run, ordinary Debug build, and diff check. It must require the detailed test-result view for the model bundle too, so execution counts and skipped/expected outcomes are inspectable. |
| Native confirmation and real success | A secret-free automated UI fixture cannot legitimately reach confirmation. The signed owner-native run is therefore the correct exclusive proof, but its required observations must explicitly distinguish the native chooser from a stock in-progress sheet and confirm the return to the custom confirmation state. |

## Required plan amendments

1. Strengthen the new UI method's post-error and post-cancel contract. While
   the inline error is displayed, reassert the entry title, recovery-key field,
   and primary action. After tapping Cancel, require all of the following
   before asserting that the launch action returns:

   ```swift
   XCTAssertFalse(error.exists)
   XCTAssertFalse(app.staticTexts["Export protected copy"].exists)
   XCTAssertEqual(app.sheets.count, 0)
   XCTAssertTrue(app.buttons["create-protected-export"].waitForExistence(timeout: 2))
   ```

   Keep the existing no-sheet assertions before and after the controlled
   entry error. This remains a presentation test; it adds no identifier,
   fixture, accessibility, or native-panel behavior.

2. Extend the focused model invocation to include all three omitted existing
   protected-export regressions, and inspect both its summary and detailed
   test-result view. Add these selectors to the plan's model command:

   ```text
   testProtectedExportInvalidFilenameUsesExactCorrectionMessage
   testCancellingConfirmedProtectedExportInvalidatesInFlightOperation
   testProtectedExportSuccessClearsForEveryWorkspaceTransition
   ```

   The model bundle must show every selected method executing once with zero
   skips and zero expected failures. The focused UI bundle must meet the same
   condition. This preserves all existing lower-layer non-happy-path coverage
   without changing its source.

3. Replace the owner-native acceptance text with a state-only checklist. In
   the signed owner run, the owner must observe and attest, without retaining
   sensitive material, that:

   - the entry state is the custom navy dialog;
   - invoking its existing primary action presents the native chooser in
     front of that dialog;
   - returning from a valid chooser selection presents the custom
     confirmation dialog, not a stock in-progress sheet, with safe facts only;
   - confirmed, verified completion dismisses the in-progress dialog before
     the unchanged success dialog appears; and
   - the recorded evidence is limited to pass/fail state observations.

   This native check remains owner-only and is a release blocker until it is
   independently recorded. It neither introduces test-only success nor
   changes the VD2-08 accessibility deferral.

## Release condition

Do not release the implementer until the plan includes all three amendments.
After implementation, accept only when the executable RED has the stated
single presentation failure; the amended UI and complete focused model suites
are green with inspectable result evidence; the ordinary Debug build and diff
check pass; independent review finds no scope expansion; and the owner-native
state-only checklist is recorded as passed. VD2-08 accessibility work remains
deferred and unchanged.
