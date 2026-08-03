# VD2-07b planning gate — 2026-08-02

## Decision

**Recommendation: approve for independent pre-implementation gates; do not yet release implementation.**

`VD2-07b` is dependency-safe: its declared predecessors, `VD2-06` and `VD2-07`, are accepted. The planned work is a bounded visual-alignment slice covering every current app-owned editable/search control, while expressly excluding native macOS file panels and all workflow/data/security behavior.

## Plan quality and required gates

The task brief is test-first and serial: fixture-backed RED establishes an exhaustive control inventory and preservation baseline; a shared semantic control family is then applied at the theme seam; retained persistence, validation, audit, recovery, privacy, responsive, signing, and UI evidence must be GREEN before independent review. It assigns no production change to fixtures, project/signing configuration, stores, models, routes, or native-panel behavior.

Implementation release still requires fresh independent Architecture, TPM, QA/test, Security/privacy, and Delivery approval. A fresh implementer must be followed by separate Code Review and QA verification; Architecture, Security/privacy, TPM/Delivery, and product-owner hands-on verification then decide acceptance.

## Risks requiring gate attention

1. The broad inventory can miss controls embedded in dialogs or currently inactive branches. QA must compare the final source search inventory with the brief and reject unaccounted app-owned fields.
2. A global SwiftUI style can change focus, `TextEditor` selection/scrolling, picker semantics, layout, or validation visibility. The preservation matrix and compact/large-text test must execute before acceptance.
3. Recovery-key and document flows create disclosure risk. No key/document metadata may appear in identifiers, labels, logs, screenshots, or result attachments; file panels remain fully native and outside scope.
4. Pipeline’s custom AppKit controls have retained keyboard and accessibility semantics. They must not be rewritten merely to match generic SwiftUI styling.
5. Existing Settings, Contacts, and Board accessibility debts remain `VD2-08` work. VD2-07b must record them as outstanding rather than masking or reclassifying them.

## Release condition

Release only when the independent gates accept the exhaustive inventory, test fixtures, exact RED classification, unchanged native-panel boundary, secret/metadata handling, and the stated VD2-08 debt handoff. Otherwise return the brief for amendment; no implementation is authorized by this report alone.

## 2026-08-02 amendment after QA block

The planning brief now corrects the blocked Task-1 contract. It adds a
source-to-selector, table-driven matrix for every current app-owned in-scope
control: all Pipeline native controls in Table and Board (including
`pipeline-include-closed` and `pipeline-view-mode`); the Contacts Employer
picker and both employer-editor branches; every Contact text/editor field;
all Add and canonical-overview text, multiline, numeric, picker, conditional,
and date/toggle preservation paths; reschedule and every root-owned recovery
entry; document-reference, reconciliation, every `CSVImportField.allCases`
mapping and duplicate-decision picker; and Activity search plus all eight AI
filters. Each row specifies its fixture/route, current selector or stable
label, existing semantic/binding preservation checks, and a non-secret
additive `kind`/`state` projection assertion.

The former overview “Cancel” assertion is replaced by the source-accurate
`Back to Pipeline` no-save contract. The renamed
`testVD207bOpportunityEditorsRetainBindingsValidationAndNoSaveBack()` must
prove that Back after edits creates no record or activity event and that
relaunch retains the original record; Add Opportunity retains its actual
Cancel/no-write test separately. The verification command is amended to the
new method name. The amendment preserves the original scope/debt boundaries:
no production release, no native-panel automation or customization, no secret
or document evidence, no data/workflow change, and no VD2-08 debt closure.

**Planning recommendation after amendment:** return the exact amended brief to
fresh independent QA/test review. Implementation remains blocked pending QA,
Security/privacy, and Delivery approval; this report does not release work.

## 2026-08-02 correction after Architecture and QA rechecks

The brief now closes the remaining planning contradictions without expanding
the implementation card. Its additive projection taxonomy explicitly includes
the truthful native `checkbox` and `radioGroup` kinds (with applicable
`checked`/`unchecked` and `selected` states), and prohibits a competing focus
owner, first-responder change, accessibility-element replacement, or native
delegate/target-action change. The portable-archive restore recovery input is
classified as an included root-owned app sheet input; the archive chooser that
precedes it remains excluded. Because no current fixture reaches that state
without automating the excluded chooser, its verification is limited to the
documented root-sheet source/selector/static coverage, not an interaction
claim. The same narrow restriction applies to the conditional CSV mapping and
duplicate-decision controls: no current fixture seeds `csvPreview` or
`csvImportPlan`, and their only route begins in the excluded CSV chooser. They
remain exhaustive source-to-selector inventory rows, while UI proof covers only
the app-side trigger; a separately approved deterministic seam is required
before interaction evidence may be claimed. All reachable rows retain the
fixture-backed, table-driven RED-before-implementation requirement.

**Corrected planning recommendation:** return the amended brief to fresh QA,
then Security/privacy, TPM, and Delivery review. Implementation remains
blocked; this correction grants no release.
