# VD2-07 Settings Information Architecture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract Settings into a local four-section sub-navigation while preserving the existing app rail and all local recovery, archive, export, purge, restore, document, and AI behavior.

**Architecture:** `ContentView` remains the sole owner of the workspace model, global route, every Settings dialog/alert, recovery-key text, and action dispatch. The new `SettingsView` owns only ephemeral section selection and renders four focused views from display-safe values plus callbacks. No persistence, recovery, document, or network implementation changes are part of this work.

**Tech Stack:** Swift 6, SwiftUI, XCTest/XCUITest, Xcode signed Debug macOS builds, existing `REKON_UI_TEST_HOST` deterministic encrypted fixtures.

## Global Constraints

- The controlling design is `docs/superpowers/specs/2026-08-01-vd207-settings-information-architecture-design.md`; all retained recovery and privacy behavior is a hard baseline.
- `SettingsSection` is local `@State`, defaults to `.recoveryArchives`, is not an `AppDestination` or `DailyRoute`, and is never written to `UserDefaults`, `AppStorage`, a model, or a store.
- `ContentView` owns the `WorkspaceViewModel`, global navigation, all Settings sheets/alert, all recovery-key strings, and every action invocation. `SettingsView` and its child sections receive display-safe values plus closures only.
- Keep existing action labels, identifiers, disabled predicates, confirmation/cancel/error behavior, and inactive-restore semantics. In particular, retain `purge-retained-archive-data` when recovery is enrolled.
- Do not modify `WorkspaceViewModel.swift`, `RekonPursuitCore/**`, migrations, persistence, fixtures, launch argument parsing, app rail, entitlements, signing, network behavior, or recovery/export/archive/document/AI contracts.
- Document Settings may display only aggregate `DocumentReferenceSummary` counts. It must not render a document path, filename, bookmark, source hash, byte count, access action, or recovery key.
- AI & connections may state only the existing unconfigured/offline MVP fact. It must add no setting, default, consent, or control for AI, cloud, Gmail, Calendar, or network work.
- Use UUID-qualified isolated fixture sessions and the existing fixed clock. Never place a recovery-key value in source, fixture data, result attachment, screenshot, log, command output, or evidence.
- All builds and tests use the configured Debug signing identity. `CODE_SIGNING_ALLOWED=NO` is prohibited.
- Preserve the dirty worktree. Stage only files named in the current task after checking their exact diff.

## File Structure and Interfaces

- Create: `RekonPursuit/SettingsView.swift`
  - Defines `SettingsSection`, `SettingsArchiveSummary`, `SettingsRecoveryPresentation`, `SettingsView`, `WorkspaceSettingsSection`, `RecoveryArchivesSettingsSection`, `DocumentReferencesSettingsSection`, and `AIConnectionsSettingsSection`.
  - Contains no `WorkspaceViewModel`, store, file panel, recovery key, route, sheet, alert, or persistence call.
- Modify: `RekonPursuit/ContentView.swift:31-40,159,843-1169`
  - Moves the existing Settings sheet/alert state and the exact existing sheet/alert bodies from the former private `SettingsView` to `ContentView` without changing their wording or model calls.
  - Builds `SettingsRecoveryPresentation` from currently published model facts and passes named closures to `SettingsView`.
- Modify: `RekonPursuit.xcodeproj/project.pbxproj`
  - Adds one file reference and exactly one sources membership per app target.
- Modify: `RekonPursuitUITests/RekonPursuitUITests.swift`
  - Adds five focused `testVD207...` functions and no fixture/data transport mechanism.
- Modify: `RekonPursuitTests/WorkspaceViewModelTests.swift`
  - Adds only `testCancellingReviewedProtectedExportClearsReviewWithoutWritingOrChangingActiveWorkspace`; it creates a recovery key in local test memory but records no key value, fixture data, log, attachment, or screenshot.
- Modify: `RekonPursuitUITestHostTests/RekonPursuitUITestHostTests.swift`
  - Adds only `testVD207SettingsRecoveryPresentationPreservesBusyDisabledAndInactiveCandidateContracts`; it constructs display-safe presentation values and cannot alter fixture creation, launch parsing, test-host routing, or product behavior.

`SettingsView` consumes and produces these exact interfaces:

```swift
struct SettingsArchiveSummary: Identifiable, Equatable {
    let id: UUID
    let text: String
    let accessibilityValue: String
    init(archive: PortableArchiveCatalogueRow)
    private static func makeText(_ archive: PortableArchiveCatalogueRow) -> String
    private static func makeAccessibilityValue(_ archive: PortableArchiveCatalogueRow) -> String
    private static func lifecycleText(_ archive: PortableArchiveCatalogueRow) -> String
}

struct SettingsRecoveryPresentation: Equatable {
    let recoveryEnrollmentEnabled: Bool
    let archiveSummaries: [SettingsArchiveSummary]
    let isCreatingPortableArchive: Bool
    let isCreatingProtectedExport: Bool
    let isPurgingRetainedArchiveData: Bool
    let isRestoringPortableArchive: Bool
    let restoreProgressText: String?
    let retainedDataPurgeStatusText: String?
    let restoreReady: Bool

    var createPortableArchiveIsDisabled: Bool {
        isCreatingPortableArchive || isRestoringPortableArchive
    }
    var protectedExportIsDisabled: Bool {
        isCreatingProtectedExport || isCreatingPortableArchive || isRestoringPortableArchive
    }
    var retainedDataPurgeIsDisabled: Bool {
        archiveSummaries.isEmpty || isPurgingRetainedArchiveData || isCreatingPortableArchive || isRestoringPortableArchive
    }
    var portableArchiveRestoreIsDisabled: Bool {
        isCreatingPortableArchive || isRestoringPortableArchive
    }
    var archiveProgressText: String? {
        isCreatingPortableArchive ? "Creating and verifying archive…" : nil
    }
    var protectedExportProgressText: String? {
        isCreatingProtectedExport ? "Preparing protected export…" : nil
    }
    var retainedDataPurgeProgressText: String? {
        isPurgingRetainedArchiveData ? "Purging retained archive data…" : nil
    }
    var inactiveRestoreCandidateText: String? {
        restoreReady ? "Restored workspace ready. It remains inactive; a future workspace-open action is required." : nil
    }
}

struct SettingsView: View {
    let usingSeparateLocalWorkspace: Bool
    let recovery: SettingsRecoveryPresentation
    let documentReferenceSummary: DocumentReferenceSummary
    let returnToPreservedWorkspaceRecovery: () -> Void
    let beginRecoveryKeyEnrollment: () -> Void
    let presentArchiveCreation: () -> Void
    let presentProtectedExport: () -> Void
    let presentRetainedDataPurge: () -> Void
    let cancelRetainedDataPurge: () -> Void
    let choosePortableArchiveForRestore: () -> Void
}
```

