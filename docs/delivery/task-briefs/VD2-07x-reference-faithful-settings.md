# VD2-07x — Reference-faithful Settings Task 1 brief

**Status:** Amended after Architecture, QA, and Security/privacy preimplementation NEEDS CHANGE decisions. The user-approved [VD2-08 accessibility deferral addendum](VD2-07x-vd208-accessibility-deferral-addendum.md) controls over conflicting Task 1/Task 2 matrix and release language: it defers the remaining local Settings keyboard-focus handoff and AI label/value accessibility regressions without deleting, skipping, or weakening their tests. No implementation is released by this brief. Delivery may release Task 1 only after fresh independent Architecture, QA, Security/privacy, TPM, and Delivery approvals are recorded.

## Controlling artifacts

- docs/superpowers/specs/2026-08-01-vd207-reference-faithful-recovery-screen-design.md
- docs/superpowers/plans/2026-08-01-vd207-reference-faithful-recovery-screen.md
- docs/delivery/reviews/VD2-07x-preimplementation-architecture-2026-08-01.md
- docs/delivery/reviews/VD2-07x-preimplementation-qa-2026-08-01.md
- docs/delivery/reviews/VD2-07x-preimplementation-security-privacy-2026-08-01.md
- docs/delivery/task-briefs/VD2-07-settings-information-architecture.md
- docs/delivery/task-briefs/VD2-07x-vd208-accessibility-deferral-addendum.md

## Objective, ownership, and scope

Task 1 creates the signed deterministic RED contract for the four-section reference and adds only the minimum model/root presentation seam needed to prove a protected-export success follows a real verified write. Task 1 does not render reference tabs, panels, responsive layout, action-card styling, or the success dialog; Task 2 alone renders them.

ContentView remains owner of WorkspaceViewModel, global route, recovery-key text, file panel, all sheets/alerts, destination selection, export error/cancel behavior, root success projection, and action dispatch. SettingsView owns only local selected/focused section state and display-safe values plus callbacks. It may not own a model, route, persistence, URL, key, bookmark, review, file panel, sheet, or invented success.

The four eventual local sections stay non-persisted:

| Section | Testable presentation boundary |
| --- | --- |
| Workspace | Local workspace, Active, Local only, recovery assurance, and disabled-or-existing preserved-workspace return. |
| Recovery & archives | Cyan selected tab, safe overview/catalogue/action cards, and real-write-only root success. |
| Document references | Aggregate counts/privacy only; no document metadata or actionable control. |
| AI & connections | Offline/unconfigured informational cards only; no setup, cloud, Gmail, Calendar, or network control. |

## Task 1 allowlist

| Path | Permitted authored hunk |
| --- | --- |
| RekonPursuit/WorkspaceViewModel.swift | Filename-only event, opaque token/invalidation, and local test-injected creation closure whose default calls the unchanged store API. |
| RekonPursuit/ContentView.swift | Root presentation projection and root-only success dismissal callback. No overlay or sheet close in Task 1. |
| RekonPursuit/SettingsView.swift | SettingsRootModalPresentation safe event projection and root binding helper only; no View body, card, selector, or dialog changes. |
| RekonPursuitTests/WorkspaceViewModelTests.swift | Four named event/root/token/workspace-transition contracts. |
| RekonPursuitUITests/RekonPursuitUITests.swift | Four named deterministic reference UI contracts. |
| RekonPursuitUITestHostTests/RekonPursuitUITestHostTests.swift | Extend the existing pure Settings recovery presentation-state test only. |

## Explicitly prohibited

- No project graph, app-shell/global-route, theme, fixture construction/identity, fixture host, launch parsing, signing, entitlement, product-test switch, or network change.
- No RekonPursuitCore change; no store/schema/migration/persistence/recovery/archive/export-review/export-write/purge/restore/expiry/document/AI/cloud/Gmail/Calendar behavior change.
- No fixture/default/demo success, launch input, environment transport, raw destination/key/review transport, or test UI control.
- No source, process argument, log, attachment, screenshot, report, or test name containing a recovery key, absolute destination path, document filename, hash, bookmark, MIME type, checksum, fingerprint, receipt, or document metadata.
- No dashboard, roadmap, progress, result bundle, generated artifact, unrelated dirty hunk, whole-file staging, reset, or reformat.

