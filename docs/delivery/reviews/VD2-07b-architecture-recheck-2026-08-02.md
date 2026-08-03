# VD2-07b architecture recheck — 2026-08-02

**Role:** Fresh independent Architect  
**Scope:** Amended planning brief only; no production implementation reviewed.  
**Verdict:** **BLOCK — return the amended Task-1 projection vocabulary for one narrow correction before release to the remaining gates.**

## Decision

The amendment correctly resolves the prior source-accuracy issue: canonical
opportunity editing has a `Back to Pipeline` no-save route, while Add
Opportunity has the distinct Cancel/no-write route. It also replaces
representative coverage with an exhaustive source-to-selector matrix, preserves
the Task-2 ownership/allowlist boundary, continues to exclude every native
macOS file panel, and explicitly retains the VD2-08 debts.

However, the amended matrix requires an additive `kind`/`state` projection for
all four Pipeline controls, including the native checkbox and native segmented
view-mode control, while the permitted `kind` vocabulary is exactly
`text|search|multiline|numeric|picker`. A checkbox and a radio-group/segmented
control cannot truthfully emit one of those kinds. Relabeling either as a
picker would make the new accessibility/test evidence semantically false;
wrapping or replacing it to make the vocabulary fit would violate the retained
native-owner boundary. Thus the contract is not yet implementable without
choosing between conflicting requirements.

## Recheck findings

| Architecture boundary | Finding | Result |
| --- | --- | --- |
| Root-owned shared controls | `ContentView` retains `WorkspaceViewModel`, route state, recovery-entry strings, modal presentation, and callback actions. `SettingsView` remains a presentation/callback consumer; the protected-export dialog is still presented by `ContentView`. | Preserved. |
| Native file panels | Document import remains the root `.fileImporter` boundary and CSV selection remains root `NSOpenPanel` code. The amendment prohibits querying, styling, wrapping, automating, or representing either OS panel. | Preserved. |
| Pipeline native controls | `PipelineNavySearchControl`, `PipelineNavyStageControl`, `PipelineNavyCheckboxControl`, and `PipelineNavyViewModeControl` retain their existing AppKit responder/delegate/target-action and accessibility ownership. The amended table correctly includes all four in Table and Board. | Preserved, subject to the projection-vocabulary correction below. |
| Accessibility semantics | The amendment correctly requires additive, content-free evidence and preservation of each current identifier, role, label, value, binding, and keyboard order. Its enum is incomplete for the two native non-picker controls it simultaneously requires to project. | Blocker. |
| Persistence and local-only behavior | The brief continues to prohibit model/callback/persistence inputs at the theme seam, `onChange` persistence, workflow/audit changes, recovery or document disclosure, and AI/network/provider behavior. Its Back/no-save and relaunch assertions align with the root route behavior. | Preserved. |
| VD2-08 debt handoff | The amendment neither closes nor weakens the Settings, Contacts, or Board deferred accessibility evidence. | Preserved. |

## Required correction

Amend only the Task-1 matrix/projection contract so each Pipeline native
control has a truthful, additive, non-interactive presentation projection that
does not alter its existing accessibility element. Either:

1. extend the closed `kind` vocabulary with explicit `checkbox` and
   `segmented` (or `radioGroup`) values; or
2. exempt these two native controls from the `kind` enum while still requiring
   a separate additive `state` projection and the listed role/label/value/
   keyboard preservation assertions.

The correction must state that the projection is attached without installing a
competing focus owner, changing first-responder order, replacing the native
accessibility element, or changing the existing delegate/target-action path.
No source, model, file-panel, security, persistence, or route change is needed
to resolve this planning inconsistency.

## ADR assessment

**No ADR is needed.** The required correction clarifies test/presentation
evidence within the already-approved `RekonTheme` and native-Pipeline seams; it
does not alter a capability, data, security, persistence, routing, or ownership
boundary.

## Release condition

After the narrow vocabulary amendment, obtain the fresh QA/test,
Security/privacy, TPM, and Delivery decisions required by the brief. This
architecture recheck does not release implementation.