The only `ContentView` actions supplied to that interface are existing actions:

```swift
returnToPreservedWorkspaceRecovery: { model.returnToPreservedWorkspaceRecovery() }
beginRecoveryKeyEnrollment: {
    generatedRecoveryKey = try? RecoveryKey.generate()
    recoveryKeyCopied = false
}
presentArchiveCreation: { isPresentingArchiveCreation = true }
presentProtectedExport: { isPresentingProtectedExport = true }
presentRetainedDataPurge: { isPresentingRetainedDataPurge = true }
cancelRetainedDataPurge: { model.cancelRetainedDataPurge() }
choosePortableArchiveForRestore: { model.choosePortableArchiveForRestore() }
```

---

### Task 1: Establish the focused Settings RED and baseline safety evidence

**Files:**

- Modify: `RekonPursuitUITests/RekonPursuitUITests.swift`
- Modify: `RekonPursuitTests/WorkspaceViewModelTests.swift`
- Read-only test evidence: `RekonPursuitCoreTests/PortableArchiveTests.swift`, `RekonPursuitCoreTests/ProtectedExportTests.swift`, and `RekonPursuitUITestHostTests/RekonPursuitUITestHostTests.swift`

**Consumes:** The approved VD2-07 design, current `launchApp(fixture:windowSize:session:reduceMotion:)`, current `tabToKeyboardFocus(_:in:maximumTabPresses:)`, and existing `populated`, `archive`, `document-relink`, and `recovery` fixtures.

**Produces:** Five named UI RED selectors that fail only because the new Settings local selectors/panels do not yet exist, one new protected-export cancellation/no-write GREEN regression, and recorded fixture-host/lower-layer GREEN baselines for every unchanged safety contract.

- [ ] **Step 1: Add the local-navigation and global-rail RED test**

Append this complete test method to `RekonPursuitUITests`:

```swift
@MainActor
func testVD207SettingsSecondaryNavigationDefaultsToRecoveryAndKeepsGlobalRail() {
    let app = launchApp(fixture: "populated")
    let rail = app.descendants(matching: .any)["sidebar-settings"]
    XCTAssertTrue(rail.waitForExistence(timeout: 5))
    rail.tap()
    XCTAssertTrue(rail.isSelected)
    XCTAssertTrue(app.descendants(matching: .any)["settings-secondary-navigation"].waitForExistence(timeout: 2))

    let recovery = app.buttons["settings-section-recovery-archives"]
    XCTAssertTrue(recovery.waitForExistence(timeout: 2))
    XCTAssertEqual(recovery.value as? String, "Selected")
    XCTAssertTrue(app.descendants(matching: .any)["settings-section-recovery-archives-panel"].exists)
    XCTAssertTrue(app.buttons["set-up-recovery-key"].exists)

    for (control, panel) in [
        ("settings-section-workspace", "settings-section-workspace-panel"),
        ("settings-section-document-references", "settings-section-document-references-panel"),
        ("settings-section-ai-connections", "settings-section-ai-connections-panel")
    ] {
        app.buttons[control].tap()
        XCTAssertTrue(app.descendants(matching: .any)[panel].waitForExistence(timeout: 2))
        XCTAssertEqual(app.buttons[control].value as? String, "Selected")
        XCTAssertTrue(rail.isSelected)
    }
}
```

- [ ] **Step 2: Add the compact keyboard RED test**

Append this complete test method, using the pre-existing semantic focus helper instead of coordinates or sleeps:

```swift
@MainActor
func testVD207SettingsSecondaryNavigationIsKeyboardOperableAtCompactWidth() {
    let app = launchApp(fixture: "populated", windowSize: "compact")
    app.descendants(matching: .any)["sidebar-settings"].tap()

    let document = app.buttons["settings-section-document-references"]
    XCTAssertTrue(document.waitForExistence(timeout: 2))
    XCTAssertTrue(document.isHittable)
    XCTAssertTrue(
        tabToKeyboardFocus(document, in: app, maximumTabPresses: 20),
        "The compact Settings selector must expose semantic keyboard focus."
    )
    app.typeKey(.space, modifierFlags: [])
    XCTAssertTrue(app.descendants(matching: .any)["settings-section-document-references-panel"].waitForExistence(timeout: 2))
    XCTAssertEqual(document.value as? String, "Selected")
    XCTAssertTrue(app.descendants(matching: .any)["sidebar-settings"].isSelected)
}
```

- [ ] **Step 3: Add the enrolled archive, root-modal cancellation, and privacy RED tests**

Append these two complete methods. They never type into a recovery-key field and attach no screenshot or text attachment, so no recovery-key value enters the test artifact. The archive test proves only the root-owned entry/cancel path: it does not attempt an archive create, protected-export review, purge, or restore operation.

