# VD2-07x — Baseline-repair prerequisite brief

**Status:** DRAFT — planning only. No implementation is released by this brief. Fresh independent Architecture, QA, Security/privacy, TPM, and Delivery approvals are required before a fresh implementer begins.

## Objective

Repair the three proven defects that prevent the approved VD2-07x Task 1 contract from reporting only its intentionally absent reference UI selectors. This is a pre-Task-2 baseline repair; it does not build the approved reference-faithful Settings surfaces.

## Controlling artifacts

- `docs/superpowers/specs/2026-08-01-vd207-reference-faithful-recovery-screen-design.md`
- `docs/superpowers/plans/2026-08-01-vd207-reference-faithful-recovery-screen.md`
- `docs/delivery/task-briefs/VD2-07x-reference-faithful-settings.md`
- `docs/superpowers/plans/2026-08-01-vd207x-baseline-repair-prerequisite.md`
- `.superpowers/sdd/2026-08-01-vd207-reference-faithful-recovery-screen/task-1-report.md`

## Verified causes and required outcomes

| Cause | Required repair result |
| --- | --- |
| `VisualFixtureLaunchConfiguration.fixedNow` is the May 1 UTC epoch despite its May 6 comment. | The fixture time is exactly 2025-05-06T12:00:00Z and archive expiry is 2025-06-05T12:00:00Z. |
| Settings local buttons do not reflect actual tab focus in their accessibility value. | At compact width each existing section control can be Tab-focused and reports exactly `Not selected; Keyboard focus`; after Space it reports exactly `Selected; Keyboard focus`, shows its matching existing panel, and retains selected global Settings rail. |
| The AI unavailable `Text` is exposed as an arbitrary element after an overriding accessibility label. | Existing static-text checks pass while preserving the same local-only/unavailable copy and no-control boundary. |

## Ownership and allowlist

| Path | Permitted authored hunk |
| --- | --- |
| `RekonPursuit/RekonVisualTheme.swift` | The `VisualFixtureLaunchConfiguration.fixedNow` numeric literal only. |
| `RekonPursuit/SettingsView.swift` | `sectionSelector(_:)` Button focus/label modifiers and removal of the AI `Text` override only. |
| `RekonPursuitUITestHostTests/RekonPursuitUITestHostTests.swift` | One direct ISO-UTC assertion in `testVisualFixtureUsesFixedTimeAndReducedMotionContracts`. |
| `RekonPursuitUITests/RekonPursuitUITests.swift` | Remove only the temporary compact-reference `guard section.exists else { continue }` paths if present, and add only an `app.staticTexts["settings-ai-connections-unavailable"]` role assertion alongside the existing `Any` query. Retain all selector names, existing assertions, and RED activities. |

## Explicit exclusions

- No Task 2 reference tab/card/hero/icon/colour/layout/dialog rendering.
- No changes to `ContentView`, `WorkspaceViewModel`, `RekonPursuitCore`, persistence, archive/export/review/write/purge/restore behavior, fixtures beyond the single time literal, launch parser, routes, global rail, project graph, signing, entitlement, or network behavior.
- No changes to the four local Settings identifiers, the default Recovery selection, tab labels, action closures, aggregate counts, or AI/document/recovery copy other than removing the overriding AI accessibility label.
- No fixture/default/demo export success, test-only UI control, raw destination/key/path, recovery material, or document metadata.
- No `XCTSkip`, `XCTExpectFailure`, retry workaround, test expectation relaxation, result-bundle workaround, bulk stage, reset, or reformat.

## Test-first contracts

1. Extend `testVisualFixtureUsesFixedTimeAndReducedMotionContracts` with:

   ```swift
   let formatter = ISO8601DateFormatter()
   XCTAssertEqual(
       formatter.string(from: VisualFixtureLaunchConfiguration.fixedNow),
       "2025-05-06T12:00:00Z"
   )
   ```

   It must fail against the known May 1 epoch before the source literal changes, then pass after it becomes `1_746_532_800`.

2. Do not alter the existing compact keyboard expectations. The implementation must make these already-signed assertions true for all four controls:

   ```swift
   XCTAssertEqual(section.value as? String, "Not selected; Keyboard focus")
   app.typeKey(.space, modifierFlags: [])
   XCTAssertEqual(section.value as? String, "Selected; Keyboard focus")
   ```

   The source uses the already-working local `Button` pattern: `.buttonStyle(.plain)`, `.focusable()`, `.focused($focusedSection, equals: section)`, existing Space handler, `.focusEffectDisabled(true)`, `.accessibilityLabel(section.title)`, existing value/identifier/selection traits. It must not add a new state model or mutate selection on focus alone.