## Test-first contracts

### Reference UI RED rules

Add these exact methods:

~~~
func testVD207ReferenceRecoveryDashboardKeepsRailAndUsesCardComposition()
func testVD207ReferenceRecoveryDoesNotInventExportSuccess()
func testVD207ReferenceTabsKeepKeyboardSelectionAtCompactWidth()
func testVD207ReferenceOtherSettingsSectionsUseTruthfulInformationalCards()
~~~

Every method begins with a ready deterministic fixture, selected sidebar-settings rail, and current applicable panel/summary proof. Missing Task-2 visuals are recorded individually with XCTContext.runActivity and an assertion message beginning exactly VD2-07x RED: unrendered visual selector . No XCTExpectFailure, XCTSkip, generic timeout, fixture/route failure, focus query failure, or non-selector copy failure may count as RED. When any declared visual selector is absent, record every declared absence then return before Task-2 copy/control assertions. This is a failing test, not a skip.

The archive Recovery test must keep its existing fixed value exactly:

~~~
created=2025-05-06T12:00:00Z;expires=2025-06-05T12:00:00Z;lifecycle=Verified
~~~

Its only Task-1 RED selectors are:

~~~
settings-reference-tab-strip
settings-reference-tab-recovery-archives
settings-recovery-overview-card
settings-recovery-status-enrollment
settings-recovery-status-state
settings-recovery-archive-detail-card
settings-recovery-action-create
settings-recovery-action-purge
settings-recovery-action-restore
settings-recovery-protected-export
~~~

Before those RED checks it proves archive fixture readiness, existing Recovery panel/action IDs, active rail, fixed archive summary, and existing cancellation/error behavior. After Task 2 it additionally rejects fixture-document-hash, application/pdf, /private/, and recovery key in all Recovery labels/values.

Extend testVD207SettingsRecoveryPresentationPreservesBusyDisabledAndInactiveCandidateContracts without fixture, launch-parser, or host-routing changes. Construct only safe SettingsArchiveSummary values. It must assert not enrolled as Recovery key not set up / Set up a recovery key to protect this workspace.; enrolled/no archive as Recovery key enrolled / No verified archive available; and enrolled/verified archive as Recovery key enrolled / Verified archive available. Retain every existing create/export/purge/restore enabled/busy predicate, progress text, retained-purge status, and inactive-candidate assertion. Task 2 renders these values in settings-recovery-status-enrollment and settings-recovery-status-state.

The default-success test uses a ready archive fixture, proves the existing Recovery panel/rail, and asserts settings-protected-export-success-dialog is absent without starting export. It is green in Task 1 and Task 2.

The compact test uses populated with compact window size. It proves all four existing labels/selectors are present, hittable, and keyboard reachable:

~~~
settings-section-workspace
settings-section-recovery-archives
settings-section-document-references
settings-section-ai-connections
~~~

Starting at Recovery, it tabs to each non-selected section, asserts exactly Not selected; Keyboard focus, presses Space, asserts exactly Selected; Keyboard focus and matching panel, and asserts sidebar-settings remains selected. Only after those green baseline semantics does it record these Task-1 RED selectors:

~~~
settings-reference-tab-strip
settings-reference-tab-recovery-archives
~~~

After Task 2 the exact loop proves all four labeled reference tabs remain present/reachable in compact vertical layout.

The document-relink test first proves exact existing aggregate summary 0 available · 1 require relinking, current Document/AI panels, no button/link/menu button/text field/switch/checkbox descendants, and absence of fixture-resume.pdf, fixture-document-hash, application/pdf, and /private/ in labels/values. Its only Task-1 RED selectors are:

~~~
settings-workspace-overview-card
settings-workspace-recovery-card
settings-workspace-return-card
settings-document-overview-card
settings-document-available-card
settings-document-relink-card
settings-document-privacy-card
settings-ai-overview-card
settings-ai-assistant-card
settings-ai-email-calendar-card
settings-ai-cloud-card
settings-ai-privacy-card
~~~

