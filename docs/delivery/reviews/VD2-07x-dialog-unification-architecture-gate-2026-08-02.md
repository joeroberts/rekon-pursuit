# VD2-07x protected-export dialog unification — Architecture gate

**Date:** 2026-08-02
**Role:** Fresh independent Architect
**Verdict:** **NEEDS CHANGE**

## Decision

The proposed ownership and display seam is approved in principle. The root
composition view retains all protected-export state, recovery-key binding,
model actions, native destination selection, cancellation, and real-success
dismissal. The new Settings presentation component is correctly constrained to
a two-mode, safe display contract plus callbacks; it has no business, storage,
or destination authority.

One plan-level correction is mandatory before implementation: explicitly
preserve the existing cancel-role keyboard semantics in the custom dialog. The
plan currently requires only a visible Cancel control that invokes `cancel`.
That is insufficient to prove continuity with the current cancel-role button
once the native sheet is removed. Require the custom Cancel control to retain
`role: .cancel` and invoke only the supplied `cancel` closure. This is a
documentation correction, not authorization for a production edit.

## Architecture assessment

| Concern | Evidence | Required implementation result |
| --- | --- | --- |
| Root presentation ownership | The root already owns the in-progress Boolean and recovery-key entry, observes real success to dismiss the in-progress state, and supplies the three existing model actions. The plan preserves that ownership and moves the review-change key clear to a root modifier. | The root is the only presenter. The Settings component receives no model, URL, persistence, worker, receipt, or workspace object. |
| Exclusive states | The proposed single overlay uses `if` for the in-progress dialog and `else if` for real success. The existing real-success observer clears the in-progress Boolean when verified success is published. | There must be one protected-export overlay branch, not independent overlays. Success is reachable only after the verified-success model event and after the in-progress branch is no longer selected. |
| Safe display contract | The proposed mode projects only entry or confirmation plus a display filename. Confirmation substitutes fixed safe labels for destination and active data; the existing review derives its display filename from the selected item’s final component. | The component may receive only mode, display filename, the existing recovery-key binding, controlled error text, busy state, and root callbacks. It must never receive or derive a destination locator, key material outside that binding, receipt, store, persistence dependency, or workspace object. |
| Action and key-clearing continuity | The planned primary callbacks preserve review versus confirm selection. Review success clears the entry before confirmation; confirm clears it after invocation; Cancel clears it after cancellation; and the existing real-success observer clears it again while dismissing the in-progress state. Controlled errors remain in the active mode and a failed confirm retains the review. | Preserve the existing action order and exact model calls. The native destination panel remains opened only by the existing review action and stays in front of the root dialog. Do not clear review or error state from the presentation component. |
| Cancel behavior | The current in-progress form uses a cancel-role control. The plan retains its callback and clears state but does not require the cancel role after replacing the native sheet. | Amend the plan to require `Button("Cancel", role: .cancel)` (or an exactly equivalent retained cancel-action semantic) bound solely to `cancel`. |
| Prohibited scope | The proposal confines the slice to presentation, one focused UI journey, and delivery evidence; it leaves verified-write, native-panel, persistence, activity, entitlement, success content/timing, Settings navigation, theme-wide styles, and deferred accessibility work alone. | No change outside the approved slice is released by this gate. A scope expansion, a second presentation owner, or a widened display input requires a fresh architecture decision. |

## Mandatory correction

1. Amend the implementation plan’s custom-dialog requirements to state that
   the Cancel control retains the current cancel-role keyboard semantics while
   invoking only the root-supplied cancellation closure. Keep the existing
   primary default-action requirement unchanged.

## Release condition

Do not dispatch an implementer under this gate yet. First make the single
plan-only correction above and obtain a fresh Architect recheck confirming the
root-owned exclusive-overlay and safe-input contract remains unchanged. A
fresh implementer may begin only after that recheck and the independent
Planning, TPM, QA, Security/privacy, and Delivery Manager releases. The final
implementation review must verify that no prohibited behavior or sensitive
display data entered the dialog boundary.
