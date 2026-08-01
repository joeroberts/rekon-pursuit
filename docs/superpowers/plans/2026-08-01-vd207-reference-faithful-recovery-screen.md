# VD2-07x Reference-faithful Recovery & archives implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver the approved dark four-section Settings dashboard, including the Recovery protected-export success dialog, without changing product behavior.

**Architecture:** `ContentView` remains root owner of the workspace model, every recovery/export sheet and alert, and the success-dialog binding. `WorkspaceViewModel` emits only a safe post-success display filename after its existing verified export call returns. `SettingsView` owns local tab selection and uses display-safe data plus existing callbacks.

**Tech Stack:** Swift 6, SwiftUI, XCTest/XCUITest, existing signed Debug macOS targets, deterministic `REKON_UI_TEST_HOST` fixtures, and the existing Rekon visual theme.

## Global constraints

- The controlling visual authority is `docs/superpowers/specs/2026-08-01-vd207-reference-faithful-recovery-screen-design.md`.
- Preserve the global five-destination rail, root route ownership, and Settings-local non-persisted selection.
- The success dialog is impossible by default and appears only after the existing verified protected-export write succeeds. It is never a test switch or a fixture state.
- Never pass a recovery key, URL, bookmark, checksum, signature, document name, or document metadata into Settings display state, a fixture, process argument, screenshot, attachment, source, log, or report.
- The only new UI success datum is `displayFilename`; the destination wording remains `Selected local folder`.
- Do not change recovery-key verification, archive/export/purge/restore/expiry, workspace, document, AI, cloud, Gmail, Calendar, storage, migration, fixture-launch, signing, entitlement, or network behavior.
- Preserve all existing busy, disabled, error, cancellation, no-write, no-overwrite, inactive-restore, and separate-workspace contracts.
- The shared worktree is dirty. Never stage a whole file, reset/revert user work, normalize unrelated diffs, or update dashboard/roadmap/progress files. Delivery creates hunk-isolated checkpoints only after independent acceptance.
- The interrupted prior Task 2 work is unaccepted. It may be inspected and selectively reworked, but never counts as evidence.
- VD2-08 and its accepted accessibility/recovery automation debts remain open.

## Files and boundaries

- `RekonPursuit/WorkspaceViewModel.swift`: safe transient export-success event, emitted only on real verified success.
- `RekonPursuit/ContentView.swift`: root-owned success overlay and dismissal; current export sheets/errors remain root-owned.
- `RekonPursuit/SettingsView.swift`: local icon tabs, four reference-faithful Settings sections, and display-only dialog.
- `RekonPursuit.xcodeproj/project.pbxproj`: only narrow two-target registration if the existing dirty graph does not already contain it.
- `RekonPursuitTests/WorkspaceViewModelTests.swift`: real injected-destination success/no-mutation proof.
- `RekonPursuitUITests/RekonPursuitUITests.swift`: dashboard/tab/default-success-absence/compact-focus and safety proofs.
- `RekonPursuitUITestHostTests/RekonPursuitUITestHostTests.swift`: display-state/action-card disabled-state proofs without fixture changes.

---

### Task 1: Define the visual RED and safe real-export event

**Files:**

- Modify: `RekonPursuit/WorkspaceViewModel.swift`
- Modify: `RekonPursuit/SettingsView.swift`
- Modify: `RekonPursuit/ContentView.swift`
- Modify: `RekonPursuitTests/WorkspaceViewModelTests.swift`
- Modify: `RekonPursuitUITests/RekonPursuitUITests.swift`
- Modify: `RekonPursuitUITestHostTests/RekonPursuitUITestHostTests.swift`

**Consumes:** accepted selector tests at `7b92d50c08d379e2823becdc961e5c2737044259`, deterministic `archive` and `populated` fixtures, `ProtectedExportReview.displayFilename`, and the existing injected `protectedExportDestination` dependency.

**Produces:** named RED selectors, a safe transient success event, and tests that prove the event occurs only after an actual export write.

- [ ] **Step 1: Record the dirty baseline**

```bash
git status --short
git diff -- RekonPursuit/WorkspaceViewModel.swift RekonPursuit/ContentView.swift RekonPursuit/SettingsView.swift RekonPursuitTests/WorkspaceViewModelTests.swift RekonPursuitUITests/RekonPursuitUITests.swift RekonPursuitUITestHostTests/RekonPursuitUITestHostTests.swift
git hash-object RekonPursuit.xcodeproj/project.pbxproj
```