After Task 2 it proves exact Workspace text Local workspace, Workspace status / Active, Storage / Local only, and Returning does not modify the active workspace. It requires No preserved workspace available; Disabled and no actionable return-card descendant where no separate workspace is active. It requires Document card facts Available / 0 and Needs relinking / 1 plus privacy wording that names and locations stay private. It requires AI activity / No activity recorded, Connection status / Offline, and exact AI assistant / Not configured, Email & calendar / Not connected, and Cloud sync / Not configured. The Document and AI no-control/no-metadata assertions remain active after every visual card exists.

### Green event, root, and token contracts

Add these exact async WorkspaceViewModelTests methods:

~~~
func testVerifiedProtectedExportPublishesSafeSuccessAndRootPresentationOnlyAfterRealWriting() async throws
func testProtectedExportSuccessRemainsNilForEveryNonSuccessBranch() async throws
func testCancellingConfirmedProtectedExportInvalidatesInFlightOperation() async throws
func testProtectedExportSuccessClearsForEveryWorkspaceTransition() async throws
~~~

The positive test creates an enrolled real store and active opportunity, uses the existing protectedExportDestination injection with one exact non-existent generated .rekonexport URL, and uses the production-default creation closure. It asserts nil before review/confirmation; after real write, it asserts output existence, event displayFilename equals destination.lastPathComponent, filename contains no slash, and active IDs are unchanged. It constructs SettingsRootModalPresentation from the event and proves it exposes only the safe filename and Selected local folder. Its simulated Done path calls only SettingsRootModalBindings.dismissProtectedExportSuccess { model.dismissProtectedExportSuccess() }, then proves event/root presentation are absent and output/active IDs are unchanged. It never passes a review, URL, key, receipt, archive row, document value, store, or model into Settings presentation.

The exhaustive nil test uses independent model/destination subcases. In every row it asserts protectedExportSuccess == nil, false root success presentation, applicable no-output/no-overwrite, and unchanged active IDs:

| Branch | Deterministic setup |
| --- | --- |
| Invalid confirmation/re-entry | Complete a valid review, call confirmProtectedExport with invalid entry. |
| Destination cancellation | Use protectedExportDestination: { nil }, then call review. |
| Review failure | Review against an already occupied generated output. |
| Stale/source-changed | Complete valid review, change real source revision, then confirm. |
| Write failure | Complete valid review, create occupied output before confirm, then preserve its bytes. |
| Fresh review | Create real success, start a new valid review, then assert prior event cleared before/during review. |
| Cancel | Create real success, call cancelProtectedExport, then assert prior event cleared. |

Use generated temporary artifacts only and remove only those generated artifacts. The existing Core no-overwrite/source-change tests supplement but never replace these event assertions.

For every invalid/review/write failure branch, assert the existing safe protectedExportErrorMessage is non-empty where the current flow exposes an error. The signed UI testVD207SettingsRecoveryRetainsArchiveTruthAndRootOwnedCancellation retains its protected-export-error accessibility label/value assertion and verifies success dialog absence after its error/cancel path.

The gated-cancel test adds a private GatedProtectedExportCreate actor with waitUntilStarted() and release() continuations. Construct the model with that creation closure, complete a valid real store review, wait until confirmation enters the gate, call existing model.cancelProtectedExport(), release the gate, then wait until isCreatingProtectedExport is false. It proves nil event, false root presentation, no gated output, cleared review/error, and unchanged active IDs. It does not claim a lower-layer write cancellation or alter its contract.

The every-workspace-transition test first creates a real success for a distinct model/destination before each case. It then proves nil event and false root presentation after every public route through apply or clearWorkspaceDerivedState: start normal replacement, createWorkspaceIfNeeded, createSeparateLocalWorkspace, returnToPreservedWorkspaceRecovery, successful restoreEncryptedBackup(from:), failed restoreEncryptedBackup(from:), chooseExistingWorkspaceFolder external replacement, chooseExistingWorkspaceFolder cancellation-to-recovery, closeWorkspace, and teardown. It preserves existing active-ID semantics per route and uses existing bookmark/separate-workspace fixtures only.

### Required event implementation

Add exactly one safe payload:

~~~
struct ProtectedExportSuccess: Equatable {
    let displayFilename: String
}
~~~

Keep a private opaque ProtectedExportOperationToken containing UUID. Store a current token next to protected-export state. invalidateProtectedExportOperation creates a new token and clears protectedExportSuccess.

Invalidate before every new review, invalid review input, destination cancellation, review failure, confirmation invalid input, confirmation failure, stale/early return, cancelProtectedExport, clearWorkspaceDerivedState, and every apply transition that replaces or leaves the store. Confirmation captures the current token before it starts. After the existing createProtectedExport call returns, the sole success assignment follows this guard:

~~~
guard self.protectedExportOperationToken == operationToken, self.store === store else { return }
self.protectedExportSuccess = .init(displayFilename: review.displayFilename)
~~~

A stale token/store completion can finish only its own busy bookkeeping. It must not publish success or mutate review/error/status. The model event is never persisted or transported to Settings. The injected creation closure defaults exactly to the existing store.createProtectedExport call and is never configured by fixture/launch/UI behavior.

SettingsRootModalPresentation gains only protectedExportSuccess, isProtectedExportSuccessPresented, protectedExportSuccessDisplayFilename, and fixed protectedExportSuccessDestinationLabel. SettingsRootModalBindings gains only dismissProtectedExportSuccess(dismissProtectedExportSuccess:). ContentView projects the event and exposes the root-only callback; Task 1 must not render the dialog or close the sheet.

## Exact signed Task 1 matrix

Run this command after the event implementation. The Task 2 matrix below repeats the same exact selector set; only its DerivedData/result paths differ.

