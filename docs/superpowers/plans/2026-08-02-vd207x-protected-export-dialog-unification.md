# VD2-07x protected-export dialog unification implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace only the protected-export entry and confirmation stock sheets with one root-owned custom navy dialog that visually belongs to the existing real-success dialog while preserving the complete export flow.

**Architecture:** `ContentView` continues to own all presentation state, recovery-key binding, ViewModel calls, native Save-panel invocation, cancellation, and success dismissal. `SettingsView` adds a presentation-only, two-mode dialog that receives safe display values and action closures; the root overlay selects either that in-progress dialog or the unchanged real-success dialog, never both.

**Tech Stack:** Swift, SwiftUI, AppKit `NSSavePanel`, XCTest/XCUITest, existing Rekon visual theme and signed macOS Debug build.

## Global Constraints

- Change only `RekonPursuit/ContentView.swift`, `RekonPursuit/SettingsView.swift`, the focused existing UI-test hunk, and delivery evidence for this slice.
- Retain existing export, review, native Save panel, filename-extension, sandbox entitlement, persistence, activity, and real-success behavior exactly as is.
- The dialog receives no destination URL, recovery-key value beyond its existing binding, receipt, store, workspace data, or persistence dependency.
- Preserve the current error copy, error selector, reviewed-export retention, cancellation behavior, recovery-key clearing, primary labels, busy disablement, and `keyboardShortcut(.defaultAction)` behavior.
- Never log, attach, or record a recovery key, raw destination path, export payload, database, Finder window, or document metadata.
- Keep the success dialog unchanged and show it only after an actual verified export. Do not add a fixture, demo state, launch argument, or test-only success path.
- Do not alter other recovery sheets, Settings navigation, the Kanban/dashboard, the global theme, or VD2-08 accessibility work.

---

## File structure and boundary

| Path | Responsibility in this slice |
| --- | --- |
| `RekonPursuit/ContentView.swift` | Replaces the protected-export stock `.sheet` with its existing root state/action wiring inside the single root overlay. |
| `RekonPursuit/SettingsView.swift` | Defines the presentation-only entry/confirmation dialog and its safe two-mode display contract beside the existing success dialog. |
| `RekonPursuitUITests/RekonPursuitUITests.swift` | Adds one focused invalid-key protected-export journey to prove it is app-owned custom-dialog presentation, then proves the retained inline-error/cancel behavior. |
| `docs/delivery/reviews/` and `.superpowers/sdd/` | Records independent gate, implementation, review, QA, security, and owner-native evidence after each decision. |

### Task 1: Deliver the protected-export dialog as one bounded vertical slice

**Files:**

- Modify: `RekonPursuit/ContentView.swift:68-89,207-252,542-555`
- Modify: `RekonPursuit/SettingsView.swift:after SettingsProtectedExportSuccessDialog`
- Modify: `RekonPursuitUITests/RekonPursuitUITests.swift` by adding `testVD207ProtectedExportEntryUsesRootDialogAndRetainsErrorUntilCancel`
- Record: `docs/delivery/reviews/` and `.superpowers/sdd/`

**Interfaces:**

- Consumes: `Binding<String>` for the already root-owned `protectedExportReentry`; `ProtectedExportReview?` projected only to its existing `displayFilename`; `String?` current controlled error; `Bool` current export-busy state; and root-owned cancel/primary closures.
- Produces: `SettingsProtectedExportDialogMode.entry` or `.confirmation(displayFilename:)` and `SettingsProtectedExportDialog`, a presentation-only view with no ViewModel, URL, persistence, or export-worker dependency.
- Preserves: `WorkspaceViewModel.reviewProtectedExport(reentry:)`, `confirmProtectedExport(reentry:)`, `cancelProtectedExport()`, `protectedExportSuccess`, and the `SettingsProtectedExportSuccessDialog` contract unchanged.

