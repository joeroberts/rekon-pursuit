# VD2-07x Reference-faithful Recovery & archives implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (- [ ]) syntax for tracking.

**Goal:** Deliver the approved four-section Settings dashboard and root-owned protected-export success dialog without changing recovery, archive, export, workspace, fixture, or privacy behavior.

**Architecture:** WorkspaceViewModel owns a filename-only, store-scoped export-completion event and an opaque operation token. ContentView projects that event at the root, closes only the existing export sheet after valid success, and owns Done. SettingsView owns only local tab/focus state and receives safe display values and callbacks.

**Tech Stack:** Swift 6, SwiftUI, XCTest/XCUITest, existing signed Debug macOS targets, deterministic REKON_UI_TEST_HOST fixtures, and the existing Rekon visual theme.

## Global constraints

- The controlling visual authority is docs/superpowers/specs/2026-08-01-vd207-reference-faithful-recovery-screen-design.md.
- Preserve the five-destination rail, DailyRoute.settings, root file-panel/sheet/alert ownership, and local non-persisted Settings selection.
- ProtectedExportSuccess has exactly displayFilename: String. No review, URL, parent identity, key, bookmark, receipt, fingerprint, checksum, archive row, document value, store identity, or operation token may cross into Settings, fixtures, logs, screenshots, attachments, or reports.
- The fixed destination copy is Selected local folder. Success is absent at launch and after every cancel/failure/stale completion. It is never a fixture state, launch argument, demo control, or product test switch.
- Do not change recovery-key verification, archive/export/purge/restore/expiry semantics, Core workers, storage, migration, fixtures, launch parsing, signing, entitlements, routing, AI/cloud/Gmail/Calendar behavior, or network behavior.
- Preserve busy, disabled, error, cancellation, no-write, no-overwrite, inactive-restore, and separate-workspace contracts. A lower-layer export that finishes after cancellation may retain its existing lower-layer outcome, but it must not publish UI success.
- The shared worktree is dirty. Record the baseline first. Never reset/reformat unrelated work, stage a whole dirty file, or update dashboard, roadmap, or progress artifacts.
- Task 1 may be RED only for explicitly named, not-yet-rendered visual selector/card assertions. Every operation, event, root-presentation, fixture, route, accessibility, and lower-layer safety assertion must be green with zero skip and zero expected failure.

## Files and interfaces

| Path | Responsibility |
| --- | --- |
| RekonPursuit/WorkspaceViewModel.swift | Opaque token lifecycle, safe completion event, and a test-injected creation closure whose production default calls the current store method. |
| RekonPursuit/ContentView.swift | Root event projection, close order, overlay, and Done binding. |
| RekonPursuit/SettingsView.swift | Safe root-presentation value/binding, local tabs, four display-only panels, and string-only dialog. |
| RekonPursuitTests/WorkspaceViewModelTests.swift | Real-write/root projection, exhaustive no-event, gated-cancel, and workspace-transition tests. |
| RekonPursuitUITests/RekonPursuitUITests.swift | Fixture-driven reference selector/copy/control/compact/screenshot evidence. |
| RekonPursuitUITestHostTests/RekonPursuitUITestHostTests.swift | Pure safe display-state tests only; fixture construction is read-only. |

The sole test seam is an initializer dependency local to WorkspaceViewModel:

~~~
private let createProtectedExport:
    (WorkspaceStore, ProtectedExportReview, RecoveryKey) async throws -> Void

// Production default.
{ store, review, recoveryKey in
    _ = try await store.createProtectedExport(review: review, recoveryKey: recoveryKey)
}
~~~

It is not a Setting, launch argument, fixture field, environment value, route, or UI control. The positive test uses the production default and a real injected destination. The gated-cancel test constructs its model with the gated closure; its review still calls the real store review path before confirmation enters that gate.

---

### Task 1: Test-first event lifecycle, root projection, and visual RED

**Files:** Modify only the six files named above. Do not modify project membership, fixture host, fixture code, Core, signing, entitlements, or launch parsing.

**Produces:** green operation/event/root tests; the complete pre-existing safety baseline; and three mechanically classifiable visual RED methods.

- [ ] **Step 1: Record the dirty baseline**

