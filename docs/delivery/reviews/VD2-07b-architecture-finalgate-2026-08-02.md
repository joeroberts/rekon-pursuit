# VD2-07b architecture final gate — 2026-08-02

**Role:** Fresh independent Architect  
**Scope:** Final amended planning brief, prior VD2-07b planning/Architecture/QA
reports, and current source/test readback. No implementation is reviewed or
released by this gate.  
**Verdict:** **APPROVE — the amended Task-1 contract resolves the prior
Architecture and QA blockers without expanding the card's scope, persistence,
or security boundary.**

## Decision

The final amendment is an executable planning correction, not a feature
expansion. It keeps `RekonTheme` as the only presentation seam and retains
the Task-2 production allowlist. `ContentView` remains the owner of workspace,
route, recovery-entry, modal, import, and callback state; the four Pipeline
controls retain their AppKit responder/delegate/target-action and accessibility
ownership.

Task 1 remains unreleased. Its reachable rows must first produce the stipulated
preservation-green, additive-projection-only RED, and the required independent
QA/test, Security/privacy, TPM, and Delivery gates still decide release.

## Earlier concrete blockers — final validation

| Earlier blocker | Final amended contract and source/test validation | Result |
| --- | --- | --- |
| The inventory omitted Pipeline checkbox/view-mode controls, the Contacts Employer picker, broader form/dialog/filter rows, and used representative coverage. | The table now enumerates every required key, including `pipeline-include-closed`, `pipeline-view-mode` in Table and Board, `Filter contacts by employer`, both employer branches, opportunity/dialog/reconciliation/document rows, `CSVImportField.allCases`, duplicate decision, Activity search, and all eight AI filters. Current source exposes the cited Pipeline, Contacts, CSV, and Activity selectors/branches. | Resolved. |
| The canonical overview test invented a Cancel action. | The amended row and renamed test use the actual `Back to Pipeline` no-save path; Add Opportunity separately retains its real Cancel/no-write proof. Current source contains that route distinction. | Resolved. |
| The closed presentation-kind vocabulary could not truthfully represent the native checkbox and view-mode radio group. | The final matrix adds `checkbox` and `radioGroup`, with applicable `checked`/`unchecked` and `selected` state. It expressly prohibits a competing focus owner, responder-order change, accessibility-element replacement, or delegate/target-action change. Current Pipeline controls are respectively native checkbox and segmented/radio-group controls. | Resolved. |
| CSV mapping/duplicate-decision rows could only be reached through the excluded native chooser; restore recovery entry had the same preceding-native-panel constraint. | The final matrix keeps all of these as exhaustive static source-to-selector coverage rows, limits UI proof to the existing app-side trigger, and makes no interaction RED/GREEN claim. It requires a separately approved deterministic seam before any future interaction proof. Source confirms CSV controls are conditional on `csvPreview`/`csvImportPlan`, CSV selection uses `NSOpenPanel`, and restore entry is conditional on `awaitingRecoveryKey`. | Resolved without widening the fixture, panel, or route boundary. |
| VD2-08 accessibility debts could be obscured by this card. | The amendment retains the Settings, Contacts, and Board debts as unchanged reported regressions; no skip, expected failure, predicate weakening, masking, or reclassification is allowed. Existing named regression methods remain present. | Preserved. |

## Boundary confirmation

- The projection is additive, non-interactive, fixed to a control key plus
  kind/state, and prohibited from carrying input, record, recovery, file,
  document, path, or fixture content.
- No model, store, persistence, audit, recovery/archive/restore, AI/network,
  route, native-panel, fixture, signing, or project-graph change enters the
  Task-2 allowlist. The contract continues to prohibit `onChange`-driven save
  behavior.
- Root-owned recovery and document flows remain root-owned; the OS panels are
  app-trigger-only and excluded from styling, automation, representation, and
  evidence.
- No ADR is required: the correction clarifies presentation/test evidence
  inside established seams and changes no data, capability, ownership, or
  security contract.

## Release condition

This approval authorizes no implementation by itself. Release only after fresh
independent QA/test confirmation that the amended RED matrix is executable,
the required Security/privacy, TPM, and Delivery gates approve the same brief,
and Delivery releases Task 1 to a fresh implementer. Any deviation from the
static-only boundary, native-control ownership, additive projection contract,
or retained debt handoff requires return to architecture review.
