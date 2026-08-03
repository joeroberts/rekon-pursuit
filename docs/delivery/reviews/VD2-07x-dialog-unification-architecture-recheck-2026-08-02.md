# VD2-07x protected-export dialog unification — Architecture recheck

**Date:** 2026-08-02
**Role:** Fresh independent Architect
**Scope:** Recheck only the prior custom root-overlay cancellation concern.

## Verdict: ACCEPT

The amended implementation plan resolves the sole prior architecture finding.
It explicitly retains both the cancel role and cancel keyboard shortcut on the
custom-dialog control, while keeping all cancellation effects in the root
callback. This preserves the pre-existing Escape/cancel semantic without
granting the presentation component state, model, destination-selection, or
persistence authority.

## Evidence

| Rechecked contract | Evidence in approved artifacts | Architecture result |
| --- | --- | --- |
| Custom Cancel preserves cancellation semantics | The prior architecture gate required the custom control to retain a cancel role (or an exactly equivalent cancel-action semantic). The amended plan now requires `Button("Cancel", role: .cancel, action: cancel).keyboardShortcut(.cancelAction)`. | Resolved. A visible Cancel activation and the cancel keyboard action both dispatch only the injected root callback. |
| Root retains cancellation ownership | The design assigns cancellation, in-progress presentation state, recovery-key clearing, native destination selection, and real-success transition to `ContentView`. The amended plan’s injected `cancel` closure performs the existing model cancellation and then clears the root presentation Boolean and root-held re-entry text. | Resolved. The dialog does not call the model, mutate review/error state, or own presentation state. |
| Protected-export overlays are exclusive | The design requires one protected-export state at a time. The plan’s single root overlay selects the in-progress dialog first and the success dialog only in the alternative branch. The existing verified-success observer dismisses the in-progress state before the success branch can present. | Resolved. Cancellation returns to no protected-export overlay; it cannot leave a success overlay competing with an active in-progress dialog. |
| Safe dialog inputs remain bounded | The dialog contract is limited to two-mode state, filename-only reviewed display data, fixed safe labels, the existing root-owned recovery-key binding, controlled error text, busy state, and callbacks. | Resolved. The presentation boundary excludes locator data, receipts, workspace objects, storage, workers, and destination-panel authority. |
| Native chooser behavior remains separate | The root primary callback retains the existing review action, which owns the native chooser; the plan requires that chooser to remain in front of the custom in-progress dialog. | Compatible. Its own cancellation remains native-panel behavior and is not reimplemented by the root overlay. |

## Precise implementation release condition

The architecture condition is released only for the approved visual slice if
the implementation satisfies every item below:

1. `SettingsProtectedExportDialog` implements Cancel exactly as a
   cancel-role control with `.keyboardShortcut(.cancelAction)` and binds it
   solely to the injected `cancel` closure. It must not independently clear,
   dismiss, modify review/error state, or invoke a model action.
2. `ContentView` remains the only owner of the in-progress Boolean, re-entry
   binding, model cancellation call, state clearing, native chooser action,
   and verified-success dismissal.
3. A single root overlay uses mutually exclusive in-progress and verified-
   success branches; a non-success cancellation must select neither branch.
4. The dialog call site passes only the approved safe display values and
   callbacks. No destination locator, review object, recovery-key copy,
   receipt, store, workspace payload, persistence dependency, or native-panel
   authority may cross into `SettingsView`.
5. The focused post-implementation review and QA evidence must demonstrate
   that activating Cancel dismisses the custom entry dialog and retains the
   existing controlled-error/cancellation behavior, with no stock in-progress
   sheet and no invented success state.

This decision reopens only the architecture portion of the gate. A fresh
implementer may start only after the required independent planning, QA,
security/privacy, TPM, and delivery releases are also recorded. Any deviation
from the five conditions requires a fresh architecture decision before
implementation proceeds.
