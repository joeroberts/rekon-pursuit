# VD2-07x protected-export dialog unification design

## Status

Approved visual direction pending review of this written specification. This
document authorizes no production edit until the independent delivery gates for
the resulting implementation plan release a fresh implementer.

## Problem and evidence

The successful protected-export state uses the approved custom navy dialog:
an app-level dimmer, elevated rounded panel, restrained border, centered
icon/title treatment, a safe facts card, and a full-width gradient action.

The destination-review and confirmation states still use the stock SwiftUI
sheet in `ContentView`. In the signed owner flow, those two gray macOS sheets
visibly break the otherwise consistent protected-export journey.

## Decision

Replace only the two in-progress protected-export sheets with a root-owned
custom modal that shares the success dialog's presentation language.

The new modal has two content modes inside one consistent shell:

1. **Destination review** — emerald shield-in-circle, “Export protected copy”
   title, existing explanatory copy, recovery-key entry, and existing “Choose
   destination and review” primary action.
2. **Confirmation** — emerald shield-in-circle, “Confirm protected export”
   title, existing explanatory copy, a bordered safe facts card for filename,
   selected local folder, and active tracker workspace data, recovery-key
   re-entry, and existing “Confirm and export” primary action.

Both use the same full-window dimmer, elevated navy rounded panel, border,
spacing cadence, safe text colors, field treatment, cancel control, and
full-width `RekonPrimaryButtonStyle` label treatment used by
`SettingsProtectedExportSuccessDialog`. Contextual shield iconography replaces
the success checkmark; the shell itself is not redesigned.

Any controlled export error remains in the same modal state directly above its
form, with the existing error copy unchanged. It does not close the flow,
leak a path, or change the reviewed export.

## Architecture and state contract

`ContentView` remains the root presenter and continues to own:

- `isPresentingProtectedExport`;
- `protectedExportReentry`;
- opening the existing native `NSSavePanel` through the current ViewModel
  review action;
- cancellation, key clearing, and the existing success-state transition.

`SettingsView` gains a presentation-only dialog component that receives only
safe display data and closures/bindings already owned by `ContentView`:
review-or-confirm mode, safe filename when reviewed, fixed “Selected local
folder” label, the existing user-entered recovery-key binding, current busy
state, controlled error text, and cancel/primary actions. It receives no URL,
recovery key value outside the existing binding, receipt, store, workspace
data, or persistence dependency.

The root overlay presents exactly one protected-export state at a time:

1. the custom in-progress dialog while `isPresentingProtectedExport` is true;
2. the existing success dialog only after the real verified success event and
   the in-progress dialog has been dismissed.

The native Save panel remains untouched and continues to sit in front of the
in-progress dialog after its existing primary action is invoked. No permission,
security scope, export worker, database, event, activity, file-extension,
or entitlement behavior changes.

## Scope

| Path | Allowed work |
| --- | --- |
| `RekonPursuit/ContentView.swift` | Replace only the protected-export stock sheet with the root custom-overlay presentation and preserve its current action/state wiring. |
| `RekonPursuit/SettingsView.swift` | Add only the presentation-only in-progress protected-export dialog and reuse the success dialog’s shell conventions. |
| Focused tests and delivery records | Add only tests that prove presentation state/action continuity and record independent reviews. |

Out of scope: the success dialog content and timing; all export/security logic;
native file-panel configuration; recovery-key handling and text; Settings
sub-navigation; theme-wide button styles; recovery archive, restore, purge,
contacts, home, pipeline, dashboard, roadmap, and VD2-08 accessibility work.

## Acceptance criteria

- The entry and confirmation screenshots read as the same dialog family as
  the successful export dialog, not as gray system sheets.
- Entry preserves the existing recovery-key field, cancel behavior, primary
  label, busy disablement, and native destination-selection flow.
- Confirmation preserves the safe filename-only facts, selected-local-folder
  label, active-data label, recovery-key re-entry, cancel behavior, primary
  label, busy disablement, and reviewed-export state.
- Controlled errors remain in context, retain the reviewed export when the
  current behavior does, and reveal neither paths nor key material.
- The success dialog appears only after a real verified export, unchanged.
- The root app displays one protected-export overlay at a time; cancellation,
  failure, and success clear the same state as before.
- Focused automated tests and a signed owner-native run cover entry,
  review/native selection, confirmation, cancellation/error continuity, and
  post-success presentation without recording a recovery key, raw destination
  path, export data, or database.

## Considered approaches

1. **Recommended: one custom modal with two content modes.** It provides one
   coherent flow and shares the success dialog’s visual rules without changing
   ViewModel/export state or native panel behavior.
2. Restyle the existing SwiftUI sheet. This retains the gray window/chrome and
   cannot match the root success dialog’s presentation closely enough.
3. Convert all recovery sheets to the new shell. This is a broader visual
   system change and is outside this owner-reported defect.

## Verification plan

Before code, independent planning, architecture, QA, security/privacy, TPM,
and Delivery Manager gates must release one bounded task. A fresh implementer
will use test-first changes. A separate fresh reviewer and QA verifier will
check the narrowed diff, state/action continuity, error/cancel behavior, and
focused test evidence. The signed owner build must again run the real native
Save-panel path through success; the owner will keep recovery material local
and report only redacted result evidence.