Expected: record only pre-existing and interrupted-task hunks; stage nothing.

- [ ] **Step 2: Add three failing UI contracts**

Add these `@MainActor` methods to `RekonPursuitUITests/RekonPursuitUITests.swift`:

```swift
func testVD207ReferenceRecoveryDashboardKeepsRailAndUsesCardComposition()
func testVD207ReferenceRecoveryDoesNotInventExportSuccess()
func testVD207ReferenceTabsKeepKeyboardSelectionAtCompactWidth()
func testVD207ReferenceOtherSettingsSectionsUseTruthfulInformationalCards()
```

The archive fixture dashboard test navigates with `sidebar-settings` and asserts the selected rail plus these exact identifiers:

```swift
["settings-reference-tab-strip", "settings-reference-tab-recovery-archives", "settings-recovery-overview-card", "settings-recovery-status-enrollment", "settings-recovery-status-state", "settings-recovery-archive-detail-card", "settings-recovery-action-create", "settings-recovery-action-purge", "settings-recovery-action-restore", "settings-recovery-protected-export"]
```

It asserts the existing archive accessibility value is exactly `created=2025-05-06T12:00:00Z;expires=2025-06-05T12:00:00Z;lifecycle=Verified` and no descendant label/value contains `fixture-document-hash`, `application/pdf`, `/private/`, or `recovery key`. The default-success test asserts `settings-protected-export-success-dialog` is absent without attempting export. The compact test uses `populated`, tabs to `settings-section-document-references`, asserts `Not selected; Keyboard focus`, presses Space, then asserts `Selected; Keyboard focus` and selected global rail.

The fourth method uses `document-relink` and asserts the following exact cards after selecting each local tab:

```swift
["settings-workspace-overview-card", "settings-workspace-recovery-card", "settings-workspace-return-card"]
["settings-document-overview-card", "settings-document-available-card", "settings-document-relink-card", "settings-document-privacy-card"]
["settings-ai-overview-card", "settings-ai-assistant-card", "settings-ai-email-calendar-card", "settings-ai-cloud-card", "settings-ai-privacy-card"]
```

It asserts `settings-document-reference-summary` still reports only the aggregate count; the document panel has no button, link, menu button, text field, switch, or checkbox descendants; and the AI panel has the same absence checks plus required unavailable words `No cloud services`, `Not configured`, `Not connected`, and `Offline`.

- [ ] **Step 3: Add the failing real-export unit contract**

Add async `testVerifiedProtectedExportPublishesSafeSuccessOnlyAfterWritingAndDismissesWithoutWorkspaceMutation()` in `WorkspaceViewModelTests`. Generate `RecoveryKey` only in process memory; inject one exact non-existent temporary `.rekonexport` URL; create an active opportunity; review and confirm export; wait while `isCreatingProtectedExport`; and assert:

```swift
XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path))
XCTAssertEqual(model.protectedExportSuccess?.displayFilename, destination.lastPathComponent)
XCTAssertFalse(model.protectedExportSuccess!.displayFilename.contains("/"))
model.dismissProtectedExportSuccess()
XCTAssertNil(model.protectedExportSuccess)
XCTAssertEqual(model.opportunities.map(\.id), activeIDsBefore)
```

Before review, after cancellation, and after review error, success must be nil. Deferred cleanup removes only the generated destination. No key is logged or attached.

- [ ] **Step 4: Extend the existing display-state host test**

Extend `testVD207SettingsRecoveryPresentationPreservesBusyDisabledAndInactiveCandidateContracts` to assert truthful overview wording and action enabled states for not-enrolled, enrolled/no archive, verified archive, exporting, and restoring presentation values. Construct only `SettingsArchiveSummary` display values; do not change fixture construction, launch parsing, or host routing.

- [ ] **Step 5: Run focused RED evidence**

