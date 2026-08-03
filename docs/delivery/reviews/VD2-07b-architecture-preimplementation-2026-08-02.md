# VD2-07b architecture pre-implementation review — 2026-08-02

**Role:** Independent Architect  
**Verdict:** **APPROVE for the remaining independent release gates; implementation is not released by this review.**

## Decision

`VD2-06` and `VD2-07` are accepted, and the dashboard records `VD2-07b` as a
separately released Backlog card. The brief is a bounded presentation-only
change that conforms to the controlling V2 contracts: `RekonTheme` stays the
semantic design-system seam; `ContentView` remains the sole owner of the
workspace model, routes, recovery strings, modal state, and document-panel
entry points; and native Pipeline controls retain their AppKit ownership.

No ADR is required. This work consumes ADR-VD2-01, ADR-VD2-02, and ADR-VD2-04
without changing a data, route, persistence, recovery, privacy, or capability
boundary.

## Architecture evidence

| Boundary | Finding | Required result |
| --- | --- | --- |
| Shared visual seam | `RekonVisualTheme.swift` already centralizes the palette, control geometry, and native Pipeline surface contract. Its existing `RekonTextFieldStyle`/`RekonControlSurface` are insufficient as a wholesale drop-in: the latter currently gives hover precedence over focus and neither defines disabled, error, selected, multiline, or picker semantics. | Add the smallest semantic app-owned form family at this seam; do not create screen-local style variants. |
| Focus and non-color cues | Pipeline's semantic state contract gives keyboard focus precedence over hover. The generic family must have the same property, including a non-color difference such as focus-ring width/elevation, while preserving visible textual validation. | A pointer hovering over a keyboard-focused field must not erase its distinguishable focus evidence. Disabled and validation/error presentation must derive only from existing state. |
| Bindings and persistence | `ContentView` owns `WorkspaceViewModel`, all opportunity/reconciliation/import bindings, recovery re-entry strings, modal state, and the existing importer. Contacts owns only its existing view focus/editor state. | Styles/wrappers accept presentation state only. They must not accept a model, URL, recovery key, persistence object, or callback, and must not add `onChange`, debouncing, drafts, or persistence. |
| Root-owned sensitive flows | Recovery and protected-export entry fields are root overlays/sheets in `ContentView`; Settings supplies callbacks only. The document importer is likewise root-owned. | Apply chrome only around the existing recovery inputs. Retain root ownership and every existing cancel/error/confirmation path. Do not touch importer modifiers, callback handling, allowed types, or native-panel automation. |
| Pipeline native boundary | `PipelineNavySearchControl`, `PipelineNavyStageControl`, `PipelineNavyCheckboxControl`, and `PipelineNavyViewModeControl` own native responder, delegate/target-action, binding, identifier, and role behavior. | Do not replace, wrap with a competing focus owner, or edit their native classes/representables. `PipelineView` may receive layout/container alignment only. |
| Accessibility projection | Existing controls have stable identifiers and, in several cases, explicit labels/values. A modifier that replaces an identifier/value or uses an accessibility representation that hides the native control would violate the card. | Any common test evidence must be additive, non-interactive, content-free, and preserve the original element's role, label, value, identifier, and keyboard order. It may expose only control kind and semantic presentation state; it must never encode field text, selected IDs, recovery material, file/document metadata, or paths. |
| Adaptive multiline/picker behavior | Opportunity and Contact `TextEditor`s retain explicit expanded/minimum heights; SwiftUI `Picker`s retain their tags and typed selections. | Preserve editor scrolling, selection/caret behavior, current min/max heights, and large-text wrapping. Preserve picker labels, option sets, tags/types, selected-value disclosure, and VoiceOver/keyboard operation. |

## Required implementation constraints

1. Treat every concrete control in the approved inventory as a coverage item,
   including the opportunity/dialog and Activity & AI controls, not merely the
   selectors exercised by the new tests. Date and toggle controls listed beside
   those fields retain their native roles and bindings; if a proposed visual
   treatment would require replacement or semantic customization of either,
   stop and amend the brief rather than broadening this card implicitly.
2. Keep all existing `@FocusState` ownership. A shared surface may receive the
   caller's already-owned focus presentation state, but it must not install a
   competing focus binding, change first-responder order, or suppress native
   focus behavior. New fields without an existing focus owner may use only
   presentation-local state that does not alter traversal or activation.
3. Define state precedence explicitly and test it: disabled first; focused
   remains distinguishable from hover; validation/error is supplemental to,
   not a replacement for, the existing textual error; selection is never used
   as a proxy for focus. The common state projection must therefore be derived
   from actual presentation state, not a static or user-entered value.
4. The Task 1 RED may fail only for the absent additive common-surface
   projection after all preservation assertions pass. No fixture, signing,
   route, native-panel, privacy, accessibility-debt, or functional failure is
   classifiable as RED evidence.
5. Preserve the explicit VD2-08 handoff: Settings compact keyboard focus and
   AI text semantics, Contacts accessibility/recovery automation, and Board
   card-anchor semantics remain open and must be reported unchanged. This card
   may not skip, expect-fail, weaken, mask, or reclassify their tests.

## Gate conclusion

The architecture permits implementation after independent TPM, QA/test,
Security/privacy, and Delivery approvals. The implementer must keep changes in
the Task 2 allowlist and stop for independent diagnosis on any behavior,
persistence, audit, accessibility-semantic, secret/metadata, or native-panel
regression. A post-implementation architecture review remains required before
acceptance.