3. First extend `testVD207SettingsDocumentAndAISectionsStayAggregateAndUnavailable` without removing or replacing its existing `app.descendants(matching: .any)["settings-ai-connections-unavailable"]` query or any current assertion. Add this exact role predicate beside it:

   ```swift
   let unavailableStaticText = app.staticTexts["settings-ai-connections-unavailable"]
   XCTAssertTrue(unavailableStaticText.waitForExistence(timeout: 2))
   XCTAssertTrue(unavailableStaticText.label.contains("No AI requests"))
   XCTAssertTrue(unavailableStaticText.label.contains("Gmail"))
   XCTAssertTrue(unavailableStaticText.label.contains("Calendar"))
   ```

   The new role assertions must be red with the current accessibility-label override. Then preserve the exact unavailable `Text` content and identifier, remove only its explicit `.accessibilityLabel`, and prove the old `Any` assertions plus the new `StaticText` assertions green. The Document and AI panels still have no buttons, links, menu buttons, fields, switches, or checkboxes.

4. The compact reference test must not use its temporary guarded continuation to pass a missing section. Existing presence/hittability assertions fail normally. Once baseline focus is real, it records exactly these two expected visual RED selectors:

   ```text
   settings-reference-tab-strip
   settings-reference-tab-recovery-archives
   ```

## Focused commands

```bash
xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit -configuration Debug -destination 'platform=macOS,arch=arm64' -only-testing:RekonPursuitUITestHostTests/RekonPursuitUITestHostTests/testVisualFixtureUsesFixedTimeAndReducedMotionContracts -only-testing:RekonPursuitUITestHostTests/RekonPursuitUITestHostTests/testArchiveVisualFixtureSeedsVerifiedArchiveCatalogue -derivedDataPath /private/tmp/rekon-vd207x-baseline-focused-host-dd -resultBundlePath /private/tmp/rekon-vd207x-baseline-focused-host.xcresult

xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit -configuration Debug -destination 'platform=macOS,arch=arm64' -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207SettingsSecondaryNavigationDefaultsToRecoveryAndKeepsGlobalRail -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207SettingsSecondaryNavigationIsKeyboardOperableAtCompactWidth -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207SettingsDocumentAndAISectionsStayAggregateAndUnavailable -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207SettingsRecoveryRetainsArchiveTruthAndRootOwnedCancellation -derivedDataPath /private/tmp/rekon-vd207x-baseline-focused-ui-dd -resultBundlePath /private/tmp/rekon-vd207x-baseline-focused-ui.xcresult
```

Expected: every selected focused contract passes with zero skip and zero expected failure.

## Exact 43-selector matrix

```bash
xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit -configuration Debug -destination 'platform=macOS,arch=arm64' \
  -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207ReferenceRecoveryDashboardKeepsRailAndUsesCardComposition \
  -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207ReferenceRecoveryDoesNotInventExportSuccess \
  -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207ReferenceTabsKeepKeyboardSelectionAtCompactWidth \
  -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207ReferenceOtherSettingsSectionsUseTruthfulInformationalCards \
  -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207SettingsSecondaryNavigationDefaultsToRecoveryAndKeepsGlobalRail \
  -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207SettingsSecondaryNavigationIsKeyboardOperableAtCompactWidth \
  -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207SettingsRecoveryRetainsArchiveTruthAndRootOwnedCancellation \
  -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207SettingsDocumentAndAISectionsStayAggregateAndUnavailable \
  -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207SettingsRelaunchKeepsFixtureTruthAndResetsLocalSelection \
  -only-testing:RekonPursuitUITests/RekonPursuitUITests/testRecoveryFixtureShowsOnlyRecoveryActionsAndDoesNotOpenAWorkspace \
  -only-testing:RekonPursuitUITestHostTests/RekonPursuitUITestHostTests/testVD202FixtureHostPublishesAProofThatLiveStoresAreUnavailable \
  -only-testing:RekonPursuitUITestHostTests/RekonPursuitUITestHostTests/testVisualFixtureLaunchConfigurationIsExplicitAndIsolated \
  -only-testing:RekonPursuitUITestHostTests/RekonPursuitUITestHostTests/testVisualFixtureConfigurationsUsePerRunTemporaryRoots \
  -only-testing:RekonPursuitUITestHostTests/RekonPursuitUITestHostTests/testVisualFixtureUsesFixedTimeAndReducedMotionContracts \
  -only-testing:RekonPursuitUITestHostTests/RekonPursuitUITestHostTests/testArchiveVisualFixtureConstructionCompletesOnTheMainActor \
  -only-testing:RekonPursuitUITestHostTests/RekonPursuitUITestHostTests/testArchiveVisualFixtureSeedsVerifiedArchiveCatalogue \
  -only-testing:RekonPursuitUITestHostTests/RekonPursuitUITestHostTests/testArchiveVisualFixtureUsesItsDeclaredTimeZoneAtTheCalendarBoundary \
  -only-testing:RekonPursuitUITestHostTests/RekonPursuitUITestHostTests/testDocumentRelinkVisualFixtureContainsASelectedRelinkRequiredReference \
  -only-testing:RekonPursuitUITestHostTests/RekonPursuitUITestHostTests/testVD207SettingsRecoveryPresentationPreservesBusyDisabledAndInactiveCandidateContracts \
  -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testVerifiedProtectedExportPublishesSafeSuccessAndRootPresentationOnlyAfterRealWriting \
  -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testProtectedExportSuccessRemainsNilForEveryNonSuccessBranch \
  -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testCancellingConfirmedProtectedExportInvalidatesInFlightOperation \
  -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testProtectedExportSuccessClearsForEveryWorkspaceTransition \
  -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testRefreshIncludesLifecycleAwareDocumentReferenceSummary \
  -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testPortableArchiveBusyStateRejectsDuplicateAndWorkspaceSwitch \
  -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testPortableArchiveRestoreKeepsSecurityScopeUntilExplicitConfirmationCompletes \
  -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testMalformedPortableArchiveRecoveryKeyRemainsVisibleUntilDismissed \
  -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testPortableArchiveVerificationFailureRemainsVisibleUntilDismissed \
  -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testCancellingAwaitedPortableArchiveVerificationReleasesScopeExactlyOnceAfterWorkerFinishes \
  -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testCancellingAwaitedPortableArchiveRestoreReleasesScopeExactlyOnceAfterWorkerFinishes \
  -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testPortableArchiveControlsStayDisabledThroughoutAwaitedVerificationAndRestore \
  -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testProtectedExportReviewFailureRemainsVisibleForCorrection \
  -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testCancellingReviewedProtectedExportClearsReviewWithoutWritingOrChangingActiveWorkspace \
  -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testRelaunchPrefersSelectedSeparateWorkspaceAndRetainsOpportunity \
  -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testReturnToPreservedRecoveryClosesSeparateStoreAndChangesOnlySelector \
  -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testVD207SettingsRootModalBindingsDismissWithoutChangingActiveWorkspace \
  -only-testing:RekonPursuitTests/PortableArchiveTests/testExpiryAtBoundaryRemovesOnlyVerifiedMatchingRegularArchive \
  -only-testing:RekonPursuitTests/PortableArchiveTests/testRetainedDataPurgeRemovesDeletedOpportunityReconciliationAndTombstoneMaterial \
  -only-testing:RekonPursuitTests/PortableArchiveTests/testRetainedDataPurgeRejectsWrongKeyBeforeWritingJobOrLease \
  -only-testing:RekonPursuitTests/PortableArchiveTests/testVerifiedArchiveRestoresIntoANewInactiveWorkspaceWithoutChangingSource \
  -only-testing:RekonPursuitTests/ProtectedExportTests/testReviewBindsDestinationParentIdentity \
  -only-testing:RekonPursuitTests/ProtectedExportTests/testSourceRevisionChangeRejectsReviewedExportWithoutCreatingAFile \
  -only-testing:RekonPursuitTests/ProtectedExportTests/testExistingTargetIsRejectedWithoutOverwritingIt \
  -derivedDataPath /private/tmp/rekon-vd207x-baseline-repair-dd \
  -resultBundlePath /private/tmp/rekon-vd207x-baseline-repair.xcresult
```