```bash
xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit -configuration Debug -destination 'platform=macOS,arch=arm64' -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207ReferenceRecoveryDashboardKeepsRailAndUsesCardComposition -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207ReferenceRecoveryDoesNotInventExportSuccess -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207ReferenceTabsKeepKeyboardSelectionAtCompactWidth -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207ReferenceOtherSettingsSectionsUseTruthfulInformationalCards -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207SettingsRecoveryRetainsArchiveTruthAndRootOwnedCancellation -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207SettingsSecondaryNavigationDefaultsToRecoveryAndKeepsGlobalRail -only-testing:RekonPursuitUITestHostTests/RekonPursuitUITestHostTests/testVD207SettingsRecoveryPresentationPreservesBusyDisabledAndInactiveCandidateContracts -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testVerifiedProtectedExportPublishesSafeSuccessOnlyAfterWritingAndDismissesWithoutWorkspaceMutation -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testCancellingReviewedProtectedExportClearsReviewWithoutWritingOrChangingActiveWorkspace -only-testing:RekonPursuitTests/ProtectedExportTests/testReviewBindsDestinationParentIdentity -only-testing:RekonPursuitTests/ProtectedExportTests/testSourceRevisionChangeRejectsReviewedExportWithoutCreatingAFile -only-testing:RekonPursuitTests/ProtectedExportTests/testExistingTargetIsRejectedWithoutOverwritingIt -derivedDataPath /private/tmp/rekon-vd207x-task-1-red-dd -resultBundlePath /private/tmp/rekon-vd207x-task-1-red.xcresult
```

Expected: signed fixture host and all existing safety tests pass. New composition selectors/event are the only allowed RED. Any build, signing, fixture, rail, or baseline failure blocks the task.

- [ ] **Step 6: Implement the minimum safe success event**

In `WorkspaceViewModel.swift`, add adjacent to current protected-export state:

```swift
struct ProtectedExportSuccess: Equatable {
    let displayFilename: String
}

@Published private(set) var protectedExportSuccess: ProtectedExportSuccess?

func dismissProtectedExportSuccess() {
    protectedExportSuccess = nil
}
```

After `createProtectedExport` returns successfully and the existing `self.store === store` guard passes, assign `.init(displayFilename: review.displayFilename)`. Clear it before a fresh review and in `cancelProtectedExport()`. Never retain/publish the destination URL, parent identity, fingerprint, key, or receipt. Extend `SettingsRootModalPresentation` with this optional event and a root-only dismissal helper.

- [ ] **Step 7: Re-run focused evidence**

Run the command in Step 5 unchanged. Expected: the real-export unit and display-state host test now pass; only the three new reference UI methods remain RED.

---

### Task 2: Render the four reference sections, icon tabs, and real success dialog

**Files:**

- Modify: `RekonPursuit/SettingsView.swift`
- Modify: `RekonPursuit/ContentView.swift`
- Modify: `RekonPursuit.xcodeproj/project.pbxproj` only if narrow source registration is necessary
- Modify: `RekonPursuitUITests/RekonPursuitUITests.swift`
- Modify: `RekonPursuitUITestHostTests/RekonPursuitUITestHostTests.swift`

**Consumes:** Task 1 safe success event; `SettingsRecoveryPresentation`; `RekonTheme`, `RekonCard`, and `RekonPrimaryButtonStyle`; and the approved reference design.

**Produces:** all four dark reference-faithful Settings sections and root-owned dialog. The dialog can occur only after Task 1's verified success event.

- [ ] **Step 1: Prove project membership before modifying it**

```bash
git hash-object RekonPursuit.xcodeproj/project.pbxproj
git diff -- RekonPursuit.xcodeproj/project.pbxproj
rg -n "SettingsView.swift" RekonPursuit.xcodeproj/project.pbxproj
```

Expected: if `SettingsView.swift` is already referenced exactly once by both app targets, leave the project file untouched. Otherwise change only the file reference, build file, and the two necessary target memberships; do not normalize unrelated dirty project entries.

- [ ] **Step 2: Render accessible icon-and-label reference tabs**

Replace text-only local selector buttons in `SettingsView` with a focused `SettingsReferenceTab` that receives `SettingsSection`, selection/focus state, and action. Use `folder`, `externaldrive`, `doc`, and `link`; use cyan icon/text plus a cyan bottom rule in the selected tab cell; use cool-gray inactive text and a full-width divider. The root selector gets `settings-reference-tab-strip`; recovery tab also gets `settings-reference-tab-recovery-archives`; existing section identifiers stay unchanged.

Keep this exact behavior:

```swift
.focusable()
.focused($focusedSection, equals: section)
.onKeyPress(.space) {
    selectedSection = section
    return .handled
}
.accessibilityValue(selectorAccessibilityValue(for: section))
```

`ViewThatFits` may switch only the complete labeled tab row to a vertical compact stack. It must not hide a tab or turn local selection into a route.

- [ ] **Step 3: Render the Recovery dashboard from display-safe values**

Replace the generic `GroupBox("Recovery & archives")` with these private views in `SettingsView.swift`:

```swift
SettingsRecoveryOverviewCard(recovery: recovery)
SettingsRecoveryArchiveDetailCard(summaries: recovery.archiveSummaries)
SettingsRecoveryActionRow(
    recovery: recovery,
    beginRecoveryKeyEnrollment: beginRecoveryKeyEnrollment,
    presentArchiveCreation: presentArchiveCreation,
    presentProtectedExport: presentProtectedExport,
    presentRetainedDataPurge: presentRetainedDataPurge,
    choosePortableArchiveForRestore: choosePortableArchiveForRestore
)
```

The overview uses an emerald `checkmark.shield` decorative visual paired with enrollment/recovery text facts. The archive card contains only the current summary values. The action row has three large labeled cards for archive creation, retained-data management, and restore. `Export protected copy` remains a visible primary action in the archive-detail surface and has both `settings-recovery-protected-export` and the existing `create-protected-export` compatibility identifier. Preserve all current disabled/progress/incomplete-purge/inactive-candidate values.

Use `RekonCard`, `RekonTheme.borderSubtle`, `RekonTheme.success`, and `RekonTheme.secondaryText` for the reference's navy cards, thin outlines, emerald verified state, and muted facts. Do not create a duplicate visual theme or alter shared theme values.

- [ ] **Step 4: Render the remaining three reference sections without new behavior**

Replace the generic Workspace, Document references, and AI & connections groups with private `SettingsView` child views using the same `RekonCard` hero/card system.

Workspace renders a cyan `folder` hero with `Local workspace`, `Workspace status` / `Active`, and `Storage` / `Local only`; a `Workspace recovery` explanatory card; and a final return card. The return card is visibly disabled with no action when `usingSeparateLocalWorkspace` is false. When true, it exposes only the existing `returnToPreservedWorkspaceRecovery` callback. Use the three workspace identifiers from the Task 1 test.

Document references renders a cyan `doc` hero, existing aggregate Available and Needs relinking facts, two matching count cards, and a privacy information card. Use the five document identifiers from the Task 1 test. The only source values are `DocumentReferenceSummary.availableCount` and `.relinkRequiredCount`; do not add a document control or metadata field.

AI & connections renders a cool-violet `link` hero with no-cloud/no-activity/offline facts, three status-only cards for AI assistant, Email & calendar, and Cloud sync, plus a privacy information card. Use the five AI identifiers from the Task 1 test. All cards are non-actionable; do not add a setup button, link, or configuration state.

- [ ] **Step 5: Render the root-owned success dialog**

Define `SettingsProtectedExportSuccessDialog` in `SettingsView.swift`:

```swift
struct SettingsProtectedExportSuccessDialog: View {
    let displayFilename: String
    let dismiss: () -> Void
}
```

Its root identifier is `settings-protected-export-success-dialog`; it renders `checkmark.circle`, `Protected copy exported`, the safe filename, `Selected local folder`, the non-secret key reminder, and a `Done` button with identifier `settings-protected-export-success-done` using `RekonPrimaryButtonStyle`. It accepts no URL or key.

`ContentView` overlays it above the Settings/AppShell content only while `SettingsRootModalPresentation.isProtectedExportSuccessPresented` is true. It closes the export sheet only after the model event is non-nil. Done invokes the root dismissal helper only. Existing cancel/error sheets stay root-owned and never trigger the dialog.

- [ ] **Step 6: Make the reference contract green**

```bash
xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit -configuration Debug -destination 'platform=macOS,arch=arm64' -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207ReferenceRecoveryDashboardKeepsRailAndUsesCardComposition -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207ReferenceRecoveryDoesNotInventExportSuccess -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207ReferenceTabsKeepKeyboardSelectionAtCompactWidth -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207ReferenceOtherSettingsSectionsUseTruthfulInformationalCards -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207SettingsRecoveryRetainsArchiveTruthAndRootOwnedCancellation -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207SettingsSecondaryNavigationDefaultsToRecoveryAndKeepsGlobalRail -only-testing:RekonPursuitUITestHostTests/RekonPursuitUITestHostTests/testVD207SettingsRecoveryPresentationPreservesBusyDisabledAndInactiveCandidateContracts -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testVerifiedProtectedExportPublishesSafeSuccessOnlyAfterWritingAndDismissesWithoutWorkspaceMutation -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testCancellingReviewedProtectedExportClearsReviewWithoutWritingOrChangingActiveWorkspace -only-testing:RekonPursuitTests/ProtectedExportTests/testReviewBindsDestinationParentIdentity -only-testing:RekonPursuitTests/ProtectedExportTests/testSourceRevisionChangeRejectsReviewedExportWithoutCreatingAFile -only-testing:RekonPursuitTests/ProtectedExportTests/testExistingTargetIsRejectedWithoutOverwritingIt -derivedDataPath /private/tmp/rekon-vd207x-task-2-green-dd -resultBundlePath /private/tmp/rekon-vd207x-task-2-green.xcresult
```