```swift
@MainActor
func testVD207SettingsRecoveryRetainsArchiveTruthAndRootOwnedCancellation() {
    let app = launchApp(fixture: "archive")
    app.descendants(matching: .any)["sidebar-settings"].tap()

    XCTAssertTrue(app.descendants(matching: .any)["settings-section-recovery-archives-panel"].waitForExistence(timeout: 2))
    for identifier in ["create-portable-archive", "create-protected-export", "purge-retained-archive-data", "restore-portable-archive"] {
        XCTAssertTrue(app.buttons[identifier].exists, "Missing retained recovery action \(identifier).")
    }
    let summary = app.descendants(matching: .any)
        .matching(NSPredicate(format: "identifier BEGINSWITH %@", "settings-archive-summary-"))
        .firstMatch
    XCTAssertTrue(summary.waitForExistence(timeout: 2))
    XCTAssertTrue(summary.label.contains("Fixture Archive.rekonarchive"))
    XCTAssertTrue(summary.label.contains("Verified"))
    XCTAssertEqual(
        summary.value as? String,
        "created=2025-05-06T12:00:00Z;expires=2025-06-05T12:00:00Z;lifecycle=Verified"
    )
    XCTAssertTrue(app.buttons["create-portable-archive"].isEnabled)
    XCTAssertTrue(app.buttons["create-protected-export"].isEnabled)
    XCTAssertTrue(app.buttons["purge-retained-archive-data"].isEnabled)
    XCTAssertTrue(app.buttons["restore-portable-archive"].isEnabled)

    app.buttons["create-portable-archive"].tap()
    XCTAssertTrue(app.staticTexts["Create portable recovery archive"].waitForExistence(timeout: 2))
    app.buttons["Cancel"].tap()
    XCTAssertTrue(summary.waitForExistence(timeout: 2))
    XCTAssertEqual(summary.value as? String, "created=2025-05-06T12:00:00Z;expires=2025-06-05T12:00:00Z;lifecycle=Verified")

    app.buttons["create-protected-export"].tap()
    XCTAssertTrue(app.staticTexts["Export protected copy"].waitForExistence(timeout: 2))
    app.buttons["Cancel"].tap()
    XCTAssertTrue(summary.waitForExistence(timeout: 2))
    XCTAssertEqual(summary.value as? String, "created=2025-05-06T12:00:00Z;expires=2025-06-05T12:00:00Z;lifecycle=Verified")

    app.buttons["purge-retained-archive-data"].tap()
    XCTAssertTrue(app.staticTexts["Purge deleted data from retained archives"].waitForExistence(timeout: 2))
    app.buttons["Cancel"].tap()
    XCTAssertTrue(summary.waitForExistence(timeout: 2))
    XCTAssertEqual(summary.value as? String, "created=2025-05-06T12:00:00Z;expires=2025-06-05T12:00:00Z;lifecycle=Verified")
}

@MainActor
func testVD207SettingsDocumentAndAISectionsStayAggregateAndUnavailable() {
    let app = launchApp(fixture: "document-relink")
    app.descendants(matching: .any)["sidebar-settings"].tap()
    app.buttons["settings-section-document-references"].tap()

    let summary = app.descendants(matching: .any)["settings-document-reference-summary"]
    XCTAssertTrue(summary.waitForExistence(timeout: 2))
    XCTAssertEqual(summary.value as? String, "0 available · 1 require relinking")
    let documentPanel = app.descendants(matching: .any)["settings-section-document-references-panel"]
    for metadataSentinel in ["fixture-resume.pdf", "fixture-document-hash", "application/pdf"] {
        let matchingDescendant = documentPanel.descendants(matching: .any).matching(
            NSPredicate(
                format: "label CONTAINS[c] %@ OR value CONTAINS[c] %@",
                metadataSentinel,
                metadataSentinel
            )
        ).firstMatch
        XCTAssertFalse(matchingDescendant.exists, "Document panel disclosed \(metadataSentinel).")
    }
    XCTAssertEqual(documentPanel.descendants(matching: .button).count, 0)
    XCTAssertEqual(documentPanel.descendants(matching: .menuButton).count, 0)
    XCTAssertEqual(documentPanel.descendants(matching: .link).count, 0)
    XCTAssertEqual(documentPanel.descendants(matching: .checkBox).count, 0)
    XCTAssertEqual(documentPanel.descendants(matching: .switch).count, 0)
    XCTAssertEqual(documentPanel.descendants(matching: .textField).count, 0)

    app.buttons["settings-section-ai-connections"].tap()
    let aiPanel = app.descendants(matching: .any)["settings-section-ai-connections-panel"]
    XCTAssertTrue(aiPanel.waitForExistence(timeout: 2))
    let unavailable = app.descendants(matching: .any)["settings-ai-connections-unavailable"]
    XCTAssertTrue(unavailable.waitForExistence(timeout: 2))
    XCTAssertTrue(unavailable.label.contains("No AI requests"))
    XCTAssertTrue(unavailable.label.contains("Gmail"))
    XCTAssertTrue(unavailable.label.contains("Calendar"))
    XCTAssertEqual(aiPanel.descendants(matching: .button).count, 0)
    XCTAssertEqual(aiPanel.descendants(matching: .menuButton).count, 0)
    XCTAssertEqual(aiPanel.descendants(matching: .link).count, 0)
    XCTAssertEqual(aiPanel.descendants(matching: .checkBox).count, 0)
    XCTAssertEqual(aiPanel.descendants(matching: .switch).count, 0)
    XCTAssertEqual(aiPanel.descendants(matching: .textField).count, 0)
}
```

- [ ] **Step 4: Add the selected-active-workspace relaunch RED test**

Append the following method. It uses one explicit UUID-qualified session, opens a ready local fixture, terminates it, and relaunches exactly the same fixture/session. The only state it changes is the non-persisted local Settings selection before termination; it creates no archive, export, purge, restore, document, or recovery-key value.

```swift
@MainActor
func testVD207SettingsRelaunchKeepsFixtureTruthAndResetsLocalSelection() {
    let session = "ui-shell-\(UUID().uuidString)"
    var app = launchApp(fixture: "document-relink", session: session)
    defer {
        if app.state != .notRunning {
            app.terminate()
        }
        Self.removeFixtureSessionFromTestProcess(session)
    }

    app.descendants(matching: .any)["sidebar-settings"].tap()
    app.buttons["settings-section-document-references"].tap()
    let documentSummary = app.descendants(matching: .any)["settings-document-reference-summary"]
    XCTAssertTrue(documentSummary.waitForExistence(timeout: 2))
    let preRelaunchSummary = documentSummary.value as? String
    XCTAssertEqual(preRelaunchSummary, "0 available · 1 require relinking")

    app.terminate()
    app = launchApp(fixture: "document-relink", session: session)
    app.descendants(matching: .any)["sidebar-settings"].tap()
    let recovery = app.buttons["settings-section-recovery-archives"]
    XCTAssertTrue(recovery.waitForExistence(timeout: 2))
    XCTAssertEqual(recovery.value as? String, "Selected")
    XCTAssertTrue(app.descendants(matching: .any)["settings-section-recovery-archives-panel"].exists)

    app.buttons["settings-section-document-references"].tap()
    XCTAssertTrue(documentSummary.waitForExistence(timeout: 2))
    XCTAssertEqual(documentSummary.value as? String, preRelaunchSummary)
}
```