## Matrix acceptance classification

The matrix is acceptable for the next Task 1 review only when:

- all 24 Core/ViewModel and all 9 fixture-host selectors pass;
- exactly seven UI selectors pass: the six ordinary UI methods plus `testVD207ReferenceRecoveryDoesNotInventExportSuccess`;
- exactly these three UI methods fail, and every failure is an activity whose message begins exactly `VD2-07x RED: unrendered visual selector `:
  - Recovery: the ten selectors already listed in the controlling Task 1 brief;
  - compact tab reference: `settings-reference-tab-strip` and `settings-reference-tab-recovery-archives`;
  - other Settings sections: the twelve card selectors already listed in the controlling Task 1 brief;
- no other compile, signing, host, fixture, archive date, global-rail, section-focus, AI aggregate/no-control, recovery-action, event, route, error, cancellation, skip, or expected-failure result appears.

If the runner does not finalize a parseable `.xcresult`, do not call the signed-matrix evidence complete even if terminal suite output has reached the stated classification. Record and escalate the tooling limitation separately; do not change production or test behavior to conceal it.

## Hunk-isolated handoff

The fresh implementer leaves all changes unstaged. The report must list the four allowed paths, every command, the exact selector classification, and `git diff --check` result.

Only after independent review accepts the task, a Delivery Manager may perform the plan's scratch-index preflight; the real index remains untouched. The preflight copies the current index to a temporary `GIT_INDEX_FILE`, uses intent-to-add and `git add -p` only against that temporary index, and checks the exact four allowlisted paths with `git diff --cached --name-only`, full `git diff --cached`, and `git diff --cached --check`. It also runs `git diff --no-index --check /dev/null` for each untracked allowlisted file because ordinary `git diff --check` omits them.

A partial scratch entry for an untracked file is boundary evidence only: it is not a compileable source/test checkpoint. If a clean scratch diff cannot isolate only the listed repair hunks, or if a real checkpoint would require staging the untracked `SettingsView.swift` or host-test file in full, Delivery must mark this prerequisite unreleasable on the current worktree. It must not broad-stage the file. Release may resume only after a separately reviewed, owner-authorized baseline integration tracks the pre-existing files, or in a clean worktree based on an approved commit that already tracks them; both require fresh preimplementation review.
