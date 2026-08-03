# VD2-07x Task 2 — security/privacy verification

**Date:** 2026-08-01  
**Role:** Independent Security/privacy verifier  
**Verdict:** **ACCEPT — the implemented Task 2 source preserves the required privacy and real-success boundary.**

## Scope and decision

This is a post-implementation review of the Task 2 Settings rendering and
root-owned protected-export success presentation. It accepts the constrained
source and focused evidence below. It is not final V2-07x release acceptance:
the required normal signed-Debug capture of a real successful export still
needs separate manual inspection, along with the remaining matrix and
independent release evidence.

I reviewed the controlling Task 2 brief, the VD2-08 accessibility deferral,
the Task 2 implementation-release record, and the owner-feedback visual
amendment. The amendment's privacy-relevant requirements are retained: a
dialog can show only a safe filename and `Selected local folder`, and Settings
attachments must contain the app window only. The changed visual hierarchy and
compact selection cue do not authorize any export, persistence, fixture,
route, or data-boundary change.

## Verified boundary

| Requirement | Evidence | Result |
| --- | --- | --- |
| A dialog is possible only after a real successful protected-export write. | `WorkspaceViewModel.confirmProtectedExport` awaits the existing `protectedExportCreate`, then requires both the current opaque operation token and the same store before assigning the filename-only event (`RekonPursuit/WorkspaceViewModel.swift:1355-1377`). Repository search found no fixture, launch argument, demo control, or other success assignment. | ACCEPT |
| Cancellation, failures, stale work, and workspace transitions cannot retain success. | The event/token invalidation path remains in `WorkspaceViewModel.swift:1318-1403`; the existing transition/clear-state hooks still invalidate it. | ACCEPT |
| Root presentation never receives export-sensitive data. | `ContentView` projects the event at the root (`RekonPursuit/ContentView.swift:81-98`, `542-553`). `SettingsRootModalPresentation` exposes only the filename plus the fixed `Selected local folder` label, and its success dismissal binding invokes only `model.dismissProtectedExportSuccess()` (`RekonPursuit/SettingsView.swift:117-182`). | ACCEPT |
| The rendered dialog does not add an unsafe channel. | `SettingsProtectedExportSuccessDialog` accepts only `displayFilename`; its second fact is the fixed local-folder label. It has no URL, recovery key, review, bookmark, receipt, archive, document, hash, or token input (`RekonPursuit/SettingsView.swift:909-956`). `Done` is bound solely to the root dismissal closure. | ACCEPT |
| Document and AI panels remain aggregate/informational. | The Document section reads only the aggregate summary and renders no controls; the AI section is offline informational cards and text only (`RekonPursuit/SettingsView.swift:769-907`). The focused UI test reasserts no actionable descendants and rejects filenames, hashes, MIME data, and local paths (`RekonPursuitUITests/RekonPursuitUITests.swift:3107-3162`). | ACCEPT |
| New Settings captures exclude the desktop and other apps. | The Settings attachment helper uses `app.windows.firstMatch.screenshot()` rather than an application/desktop capture (`RekonPursuitUITests/RekonPursuitUITests.swift:150-154`). I inspected the resulting `VD2-07x-wide-ai-connections` attachment: it is limited to the Rekon Pursuit window and contains no document metadata, raw local path, chooser, recovery key, or external-app content. Earlier desktop-inclusive evidence is explicitly rejected and was not used for this decision. | ACCEPT |

## Executed evidence

The focused signed Debug result bundle at
`/private/tmp/rekon-vd207x-task2-security.xcresult` is parseable and reports
three passes with zero failures, skips, or expected failures:

- `testVerifiedProtectedExportPublishesSafeSuccessAndRootPresentationOnlyAfterRealWriting`
- `testProtectedExportSuccessRemainsNilForEveryNonSuccessBranch`
- `testVD207SettingsRootModalBindingsDismissWithoutChangingActiveWorkspace`

The focused signed Debug result bundle at
`/private/tmp/rekon-vd207x-task2-security-ui.xcresult` is parseable and reports
one pass with zero failures, skips, or expected failures:

- `testVD207ReferenceAIVisualContentBoundary`

`swiftc -parse RekonPursuit/SettingsView.swift` and the compiled test runs
succeeded. `git diff --check` reported no whitespace errors for the tracked
Task 2 source/test paths. This review made no source, test, fixture, dashboard,
or route change.

## Remaining release evidence

Before V2-07x may be finally accepted, independently inspect the ordinary
signed-Debug dialog after a real export and confirm it shows only the safe
filename, `Selected local folder`, non-secret reminder, and `Done`. That
capture must be app-window-only. It cannot be replaced by a fixture, by this
focused result, or by any old desktop-inclusive image. The literal Task 2
matrix, its explicitly reported VD2-08 carried accessibility outcomes, and
the remaining independent reviews are also still required.