~~~
xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit -configuration Debug -destination 'platform=macOS,arch=arm64'  \
  -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207ReferenceRecoveryDashboardKeepsRailAndUsesCardComposition  \
  -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207ReferenceRecoveryDoesNotInventExportSuccess  \
  -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207ReferenceTabsKeepKeyboardSelectionAtCompactWidth  \
  -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207ReferenceOtherSettingsSectionsUseTruthfulInformationalCards  \
  -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207SettingsSecondaryNavigationDefaultsToRecoveryAndKeepsGlobalRail  \
  -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207SettingsSecondaryNavigationIsKeyboardOperableAtCompactWidth  \
  -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207SettingsRecoveryRetainsArchiveTruthAndRootOwnedCancellation  \
  -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207SettingsDocumentAndAISectionsStayAggregateAndUnavailable  \
  -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207SettingsRelaunchKeepsFixtureTruthAndResetsLocalSelection  \
  -only-testing:RekonPursuitUITests/RekonPursuitUITests/testRecoveryFixtureShowsOnlyRecoveryActionsAndDoesNotOpenAWorkspace  \
  -only-testing:RekonPursuitUITestHostTests/RekonPursuitUITestHostTests/testVD202FixtureHostPublishesAProofThatLiveStoresAreUnavailable  \
  -only-testing:RekonPursuitUITestHostTests/RekonPursuitUITestHostTests/testVisualFixtureLaunchConfigurationIsExplicitAndIsolated  \
  -only-testing:RekonPursuitUITestHostTests/RekonPursuitUITestHostTests/testVisualFixtureConfigurationsUsePerRunTemporaryRoots  \
  -only-testing:RekonPursuitUITestHostTests/RekonPursuitUITestHostTests/testVisualFixtureUsesFixedTimeAndReducedMotionContracts  \
  -only-testing:RekonPursuitUITestHostTests/RekonPursuitUITestHostTests/testArchiveVisualFixtureConstructionCompletesOnTheMainActor  \
  -only-testing:RekonPursuitUITestHostTests/RekonPursuitUITestHostTests/testArchiveVisualFixtureSeedsVerifiedArchiveCatalogue  \
  -only-testing:RekonPursuitUITestHostTests/RekonPursuitUITestHostTests/testArchiveVisualFixtureUsesItsDeclaredTimeZoneAtTheCalendarBoundary  \
  -only-testing:RekonPursuitUITestHostTests/RekonPursuitUITestHostTests/testDocumentRelinkVisualFixtureContainsASelectedRelinkRequiredReference  \
  -only-testing:RekonPursuitUITestHostTests/RekonPursuitUITestHostTests/testVD207SettingsRecoveryPresentationPreservesBusyDisabledAndInactiveCandidateContracts  \
  -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testVerifiedProtectedExportPublishesSafeSuccessAndRootPresentationOnlyAfterRealWriting  \
  -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testProtectedExportSuccessRemainsNilForEveryNonSuccessBranch  \
  -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testCancellingConfirmedProtectedExportInvalidatesInFlightOperation  \
  -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testProtectedExportSuccessClearsForEveryWorkspaceTransition  \
  -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testRefreshIncludesLifecycleAwareDocumentReferenceSummary  \
  -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testPortableArchiveBusyStateRejectsDuplicateAndWorkspaceSwitch  \
  -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testPortableArchiveRestoreKeepsSecurityScopeUntilExplicitConfirmationCompletes  \
  -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testMalformedPortableArchiveRecoveryKeyRemainsVisibleUntilDismissed  \
  -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testPortableArchiveVerificationFailureRemainsVisibleUntilDismissed  \
  -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testCancellingAwaitedPortableArchiveVerificationReleasesScopeExactlyOnceAfterWorkerFinishes  \
  -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testCancellingAwaitedPortableArchiveRestoreReleasesScopeExactlyOnceAfterWorkerFinishes  \
  -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testPortableArchiveControlsStayDisabledThroughoutAwaitedVerificationAndRestore  \
  -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testProtectedExportReviewFailureRemainsVisibleForCorrection  \
  -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testCancellingReviewedProtectedExportClearsReviewWithoutWritingOrChangingActiveWorkspace  \
  -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testRelaunchPrefersSelectedSeparateWorkspaceAndRetainsOpportunity  \
  -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testReturnToPreservedRecoveryClosesSeparateStoreAndChangesOnlySelector  \
  -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testVD207SettingsRootModalBindingsDismissWithoutChangingActiveWorkspace  \
  -only-testing:RekonPursuitTests/PortableArchiveTests/testExpiryAtBoundaryRemovesOnlyVerifiedMatchingRegularArchive  \
  -only-testing:RekonPursuitTests/PortableArchiveTests/testRetainedDataPurgeRemovesDeletedOpportunityReconciliationAndTombstoneMaterial  \
  -only-testing:RekonPursuitTests/PortableArchiveTests/testRetainedDataPurgeRejectsWrongKeyBeforeWritingJobOrLease  \
  -only-testing:RekonPursuitTests/PortableArchiveTests/testVerifiedArchiveRestoresIntoANewInactiveWorkspaceWithoutChangingSource  \
  -only-testing:RekonPursuitTests/ProtectedExportTests/testReviewBindsDestinationParentIdentity  \
  -only-testing:RekonPursuitTests/ProtectedExportTests/testSourceRevisionChangeRejectsReviewedExportWithoutCreatingAFile  \
  -only-testing:RekonPursuitTests/ProtectedExportTests/testExistingTargetIsRejectedWithoutOverwritingIt  \
  -derivedDataPath /private/tmp/rekon-vd207x-task-1-red-dd  \
  -resultBundlePath /private/tmp/rekon-vd207x-task-1-red.xcresult
~~~

Expected: every named event/root/fixture/recovery/lower-layer selector executes once, passes, and has zero skip/expected-failure marker. The three named reference methods are the only failures, and their result activities are exclusively the declared unrendered visual selector messages. Compile, signing, host, fixture, rail, route, accessibility, baseline, or operation/event failure blocks Task 1.

## Exact signed Task 2 matrix

Run this exact command after rendering. It deliberately retains every Task 1 selector and changes only the paths.