Expected: each named test executes once and passes; no selector fails, skips, or is marked expected failure.

- [ ] **Step 7: Capture wide and compact visual evidence**

```bash
xcrun xcresulttool get test-results summary --path /private/tmp/rekon-vd207x-task-2-green.xcresult
xcrun xcresulttool get test-results tests --path /private/tmp/rekon-vd207x-task-2-green.xcresult
xcrun xcresulttool export attachments --path /private/tmp/rekon-vd207x-task-2-green.xcresult --output-path /private/tmp/rekon-vd207x-task-2-attachments
find /private/tmp/rekon-vd207x-task-2-attachments -maxdepth 2 -type f -print
```

Expected: inspect every retained artifact. It must show the global rail, icon tab hierarchy, cyan active rule, large recovery overview, archive/action cards, and dark dialog hierarchy when available; it must contain no key, absolute path, or document metadata. If the selected tests create no attachment, record that fact and capture a named signed-app image outside the repository before review.

---

### Task 3: Verify signed behavior and release owner testing

**Files:**

- Modify only for a separately approved concrete defect: Task 2's allowlist.
- Evidence only: unique `/private/tmp/rekon-vd207x-task-3-*` paths outside the repository.

**Consumes:** Task 2 green result, narrow source/project diff, and retained visual evidence.

**Produces:** a signed verification package for independent Code Review, QA, Architecture, Security/privacy, TPM, Delivery, and product-owner testing.

- [ ] **Step 1: Build both actual apps with Debug signing**

```bash
xcodebuild build -project RekonPursuit.xcodeproj -scheme RekonPursuit -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath /private/tmp/rekon-vd207x-task-3-app-dd
xcodebuild build -project RekonPursuit.xcodeproj -scheme RekonPursuitUITestHost -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath /private/tmp/rekon-vd207x-task-3-host-dd
find /private/tmp/rekon-vd207x-task-3-app-dd /private/tmp/rekon-vd207x-task-3-host-dd -name '*.app' -type d -print
```

Expected: resolved signed main-app and fixture-host paths. Never disable signing.

- [ ] **Step 2: Verify signing and source scope**

Run this exact signature verification after Step 1:

```bash
find /private/tmp/rekon-vd207x-task-3-app-dd /private/tmp/rekon-vd207x-task-3-host-dd -name '*.app' -type d -print0 | while IFS= read -r -d '' app_path; do
  codesign --verify --deep --strict "$app_path"
  codesign -dvv "$app_path"
done
```

Then run:

```bash
git diff --check
git diff -- RekonPursuit/WorkspaceViewModel.swift RekonPursuit/ContentView.swift RekonPursuit/SettingsView.swift RekonPursuit.xcodeproj/project.pbxproj RekonPursuitTests/WorkspaceViewModelTests.swift RekonPursuitUITests/RekonPursuitUITests.swift RekonPursuitUITestHostTests/RekonPursuitUITestHostTests.swift
```

Expected: strict verification succeeds. The isolated checkpoint contains only the safe event, root overlay, reference dashboard, tests, and any necessary narrow registration.

- [ ] **Step 3: Obtain independent decisions in order**

1. Code Review: visual/spec fidelity, allowlist, root ownership, and no model/store/file/key leakage into Settings.
2. QA: exact full command, no skips, compact/wide visual evidence, archive/export safety selectors, safe artifact contents.
3. Architecture: presentation-only model event, local tabs, and root ownership; any deviation needs an ADR.
4. Security/privacy: key/document/path redaction, success trigger, fixture isolation, no network/configuration effect, and signing/entitlement non-change.
5. TPM and Delivery: all decisions, evidence, checkpoint, risks, and release of only owner testing.

- [ ] **Step 4: Hand the signed build to the owner**

Owner checks the global rail remains visible; Recovery opens by default; wide/compact tabs and cards match the reference; a real successful protected export alone reveals the dialog; Done changes no workspace state; and no key, path, or document metadata is displayed.

## Completion evidence

VD2-07x is complete only after a hunk-isolated Task 2 checkpoint, signed focused matrix, signing/source/visual evidence, all independent decisions, and explicit product-owner hands-on acceptance are recorded. VD2-08 remains open.
