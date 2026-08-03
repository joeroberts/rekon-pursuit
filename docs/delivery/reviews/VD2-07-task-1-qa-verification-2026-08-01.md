# VD2-07 Task 1 — independent QA verification

**Date:** 2026-08-01  
**Role:** Fresh independent QA verifier  
**Verdict:** **ACCEPT**

## Scope and evidence

Verified the intended-RED test-only slice against:

- `.superpowers/sdd/2026-08-01-vd207-settings-information-architecture/task-1-brief.md`
- `docs/superpowers/plans/2026-08-01-vd207-settings-information-architecture.md`
- `.superpowers/sdd/2026-08-01-vd207-settings-information-architecture/task-1-report.md`

I independently inspected the implementer result bundle at
`/private/tmp/rekon-vd207-task-1-red.xcresult`; its `xcresulttool` summary is
**33 total, 28 passed, 5 failed, 0 skipped, and 0 expected failures**.

I then reran the report's exact signed Debug command, retaining every
`-only-testing` selector and changing only the required isolated artifact
paths:

```text
-derivedDataPath /private/tmp/rekon-vd207-task-1-qa-red-dd
-resultBundlePath /private/tmp/rekon-vd207-task-1-qa-red.xcresult
```

The independent bundle reports the same **33 total, 28 passed, 5 failed, 0
skipped, and 0 expected failures**. The Debug build log records the configured
`Apple Development: jaroberts4@gmail.com (PT7GS96H3L)` identity for the app,
unit-test bundle, and UI-test runner. The nonzero `xcodebuild` exit (65) is the
expected consequence of the five deliberate UI RED failures; there was no
compile, signing, fixture-launch, automation-initialization, rail, or baseline
test failure.

## Failure classification

| UI test | Result | Classification |
| --- | --- | --- |
| `testVD207SettingsSecondaryNavigationDefaultsToRecoveryAndKeepsGlobalRail` | Failed | **Allowed RED.** `sidebar-settings` existed, was tapped, and remained selected. The failures at `RekonPursuitUITests.swift:2635`, `:2638`, and `:2639` are the absent `settings-secondary-navigation` and `settings-section-recovery-archives` elements only. |
| `testVD207SettingsSecondaryNavigationIsKeyboardOperableAtCompactWidth` | Failed | **Allowed RED.** After the Settings rail tap, the failures at `:2661`, `:2662`, and the focus helper's `:77` all derive from absent `settings-section-document-references`; no compact-window or keyboard-runner failure occurred. |
| `testVD207SettingsRecoveryRetainsArchiveTruthAndRootOwnedCancellation` | Failed | **Allowed RED.** The absent `settings-section-recovery-archives-panel` at `:2679` and absent `settings-archive-summary-*` at `:2686-2687` are the only failures. It reached the existing Settings route before the new Settings panel boundary. |
| `testVD207SettingsDocumentAndAISectionsStayAggregateAndUnavailable` | Failed | **Allowed RED.** The sole failure at `:2728` is the absent `settings-section-document-references` selector after the successful Settings rail tap. |
| `testVD207SettingsRelaunchKeepsFixtureTruthAndResetsLocalSelection` | Failed | **Allowed RED.** The sole failure at `:2779` is the absent `settings-section-document-references` selector after the successful Settings rail tap. |

All eleven individual XCTest assertions/messages behind those five failed test
cases map to one of the required absent `settings-*` selectors or panels above.
They are not assertion failures from an existing recovery/archive/export action
or an unrelated product behavior.

## Baseline and regression results

Every non-RED selected test ran once and passed:

- Recovery-only UI baseline: 1/1.
- Fixture-host isolation/time/archive/document baselines: 8/8.
- Existing WorkspaceViewModel safety selectors plus the new cancellation/no-write
  regression: 12/12. In particular,
  `testCancellingReviewedProtectedExportClearsReviewWithoutWritingOrChangingActiveWorkspace`
  passed once.
- Portable-archive lower-layer safety selectors: 4/4.
- Protected-export lower-layer safety selectors: 3/3.

The five named UI methods and one named unit method are present exactly once in
the two permitted test files and match the Task 1 prescribed contracts: the UI
tests use the existing fixtures, semantic focus helper, and UUID-qualified
relaunch session; the unit test keeps its recovery key in process memory and
asserts no destination write or active-workspace mutation after cancellation.
`git diff --check` passed. I did not modify product/test source, fixtures,
project files, the index, or commits; this review is the only artifact created.

## Decision

**ACCEPT.** Task 1 supplies the required deterministic Settings RED boundary
and the full green recovery/fixture/lower-layer safety baseline in the
configured signed Debug app. Task 2 may be considered by the Delivery and TPM
gates; this QA decision does not itself alter delivery status or approve the
future Settings implementation.