- [ ] **Step 1: Write the focused RED UI contract without any recovery material.**

  Add this complete new test method beside the existing VD2-07x recovery tests:

  ```swift
  @MainActor
  func testVD207ProtectedExportEntryUsesRootDialogAndRetainsErrorUntilCancel() {
      let app = launchApp(fixture: "archive")
      app.descendants(matching: .any)["sidebar-settings"].tap()
      app.buttons["create-protected-export"].tap()

      XCTAssertTrue(app.staticTexts["Export protected copy"].waitForExistence(timeout: 2))
      XCTAssertTrue(app.textFields["Recovery key"].exists)
      XCTAssertTrue(app.buttons["Choose destination and review"].exists)
      XCTAssertEqual(app.sheets.count, 0)

      app.buttons["Choose destination and review"].tap()
      let error = app.staticTexts["protected-export-error"]
      XCTAssertTrue(error.waitForExistence(timeout: 2))
      XCTAssertEqual(error.label, "Enter the complete recovery key, including its checksum.")
      XCTAssertTrue(app.staticTexts["Export protected copy"].exists)
      XCTAssertTrue(app.textFields["Recovery key"].exists)
      XCTAssertTrue(app.buttons["Choose destination and review"].exists)
      XCTAssertEqual(app.sheets.count, 0)
      XCTAssertFalse(app.descendants(matching: .any)["settings-protected-export-success-dialog"].exists)

      app.buttons["Cancel"].tap()
      XCTAssertFalse(error.exists)
      XCTAssertFalse(app.staticTexts["Export protected copy"].exists)
      XCTAssertEqual(app.sheets.count, 0)
      XCTAssertTrue(app.buttons["create-protected-export"].waitForExistence(timeout: 2))
  }
  ```

  This is a UI-presentation test, not VD2-08 accessibility work. Do not add a recovery-key fixture, type any key, make a native Save panel test-only, or alter deferred accessibility tests.

- [ ] **Step 2: Run the focused UI selector and verify an executable RED.**

  Run:

  ```bash
  xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit \
    -configuration Debug -destination 'platform=macOS,arch=arm64' \
    -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207ProtectedExportEntryUsesRootDialogAndRetainsErrorUntilCancel \
    -derivedDataPath /private/tmp/rekon-vd207x-dialog-unification-red-dd \
    -resultBundlePath /private/tmp/rekon-vd207x-dialog-unification-red.xcresult
  xcrun xcresulttool get test-results summary --path /private/tmp/rekon-vd207x-dialog-unification-red.xcresult
  ```

  Expected: the new test executes once and fails only because the current entry form is a stock sheet (`app.sheets.count == 1`). The pre-existing invalid-key error and cancel journey must still reach their assertions; a build failure, skip, fixture failure, or native-panel interaction is not an acceptable RED.