~~~
xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit -configuration Debug -destination 'platform=macOS,arch=arm64'  \
  -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207ReferenceRecoveryDashboardKeepsRailAndUsesCardComposition  \
  -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207ReferenceRecoveryDoesNotInventExportSuccess  \
  -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207ReferenceTabsKeepKeyboardSelectionAtCompactWidth  \
  -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207ReferenceOtherSettingsSectionsUseTruthfulInformationalCards  \
  -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207SettingsSecondaryNavigationDefaultsToRecoveryAndKeepsGlobalRail  \
  -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207SettingsSecondaryNavigationIsKeyboardOperableAtCompactWidth  \
  -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207SettingsRecoveryRetainsArchiveTruthAndRootOwnedCancellation  \
  -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207SettingsDocumentAndAISectionsStayAggregateAndUnavailable  \
  -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207SettingsRelaunchKeepsFixtureTruthAndResetsLocalSelection  \
  -only-testing:RekonPursuitUITests/RekonPursuitUITests/testRecoveryFixtureShowsOnlyRecoveryActionsAndDoesNotOpenAWorkspace  \
  -only-testing:RekonPursuitUITestHostTests/RekonPursuitUITestHostTests/testVD202FixtureHostPublishesAProofThatLiveStoresAreUnavailable  \
  -only-testing:RekonPursuitUITestHostTests/RekonPursuitUITestHostTests/testVisualFixtureLaunchConfigurationIsExplicitAndIsolated  \
  -only-testing:RekonPursuitUITestHostTests/RekonPursuitUITestHostTests/testVisualFixtureConfigurationsUsePerRunTemporaryRoots  \
  -only-testing:RekonPursuitUITestHostTests/RekonPursuitUITestHostTests/testVisualFixtureUsesFixedTimeAndReducedMotionContracts  \
  -only-testing:RekonPursuitUITestHostTests/RekonPursuitUITestHostTests/testArchiveVisualFixtureConstructionCompletesOnTheMainActor  \
  -only-testing:RekonPursuitUITestHostTests/RekonPursuitUITestHostTests/testArchiveVisualFixtureSeedsVerifiedArchiveCatalogue  \
  -only-testing:RekonPursuitUITestHostTests/RekonPursuitUITestHostTests/testArchiveVisualFixtureUsesItsDeclaredTimeZoneAtTheCalendarBoundary  \
  -only-testing:RekonPursuitUITestHostTests/RekonPursuitUITestHostTests/testDocumentRelinkVisualFixtureContainsASelectedRelinkRequiredReference  \
  -only-testing:RekonPursuitUITestHostTests/RekonPursuitUITestHostTests/testVD207SettingsRecoveryPresentationPreservesBusyDisabledAndInactiveCandidateContracts  \
  -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testVerifiedProtectedExportPublishesSafeSuccessAndRootPresentationOnlyAfterRealWriting  \
  -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testProtectedExportSuccessRemainsNilForEveryNonSuccessBranch  \
  -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testCancellingConfirmedProtectedExportInvalidatesInFlightOperation  \
  -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testProtectedExportSuccessClearsForEveryWorkspaceTransition  \
  -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testRefreshIncludesLifecycleAwareDocumentReferenceSummary  \
  -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testPortableArchiveBusyStateRejectsDuplicateAndWorkspaceSwitch  \
  -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testPortableArchiveRestoreKeepsSecurityScopeUntilExplicitConfirmationCompletes  \
  -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testMalformedPortableArchiveRecoveryKeyRemainsVisibleUntilDismissed  \
  -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testPortableArchiveVerificationFailureRemainsVisibleUntilDismissed  \
  -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testCancellingAwaitedPortableArchiveVerificationReleasesScopeExactlyOnceAfterWorkerFinishes  \
  -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testCancellingAwaitedPortableArchiveRestoreReleasesScopeExactlyOnceAfterWorkerFinishes  \
  -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testPortableArchiveControlsStayDisabledThroughoutAwaitedVerificationAndRestore  \
  -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testProtectedExportReviewFailureRemainsVisibleForCorrection  \
  -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testCancellingReviewedProtectedExportClearsReviewWithoutWritingOrChangingActiveWorkspace  \
  -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testRelaunchPrefersSelectedSeparateWorkspaceAndRetainsOpportunity  \
  -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testReturnToPreservedRecoveryClosesSeparateStoreAndChangesOnlySelector  \
  -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testVD207SettingsRootModalBindingsDismissWithoutChangingActiveWorkspace  \
  -only-testing:RekonPursuitTests/PortableArchiveTests/testExpiryAtBoundaryRemovesOnlyVerifiedMatchingRegularArchive  \
  -only-testing:RekonPursuitTests/PortableArchiveTests/testRetainedDataPurgeRemovesDeletedOpportunityReconciliationAndTombstoneMaterial  \
  -only-testing:RekonPursuitTests/PortableArchiveTests/testRetainedDataPurgeRejectsWrongKeyBeforeWritingJobOrLease  \
  -only-testing:RekonPursuitTests/PortableArchiveTests/testVerifiedArchiveRestoresIntoANewInactiveWorkspaceWithoutChangingSource  \
  -only-testing:RekonPursuitTests/ProtectedExportTests/testReviewBindsDestinationParentIdentity  \
  -only-testing:RekonPursuitTests/ProtectedExportTests/testSourceRevisionChangeRejectsReviewedExportWithoutCreatingAFile  \
  -only-testing:RekonPursuitTests/ProtectedExportTests/testExistingTargetIsRejectedWithoutOverwritingIt  \
  -derivedDataPath /private/tmp/rekon-vd207x-task-2-green-dd  \
  -resultBundlePath /private/tmp/rekon-vd207x-task-2-green.xcresult
