# VD2-07b QA/test amended-plan recheck — 2026-08-02

**Role:** Fresh independent QA/test review  
**Scope:** Amended `VD2-07b` Task 1 plan only; source and existing test/fixture
readback.  
**Verdict:** **BLOCK — do not release Task 1.**

## Decision

The amendment resolves the prior QA blockers that made the first Task-1 plan
non-inventory-backed: it now names the missing Pipeline checkbox and view-mode
controls, the Contacts Employer picker and editor branches, all listed
opportunity/dialog/Activity controls, and it correctly replaces the
non-existent canonical-overview Cancel path with `Back to Pipeline` no-save
verification. It also preserves the required `VD2-08` handoff rather than
counting those debts as evidence for this card.

The amended matrix is nevertheless not executable under its own Task-1
allowlist and native-panel prohibition. It cannot currently reach all required
controls, and two mandatory Pipeline controls have no valid allowed projection
value. A baseline failure in either condition would not be the stipulated
shared-surface-only RED.

## Prior blocker recheck

| Prior QA blocker | Recheck result |
| --- | --- |
| Pipeline omitted `pipeline-include-closed` and `pipeline-view-mode`; Contacts omitted the label-only Employer filter. | **Resolved in inventory.** The amendment has rows for all four Pipeline controls in Table and Board and names `Filter contacts by employer`, both employer-editor branches, all Contact fields, and both `TextEditor`s. Source confirms those controls at `PipelineView.swift:177-218` and `ContactsView.swift:193-202,527-648`. |
| Representative selectors did not cover all app-owned controls. | **Resolved in coverage intent.** The rows now cover every current `TextField`, `TextEditor`, `Picker`, date/toggle preservation path, and the custom Pipeline controls found in `ContentView.swift`, `ContactsView.swift`, `SettingsView.swift`, and `PipelineView.swift`. `CSVImportField.allCases` is explicitly required, so future field additions can be made detectable once a review-state fixture exists. |
| The overview test invented Cancel behavior. | **Resolved.** `OpportunityOverviewView` exposes `Save changes locally` and `Back to Pipeline`, not Cancel (`ContentView.swift:665-687`). The renamed test requires Add Cancel/no-write separately from overview Back/no-save/relaunch, matching the source. |

## Remaining release blockers

1. **CSV mapping and duplicate-decision rows are unreachable.**

   The table requires an “existing deterministic CSV review state,” but the
   available fixture IDs contain no CSV-review fixture and fixture seeding does
   not initialize the transient `WorkspaceViewModel.csvPreview` or
   `csvImportPlan` state (`RekonVisualTheme.swift:1231-1241,1885-2095`). The
   mapping pickers render only when `csvPreview` is non-`nil`, and the duplicate
   picker renders only after an import plan exists (`ContentView.swift:926-987`).
   At present, the sole path to both is `chooseCSVFile()`, which opens the
   native file chooser (`ContentView.swift:486-495`). Task 1 forbids querying
   or automating that chooser and permits edits only to the UI-test file.

   Amend the plan with a separately reviewed prerequisite that supplies a
   deterministic, non-document-metadata CSV review fixture/launch seam (with
   mapping and at least one duplicate decision row), then make that prerequisite
   a dependency of Task 1. The matrix must name that fixture and use it to
   iterate every `CSVImportField.allCases` case.

2. **The portable-archive restore recovery field is unreachable.**

   The `archive` fixture supplies an enrolled key and verified catalogue, but
   not an `awaitingRecoveryKey` restore state (`RekonVisualTheme.swift:2062-2091`).
   Its Restore action calls `choosePortableArchiveForRestore`; the recovery
   entry field appears only after a selected archive moves the model into that
   state (`SettingsView.swift:671-681`, `ContentView.swift:263-281`). Reaching
   it therefore requires the excluded operating-system chooser. No current
   fixture starts at the safe root-owned recovery-entry state.

   Add a reviewed deterministic restore-entry fixture/launch seam that exposes
   only the root-owned empty/error/cancel state and no recovery value, or split
   that fixture prerequisite from this card. Do not substitute native-panel
   automation.

3. **The prescribed projection enum cannot represent all required Pipeline
   projections.**

   The amendment requires projections for Pipeline search, stage popup,
   checkbox, and view-mode radio group, while allowing only
   `kind=text|search|multiline|numeric|picker`. Source confirms the last two
   are a native checkbox and radio group, not any listed kind
   (`PipelineView.swift:196-218`; existing UI tests assert `.checkBox` and
   `.radioGroup`). The proposed assertion therefore has no truthful expected
   `kind` value for two mandatory rows.

   Amend the projection contract before RED work: either add content-free
   `checkbox` and `radioGroup` kinds with their state vocabulary, or explicitly
   define a separate additive surface projection for those native controls.
   The test table must give each control one concrete expected projection and
   retain its original role, value, selection, and keyboard assertions.

## Preservation and deferred-accessibility check

- The non-happy-path contract is otherwise correctly partitioned: Contacts
  valid-save/relaunch versus invalid-draft/Cancel; Add Cancel/no-write versus
  canonical overview Back/no-save; recovery empty/error/cancel; native-boundary
  triggers; reconciliation offline behavior; and Activity/AI clear, no-results,
  invalid-cost-range, and non-persistence behavior.
- The full source scan found no omitted app-owned editable control outside the
  amended rows. `reconcile.evidence` is a vertical-axis `TextField`, so its
  table implementation must apply the multiline presentation expectation to
  that actual control rather than assume it is a `TextEditor`.
- The amendment properly keeps the Settings compact keyboard-focus tests,
  Settings AI text-semantic check, Contacts accessibility/recovery automation,
  and the Board card-anchor issue exclusively with `VD2-08`. It prohibits skips,
  expected failures, weakened predicates, and reclassification. These remain
  required reported regression evidence, not VD2-07b GREEN evidence.

## Required return gate

Planning must amend the exact brief to resolve all three blockers above,
including named deterministic fixtures/routes and a complete native-control
projection schema. Fresh QA must then confirm that every matrix row can first
prove its preservation baseline and can fail solely for the absent additive,
content-free projection. Until then, the four new tests cannot produce a valid
RED and Task 1 must remain unreleased.