- [ ] **Step 3: Replace the stock sheet with the minimum root-owned overlay and presentation-only dialog.**

  In `ContentView`, remove only `.sheet(isPresented: $isPresentingProtectedExport)`. Keep `isPresentingProtectedExport`, `protectedExportReentry`, the success `onChange`, and the same three ViewModel calls. Move the existing review-change clearing rule to a root modifier:

  ```swift
  .onChange(of: model.protectedExportReview) { _, review in
      if review != nil { protectedExportReentry = "" }
  }
  ```

  Make the existing root overlay mutually exclusive:

  ```swift
  .overlay {
      if isPresentingProtectedExport {
          ZStack {
              Color.black.opacity(0.52).ignoresSafeArea()
              SettingsProtectedExportDialog(
                  mode: model.protectedExportReview.map {
                      .confirmation(displayFilename: $0.displayFilename)
                  } ?? .entry,
                  recoveryKey: $protectedExportReentry,
                  errorMessage: settingsRootModalPresentation.protectedExportErrorMessage,
                  isBusy: model.isCreatingProtectedExport,
                  cancel: {
                      model.cancelProtectedExport()
                      isPresentingProtectedExport = false
                      protectedExportReentry = ""
                  },
                  primaryAction: {
                      if model.protectedExportReview != nil {
                          model.confirmProtectedExport(reentry: protectedExportReentry)
                          protectedExportReentry = ""
                      } else {
                          model.reviewProtectedExport(reentry: protectedExportReentry)
                      }
                  }
              )
          }
      } else if settingsRootModalPresentation.isProtectedExportSuccessPresented,
                let displayFilename = settingsRootModalPresentation.protectedExportSuccessDisplayFilename {
          ZStack {
              Color.black.opacity(0.52).ignoresSafeArea()
              SettingsProtectedExportSuccessDialog(
                  displayFilename: displayFilename,
                  dismiss: dismissProtectedExportSuccess
              )
          }
      }
  }
  ```

  In `SettingsView`, add the enum and dialog directly beside `SettingsProtectedExportSuccessDialog`:

  ```swift
  enum SettingsProtectedExportDialogMode: Equatable {
      case entry
      case confirmation(displayFilename: String)
  }

  struct SettingsProtectedExportDialog: View {
      let mode: SettingsProtectedExportDialogMode
      @Binding var recoveryKey: String
      let errorMessage: String?
      let isBusy: Bool
      let cancel: () -> Void
      let primaryAction: () -> Void
  }
  ```

  The view must use the success dialog's `560`-point elevated navy rounded panel, border, and single outer shadow. Above the form, show the same centered icon-area treatment but with an emerald `shield.checkered` symbol. Use the exact current entry and confirmation title/copy. When mode is `.confirmation(displayFilename:)`, render a `RekonCard` with exactly `Filename`, `Selected local folder`, and `Active tracker workspace data`; never render a path. Render `errorMessage` unchanged immediately above the form using `protected-export-error`. Use the existing `TextField("Recovery key", text: $recoveryKey).textFieldStyle(.roundedBorder)`. Place the primary action in a `Button` label whose `Text` has `.frame(maxWidth: .infinity)` before `RekonPrimaryButtonStyle`; keep the primary label exact for its mode, disable it with `isBusy`, and retain `.keyboardShortcut(.defaultAction)`. Implement Cancel exactly as `Button("Cancel", role: .cancel, action: cancel).keyboardShortcut(.cancelAction)` so the custom root overlay preserves the current Escape/cancel semantics while invoking only the root callback. Do not add or change accessibility identifiers for this visual slice; retain the existing `protected-export-error` and success-dialog identifiers unchanged.

- [ ] **Step 4: Run focused GREEN and inspect the exact slice.**

  Run:

  ```bash
  xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit \
    -configuration Debug -destination 'platform=macOS,arch=arm64' \
    -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207ProtectedExportEntryUsesRootDialogAndRetainsErrorUntilCancel \
    -derivedDataPath /private/tmp/rekon-vd207x-dialog-unification-green-dd \
    -resultBundlePath /private/tmp/rekon-vd207x-dialog-unification-green.xcresult
  xcrun xcresulttool get test-results summary --path /private/tmp/rekon-vd207x-dialog-unification-green.xcresult
  xcrun xcresulttool get test-results tests --path /private/tmp/rekon-vd207x-dialog-unification-green.xcresult
  xcodebuild build -project RekonPursuit.xcodeproj -scheme RekonPursuit \
    -configuration Debug -destination 'platform=macOS,arch=arm64' \
    -derivedDataPath /private/tmp/rekon-vd207x-dialog-unification-build-dd
  git diff --check
  ```

  Expected: the new UI method executes once with no skip or expected failure; it proves no stock sheet, the entry title/controls, unchanged invalid-key error, no invented success, and Cancel behavior. The existing protected-export model selectors below retain the non-happy-path and safe-success contract. The app builds. Diff inspection must show no ViewModel, worker, store, entitlement, native-panel, success-content, dashboard, or VD2-08 accessibility change.

  Also run the existing model protections without modifying their test file:

  ```bash
  xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit \
    -configuration Debug -destination 'platform=macOS,arch=arm64' \
    -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testProtectedExportReviewFailureRemainsVisibleForCorrection \
    -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testProtectedExportInvalidFilenameUsesExactCorrectionMessage \
    -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testCancellingReviewedProtectedExportClearsReviewWithoutWritingOrChangingActiveWorkspace \
    -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testCancellingConfirmedProtectedExportInvalidatesInFlightOperation \
    -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testProtectedExportUnavailableSelectedLeafConfirmUsesExactCorrectionMessage \
    -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testProtectedExportPostCreateFailureRetainsMayRemainFeedback \
    -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testVerifiedProtectedExportPublishesSafeSuccessAndRootPresentationOnlyAfterRealWriting \
    -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testProtectedExportSuccessRemainsNilForEveryNonSuccessBranch \
    -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testProtectedExportSuccessClearsForEveryWorkspaceTransition \
    -derivedDataPath /private/tmp/rekon-vd207x-dialog-unification-model-dd \
    -resultBundlePath /private/tmp/rekon-vd207x-dialog-unification-model.xcresult
  xcrun xcresulttool get test-results summary --path /private/tmp/rekon-vd207x-dialog-unification-model.xcresult
  xcrun xcresulttool get test-results tests --path /private/tmp/rekon-vd207x-dialog-unification-model.xcresult
  ```

