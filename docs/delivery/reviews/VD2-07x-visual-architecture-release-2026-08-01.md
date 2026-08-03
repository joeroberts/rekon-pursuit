# VD2-07x Task 2 — visual architecture release

**Date:** 2026-08-01  
**Role:** Independent Architecture  
**Verdict:** **ACCEPT — release the reference-faithful visual implementation only.**

## Decision

The product-owner VD2-08 accessibility-deferral addendum permits the approved
VD2-07x visual implementation to proceed. It supersedes the prior sequencing
constraint only for the two recorded local accessibility regressions:

1. compact Settings-local keyboard focus / Tab / Space handoff; and
2. the AI-unavailable informational text's accessibility role, label, or
   value.

The Task 2 implementer may render the four approved Settings surfaces and the
root-owned protected-export success dialog. This is not acceptance of Task 2,
the signed matrix, or VD2-07x as a whole. All non-deferred safety, privacy,
fixture, and visual evidence gates remain required for acceptance.

## Architecture evidence

| Boundary | Current evidence | Decision |
| --- | --- | --- |
| Global application navigation | The approved design requires the existing five-destination rail and `DailyRoute.settings` to remain the app-level owner. The visual task must add only local Settings selection; it may not turn a local tab into a global route. | Preserved. |
| Local Settings state | `SettingsView` currently owns `selectedSection` / `focusedSection` locally and has no model, URL, recovery key, or persisted setting. The four new panels can remain display-only descendants of that boundary. | Preserved. |
| Export-success data flow | `ProtectedExportSuccess` contains only `displayFilename`. `WorkspaceViewModel` guards its publication with its opaque operation token and store identity, clears it for invalid/cancel/failure/transition paths, and `SettingsRootModalPresentation` projects only filename plus the fixed `Selected local folder` label. | Preserved; no ADR required. |
| Root ownership | `ContentView` owns the workspace model, recovery/export sheets and root presentation projection. `SettingsRootModalBindings.dismissProtectedExportSuccess` reaches only the model dismissal. The dialog must therefore be overlaid at the root, and `Done` may only dismiss success. | Required implementation shape. |
| Deterministic archive baseline | `VisualFixtureLaunchConfiguration.fixedNow` is now `2025-05-06T12:00:00Z`, and the host test asserts that exact ISO timestamp. The focused host evidence reports the matching archive fixture as green. | V2-07x fixture gate remains active. |
| Keyboard and AI semantic failures | The baseline-repair report records the keyboard-value and AI `StaticText` failures. The addendum explicitly carries exactly those observations to VD2-08, retains the original test identifiers/assertions, forbids skips/expected failures/guarded continuations, and requires them to run and be reported. | Excluded from this visual-start gate only. |

## Authorized Task 2 architecture boundary

The implementer may modify the Settings rendering, root dialog presentation,
and focused visual tests needed for the approved reference. It must:

- retain the global rail and all root-owned recovery/export UI ownership;
- render the four local sections without persistence or route changes;
- use safe archive summaries and aggregate document counts only;
- retain no-control/no-metadata treatment for Document and AI panels;
- show the success dialog only from a non-nil real-write event, never from a
  fixture, launch argument, demo control, or default state;
- close the existing export sheet and clear its re-entry text before showing a
  valid success dialog, while keeping the event until `Done` calls the
  root-only dismissal binding;
- add focused pointer-selection coverage for compact tabs and a focused AI
  visual/content-boundary check, without modifying, skipping, weakening, or
  accommodating the three deferred accessibility tests; and
- retain wide and compact fixture screenshots plus the signed normal-app
  real-export dialog evidence required by the controlling plan.

No Task 2 work may change `WorkspaceViewModel` export/recovery semantics,
Core/persistence, fixture launch behavior, time, global navigation, document
metadata policy, or AI/cloud/Gmail/Calendar capability.

## Carried risk and final acceptance requirements

The prior task's full matrix result bundle did not finalize parseably. That is
not an architectural reason to delay visual rendering under the explicit
product-owner addendum; it is still a final V2-07x verification requirement.
The Task 2 release must retain and report the deferred test results separately
with their exact assertions and VD2-08 regression mapping. Any non-deferred
failure—including fixed-date fixture, protected-export event/token/root,
global-rail/route, safe-content, pointer tab selection, visual composition, or
real-success dialog failure—blocks V2-07x acceptance.

No ADR is required: this release consumes the existing root-presentation seam
and does not broaden a data, route, persistence, or capability boundary.