~~~
git status --short
git diff -- RekonPursuit/WorkspaceViewModel.swift RekonPursuit/ContentView.swift RekonPursuit/SettingsView.swift RekonPursuitTests/WorkspaceViewModelTests.swift RekonPursuitUITests/RekonPursuitUITests.swift RekonPursuitUITestHostTests/RekonPursuitUITestHostTests.swift
git hash-object RekonPursuit.xcodeproj/project.pbxproj
~~~

Expected: record baseline only and stage nothing.

- [ ] **Step 2: Add four deterministic reference UI methods before rendering**

~~~
func testVD207ReferenceRecoveryDashboardKeepsRailAndUsesCardComposition()
func testVD207ReferenceRecoveryDoesNotInventExportSuccess()
func testVD207ReferenceTabsKeepKeyboardSelectionAtCompactWidth()
func testVD207ReferenceOtherSettingsSectionsUseTruthfulInformationalCards()
~~~

Each method first proves a ready named fixture, selected sidebar-settings rail, and applicable existing Settings panel/summary. Use XCTContext.runActivity(named:) once per required visual selector/card. Each assertion activity name and assertion message starts exactly VD2-07x RED: unrendered visual selector . Do not use XCTExpectFailure, XCTSkip, a generic timeout, or a blanket expected-failure classification. If named visual selectors are missing, record every named absence and return before Task-2 copy/control assertions; thus Task 1 has no non-visual RED.

The Recovery method uses archive, proves the existing settings-section-recovery-archives-panel and exact settings-archive-summary-* value created=2025-05-06T12:00:00Z;expires=2025-06-05T12:00:00Z;lifecycle=Verified, and preserves the existing action/error/cancel checks. Its only declared visual RED selectors are:

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

When green, it rejects fixture-document-hash, application/pdf, /private/, and recovery key from every Recovery descendant label/value, retains the fixed archive facts, and checks enabled/cancel/error action behavior.

Extend testVD207SettingsRecoveryPresentationPreservesBusyDisabledAndInactiveCandidateContracts without changing fixture construction, launch parsing, or host routing. Construct only safe SettingsArchiveSummary values and assert the exact overview facts for all three states: not enrolled is Recovery key not set up / Set up a recovery key to protect this workspace.; enrolled with no archive is Recovery key enrolled / No verified archive available; enrolled with a verified archive is Recovery key enrolled / Verified archive available. Retain the existing create/export/purge/restore enabled and busy predicates, progress text, retained-purge status, and inactive-candidate assertions. Task 2 renders these same safe properties in settings-recovery-status-enrollment and settings-recovery-status-state.

The default-success method uses ready archive, enters Settings, proves the rail and Recovery panel, and asserts settings-protected-export-success-dialog does not exist. It never attempts export and must be green in both matrices.

The compact method uses populated at compact size. Before any RED assertion, it proves settings-section-workspace, settings-section-recovery-archives, settings-section-document-references, and settings-section-ai-connections are all present, hittable, and keyboard reachable. Starting on Recovery, tab to each non-selected section, assert exactly Not selected; Keyboard focus, press Space, assert exactly Selected; Keyboard focus and the matching existing panel, and assert sidebar-settings remains selected. It then records only settings-reference-tab-strip and settings-reference-tab-recovery-archives as visual RED selectors. When rendered, the same sequence proves every labeled tab remains in the vertical compact stack and is not rerouted.

The other-sections method uses document-relink. Before visual RED checks, it proves the existing aggregate summary is exactly 0 available · 1 require relinking, the existing Document/AI panels, their no-actionable-descendant conditions, and no fixture-resume.pdf, fixture-document-hash, application/pdf, or /private/ label/value disclosure. Its only declared visual RED selectors are:

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

When green, it asserts Workspace copy Local workspace, Workspace status / Active, Storage / Local only, and Returning does not modify the active workspace. The no-separate-workspace return card reports No preserved workspace available; Disabled and has no button/link/menu-button descendant. It asserts Document cards Available / 0 and Needs relinking / 1, privacy copy that names and locations stay private, and no button, link, menu button, text field, switch, or checkbox. It asserts AI activity / No activity recorded, Connection status / Offline, and exact status pairs AI assistant / Not configured, Email & calendar / Not connected, Cloud sync / Not configured, also with no actionable descendants.

- [ ] **Step 3: Add four green model contracts before the event implementation**

Add these async tests to WorkspaceViewModelTests:

~~~
func testVerifiedProtectedExportPublishesSafeSuccessAndRootPresentationOnlyAfterRealWriting() async throws
func testProtectedExportSuccessRemainsNilForEveryNonSuccessBranch() async throws
func testCancellingConfirmedProtectedExportInvalidatesInFlightOperation() async throws
func testProtectedExportSuccessClearsForEveryWorkspaceTransition() async throws
~~~