- [ ] **Step 5: Add the reviewed protected-export cancellation/no-write GREEN regression**

Append this complete unit test to `WorkspaceViewModelTests`. It proves the state after review exists, uses only an in-memory generated key, and asserts the active workspace and destination are unchanged after cancellation. Do not print `recoveryKey.displayValue`, attach it, or use it in a fixture.

```swift
func testCancellingReviewedProtectedExportClearsReviewWithoutWritingOrChangingActiveWorkspace() async throws {
    let store = try makeStore()
    let recoveryKey = try RecoveryKey.generate()
    try store.enroll(recoveryKey: recoveryKey)
    let activeOpportunity = try store.create(CreateOpportunity(title: "Protected export cancellation", company: "Rekon Labs"))
    let destination = FileManager.default.temporaryDirectory
        .appendingPathComponent("cancel-reviewed-export-\(UUID().uuidString).rekonexport")
    defer { try? FileManager.default.removeItem(at: destination) }
    let model = WorkspaceViewModel(
        openWorkspace: { .ready(store) },
        createWorkspace: { store },
        protectedExportDestination: { destination },
        separateLocalWorkspace: .disabledForTesting
    )
    model.start()
    let activeIDsBeforeCancellation = model.opportunities.map(\.id)

    model.reviewProtectedExport(reentry: recoveryKey.displayValue)
    while model.isCreatingProtectedExport { await Task.yield() }
    XCTAssertNotNil(model.protectedExportReview)
    XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))

    model.cancelProtectedExport()

    XCTAssertNil(model.protectedExportReview)
    XCTAssertNil(model.protectedExportErrorMessage)
    XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
    XCTAssertTrue(model.workspaceReady)
    XCTAssertEqual(model.opportunities.map(\.id), activeIDsBeforeCancellation)
    XCTAssertEqual(model.opportunities.first?.id, activeOpportunity.id)
}
```

- [ ] **Step 6: Run the signed RED and unchanged fixture/lower-layer baselines**

Run the exact focused command; do not disable signing and do not change the fixture session manually:

```bash
xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
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
  -only-testing:RekonPursuitTests/PortableArchiveTests/testExpiryAtBoundaryRemovesOnlyVerifiedMatchingRegularArchive \
  -only-testing:RekonPursuitTests/PortableArchiveTests/testRetainedDataPurgeRemovesDeletedOpportunityReconciliationAndTombstoneMaterial \
  -only-testing:RekonPursuitTests/PortableArchiveTests/testRetainedDataPurgeRejectsWrongKeyBeforeWritingJobOrLease \
  -only-testing:RekonPursuitTests/PortableArchiveTests/testVerifiedArchiveRestoresIntoANewInactiveWorkspaceWithoutChangingSource \
  -only-testing:RekonPursuitTests/ProtectedExportTests/testReviewBindsDestinationParentIdentity \
  -only-testing:RekonPursuitTests/ProtectedExportTests/testSourceRevisionChangeRejectsReviewedExportWithoutCreatingAFile \
  -only-testing:RekonPursuitTests/ProtectedExportTests/testExistingTargetIsRejectedWithoutOverwritingIt \
  -derivedDataPath /private/tmp/rekon-vd207-task-1-red-dd \
  -resultBundlePath /private/tmp/rekon-vd207-task-1-red.xcresult
```

Expected: every named fixture-host, recovery-only, and lower-layer selector passes once with no skip; the five new UI methods reach the current Settings screen and fail only for the absent `settings-*` selector/panel identifiers. A compile, signing, fixture-launch, rail, or unrelated existing-test failure stops the task and is not RED evidence.

- [ ] **Step 7: Capture the Task 1 evidence and make an isolated checkpoint**

```bash
xcrun xcresulttool get test-results summary --path /private/tmp/rekon-vd207-task-1-red.xcresult
xcrun xcresulttool get test-results tests --path /private/tmp/rekon-vd207-task-1-red.xcresult
git diff -- RekonPursuitUITests/RekonPursuitUITests.swift
git diff --check
```

Expected: save the `xcresulttool` summary and tests output with a per-selector record: every named baseline selector occurs once as passed; every new UI selector occurs once as the allowed panel/selector-absence RED; none is skipped. This repository is intentionally dirty, including the UI-test and unit-test paths, so do not stage either whole file in the shared worktree. Delivery must issue a clean or hunk-isolated implementation checkpoint that stages only the five `testVD207...` UI methods and `testCancellingReviewedProtectedExportClearsReviewWithoutWritingOrChangingActiveWorkspace`, verifies `git diff --cached --check`, and commits it as `test: define VD2-07 Settings presentation contracts`. A fresh independent QA verifier must accept the evidence before Task 2 is released.

In the Delivery-issued checkpoint, run these exact commit commands after both targeted test-file diffs show only the five new UI methods and the one new unit test:

```bash
git add RekonPursuitUITests/RekonPursuitUITests.swift
git add RekonPursuitTests/WorkspaceViewModelTests.swift
git diff --cached --check
git diff --cached --stat
git commit -m "test: define VD2-07 Settings presentation contracts"
```

---

### Task 2: Extract the Settings presentation while retaining ContentView flow ownership

**Files:**

- Create: `RekonPursuit/SettingsView.swift`
- Modify: `RekonPursuit/ContentView.swift`
- Modify: `RekonPursuit.xcodeproj/project.pbxproj`
- Test: `RekonPursuitUITests/RekonPursuitUITests.swift`
- Test: `RekonPursuitUITestHostTests/RekonPursuitUITestHostTests.swift`

**Consumes:** Task 1 accepted RED, the `SettingsRecoveryPresentation` interface above, existing `ContentView` Settings state/sheets at lines 843-1126, and the unchanged `WorkspaceViewModel` action API.

**Produces:** A presentation-only Settings view with four local sections; ContentView-owned recovery/export/purge/restore dialogs; and a single new source file compiled by both app targets.

- [ ] **Step 1: Preserve the project-file baseline before source registration**

```bash
shasum -a 256 RekonPursuit.xcodeproj/project.pbxproj
git hash-object RekonPursuit.xcodeproj/project.pbxproj
git diff -- RekonPursuit.xcodeproj/project.pbxproj
```

Expected: record the dirty-worktree baseline without staging or normalizing unrelated project entries. Task 2 is blocked if the implementer cannot isolate the six additions in Step 4 from unrelated project changes.

