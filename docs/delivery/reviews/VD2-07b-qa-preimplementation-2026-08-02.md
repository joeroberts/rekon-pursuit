# VD2-07b QA/test pre-implementation review — 2026-08-02

## Verdict: BLOCK

`VD2-07b` remains Backlog in the delivery dashboard, with no active or next
eligible task. Its declared `VD2-06` and `VD2-07` dependencies are accepted,
but the proposed Task-1 RED suite is not yet an inventory-backed contract. Do
not release implementation until the planning brief is amended and the
following exact verification is approved.

## Basis

The source inventory is broader than the four planned tests. A test which
checks one representative control cannot prove that every current app-owned
editable/search control received the shared family, nor detect a later omitted
control. The Task-1 named controls also omit two explicitly included Pipeline
controls (`pipeline-include-closed`, `pipeline-view-mode`) and the Contacts
Employer picker (currently label-only, `Filter contacts by employer`).

The required `testVD207bOpportunityEditorsRetainBindingsValidationAndCancel()`
also describes cancelling a canonical overview edit. The current
`OpportunityOverviewView` has `Save changes locally`, `Reschedule action`, and
`Back to Pipeline`; it has no Cancel action. A RED that assumes a non-existent
current Cancel behavior would fail for a baseline/workflow reason, not solely
for the absent shared-surface projection, and therefore cannot qualify under
the brief's own RED rule.

## Required inventory-backed RED matrix

Before any production edit, Task 1 must add an explicit, non-secret selector
or deterministic label matrix for every item below. Each item must first prove
its ready fixture/route and current role, label, enabled state, selected value
where applicable, and current binding behavior. It must then fail only because
the new common presentation evidence is absent. The evidence must be a
non-content enum such as `kind=<text|search|multiline|numeric|picker>;
state=<idle|focused|disabled|error|selected>`; it must not replace an existing
accessibility identifier, role, label, or value, and must contain no field
text, record ID, recovery key, path, filename, document metadata, or fixture
data.

| Surface | Current app-owned editable/search controls that the RED must enumerate |
| --- | --- |
| Pipeline | `opportunity-search`; `pipeline-stage-filter`; `pipeline-include-closed`; `pipeline-view-mode`, in both Table and Board where rendered. Preserve the current AppKit text-field, popup, checkbox, radio-group roles, labels, values, delegate/binding behavior, and keyboard operation. |
| Contacts list/editor | `contact-search`; Employer filter picker (`Filter contacts by employer`); `contact-name`; title; both email fields; both phone fields; LinkedIn, Instagram, and Facebook fields; new-employer field or `contact-employer-search` branch; relationship-context and notes `TextEditor`s. Test validation draft retention and Cancel/no-write separately from a successful save/relaunch/activity path. |
| Opportunity routes | Add and canonical overview: title, company, URL, two multiline editors, two numeric text fields, pay-period/work-arrangement/stage/next-action pickers, conditional other-action field, applied/due-date paths, and selected-value disclosure. The canonical route must use its actual Back/no-save semantics, or the product owner must explicitly authorize a Cancel behavior as a separate out-of-scope change; it cannot be invented by VD2-07b. |
| Dialogs and recovery | Reschedule date; recovery re-entry, archive-creation re-entry, retained-purge re-entry, portable-archive restore entry, and Settings protected-export recovery entry. Each test must exercise only empty/error/cancel/confirmation state without entering, attaching, logging, or screenshotting a key. |
| Reconciliation, documents, import | Four reconciliation pickers plus multiline evidence field; document reference-type picker; every `CSVImportField.allCases` mapping picker; duplicate-decision picker. The native CSV/file chooser boundary may be triggered only through the existing app control and must not be queried, styled, or automated. |
| Activity & AI | `activity-search`; all eight local AI filters: time, feature, opportunity, route, model, completion, minimum cost, maximum cost. Assert local-only/no-results truth and invalid cost-range validation; assert that no request, provider setting, network action, ledger entry, or persisted filter state is created. |

Dates and toggles are preservation controls in the affected forms, even if the
shared visual family intentionally limits itself to text/search/multiline/
numeric/picker presentation. Task 1 must assert their existing enablement,
selection, labels, and route behavior unchanged whenever they reveal a listed
editable control. It must not claim them styled unless the approved interface
explicitly includes them.

