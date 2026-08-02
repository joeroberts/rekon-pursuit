# VD2-07x Task 1 — Protected-export dialog unification architecture verification

**Date:** 2026-08-02
**Role:** Fresh independent post-implementation Architect
**Verdict:** **ACCEPT**

## Scope and method

Read-only acceptance against the Task 1 brief, implementation plan and report,
authoritative working-tree review package, current `ContentView.swift` and
`SettingsView.swift`, the pre-implementation architecture recheck, and the
post-implementation code review. No source, test, project, dashboard, ledger,
or index content was changed or staged.

## Architecture acceptance evidence

| Required contract | Exact implementation evidence | Result |
| --- | --- | --- |
| Root retains presentation, recovery-key binding, and export actions | `ContentView` owns `protectedExportReentry` and `isPresentingProtectedExport` at lines 46-47. Its single root overlay supplies the binding and all three existing ViewModel actions at lines 89-126. The dialog contains only injected values and callbacks (`SettingsView.swift:966-972`). | Accepted. |
| One exclusive protected-export overlay | The root overlay selects the entry/review dialog in the first branch (`ContentView.swift:90-115`) and the verified-success dialog only in the `else if` branch (`116-125`). Success observation first clears the in-progress presentation and re-entry text (`81-85`). | Accepted; no competing protected-export overlay can render. |
| Settings dialog has presentation inputs only | Its mode is `entry` or a filename-only confirmation value (`SettingsView.swift:961-972`); the root projects only `review.displayFilename` (`ContentView.swift:95-99`). The dialog declares no ViewModel, URL, worker, store, receipt, workspace, or persistence dependency. | Accepted. |
| Review/new-key clearing and cancel/default actions preserve behavior | Review transition still clears the root-held re-entry value (`ContentView.swift:86-88`). The root confirmation call clears it after dispatch and the review call is unchanged (`106-112`). Cancel invokes only the injected root closure; that closure performs the existing model cancellation, dismisses presentation, and clears the root value (`101-105`). The custom controls retain cancel role plus Escape semantics and the primary default action (`SettingsView.swift:1019-1028`). | Accepted. |
| Native Save panel and real-success timing/content did not move | The working-tree package identifies no `WorkspaceViewModel` hunk. The unchanged `reviewProtectedExport` retains destination selection (`WorkspaceViewModel.swift:1318-1332`), and success is still published only after the protected-export creation returns successfully (`1355-1377`). The root still dismisses the in-progress dialog only after that event (`ContentView.swift:81-85`) before presenting the unchanged success dialog (`116-124`). | Accepted. |
| Safe facts are filename and fixed labels only | The confirmation card receives the filename and renders only fixed labels `Selected local folder` and `Active tracker workspace data` with empty values (`SettingsView.swift:991-1000`). No locator, raw path, recovery material, receipt, or workspace payload crosses the boundary. | Accepted. |
| No unapproved architecture deviation | The review package limits the slice to the authorized `ContentView`, append-only Settings dialog, and focused UI-test hunk. The implementer report records no ViewModel, worker, store, persistence, native-panel, success-dialog, or accessibility change. The retained test evidence reports 1 focused UI pass, 9 model-protection passes, and a Debug build success. This conforms to the 2026-08-02 architecture recheck conditions without requiring an ADR. | Accepted. |

## Decision

Task 1 conforms to the approved root-owned presentation architecture. The
custom entry/review dialog is a bounded presentation component; protected
export operation, chooser, cancellation, state clearing, and real-success
publication authority remain at their established root/model seams. No
architecture deviation or ADR is required.

## Next gate

Architecture acceptance is complete. The Delivery Manager may record this
decision only after the separate QA and Security/privacy verifications and the
owner-controlled signed-Debug native chooser, confirmation, and real-success
observation are recorded. This verification does not release VD2-08 work or
authorize a dashboard/roadmap transition.