- [ ] **Step 2: Create `SettingsView.swift` with display-safe state and local selection only**

Create the new file with the exact data boundary below. `SettingsArchiveSummary.init(archive:)` may read only `archiveID`, `displayFilename`, `createdAt`, `expiresAt`, `verificationState`, and `lifecycleState`, and it must return the existing catalogue wording. It must not carry checksum or signing-fingerprint bytes into a view property.

```swift
import Foundation
import SwiftUI

private enum SettingsSection: CaseIterable, Hashable {
    case workspace
    case recoveryArchives
    case documentReferences
    case aiConnections
}

struct SettingsArchiveSummary: Identifiable, Equatable {
    let id: UUID
    let text: String
    let accessibilityValue: String
    init(archive: PortableArchiveCatalogueRow) {
        id = archive.archiveID
        text = SettingsArchiveSummary.makeText(archive)
        accessibilityValue = SettingsArchiveSummary.makeAccessibilityValue(archive)
    }

    private static func lifecycleText(_ archive: PortableArchiveCatalogueRow) -> String {
        switch archive.lifecycleState {
        case .verified: return archive.verificationState
        case .expiredPendingRemoval, .expiredPrepared: return "Expired — removal pending"
        case .expiredRetryable: return "Expired — retry pending"
        case .expiredBlocked: return "Expired — removal blocked"
        case .expiredMissing: return "Expired — file unavailable"
        case .expiredManualRemovalRequired: return "Expired — manual removal required"
        case .expiredQuarantined: return "Expired — quarantined"
        }
    }

    private static func makeText(_ archive: PortableArchiveCatalogueRow) -> String {
        "\(archive.displayFilename) · created \(archive.createdAt.formatted(date: .abbreviated, time: .shortened)) · expires \(archive.expiresAt.formatted(date: .abbreviated, time: .omitted)) · \(lifecycleText(archive))"
    }

    private static func makeAccessibilityValue(_ archive: PortableArchiveCatalogueRow) -> String {
        let formatter = ISO8601DateFormatter()
        return "created=\(formatter.string(from: archive.createdAt));expires=\(formatter.string(from: archive.expiresAt));lifecycle=\(lifecycleText(archive))"
    }
}

struct SettingsRecoveryPresentation: Equatable {
    let recoveryEnrollmentEnabled: Bool
    let archiveSummaries: [SettingsArchiveSummary]
    let isCreatingPortableArchive: Bool
    let isCreatingProtectedExport: Bool
    let isPurgingRetainedArchiveData: Bool
    let isRestoringPortableArchive: Bool
    let restoreProgressText: String?
    let retainedDataPurgeStatusText: String?
    let restoreReady: Bool

    var createPortableArchiveIsDisabled: Bool {
        isCreatingPortableArchive || isRestoringPortableArchive
    }
    var protectedExportIsDisabled: Bool {
        isCreatingProtectedExport || isCreatingPortableArchive || isRestoringPortableArchive
    }
    var retainedDataPurgeIsDisabled: Bool {
        archiveSummaries.isEmpty || isPurgingRetainedArchiveData || isCreatingPortableArchive || isRestoringPortableArchive
    }
    var portableArchiveRestoreIsDisabled: Bool {
        isCreatingPortableArchive || isRestoringPortableArchive
    }
    var archiveProgressText: String? {
        isCreatingPortableArchive ? "Creating and verifying archive…" : nil
    }
    var protectedExportProgressText: String? {
        isCreatingProtectedExport ? "Preparing protected export…" : nil
    }
    var retainedDataPurgeProgressText: String? {
        isPurgingRetainedArchiveData ? "Purging retained archive data…" : nil
    }
    var inactiveRestoreCandidateText: String? {
        restoreReady ? "Restored workspace ready. It remains inactive; a future workspace-open action is required." : nil
    }
}

struct SettingsView: View {
    let usingSeparateLocalWorkspace: Bool
    let recovery: SettingsRecoveryPresentation
    let documentReferenceSummary: DocumentReferenceSummary
    let returnToPreservedWorkspaceRecovery: () -> Void
    let beginRecoveryKeyEnrollment: () -> Void
    let presentArchiveCreation: () -> Void
    let presentProtectedExport: () -> Void
    let presentRetainedDataPurge: () -> Void
    let cancelRetainedDataPurge: () -> Void
    let choosePortableArchiveForRestore: () -> Void
    @State private var selectedSection: SettingsSection = .recoveryArchives
}
```

Implement the selector with four `Button` controls, not a global `NavigationSplitView` or `TabView`. Each button must set `selectedSection`, use its exact `settings-section-*` identifier, and set `accessibilityValue(selectedSection == section ? "Selected" : "Not selected")`. Wrap it in `settings-secondary-navigation`. Switch only the local section content:

```swift
switch selectedSection {
case .workspace:
    WorkspaceSettingsSection(
        usingSeparateLocalWorkspace: usingSeparateLocalWorkspace,
        returnToPreservedWorkspaceRecovery: returnToPreservedWorkspaceRecovery
    )
    .accessibilityIdentifier("settings-section-workspace-panel")
case .recoveryArchives:
    RecoveryArchivesSettingsSection(
        recovery: recovery,
        beginRecoveryKeyEnrollment: beginRecoveryKeyEnrollment,
        presentArchiveCreation: presentArchiveCreation,
        presentProtectedExport: presentProtectedExport,
        presentRetainedDataPurge: presentRetainedDataPurge,
        cancelRetainedDataPurge: cancelRetainedDataPurge,
        choosePortableArchiveForRestore: choosePortableArchiveForRestore
    )
    .accessibilityIdentifier("settings-section-recovery-archives-panel")
case .documentReferences:
    DocumentReferencesSettingsSection(summary: documentReferenceSummary)
        .accessibilityIdentifier("settings-section-document-references-panel")
case .aiConnections:
    AIConnectionsSettingsSection()
        .accessibilityIdentifier("settings-section-ai-connections-panel")
}
```

Use `ViewThatFits(in: .horizontal)` for the selector: an `HStack` first and a `VStack` fallback. Keep the content inside the existing `ScrollView`, 28-point outer padding, and 920-point readable maximum width. The compact fallback must expose the same four semantic controls; it does not create a compact-only route.

Set the fixed accessibility values and state identifiers used by the focused UI tests exactly as follows; no identifier or value contains a document or recovery-key value:

```swift
Text(summary.text)
    .accessibilityIdentifier("settings-archive-summary-\(summary.id.uuidString)")
    .accessibilityLabel(summary.text)
    .accessibilityValue(summary.accessibilityValue)

Text(documentReferenceSummaryText)
    .accessibilityIdentifier("settings-document-reference-summary")
    .accessibilityLabel("Document reference summary")
    .accessibilityValue(documentReferenceSummaryText)

Text("The local Activity & AI ledger is read-only and empty in this MVP. No AI requests, costs, model runtime, cloud connection, Gmail, or Calendar integration is configured.")
    .accessibilityIdentifier("settings-ai-connections-unavailable")
    .accessibilityLabel("The local Activity & AI ledger is read-only and empty in this MVP. No AI requests, costs, model runtime, cloud connection, Gmail, or Calendar integration is configured.")
```

Render every retained recovery state through the computed presentation values,
not a new model or action path. Preserve the existing button identifiers and
use the exact disabled values below. The three added progress/status
identifiers carry only fixed status copy; they expose no recovery-key,
document, archive checksum, or fingerprint data.

```swift
Button("Create recovery archive", action: presentArchiveCreation)
    .accessibilityIdentifier("create-portable-archive")
    .disabled(recovery.createPortableArchiveIsDisabled)
Button("Export protected copy", action: presentProtectedExport)
    .accessibilityIdentifier("create-protected-export")
    .disabled(recovery.protectedExportIsDisabled)
Button("Purge deleted data from retained archives", action: presentRetainedDataPurge)
    .accessibilityIdentifier("purge-retained-archive-data")
    .disabled(recovery.retainedDataPurgeIsDisabled)
Button("Restore portable archive", action: choosePortableArchiveForRestore)
    .accessibilityIdentifier("restore-portable-archive")
    .disabled(recovery.portableArchiveRestoreIsDisabled)
if let text = recovery.archiveProgressText {
    ProgressView(text).accessibilityIdentifier("portable-archive-progress")
}
if let text = recovery.protectedExportProgressText {
    ProgressView(text).accessibilityIdentifier("protected-export-progress")
}
if let text = recovery.retainedDataPurgeProgressText {
    ProgressView(text).accessibilityIdentifier("retained-data-purge-progress")
}
if let text = recovery.restoreProgressText {
    ProgressView(text).accessibilityIdentifier("portable-archive-restore-progress")
}
if let text = recovery.retainedDataPurgeStatusText {
    Text(text).accessibilityIdentifier("retained-data-purge-status")
}
if let text = recovery.inactiveRestoreCandidateText {
    Text(text).accessibilityIdentifier("portable-archive-inactive-candidate")
}
```

- [ ] **Step 3: Move Settings state and all dialogs to `ContentView` without changing an action**

Add the ten existing Settings state properties alongside the current `@State` declarations in `ContentView`; remove them from the old private view. Replace the former route case with this exact dependency injection shape:

```swift
case .settings:
    SettingsView(
        usingSeparateLocalWorkspace: model.usingSeparateLocalWorkspace,
        recovery: settingsRecoveryPresentation,
        documentReferenceSummary: model.documentReferenceSummary,
        returnToPreservedWorkspaceRecovery: { model.returnToPreservedWorkspaceRecovery() },
        beginRecoveryKeyEnrollment: {
            generatedRecoveryKey = try? RecoveryKey.generate()
            recoveryKeyCopied = false
        },
        presentArchiveCreation: { isPresentingArchiveCreation = true },
        presentProtectedExport: { isPresentingProtectedExport = true },
        presentRetainedDataPurge: { isPresentingRetainedDataPurge = true },
        cancelRetainedDataPurge: { model.cancelRetainedDataPurge() },
        choosePortableArchiveForRestore: { model.choosePortableArchiveForRestore() }
    )
```

Define `settingsRecoveryPresentation` in `ContentView` from its existing published model facts. Map the catalogue through `SettingsArchiveSummary(archive:)`; map the current `RetainedDataPurgeStatus` with the exact existing five-case text; derive `restoreReady` only with `if case .ready = model.portableArchiveRestoreState`; and map restore progress to `"Verifying portable archive…"` only for `.verifying`, `"Restore in progress…"` only for `.restoring`, or `nil` for every other state. Do not pass `PortableArchiveCatalogueRow` itself, a document, a recovery key, a store, `PortableArchiveRestoreState`, or the model to a focused section.

Move the exact existing recovery-key, archive-creation, protected-export, retained-purge, portable-restore sheets and the portable-restore failure alert from the old private Settings view to the modifier chain on `ContentView`. Preserve their existing `Binding` setters, `model.enrollRecoveryKey`, `model.createPortableArchive`, `model.reviewProtectedExport`, `model.confirmProtectedExport`, `model.cancelProtectedExport`, `model.purgeRetainedArchiveData`, `model.choosePortableArchiveForRestore`, `model.verifyPortableArchiveForRestore`, `model.confirmPortableArchiveRestore`, `model.cancelPortableArchiveRestore`, and `model.dismissPortableArchiveRestoreFailure` calls verbatim. Delete the entire private `SettingsView` declaration from `ContentView` only after those modifiers compile there.

- [ ] **Step 4: Add the pure recovery-presentation busy/disabled/ready contract**

After `SettingsView.swift` compiles in `RekonPursuitUITestHost`, append this
test to `RekonPursuitUITestHostTests`. This is a presentation seam, not a
fixture or product switch: it supplies only a safe archive display summary and
asserts the exact derived values that `RecoveryArchivesSettingsSection` renders
with the named identifiers above. It must not open a store, launch an app,
generate a recovery key, or attach evidence.

