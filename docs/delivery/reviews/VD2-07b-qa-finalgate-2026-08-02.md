# VD2-07b QA/test final amended-brief gate — 2026-08-02

**Role:** Fresh independent QA/test verifier

**Scope:** Final amended planning brief, all prior VD2-07b planning/architecture/QA gates, and current source/test/fixture readback. No production implementation was reviewed or changed.
**Verdict:** **APPROVE — release-ready for Task 1 RED only.**

## Decision

The final amendment resolves every concrete QA or architecture planning blocker
identified in the earlier VD2-07b reports. It gives the implementer a
deterministic, table-driven RED contract for every currently reachable
app-owned control and a precise, reviewable static-coverage rule for the three
currently unreachable conditional groups. It does not authorize Task 2,
production edits, or task acceptance; those remain subject to the brief's
independent implementation, security/privacy, architecture, delivery, TPM,
and owner gates.

## Blocker-resolution verification

| Prior blocker | Final-brief verification | QA result |
| --- | --- | --- |
| Pipeline checkbox/view-mode controls and the Contacts Employer picker were omitted. | The table now requires all four Pipeline controls in both Table and Board, including `pipeline-include-closed` and `pipeline-view-mode`, with preserved native roles and keyboard behavior. It also includes the label-only `Filter contacts by employer` picker and both employer-editor branches. Current source contains those controls and selectors. | Resolved. |
| Representative tests could not prove exhaustive coverage. | The amended table enumerates the current Contacts, Add, canonical-overview, reschedule, recovery, document-reference, reconciliation, import, Activity, and AI-filter controls. It also identifies date/toggle rows as preservation-only rather than falsely claiming shared styling. Current source readback matches this inventory, including all eight AI filters and `CSVImportField.allCases`. | Resolved. |
| The prior overview contract invented a Cancel action. | The final contract uses the actual `Back to Pipeline` action after non-secret edits and requires no fabricated row/activity event plus relaunch proof. Add Opportunity retains its separate real Cancel/no-write flow. `OpportunityOverviewView` and `AddOpportunityView` match those semantics. | Resolved. |
| CSV mapping and duplicate-decision controls were not reachable without the excluded native chooser. | The brief accurately marks every `CSVImportField.allCases` picker and the duplicate-decision picker as exhaustive static source-to-selector coverage. UI proof is limited to the existing app-side trigger; it expressly forbids panel automation and interaction RED/GREEN claims. A separate approved deterministic seam is required before those rows can become interaction evidence. | Resolved without weakening the native-panel boundary. |
| The portable-archive restore recovery input was unreachable without archive selection through the excluded native chooser. | The brief distinguishes the included root-owned conditional recovery field from the excluded chooser, requires static root-sheet selector/callback/style coverage only, and prohibits interaction or panel automation until a separately approved deterministic seam exists. | Resolved without unsafe fixture or secret handling. |
| The projection taxonomy could not truthfully represent Pipeline native controls. | The closed taxonomy now contains `checkbox` and `radioGroup`, with applicable `checked`/`unchecked` and `selected` states. It remains additive, content-free, non-interactive, and expressly forbids competing focus ownership, first-responder changes, accessibility-element replacement, or delegate/target-action changes. | Resolved. |

## Release constraints retained

- Each reachable matrix row must establish the existing fixture/route,
  role/label/value/enabled/selection/binding/no-write/privacy baseline before
  failing solely on the absent additive projection.
- The static-only restore and CSV groups are source-review obligations, not
  synthetic interaction evidence or a reason to automate a native panel.
- Recovery keys and document material remain prohibited from test input,
  selectors, labels, logs, screenshots, and attachments.
- The existing VD2-08 Settings, Contacts, and Board accessibility debts remain
  reported regressions only; no skip, expected failure, weakened predicate, or
  reclassification is authorized.

## Fresh evidence

Readback confirmed the named Pipeline native controls in
`RekonVisualTheme.swift`/`PipelineView.swift`; Contacts controls in
`ContactsView.swift`; the opportunity, recovery, reconciliation, CSV, and
Activity/AI controls in `ContentView.swift`; and the protected-export entry in
`SettingsView.swift`. Fixture support includes `contacts`, `populated`,
`archive`, `document-relink`, and `reconciliation`; no fixture initializes
`csvPreview`, `csvImportPlan`, or portable-restore `awaitingRecoveryKey`,
which is exactly the limitation the final amendment records.

No VD2-07b automated test was run: this is a pre-implementation gate and the
four required VD2-07b RED methods do not yet exist. Task 1 may now add and run
them; any failure other than the specified absent projection remains a release
blocker rather than valid RED evidence.