testVerifiedProtectedExportPublishesSafeSuccessAndRootPresentationOnlyAfterRealWriting creates an enrolled real store and active opportunity, injects one exact non-existent temporary .rekonexport destination, and uses the production default creation closure. It asserts nil before review/confirmation, waits only for isCreatingProtectedExport, then asserts the output exists, the event equals destination.lastPathComponent, and the filename contains no slash. Construct SettingsRootModalPresentation from the event and assert isProtectedExportSuccessPresented is true, protectedExportSuccessDisplayFilename equals destination.lastPathComponent, and protectedExportSuccessDestinationLabel equals Selected local folder. Call SettingsRootModalBindings.dismissProtectedExportSuccess { model.dismissProtectedExportSuccess() }; then assert false root presentation, nil event, unchanged output, and unchanged active IDs. Do not log/attach the key or destination path; defer removes only the generated output.

testProtectedExportSuccessRemainsNilForEveryNonSuccessBranch uses independently constructed models/destinations and asserts nil event, false root presentation, applicable no-output/no-overwrite, and unchanged active IDs for each branch:

1. before review and after invalid confirmation/re-entry;
2. destination cancellation with protectedExportDestination: { nil };
3. review failure against an occupied destination;
4. stale source after valid review followed by a real source revision;
5. write failure after valid review when the destination becomes occupied before confirmation;
6. fresh review after a prior real success; and
7. cancelProtectedExport after a prior real success.

Use generated temporary paths only, compare preserved bytes for occupied outputs, and remove only generated files. Existing Core source-change/no-overwrite tests do not substitute for these event assertions.

For every invalid/review/write failure branch, also assert the existing safe protectedExportErrorMessage remains non-empty when that branch currently exposes an error. The existing signed UI selector testVD207SettingsRecoveryRetainsArchiveTruthAndRootOwnedCancellation retains its protected-export-error accessibility label/value assertion while proving the success dialog remains absent after the error/cancel path.

For testCancellingConfirmedProtectedExportInvalidatesInFlightOperation, add private actor GatedProtectedExportCreate with waitUntilStarted() and release() continuations. Complete a valid real review, call confirmProtectedExport, wait for the injected creation closure to enter, call the existing model.cancelProtectedExport(), release the gate, and wait until isCreatingProtectedExport is false. Assert nil event, false root success presentation, no generated gated output, cleared review/error state, and unchanged active IDs. The test does not claim a changed lower-layer cancellation/write contract.

testProtectedExportSuccessClearsForEveryWorkspaceTransition first creates a real event for a distinct model/destination before each action, then asserts nil event and false root presentation. It explicitly exercises every public path that calls apply or clearWorkspaceDerivedState: start normal replacement, createWorkspaceIfNeeded, createSeparateLocalWorkspace, returnToPreservedWorkspaceRecovery, successful and failed restoreEncryptedBackup(from:), chooseExistingWorkspaceFolder external replacement and cancellation-to-recovery, closeWorkspace, and teardown. Preserve each path's existing active-ID contract: unchanged for non-replacing exits, replaced only where that existing transition replaces the workspace. Use the existing bookmark/separate-workspace test fixtures without exposing a key or path.

- [ ] **Step 4: Implement the token-scoped event**

Add adjacent to current protected-export state:

~~~
struct ProtectedExportSuccess: Equatable {
    let displayFilename: String
}

private struct ProtectedExportOperationToken: Equatable {
    let value = UUID()
}

@Published private(set) var protectedExportSuccess: ProtectedExportSuccess?
private var protectedExportOperationToken = ProtectedExportOperationToken()

private func invalidateProtectedExportOperation() {
    protectedExportOperationToken = ProtectedExportOperationToken()
    protectedExportSuccess = nil
}

func dismissProtectedExportSuccess() {
    protectedExportSuccess = nil
}
~~~

Call invalidateProtectedExportOperation before every new review, in cancelProtectedExport(), in every review/confirm invalid-input, destination-cancel, catch, and stale/early-return terminal branch, at the start of clearWorkspaceDerivedState(), and in apply before replacing or leaving the current store. Confirmation captures let operationToken = protectedExportOperationToken before its task. Its only event publication is:

~~~
guard self.protectedExportOperationToken == operationToken, self.store === store else { return }
self.protectedExportSuccess = .init(displayFilename: review.displayFilename)
~~~

The injected production-default closure is called at the existing store-create location. No Core/export behavior changes. A current-token failure invalidates before publishing the existing safe error. A stale token/store completion may finish only its own busy bookkeeping; it cannot mutate review, error, status, or success.

Extend SettingsRootModalPresentation with only protectedExportSuccess: ProtectedExportSuccess?, isProtectedExportSuccessPresented, protectedExportSuccessDisplayFilename, and fixed protectedExportSuccessDestinationLabel. Add only:

~~~
static func dismissProtectedExportSuccess(
    dismissProtectedExportSuccess: () -> Void
) {
    dismissProtectedExportSuccess()
}
~~~

ContentView projects model.protectedExportSuccess into this value. Task 1 does not render a dialog or close a sheet.

- [ ] **Step 5: Run the exact signed Task 1 matrix**

Run the Task 1 brief matrix verbatim with /private/tmp/rekon-vd207x-task-1-red-dd and /private/tmp/rekon-vd207x-task-1-red.xcresult.

Expected: every event/root, fixture-host, recovery UI, archive, purge, restore, separate-workspace, and Core selector runs exactly once and passes with zero skip/expected failure. Only the three reference methods fail, and only in declared VD2-07x RED: unrendered visual selector activities. Inspect the result summary and test list.

---

### Task 2: Render the reference panels and root dialog

**Files:** Modify SettingsView.swift, ContentView.swift, RekonPursuitUITests.swift, and necessary Task-2 test/host files. Modify project.pbxproj only if SettingsView.swift is not already registered once in both app targets; isolate only source-reference/build-file/two target-membership hunks.

**Consumes:** accepted Task 1 token/event contract and green operation baseline.

**Produces:** all four reference panels, root-owned dialog, full green matrix, and named screenshot evidence.

- [ ] **Step 1: Prove project membership**

~~~
git hash-object RekonPursuit.xcodeproj/project.pbxproj
git diff -- RekonPursuit.xcodeproj/project.pbxproj
rg -n "SettingsView.swift" RekonPursuit.xcodeproj/project.pbxproj
~~~

Expected: leave the project file untouched when both memberships already exist.

- [ ] **Step 2: Render tabs and safe display panels**

Render SettingsReferenceTab with folder, externaldrive, doc, and link; cool-gray inactive icon/copy; cyan selected icon/copy/bottom rule; generous target; the existing section identifiers; and a full-width divider. Preserve:

~~~
.focusable()
.focused($focusedSection, equals: section)
.onKeyPress(.space) {
    selectedSection = section
    return .handled
}
.accessibilityValue(selectorAccessibilityValue(for: section))
~~~

ViewThatFits may replace only the complete labeled tab row with a complete labeled vertical stack. Render Recovery from SettingsArchiveSummary only and retain the existing action closures/disabled/busy/error/cancel predicates. Render Workspace, Document, and AI exactly to the Task-1 green copy/control rules. Use RekonCard, RekonTheme.borderSubtle, RekonTheme.success, RekonTheme.secondaryText, and existing primary style; do not alter theme values.

- [ ] **Step 3: Render the root-owned string-only success dialog**

Define:

~~~
struct SettingsProtectedExportSuccessDialog: View {
    let displayFilename: String
    let dismiss: () -> Void
}
~~~

Its root identifier is settings-protected-export-success-dialog. It renders checkmark.circle, Protected copy exported, the supplied filename, Selected local folder, the non-secret recovery-key reminder, and a Done button identified settings-protected-export-success-done using RekonPrimaryButtonStyle. It accepts no review, URL, key, bookmark, receipt, fingerprint, archive row, document value, or model.

At ContentView root, observe non-nil success, then set only isPresentingProtectedExport = false and protectedExportReentry = "" before overlaying the dialog. Do not clear the event at that point. Present only while settingsRootModalPresentation.isProtectedExportSuccessPresented. Existing cancel/error sheets stay root-owned and cannot overlay success. Done calls only SettingsRootModalBindings.dismissProtectedExportSuccess { model.dismissProtectedExportSuccess() }; it does not mutate route, workspace, review, export, or recovery state.

- [ ] **Step 4: Turn reference tests green and attach fixture evidence**