```swift
@MainActor
func testVD207SettingsRecoveryPresentationPreservesBusyDisabledAndInactiveCandidateContracts() {
    let archive = PortableArchiveCatalogueRow(
        archiveID: UUID(),
        displayFilename: "Archive.rekonarchive",
        formatVersion: 1,
        createdAt: VisualFixtureLaunchConfiguration.fixedNow,
        expiresAt: VisualFixtureLaunchConfiguration.fixedNow.addingTimeInterval(30 * 24 * 60 * 60),
        verificationState: "Verified",
        ciphertextChecksum: Data(repeating: 0, count: 32),
        signingKeyFingerprint: Data(repeating: 0, count: 32)
    )
    let summary = SettingsArchiveSummary(archive: archive)
    func makePresentation(
        summaries: [SettingsArchiveSummary] = [summary],
        creatingArchive: Bool = false,
        creatingExport: Bool = false,
        purging: Bool = false,
        restoring: Bool = false,
        restoreProgress: String? = nil,
        purgeStatus: String? = nil,
        restoreReady: Bool = false
    ) -> SettingsRecoveryPresentation {
        SettingsRecoveryPresentation(
            recoveryEnrollmentEnabled: true,
            archiveSummaries: summaries,
            isCreatingPortableArchive: creatingArchive,
            isCreatingProtectedExport: creatingExport,
            isPurgingRetainedArchiveData: purging,
            isRestoringPortableArchive: restoring,
            restoreProgressText: restoreProgress,
            retainedDataPurgeStatusText: purgeStatus,
            restoreReady: restoreReady
        )
    }

    let noArchive = makePresentation(summaries: [])
    XCTAssertFalse(noArchive.createPortableArchiveIsDisabled)
    XCTAssertFalse(noArchive.protectedExportIsDisabled)
    XCTAssertTrue(noArchive.retainedDataPurgeIsDisabled)
    XCTAssertFalse(noArchive.portableArchiveRestoreIsDisabled)

    let creatingArchive = makePresentation(creatingArchive: true)
    XCTAssertTrue(creatingArchive.createPortableArchiveIsDisabled)
    XCTAssertTrue(creatingArchive.protectedExportIsDisabled)
    XCTAssertTrue(creatingArchive.retainedDataPurgeIsDisabled)
    XCTAssertTrue(creatingArchive.portableArchiveRestoreIsDisabled)
    XCTAssertEqual(creatingArchive.archiveProgressText, "Creating and verifying archive…")

    let creatingExport = makePresentation(creatingExport: true)
    XCTAssertFalse(creatingExport.createPortableArchiveIsDisabled)
    XCTAssertTrue(creatingExport.protectedExportIsDisabled)
    XCTAssertFalse(creatingExport.retainedDataPurgeIsDisabled)
    XCTAssertFalse(creatingExport.portableArchiveRestoreIsDisabled)
    XCTAssertEqual(creatingExport.protectedExportProgressText, "Preparing protected export…")

    let purging = makePresentation(purging: true, purgeStatus: "The last retained-data purge was incomplete. Review retained archives before retrying.")
    XCTAssertFalse(purging.createPortableArchiveIsDisabled)
    XCTAssertFalse(purging.protectedExportIsDisabled)
    XCTAssertTrue(purging.retainedDataPurgeIsDisabled)
    XCTAssertFalse(purging.portableArchiveRestoreIsDisabled)
    XCTAssertEqual(purging.retainedDataPurgeProgressText, "Purging retained archive data…")
    XCTAssertEqual(purging.retainedDataPurgeStatusText, "The last retained-data purge was incomplete. Review retained archives before retrying.")

    let verifying = makePresentation(restoring: true, restoreProgress: "Verifying portable archive…")
    XCTAssertTrue(verifying.createPortableArchiveIsDisabled)
    XCTAssertTrue(verifying.protectedExportIsDisabled)
    XCTAssertTrue(verifying.retainedDataPurgeIsDisabled)
    XCTAssertTrue(verifying.portableArchiveRestoreIsDisabled)
    XCTAssertEqual(verifying.restoreProgressText, "Verifying portable archive…")

    let restoring = makePresentation(restoring: true, restoreProgress: "Restore in progress…")
    XCTAssertEqual(restoring.restoreProgressText, "Restore in progress…")
    XCTAssertNil(restoring.inactiveRestoreCandidateText)

    let ready = makePresentation(restoreReady: true)
    XCTAssertEqual(
        ready.inactiveRestoreCandidateText,
        "Restored workspace ready. It remains inactive; a future workspace-open action is required."
    )
}
```

- [ ] **Step 5: Register only the new source file in both existing app targets**

Use these currently unused PBX identifiers and make only these six structural additions:

```text
100000000000000000000080 /* SettingsView.swift in Sources */ = {isa = PBXBuildFile; fileRef = 200000000000000000000078 /* SettingsView.swift */; };
100000000000000000000081 /* SettingsView.swift in Sources */ = {isa = PBXBuildFile; fileRef = 200000000000000000000078 /* SettingsView.swift */; };
200000000000000000000078 /* SettingsView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = SettingsView.swift; sourceTree = "<group>"; };
```

Add the file reference to the existing `RekonPursuit` group beside `ContactsView.swift`. Add build file `...080` once to the `RekonPursuit` `900000000000000000000001` sources phase and build file `...081` once to the `RekonPursuitUITestHost` `900000000000000000000007` sources phase. Do not change a build setting, signing setting, target, dependency, framework, resource, scheme, or source membership other than those two entries.

- [ ] **Step 6: Run the focused GREEN and inspect the exact production diff**

```bash
xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
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
  -only-testing:RekonPursuitTests/PortableArchiveTests/testExpiryAtBoundaryRemovesOnlyVerifiedMatchingRegularArchive \
  -only-testing:RekonPursuitTests/PortableArchiveTests/testRetainedDataPurgeRemovesDeletedOpportunityReconciliationAndTombstoneMaterial \
  -only-testing:RekonPursuitTests/PortableArchiveTests/testRetainedDataPurgeRejectsWrongKeyBeforeWritingJobOrLease \
  -only-testing:RekonPursuitTests/PortableArchiveTests/testVerifiedArchiveRestoresIntoANewInactiveWorkspaceWithoutChangingSource \
  -only-testing:RekonPursuitTests/ProtectedExportTests/testReviewBindsDestinationParentIdentity \
  -only-testing:RekonPursuitTests/ProtectedExportTests/testSourceRevisionChangeRejectsReviewedExportWithoutCreatingAFile \
  -only-testing:RekonPursuitTests/ProtectedExportTests/testExistingTargetIsRejectedWithoutOverwritingIt \
  -derivedDataPath /private/tmp/rekon-vd207-task-2-green-dd \
  -resultBundlePath /private/tmp/rekon-vd207-task-2-green.xcresult

plutil -lint RekonPursuit.xcodeproj/project.pbxproj
xcodebuild -list -project RekonPursuit.xcodeproj
git diff -- RekonPursuit/ContentView.swift RekonPursuit/SettingsView.swift RekonPursuit.xcodeproj/project.pbxproj RekonPursuitUITests/RekonPursuitUITests.swift RekonPursuitUITestHostTests/RekonPursuitUITestHostTests.swift
git diff --check
```

