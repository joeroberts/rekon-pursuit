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
  - Adds four focused `testVD207...` functions and no fixture/data transport mechanism.

`SettingsView` consumes and produces these exact interfaces:

```swift
struct SettingsArchiveSummary: Identifiable, Equatable {
    let id: UUID
    let text: String
    init(archive: PortableArchiveCatalogueRow)
    private static func makeText(_ archive: PortableArchiveCatalogueRow) -> String
}

struct SettingsRecoveryPresentation: Equatable {
    let recoveryEnrollmentEnabled: Bool
    let archiveSummaries: [SettingsArchiveSummary]
    let isCreatingPortableArchive: Bool
    let isCreatingProtectedExport: Bool
    let isPurgingRetainedArchiveData: Bool
    let isRestoringPortableArchive: Bool
    let retainedDataPurgeStatusText: String?
    let restoreReady: Bool
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
- Read-only test evidence: `RekonPursuitTests/WorkspaceViewModelTests.swift`, `RekonPursuitCoreTests/PortableArchiveTests.swift`, and `RekonPursuitCoreTests/ProtectedExportTests.swift`

**Consumes:** The approved VD2-07 design, current `launchApp(fixture:windowSize:session:reduceMotion:)`, current `tabToKeyboardFocus(_:in:maximumTabPresses:)`, and existing `populated`, `archive`, `document-relink`, and `recovery` fixtures.

**Produces:** Four named UI RED selectors that fail only because the new Settings local selectors/panels do not yet exist, plus recorded lower-layer GREEN baselines for the unchanged safety contracts.

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

- [ ] **Step 3: Add the enrolled archive and privacy RED tests**

Append these two complete methods. They deliberately inspect no recovery-key sheet and attach no screenshot, so the test artifact cannot contain a generated secret.

```swift
@MainActor
func testVD207SettingsRecoveryShowsExistingArchiveActionsAndCatalogueTruth() {
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
    XCTAssertTrue(app.buttons["create-portable-archive"].isEnabled)
    XCTAssertTrue(app.buttons["create-protected-export"].isEnabled)
    XCTAssertTrue(app.buttons["restore-portable-archive"].isEnabled)
}

@MainActor
func testVD207SettingsDocumentAndAISectionsStayAggregateAndUnavailable() {
    let app = launchApp(fixture: "document-relink")
    app.descendants(matching: .any)["sidebar-settings"].tap()
    app.buttons["settings-section-document-references"].tap()

    let summary = app.descendants(matching: .any)["settings-document-reference-summary"]
    XCTAssertTrue(summary.waitForExistence(timeout: 2))
    XCTAssertEqual(summary.value as? String, "0 available · 1 require relinking")
    XCTAssertFalse(app.staticTexts["fixture-resume.pdf"].exists)
    XCTAssertFalse(app.staticTexts["fixture-document-hash"].exists)
    XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "relink")).firstMatch.exists)

    app.buttons["settings-section-ai-connections"].tap()
    let unavailable = app.descendants(matching: .any)["settings-ai-connections-unavailable"]
    XCTAssertTrue(unavailable.waitForExistence(timeout: 2))
    XCTAssertTrue(unavailable.label.contains("No AI requests"))
    XCTAssertTrue(unavailable.label.contains("Gmail"))
    XCTAssertTrue(unavailable.label.contains("Calendar"))
    XCTAssertFalse(app.buttons["configure-ai-connection"].exists)
    XCTAssertFalse(app.buttons["connect-gmail"].exists)
    XCTAssertFalse(app.buttons["connect-calendar"].exists)
}
```

- [ ] **Step 4: Run the signed RED and unchanged lower-layer baselines**

Run the exact focused command; do not disable signing and do not change the fixture session manually:

```bash
xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207SettingsSecondaryNavigationDefaultsToRecoveryAndKeepsGlobalRail \
  -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207SettingsSecondaryNavigationIsKeyboardOperableAtCompactWidth \
  -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207SettingsRecoveryShowsExistingArchiveActionsAndCatalogueTruth \
  -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207SettingsDocumentAndAISectionsStayAggregateAndUnavailable \
  -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testRefreshIncludesLifecycleAwareDocumentReferenceSummary \
  -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testPortableArchiveRestoreKeepsSecurityScopeUntilExplicitConfirmationCompletes \
  -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testPortableArchiveVerificationFailureRemainsVisibleUntilDismissed \
  -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testCancellingAwaitedPortableArchiveRestoreReleasesScopeExactlyOnceAfterWorkerFinishes \
  -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testPortableArchiveControlsStayDisabledThroughoutAwaitedVerificationAndRestore \
  -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testProtectedExportReviewFailureRemainsVisibleForCorrection \
  -only-testing:RekonPursuitTests/PortableArchiveTests/testRetainedDataPurgeRejectsWrongKeyBeforeWritingJobOrLease \
  -only-testing:RekonPursuitTests/ProtectedExportTests/testSourceRevisionChangeRejectsReviewedExportWithoutCreatingAFile \
  -derivedDataPath /private/tmp/rekon-vd207-task-1-red-dd \
  -resultBundlePath /private/tmp/rekon-vd207-task-1-red.xcresult