~~~

Expected: every named selector runs exactly once with zero skip and zero expected failure. Every non-deferred selector passes. The only carryable outcomes are the exact keyboard focus/Tab/Space and AI role/label/value observations classified by the VD2-08 addendum; they must be reported as executed failures with their exact assertion, observed role/label/value, platform evidence, and matching VD2-08 requirement. No missing control, selected rail, panel, layout, visible-copy, privacy, no-control, date, export, or other failure is carryable.

## Signed Task 2 focused companion procedure

The literal matrix above is unchanged and remains required. Run this separate, parseable companion result exactly once after the Task 2 rendering and test additions:

~~~
xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit -configuration Debug -destination 'platform=macOS,arch=arm64'  \
  -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207ReferenceTabsSelectByPointerAtCompactWidth  \
  -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207ReferenceAIVisualContentBoundary  \
  -derivedDataPath /private/tmp/rekon-vd207x-task-2-companion-dd  \
  -resultBundlePath /private/tmp/rekon-vd207x-task-2-companion.xcresult
~~~

The companion result must contain each named test once with zero failures, skips, and expected failures. It supplements and never replaces the literal matrix or the unchanged VD2-08 handoff tests.

`testVD207ReferenceTabsSelectByPointerAtCompactWidth` uses the compact `populated` fixture. Starting from the selected `sidebar-settings` rail, it taps each existing local selector — `settings-section-workspace`, `settings-section-recovery-archives`, `settings-section-document-references`, and `settings-section-ai-connections` — including the default Recovery selection. After each tap it proves the corresponding section panel, the tapped selector's selected state (without requiring a keyboard-focus value), and the still-selected global Settings rail. It attaches `VD2-07x-compact-workspace`, `VD2-07x-compact-recovery`, `VD2-07x-compact-document-references`, and `VD2-07x-compact-ai-connections`, respectively, immediately after the matching panel is rendered. It neither tabs nor presses Space, and it does not alter either deferred keyboard test.

`testVD207ReferenceAIVisualContentBoundary` uses the `document-relink` fixture at wide width. It proves the Document aggregate summary (`0 available · 1 require relinking`), its no-control/no-metadata boundary, then selects `settings-section-ai-connections` and proves the AI overview, assistant, email/calendar, cloud, and privacy cards with the approved truthful visible copy. It reasserts the AI no-actionable-control and no-metadata boundary and attaches `VD2-07x-wide-ai-connections` after the AI panel renders. It must not replace, change, or interpret the existing `Any` and `StaticText` assertions for `settings-ai-connections-unavailable`; those remain separate executed VD2-08 role/label/value evidence.

## Task 2 release and evidence requirements

Task 2 is blocked until Task 1 has a hunk-isolated checkpoint containing only allowed event/root/test hunks, the cached diff has been inspected, git diff --cached --check passes, and independent Architecture/QA/Security/privacy/TPM/Delivery approvals are recorded.

### Owner-approved visual correction

