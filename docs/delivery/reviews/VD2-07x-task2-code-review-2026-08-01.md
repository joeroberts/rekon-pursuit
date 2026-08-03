# VD2-07x Task 2 — independent code review

**Date:** 2026-08-01  
**Reviewer role:** Independent code reviewer  
**Scope inspected:** `RekonPursuit/SettingsView.swift`,
`RekonPursuit/ContentView.swift`, and
`RekonPursuitUITests/RekonPursuitUITests.swift`; Task 2 brief, approved
owner-feedback amendment, Task 2 report, and current signed app-window
attachments. No implementation tests were rerun and no source, test, or
dashboard file was changed by this review.

## Verdict

| Area | Verdict |
| --- | --- |
| Specification compliance | **Reject — revision required** |
| Code quality | **Needs revision** |

The wide local selector is reference-aligned, and the compact selector has the
approved replacement treatment: its selected row is a cyan-tinted rounded
surface with cyan icon/text and no compact underline. The pointer companion
test uses `app.windows.firstMatch.screenshot()`, exercises all four local
selectors, and does not relax the carried VD2-08 keyboard or AI assertions.

The protected-export presentation preserves the narrow real-success boundary:
the root observes the existing non-nil success event, closes only the export
sheet and clears re-entry text, passes only the display filename and dismissal
closure to the dialog, and Done reaches only
`model.dismissProtectedExportSuccess()`. No Task 2 Settings source changes
introduce Pipeline/Kanban/data-surface behavior.

However, the owner-approved dialog correction is not ready for acceptance.

## Findings

### P1 — Primary action is not rendered full width

`SettingsProtectedExportSuccessDialog` applies `RekonPrimaryButtonStyle` and
only then expands the resulting view with `.frame(maxWidth: .infinity)`.
The button style paints its gradient background around its label before that
outer frame is applied, so the background remains the intrinsic `Done` button
rather than the full facts-panel width required by the reference and owner
amendment. The source also provides an outline but no dialog shadow, despite
the specified single elevated outline/shadow treatment.

**Location:** `RekonPursuit/SettingsView.swift:944-952`

**Required correction:** Size the button label to the dialog content width
*before* `RekonPrimaryButtonStyle` paints it (without changing the existing
style globally), and give the dialog its single deliberate elevation shadow.
Then capture and inspect a real-success app-window-only dialog against the
reference hierarchy: centered emerald check, heading, confirmation, bordered
two-row facts, reminder, and a visibly full-width gradient Done action.

### P1 — Required real-export dialog evidence is still absent

The Task 2 report records that the normal-Debug, real successful export capture
is still awaiting a tester. The available signed attachments prove the wide and
compact Settings surfaces, not the success dialog. Therefore there is no visual
evidence for the owner-reported dialog mismatch, nor for the required safe
facts and post-Done unchanged-workspace check in the normal app.

**Evidence:** `.superpowers/sdd/2026-08-01-vd207-reference-faithful-recovery-screen/task-2-report.md:103-112`

**Required correction:** Do not simulate this state. Complete the existing
real export flow in the signed normal Debug app, save only the app-window
capture to the approved outside-repository path, inspect it against the
reference, press Done, and record that the active workspace remains unchanged.

## Confirmed non-findings

- Wide Settings navigation retains cyan icon/text plus a cell-width bottom
  rule (`SettingsView.swift:223-240`, `346-363`).
- Compact navigation replaces that rule with the approved cyan-tinted rounded
  row and retains pointer selection (`SettingsView.swift:223-240`, `346-363`;
  `RekonPursuitUITests/RekonPursuitUITests.swift:3081-3104`).
- The app-window-only screenshot helper is correct
  (`RekonPursuitUITests/RekonPursuitUITests.swift:150-155`).
- The focused Document/AI visual boundary test preserves aggregate-only,
  no-control, and no-metadata assertions
  (`RekonPursuitUITests/RekonPursuitUITests.swift:3107-3161`).
- The three VD2-08 handoff tests remain executable assertions; no skip,
  expected-failure, retry, or guarded-continuation accommodation was added.

## Release condition

Keep Task 2 and V2-07x **in progress**. A fresh bounded revision must correct
the dialog visual defect, pass its focused regression coverage, and provide
the required real-success app-window evidence before this review can be
accepted.