- [ ] **Step 5: Commit only this slice after independent review release.**

  Before staging, inspect the limited diff:

  ```bash
  git diff -- RekonPursuit/ContentView.swift RekonPursuit/SettingsView.swift RekonPursuitUITests/RekonPursuitUITests.swift
  git diff --check
  ```

  Because these files contain unrelated owner work, use `git add -p` and stage only the protected-export overlay/dialog and the new focused test. Confirm the temporary index contains no unrelated hunk, then commit:

  ```bash
  git add -p -- RekonPursuit/ContentView.swift RekonPursuit/SettingsView.swift RekonPursuitUITests/RekonPursuitUITests.swift
  git diff --cached --check
  git commit -m "fix: unify protected export dialogs"
  ```

## Post-implementation verification and handoff

1. A fresh reviewer verifies that only the approved files/hunks changed, the stock protected-export `.sheet` is gone, both custom modes share the success-dialog shell, one protected-export overlay is possible, and no safe-data or action boundary widened.
2. A fresh QA verifier independently reruns the focused UI methods and build, confirms the RED/GREEN outcomes from their result bundles, and confirms error/cancel behavior remains in the custom entry dialog without an introduced key fixture.
3. A fresh security/privacy verifier confirms no key, raw path, export bytes, URL, persistence, or native Save-panel behavior was added to the dialog or tests.
4. The owner performs the real signed Debug flow and records only pass/fail state observations. They attest that (a) the entry state is the custom navy dialog; (b) its existing primary action opens the native chooser in front of that dialog; (c) returning from a valid local selection shows the custom confirmation dialog—not a stock sheet—with filename-only safe facts; and (d) verified completion dismisses the in-progress dialog before the unchanged success dialog appears. Keep recovery material and destination local; do not retain screenshots, paths, Finder/file-chooser views, export content, or database data.
5. The Delivery Manager records the independent decisions and owner result, updates the dashboard only if the full VD2-07x completion transition is justified, and releases no VD2-08 work.

## Plan self-review

- **Spec coverage:** Task 1 covers the entry and confirmation shell, exact current form/copy/actions, safe facts, controlled errors, exclusive root overlay, unchanged real success, focused automated error/cancel proof, and owner-native actual-save proof. It excludes all stated out-of-scope systems.
- **Placeholder scan:** No task step relies on a future design choice, generic test instruction, or unnamed interface; the dialog mode, initializer inputs, selectors, expected RED/GREEN behavior, commands, and staging boundary are written above.
- **Type consistency:** `SettingsProtectedExportDialogMode`, `SettingsProtectedExportDialog`, `recoveryKey`, `errorMessage`, `isBusy`, `cancel`, and `primaryAction` use the same names from the code step through verification. `displayFilename` remains the sole reviewed filename input.