## Focused automated tests required before implementation

1. Keep the four planned `testVD207b…` methods, but make their expected
   shared-surface assertions table-driven over the inventory above. A method
   may cover multiple routes, but its assertion failure must name the missing
   control and expected non-secret evidence value.
2. Split or add focused deterministic methods where fixture/setup would make a
   single method ambiguous: Pipeline native role/keyboard preservation;
   Contacts valid-save plus invalid-draft/Cancel; add/overview no-save
   preservation; recovery/root-dialog error/cancel; CSV/reconciliation native
   boundary; and Activity/AI local-filter truth.
3. For the overview path, baseline preservation must prove that edits followed
   by the current `Back to Pipeline` route do not create an opportunity or
   activity event and that a relaunch retains the original persisted record.
   If source behavior shows a different existing semantic, the test must state
   that exact semantic instead of calling it Cancel.
4. At wide and compact host sizes, use the supported larger accessibility-text
   launch setting only if the host demonstrably supports it. For every
   multiline editor, prove label, visible or scrollable content, focus cue,
   validation text, and Save/Back-or-Cancel action are reachable without
   clipping. Attachments must contain no recovery or document material.
5. Run the four new tests as a RED before production work. A valid RED is:
   named deterministic fixture ready; all role/label/value/binding/no-write/
   privacy assertions green; exactly the new shared-surface evidence absent.
   Any route, fixture, signing, native-panel, persistence/audit, behavior,
   accessibility-debt, or disclosure failure is a blocker, not RED evidence.

After implementation, run the exact VD2-07b UI and lower-layer command matrix
from the task brief, inspect each selected test once in the signed result
bundle (zero skips and zero expected failures), build with the configured Debug
signing identity, verify app/host/test-bundle signatures, inspect attachments
for secrets/metadata, and run `git diff --check`. The implementation review
must additionally record the source-to-selector matrix above, before/after
coverage, each RED-to-GREEN result, and the unchanged-native-file-panel
statement.

## VD2-08 accessibility-debt handoff — not VD2-07b acceptance evidence

The following observed outstanding issues remain exclusively VD2-08 work. They
must execute unchanged during VD2-07b verification and be reported with exact
failing assertion, observed role/label/value, macOS/Xcode version, and signed
result-bundle path. No `XCTSkip`, `XCTExpectFailure`, predicate weakening, or
scope reclassification is permitted.

| Deferred issue and current evidence | Required VD2-08 regression |
| --- | --- |
| Settings compact keyboard handoff: `testVD207ReferenceTabsKeepKeyboardSelectionAtCompactWidth` and `testVD207SettingsSecondaryNavigationIsKeyboardOperableAtCompactWidth` retain their failure evidence only for missing semantic Tab/Space selected/not-selected keyboard-focus behavior. | At compact and wide widths, all four Settings local-section controls must be Tab reachable, expose selected/not-selected plus keyboard focus, activate with Space, render the matching panel, and retain the selected Settings rail. |
| Settings AI informational semantics: `testVD207SettingsDocumentAndAISectionsStayAggregateAndUnavailable` retains failing evidence only for the AI informational text role/label/value. | Preserve the truthful local-only copy and identifier; assert both `Any` and `StaticText` queries expose a stable semantic text role/label/value while no-actionable-control and no-metadata checks remain green. |
| Contacts: `contact-operation-error` lacks the precise validation/recovery text in its accessibility value; editor Back, Cancel, and Save lack verified Tab then Space/Return activation; failed Link/Unlink lacks deterministic UI injection. | Add failing-first deterministic AX-value, keyboard-activation, and failed-association recovery automation tests, then close all three with signed result evidence without weakening the existing Contacts contracts. |
| Pipeline Board card-anchor semantic debt. | Retain the existing VD2-05 Board anchor test as failure evidence and add/repair a deterministic role/label/value and keyboard-navigation regression before closure. |

These are accessibility findings, not permission to alter recovery, export,
document, AI, fixture, route, persistence, or native-panel behavior in
VD2-07b.