Keep the four Task-1 methods and every exact assertion. Once their visual gates exist, attach signed-host screenshots after each selected section with XCTAttachment(screenshot: app.screenshot()), lifetime keepAlways, and these exact names:

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

Never attach a recovery key, raw file panel, absolute path, or document metadata.

- [ ] **Step 5: Run the exact signed Task 2 matrix**

Run the Task 1 brief matrix verbatim, changing only result paths to /private/tmp/rekon-vd207x-task-2-green-dd and /private/tmp/rekon-vd207x-task-2-green.xcresult.

Expected: every selector, including all four event tests and all four reference methods, runs exactly once with zero failures, skips, and expected failures.

- [ ] **Step 6: Produce and inspect visual evidence**

~~~
mkdir -p /private/tmp/rekon-vd207x-visual-evidence
xcrun xcresulttool get test-results summary --path /private/tmp/rekon-vd207x-task-2-green.xcresult
xcrun xcresulttool get test-results tests --path /private/tmp/rekon-vd207x-task-2-green.xcresult
xcrun xcresulttool export attachments --path /private/tmp/rekon-vd207x-task-2-green.xcresult --output-path /private/tmp/rekon-vd207x-visual-evidence/fixture-attachments
find /private/tmp/rekon-vd207x-visual-evidence -type f -print
~~~

Open the eight named fixture attachments beside the approved reference images. Compare global rail, Settings hierarchy, cyan active icon/text/rule, outlined cards, wide/compact layout, Recovery action row, Workspace disabled return card, aggregate-only Document cards, and AI unavailable treatment. Inspect every image for recovery keys, absolute paths, document names, hashes, bookmarks, checksums, MIME types, and other document metadata; reject any disclosure.

For the dialog, build and launch the signed normal Debug app. A tester uses an ordinary enrolled local workspace, their own recovery key, and a newly empty local destination to complete the existing review/confirmation flow. Do not record or screenshot the key, destination chooser, or raw path. With the dialog visible, save exactly /private/tmp/rekon-vd207x-visual-evidence/VD2-07x-real-export-success.png with the macOS screenshot tool, select Done, and verify the active workspace is unchanged. Inspect it beside the reference: it shows only safe filename, Selected local folder, reminder, and Done. Record pass/fail and the outside-repository image path; do not commit the image.

---

### Task 3: Signed verification and gated handoff

- [ ] **Step 1: Build and verify both signed targets**

~~~
xcodebuild build -project RekonPursuit.xcodeproj -scheme RekonPursuit -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath /private/tmp/rekon-vd207x-task-3-app-dd
xcodebuild build -project RekonPursuit.xcodeproj -scheme RekonPursuitUITestHost -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath /private/tmp/rekon-vd207x-task-3-host-dd
find /private/tmp/rekon-vd207x-task-3-app-dd /private/tmp/rekon-vd207x-task-3-host-dd -name '*.app' -type d -print0 | while IFS= read -r -d '' app_path; do
  codesign --verify --deep --strict "$app_path"
  codesign -dvv "$app_path"
done
~~~

- [ ] **Step 2: Inspect scope and checkpoint accepted hunks only**

~~~
git diff --check
git diff -- RekonPursuit/WorkspaceViewModel.swift RekonPursuit/ContentView.swift RekonPursuit/SettingsView.swift RekonPursuit.xcodeproj/project.pbxproj RekonPursuitTests/WorkspaceViewModelTests.swift RekonPursuitUITests/RekonPursuitUITests.swift RekonPursuitUITestHostTests/RekonPursuitUITestHostTests.swift
git diff --cached --name-only
git diff --cached
git diff --cached --check
~~~

Expected: only event/token/root/visual/test hunks; no fixture-host, launch parser, Core, signing, entitlement, network, key, path, or document-metadata hunk.

- [ ] **Step 3: Obtain independent release decisions**

1. Code Review verifies visual/spec fidelity, exact allowlist, and code quality.
2. QA verifies both result bundles, zero skips, exact RED-to-green transition, and visual evidence.
3. Architecture verifies token/store lifetime, root ownership, and no boundary widening.
4. Security/privacy verifies gated cancellation, no event after failure/transition, all artifacts, and no sensitive transport.
5. TPM and Delivery record risks, evidence paths, approvals, and product-owner handoff.

## Completion evidence

VD2-07x is complete only after hunk-isolated accepted checkpoints, both exact signed matrices, strict signing verification, all nine visual images, independent approvals, and product-owner acceptance. VD2-08 remains open.