```

Expected: every named lower-layer selector passes; the four new UI methods reach the current Settings screen and fail only for the absent `settings-*` selector/panel identifiers. A compile, signing, fixture-launch, rail, or unrelated existing-test failure stops the task and is not RED evidence.

- [ ] **Step 5: Capture the Task 1 evidence and make an isolated checkpoint**

```bash
xcrun xcresulttool get test-results summary --path /private/tmp/rekon-vd207-task-1-red.xcresult
xcrun xcresulttool get test-results tests --path /private/tmp/rekon-vd207-task-1-red.xcresult
git diff -- RekonPursuitUITests/RekonPursuitUITests.swift
git diff --check
```

Expected: the result records the exact baseline GREEN and the presentation-only UI RED. This repository is intentionally dirty, including the UI-test path, so do not stage the whole file in the shared worktree. Delivery must issue a clean or hunk-isolated implementation checkpoint that stages only the four `testVD207...` methods, verifies `git diff --cached --check`, and commits it as `test: define VD2-07 Settings presentation contracts`. A fresh independent QA verifier must accept the evidence before Task 2 is released.

In the Delivery-issued checkpoint, run these exact commit commands after `git diff -- RekonPursuitUITests/RekonPursuitUITests.swift` shows only the four new methods:

```bash
git add RekonPursuitUITests/RekonPursuitUITests.swift
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
    init(archive: PortableArchiveCatalogueRow) {
        id = archive.archiveID
        text = SettingsArchiveSummary.makeText(archive)
    }
}

