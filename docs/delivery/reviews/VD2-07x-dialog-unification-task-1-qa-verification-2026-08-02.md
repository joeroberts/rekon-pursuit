# VD2-07x Task 1 — Dialog unification QA verification

**Status:** PASS

## Independent verification scope

Verified the Task 1 brief, the implementer report, the recorded preimage hunk review, and the live working tree. This verification was read-only except for this QA record. No recovery material, destination, export content, or user data was created or retained.

## Automated evidence

| Check | Independent command/result | Outcome |
| --- | --- | --- |
| Focused UI contract | `xcodebuild test` for `RekonPursuitUITests/testVD207ProtectedExportEntryUsesRootDialogAndRetainsErrorUntilCancel`, isolated DerivedData/result bundle under `/private/tmp/rekon-vd207x-dialog-unification-qa-ui-*` | PASS: summary reports 1 passed, 0 failed, 0 skipped, 0 expected failures; detailed results identify exactly the released UI method as Passed. |
| Retained protected-export model protections | `xcodebuild test` with the nine named `WorkspaceViewModelTests` selectors, isolated `/private/tmp/rekon-vd207x-dialog-unification-qa-model-*` paths | PASS: summary reports 9 passed, 0 failed, 0 skipped, 0 expected failures; detailed results list all nine selected tests as Passed. |
| Signed Debug build | `xcodebuild build -project RekonPursuit.xcodeproj -scheme RekonPursuit -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath /private/tmp/rekon-vd207x-dialog-unification-qa-build-dd` | PASS: `BUILD SUCCEEDED`; the build completed code signing. |
| Whitespace/errors | `git diff --check` | PASS: no output. |

The focused UI result contains an existing runtime warning about main-thread invocation, but it did not fail or skip the test and is not introduced evidence of this dialog slice.

## RED evidence audit

Inspected the recorded `/private/tmp/rekon-vd207x-dialog-unification-red.xcresult` summary and detailed test result. It executed the new method once; the bundle reports 1 failed, 0 passed, 0 skipped, and 0 expected failures. Its only failure messages were the two stock-sheet-count assertions in that method: each observed `1` where `0` was expected. No build, fixture, native-panel, key-entry, skip, or unrelated assertion failure is recorded. This confirms the reported RED was executable and failed only because the legacy entry form was a stock sheet.

## Working-tree and coverage assessment

The live preimage comparison against the retained Task 1 baseline reports exactly the approved delta sizes:

- `RekonPursuit/ContentView.swift`: 30 additions / 43 removals — root review clearing plus sheet-to-exclusive-overlay replacement.
- `RekonPursuit/SettingsView.swift`: 101 additions — append-only presentation mode and dialog beside the existing success dialog.
- `RekonPursuitUITests/RekonPursuitUITests.swift`: 28 additions — the one focused entry/error/cancel contract.

Manual source review confirms the protected-export sheet is absent; entry and confirmation share the existing 560-point elevated dialog shell; the root overlay is mutually exclusive with unchanged success presentation; the controlled invalid-key error is retained; Cancel invokes the root callback; and the new test supplies no recovery key or native Save-panel interaction. The reviewed slice adds no ViewModel, worker, persistence, export-data, raw-path, URL, success-content, dashboard, or new accessibility-identifier behavior.

Coverage is sufficient for this Task 1 UI presentation slice: the focused UI contract proves custom entry presentation, no stock sheet before or after invalid submission, unchanged correction text, no invented success, and Cancel dismissal. The nine model tests retain correction, cancellation, unavailable destination, post-create failure, verified-safe-success, and workspace-transition protections. Confirmation after a real local destination and final real-save behavior remain intentionally reserved for the required owner-native checklist.

## Release condition

QA release condition is satisfied for Task 1. Do not treat VD2-07x as complete or release VD2-08 on this record alone: acceptance still requires the separate code-review, architecture, security/privacy, TPM/delivery decisions and the owner’s signed Debug native-flow attestation required by the task brief. Stage or commit only the approved Task 1 hunks after those gates release it.