This correction is a Task 2 visual acceptance requirement, not a behavior,
data-boundary, or VD2-08 scope change. At wide width, the selected local
Settings tab keeps the reference cyan icon/text and bottom rule. At compact
width, the vertical local selector must have **no** selected bottom underline:
the selected complete labeled row instead has a restrained cyan-tinted rounded
selection surface with cyan icon/text. Pointer, selected/non-selected,
keyboard, and accessibility semantics are preserved.

The root-owned protected-export success dialog must closely match the supplied
reference: a centered elevated dark rounded panel, top emerald circular check,
heading, confirmation copy, a bordered two-row facts group (`Exported file` /
safe filename and `Saved to` / `Selected local folder`), a non-secret
recovery-key reminder with an emerald cue, and one full-width blue-to-violet
`Done` treatment. It receives only the existing safe filename and fixed local
folder label. It still appears only after a real successful export and Done
only dismisses the root presentation.

After green Task 2, retain these signed-host XCTest attachments outside the repository:

~~~
VD2-07x-wide-workspace
VD2-07x-wide-recovery
VD2-07x-wide-document-references
VD2-07x-wide-ai-connections
VD2-07x-compact-workspace
VD2-07x-compact-recovery
VD2-07x-compact-document-references
VD2-07x-compact-ai-connections
~~~

The Task 2 tests attach them with XCTAttachment screenshot and keepAlways after the section is selected/rendered. Export attachments using:

~~~
mkdir -p /private/tmp/rekon-vd207x-visual-evidence
xcrun xcresulttool get test-results summary --path /private/tmp/rekon-vd207x-task-2-green.xcresult
xcrun xcresulttool get test-results tests --path /private/tmp/rekon-vd207x-task-2-green.xcresult
xcrun xcresulttool export attachments --path /private/tmp/rekon-vd207x-task-2-green.xcresult --output-path /private/tmp/rekon-vd207x-visual-evidence/fixture-attachments
xcrun xcresulttool get test-results summary --path /private/tmp/rekon-vd207x-task-2-companion.xcresult
xcrun xcresulttool get test-results tests --path /private/tmp/rekon-vd207x-task-2-companion.xcresult
xcrun xcresulttool export attachments --path /private/tmp/rekon-vd207x-task-2-companion.xcresult --output-path /private/tmp/rekon-vd207x-visual-evidence/companion-attachments
find /private/tmp/rekon-vd207x-visual-evidence -type f -print
~~~

Open each image beside the approved reference, checking rail, wide cyan
selected rule, compact rounded cyan selected-row treatment with no underline,
hierarchy, cards, wide/compact response, disabled/unavailable treatment, and
the forbidden-content list. The review must include `VD2-07x-wide-recovery`
and `VD2-07x-compact-recovery` (or another named compact selection capture)
and contain only the app window—no desktop or other application window. A
tester then uses the signed normal Debug app and an ordinary enrolled local
workspace to complete a real existing export to an empty local destination.
Without recording the key, chooser, or path, capture the visible dialog at
exactly /private/tmp/rekon-vd207x-visual-evidence/VD2-07x-real-export-success.png,
crop it to the app window only, press Done, and prove active workspace IDs stay
unchanged. The dialog image must show the centered check, heading,
confirmation, two-row safe-facts group, reminder, and full-width Done, using
only the safe filename and `Selected local folder`. It is never committed.

## Dirty-baseline and checkpoint rules

1. Before edits record status, all allowlisted source/test diffs, and the project-file hash. Stage nothing.
2. Treat existing source/test hunks as unaccepted. Use git add -N only for an untracked SettingsView.swift when necessary, then git add -p for authored hunks.
3. A Task 1 checkpoint contains only allowlisted Task 1 hunks. It contains no project registration, rendered UI, fixture change, dashboard/roadmap/progress update, result bundle, or temporary artifact.
4. Before checkpoint inspect git diff --cached --name-only and full git diff --cached, then run git diff --cached --check. Any extra path, old hunk, whitespace error, generated output, or unreconciled baseline difference rejects the checkpoint.
5. Preserve each unique xcresult outside the repository. Review its summary/test list to prove every selector ran once with no skip; retain per-selector Task-1 RED versus green evidence.

VD2-08 and its accepted accessibility/recovery automation debts remain out of scope.