struct SettingsRecoveryPresentation: Equatable {
    let recoveryEnrollmentEnabled: Bool
    let archiveSummaries: [SettingsArchiveSummary]
    let isCreatingPortableArchive: Bool
    let isCreatingProtectedExport: Bool
    let isPurgingRetainedArchiveData: Bool
    let isRestoringPortableArchive: Bool
    let retainedDataPurgeStatusText: String?
    let restoreReady: Bool
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

Set the three values used by the focused UI tests exactly as follows; no identifier contains a document or recovery-key value:

```swift
Text(summary.text)
    .accessibilityIdentifier("settings-archive-summary-\(summary.id.uuidString)")
    .accessibilityLabel(summary.text)

Text(documentReferenceSummaryText)
    .accessibilityIdentifier("settings-document-reference-summary")
    .accessibilityLabel("Document reference summary")
    .accessibilityValue(documentReferenceSummaryText)

Text("The local Activity & AI ledger is read-only and empty in this MVP. No AI requests, costs, model runtime, cloud connection, Gmail, or Calendar integration is configured.")
    .accessibilityIdentifier("settings-ai-connections-unavailable")
    .accessibilityLabel("The local Activity & AI ledger is read-only and empty in this MVP. No AI requests, costs, model runtime, cloud connection, Gmail, or Calendar integration is configured.")
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

Define `settingsRecoveryPresentation` in `ContentView` from its existing published model facts. Map the catalogue through `SettingsArchiveSummary(archive:)`; map the current `RetainedDataPurgeStatus` with the exact existing five-case text; derive `restoreReady` only with `if case .ready = model.portableArchiveRestoreState`. Do not pass `PortableArchiveCatalogueRow` itself, a document, a recovery key, a store, or the model to a focused section.

Move the exact existing recovery-key, archive-creation, protected-export, retained-purge, portable-restore sheets and the portable-restore failure alert from the old private Settings view to the modifier chain on `ContentView`. Preserve their existing `Binding` setters, `model.enrollRecoveryKey`, `model.createPortableArchive`, `model.reviewProtectedExport`, `model.confirmProtectedExport`, `model.cancelProtectedExport`, `model.purgeRetainedArchiveData`, `model.choosePortableArchiveForRestore`, `model.verifyPortableArchiveForRestore`, `model.confirmPortableArchiveRestore`, `model.cancelPortableArchiveRestore`, and `model.dismissPortableArchiveRestoreFailure` calls verbatim. Delete the entire private `SettingsView` declaration from `ContentView` only after those modifiers compile there.

- [ ] **Step 4: Register only the new source file in both existing app targets**

Use these currently unused PBX identifiers and make only these six structural additions:

```text
100000000000000000000080 /* SettingsView.swift in Sources */ = {isa = PBXBuildFile; fileRef = 200000000000000000000078 /* SettingsView.swift */; };
100000000000000000000081 /* SettingsView.swift in Sources */ = {isa = PBXBuildFile; fileRef = 200000000000000000000078 /* SettingsView.swift */; };
200000000000000000000078 /* SettingsView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = SettingsView.swift; sourceTree = "<group>"; };
```

Add the file reference to the existing `RekonPursuit` group beside `ContactsView.swift`. Add build file `...080` once to the `RekonPursuit` `900000000000000000000001` sources phase and build file `...081` once to the `RekonPursuitUITestHost` `900000000000000000000007` sources phase. Do not change a build setting, signing setting, target, dependency, framework, resource, scheme, or source membership other than those two entries.

- [ ] **Step 5: Run the focused GREEN and inspect the exact production diff**

```bash
xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207SettingsSecondaryNavigationDefaultsToRecoveryAndKeepsGlobalRail \
  -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207SettingsSecondaryNavigationIsKeyboardOperableAtCompactWidth \
  -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207SettingsRecoveryShowsExistingArchiveActionsAndCatalogueTruth \
  -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207SettingsDocumentAndAISectionsStayAggregateAndUnavailable \
  -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testRefreshIncludesLifecycleAwareDocumentReferenceSummary \
  -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testPortableArchiveRestoreKeepsSecurityScopeUntilExplicitConfirmationCompletes \
  -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testPortableArchiveVerificationFailureRemainsVisibleUntilDismissed \
  -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testCancellingAwaitedPortableArchiveRestoreReleasesScopeExactlyOnceAfterWorkerFinishes \
  -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testPortableArchiveControlsStayDisabledThroughoutAwaitedVerificationAndRestore \
  -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testProtectedExportReviewFailureRemainsVisibleForCorrection \
  -only-testing:RekonPursuitTests/PortableArchiveTests/testRetainedDataPurgeRejectsWrongKeyBeforeWritingJobOrLease \
  -only-testing:RekonPursuitTests/ProtectedExportTests/testSourceRevisionChangeRejectsReviewedExportWithoutCreatingAFile \
  -derivedDataPath /private/tmp/rekon-vd207-task-2-green-dd \
  -resultBundlePath /private/tmp/rekon-vd207-task-2-green.xcresult

plutil -lint RekonPursuit.xcodeproj/project.pbxproj
xcodebuild -list -project RekonPursuit.xcodeproj
git diff -- RekonPursuit/ContentView.swift RekonPursuit/SettingsView.swift RekonPursuit.xcodeproj/project.pbxproj RekonPursuitUITests/RekonPursuitUITests.swift
git diff --check
```

Expected: every requested selector passes; Settings presents all sections but makes no direct write, sheet, route, or recovery-key leak; `plutil` succeeds; the project lists both app targets; and the diff is confined to the four named source/test paths.

- [ ] **Step 6: Commit the bounded extraction from an isolated checkpoint**

```bash
git add RekonPursuit/ContentView.swift RekonPursuit/SettingsView.swift RekonPursuit.xcodeproj/project.pbxproj
git diff --cached --check
git diff --cached --stat
git commit -m "feat: reorganize Settings information architecture"
```

Expected: the Delivery-issued isolated checkpoint stages exactly one new Swift file, the narrow ContentView ownership move, and two target registrations; the Task 1 tests are already committed in the prior checkpoint. It must not stage the shared worktree wholesale. A fresh Code Reviewer and QA verifier must review this commit; the implementer does not review or verify its own work.

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
xcrun xcresulttool get test-results summary --path /private/tmp/rekon-vd207-task-2-green.xcresult
xcrun xcresulttool get test-results tests --path /private/tmp/rekon-vd207-task-2-green.xcresult
```

Expected: strict signature verification succeeds for all three products and every requested test executes once as passed with no skip. If an Xcode layout places the UI bundle under an app `PlugIns` directory, use the path printed by `find /private/tmp/rekon-vd207-task-2-green-dd -name RekonPursuitUITests.xctest -type d -print` and record that resolved path before rerunning the two UI-bundle signature commands.

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