Expected: every requested selector executes once as passed with no skip. Settings presents all sections but makes no direct write, sheet, route, or recovery-key leak; every root-owned sheet/alert binding retains its existing cancellation reset; `plutil` succeeds; the project lists both app targets; and the diff is confined to the five named source/test paths.

- [ ] **Step 7: Commit the bounded extraction from an isolated checkpoint**

```bash
git add RekonPursuit/ContentView.swift RekonPursuit/SettingsView.swift RekonPursuit.xcodeproj/project.pbxproj RekonPursuitUITestHostTests/RekonPursuitUITestHostTests.swift
git diff --cached --check
git diff --cached --stat
git commit -m "feat: reorganize Settings information architecture"
```

Expected: the Delivery-issued isolated checkpoint stages exactly one new Swift file, the narrow ContentView ownership move, two target registrations, and the Task 2-only presentation-state unit test; the Task 1 tests are already committed in the prior checkpoint. It must not stage the shared worktree wholesale. A fresh Code Reviewer and QA verifier must review this commit; the implementer does not review or verify its own work.

---

### Task 3: Verify signed behavior, architecture boundaries, and release evidence

**Files:**

- Modify only if a separately approved concrete defect is found: the Task 2 file allowlist.
- Evidence only: unique `/private/tmp/rekon-vd207-task-3-*` paths outside the repository.

**Consumes:** Task 2 focused GREEN, its reviewed source/project diff, and independent Code Reviewer/QA/Architecture/Security/privacy reports.

**Produces:** A signed Debug verification package sufficient for Delivery/TPM and product-owner review. This task changes no dashboard, roadmap, progress ledger, implementation scope, or VD2-08 debt status.

- [ ] **Step 1: Run signed Debug builds for both real app products**

```bash
xcodebuild build -project RekonPursuit.xcodeproj -scheme RekonPursuit -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /private/tmp/rekon-vd207-task-3-app-dd

xcodebuild build -project RekonPursuit.xcodeproj -target RekonPursuitUITestHost -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /private/tmp/rekon-vd207-task-3-host-dd
```

Expected: both app targets compile from the registered `SettingsView.swift` with the configured signing identity.

- [ ] **Step 2: Verify every signed executable and focused result bundle**

```bash
codesign --verify --deep --strict --verbose=2 /private/tmp/rekon-vd207-task-3-app-dd/Build/Products/Debug/RekonPursuit.app
codesign -dvv /private/tmp/rekon-vd207-task-3-app-dd/Build/Products/Debug/RekonPursuit.app
codesign --verify --deep --strict --verbose=2 /private/tmp/rekon-vd207-task-3-host-dd/Build/Products/Debug/RekonPursuitUITestHost.app
codesign -dvv /private/tmp/rekon-vd207-task-3-host-dd/Build/Products/Debug/RekonPursuitUITestHost.app
codesign --verify --deep --strict --verbose=2 /private/tmp/rekon-vd207-task-2-green-dd/Build/Products/Debug/RekonPursuitUITests.xctest
codesign -dvv /private/tmp/rekon-vd207-task-2-green-dd/Build/Products/Debug/RekonPursuitUITests.xctest
xcrun xcresulttool get test-results summary --path /private/tmp/rekon-vd207-task-2-green.xcresult > /private/tmp/rekon-vd207-task-3-green-summary.txt
xcrun xcresulttool get test-results tests --path /private/tmp/rekon-vd207-task-2-green.xcresult > /private/tmp/rekon-vd207-task-3-green-tests.txt
xcrun xcresulttool export attachments --path /private/tmp/rekon-vd207-task-2-green.xcresult --output-path /private/tmp/rekon-vd207-task-3-green-attachments
find /private/tmp/rekon-vd207-task-3-green-attachments -type f -maxdepth 2 -print
```

Expected: strict signature verification succeeds for all three products. Review `/private/tmp/rekon-vd207-task-3-green-tests.txt` selector by selector: every selector in Task 2's command appears exactly once as passed, with no failure or skip. Inspect the attachment manifest and every exported attachment; VD2-07 adds no screenshot or text attachment, and no retained item may contain a recovery-key value or the document fixture sentinels. If an Xcode layout places the UI bundle under an app `PlugIns` directory, use the path printed by `find /private/tmp/rekon-vd207-task-2-green-dd -name RekonPursuitUITests.xctest -type d -print` and record that resolved path before rerunning the two UI-bundle signature commands.

- [ ] **Step 3: Perform independent gates in the required order**

Obtain and record separate decisions with the concrete evidence above:

1. Code Reviewer verifies specification compliance, `ContentView` flow ownership, target registration, no unapproved source scope, and no direct model/store/secret ownership in Settings sections.
2. QA verifier reruns the Task 2 test command, checks fixture isolation, fixed-clock archive summary, compact keyboard focus, disabled/busy lower-layer coverage, cancellation/no-write proof, inactive restore, separate-workspace return, relaunch truth, and no sensitive UI artifact.
3. Architect verifies the local-selector/no-global-route contract and requires a new ADR before any ownership deviation.
4. Security/privacy verifier performs the mandated deep review of the Settings/recovery/export/document/AI surfaces, no-secret evidence, no document metadata, no network/configuration implication, and no signing/entitlement change.
5. TPM and Delivery independently confirm dependencies, reviews, evidence, open risks, and whether only the next dependency-safe action is releasable.

- [ ] **Step 4: Prepare the owner hands-on checklist without declaring acceptance**

Record the built signed-app paths and instruct the owner to check the normal and compact Settings surfaces: global rail still has five destinations; Recovery & archives is the initial local section; all four local selectors have focus and a non-color selected value; archive/export/purge/restore copy and disabled states are truthful; cancellation leaves the active workspace unchanged; document counts reveal no metadata; and AI/cloud/Gmail/Calendar remain unavailable. Leave VD2-08 and its three accepted automation debts open.

No implementer may change delivery status or claim VD2-07 accepted. Only the Delivery Manager may advance the card after the independent reviews and explicit product-owner decision.
