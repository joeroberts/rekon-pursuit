# VD2-07b — Shared app-owned form-control alignment

**Status:** Planning only. `VD2-07b` is Backlog. It may enter implementation only after fresh independent Architecture, TPM, QA/test, Security/privacy, and Delivery approvals release the dependency-safe card.

## Objective

Standardize the visual and keyboard-focus treatment of every *current app-owned* editable or search control without changing its data, state, native platform semantics, or workflow. The result uses the established deep-navy surface system and restrained cyan/violet focus treatment while retaining truthful labels, current identifiers, and all existing command paths.

## Controlling boundary and dependencies

- Product-owner scope recorded in `docs/delivery/dashboard-status.json`: every app-owned text, search, multiline, numeric, and custom picker control, including Contacts, Pipeline, Settings, and app dialogs; native macOS file panels are excluded.
- `VD2-06` and `VD2-07` are accepted, satisfying the declared dependencies. `VD2-07c` and `VD2-07d` are not dependencies and are not implementation scope.
- ADR-VD2-01 and ADR-VD2-04 in `docs/superpowers/specs/2026-07-28-visual-design-v2-design.md` apply: `RekonTheme` stays the design-system seam; focus, labels, non-color cues, reduced motion, adaptable layout, and truthful empty/error states remain required.
- The existing Settings keyboard-focus and AI text-semantic debts, Contacts accessibility/recovery automation debts, and Board card-anchor semantic debt remain assigned to `VD2-08`. This task must neither resolve, weaken, mask, delete, skip, nor reclassify them.

## Scope and explicit stop

### Included control inventory

| Surface | Current control kinds | Candidate source location |
| --- | --- | --- |
| Shared/default controls | SwiftUI `TextField` chrome and any new semantic reusable field/editor/picker style wrappers | `RekonPursuit/RekonVisualTheme.swift` |
| Pipeline | custom native search field, stage popup, checkbox, and view-mode control | `RekonPursuit/RekonVisualTheme.swift`, consumed by `RekonPursuit/PipelineView.swift` |
| Contacts | contact search, employer filter/search, contact/channel fields, and relationship/notes editors | `RekonPursuit/ContactsView.swift` |
| Opportunity/workflow views and app-owned dialogs | reschedule date, recovery-key entry, add/edit/overview opportunity fields, multiline descriptions/notes, numeric compensation fields, pickers, dates, import mapping/duplicate controls, reconciliation controls, Activity and read-only AI-ledger filter fields | `RekonPursuit/ContentView.swift` |
| Settings custom protected-export dialog | recovery-key entry only; preserve root-owned presentation and callbacks | `RekonPursuit/SettingsView.swift` |

### Excluded

- `NSOpenPanel`, `.fileImporter`, and every other native macOS file panel: no styling, wrapping, accessibility customization, callback, allowed-content-type, path, security-scope, or cancellation change.
- `RekonPursuitCore/**`, `WorkspaceViewModel.swift`, persistence, migrations, models, audit events, recovery/archive/protected-export/purge/restore/document behavior, network behavior, fixture construction, launch parsing, signing, project graph, and product routes.
- New controls, new preferences, persisted filter/editor state, new identifiers except narrowly necessary stable test selectors, AI execution/configuration, and any VD2-07c/VD2-07d feature work.

## Required design and behavior contract

1. Establish a semantic shared control family in `RekonVisualTheme.swift`, rather than screen-specific ad-hoc modifiers. It must cover single-line text/search, multiline text, numeric text (still a text binding), and SwiftUI picker presentation. It may compose the already-tested Pipeline AppKit controls, but must not replace their bindings, selection types, delegates, accessibility values, or custom keyboard behavior.
2. Idle, hover, focus, disabled, validation/error, and selected states must remain legible against the navy surfaces. Focus must be visibly different from hover and must not depend on color alone; existing textual validation/error content and picker labels remain exposed.
3. Apply the family to every inventory item above. Do not alter field labels/placeholders, `accessibilityIdentifier`s, accessibility labels/values, `@FocusState` ownership, validation predicates, disabled predicates, keyboard shortcuts, control order, bindings, or `onChange` effects.
4. `TextEditor` styling must retain usable selection/caret behavior, scrolling, minimum/expanded heights, and Dynamic Type wrapping without clipping primary content. It must not synthesize persistence on keystroke.
5. Picker styling must retain option sets, selection tags/types, keyboard/VoiceOver operation, and selected-value disclosure. Custom Pipeline popup/checkbox/view-mode controls retain their current native roles and semantic values.
6. Recovery-key fields remain root-owned and secret-safe: no recovery key is added to fixture data, identifiers, labels, screenshots, logs, result attachments, or planning evidence. The existing cancel/error/confirmation behavior remains unchanged.
7. The Activity & AI fields remain informational/local-only filters; no AI request, provider setting, network path, or ledger data is introduced. Existing disabled/no-results truth remains intact.

## Serial, test-first delivery tasks

### Task 1 — Inventory-backed RED contract and safe baseline

**Allowed files:**

- Modify: `RekonPursuitUITests/RekonPursuitUITests.swift`
- Read-only baseline evidence: `RekonPursuitTests/WorkspaceViewModelTests.swift`, `RekonPursuitCoreTests/ProtectedExportTests.swift`, `RekonPursuitCoreTests/PortableArchiveTests.swift`, `RekonPursuitUITestHostTests/RekonPursuitUITestHostTests.swift`

**Deliverable:** Add fixture-driven UI tests that first prove each target route/dialog is ready, then fail only because the new shared control-surface evidence is absent. Do not modify production code in this task.

- [ ] Add `testVD207bSharedFormControlAlignmentAcrossContactsPipelineAndActivity()` using existing deterministic `contacts` and `populated` fixtures. It must exercise `contact-search`, `contact-name`, `contact-employer-search`, a contact multiline editor, `opportunity-search`, `pipeline-stage-filter`, `activity-search`, and one existing AI-ledger text/picker filter. It asserts each remains present, labeled, enabled/disabled as before, keyboard-focusable where current UI supports it, and exposes a common control-surface evidence identifier/value that does not carry user content.
- [ ] Add `testVD207bOpportunityEditorsRetainBindingsValidationAndNoSaveBack()` using a unique existing visual-fixture session. It exercises Add Opportunity Cancel/no-write separately from canonical overview edit. After non-secret overview edits to title/company/numeric fields, the existing due-date path, a picker, and description/notes editors, it activates the actual `Back to Pipeline` action—not a non-existent Cancel. It proves Back fabricates no row or activity event and a relaunch retains the original opportunity; the existing save path remains covered independently. It records a RED only for absent shared-control evidence after preservation assertions pass.
- [ ] Add `testVD207bSettingsRecoveryFieldsRetainRootOwnershipAndFilePanelsRemainNative()` using `archive` and `document-relink` fixtures. It opens existing archive/protected-export/restore entry flows and observes the root modal recovery input plus retained cancel/error state without entering or recording a key. It asserts the document action still enters the existing native importer boundary only by its current app-side trigger; it must not query, style, or automate the operating system panel. It proves Settings rail/section truth, no metadata disclosure, and no invented protected-export success before recording missing shared-control evidence.
- [ ] Add `testVD207bCompactAndLargeTextControlLayout()` at the existing wide and compact sizes, with the test process’s supported larger accessibility text setting if the host provides one. It proves primary field labels, editor contents/scroll region, Save, Back, or Cancel actions, and validation/error text are visible or scrollable rather than clipped. It must not reinterpret the three listed VD2-08 accessibility debts as green evidence.
- [ ] Run the four new tests before production work. A valid RED has a ready named fixture and all preservation baseline assertions passing, then fails only on the new shared-surface selector/value. Build, signing, fixture, route, native panel, privacy, existing accessibility debt, or functional regression failures are blockers—not RED evidence.

### Task 2 — Implement the shared semantic control family and apply it

**Allowed files:**

- Modify: `RekonPursuit/RekonVisualTheme.swift`
- Modify: `RekonPursuit/ContentView.swift`
- Modify: `RekonPursuit/ContactsView.swift`
- Modify: `RekonPursuit/PipelineView.swift` only if an invocation-level alignment is needed; do not rewrite the native controls.
- Modify: `RekonPursuit/SettingsView.swift`

**Interfaces:** The new API lives at the theme seam and accepts only presentation state; callers retain all existing bindings, labels, action closures, and accessibility contracts. `ContentView` remains sole owner of the workspace model, routes, file dialogs, confirmations, recovery-key strings, and modal state.

- [ ] Implement the smallest shared style/modifier/wrapper set in `RekonVisualTheme.swift` for text/search, multiline, and picker presentation. Reuse existing tokens and focus calculations. The public surface must not accept a `WorkspaceViewModel`, URL, recovery key, persistence object, or callback.
- [ ] Add a stable, non-secret semantic test projection to the common presentation (for example control kind plus `Idle`/`Focused`/`Disabled`); preserve each existing identifier and accessibility label/value. Do not encode current text, document data, selected opportunity IDs, recovery values, or file paths.
- [ ] Apply the theme family exhaustively to the Task 1 inventory in `ContentView.swift`, `ContactsView.swift`, and `SettingsView.swift`. Keep all existing per-control layout constraints, `@FocusState` bindings, validation text, picker tags, toggle/date behavior, and root-owned callbacks verbatim in effect.
- [ ] Keep `PipelineNavySearchControl`, `PipelineNavyStageControl`, `PipelineNavyCheckboxControl`, and `PipelineNavyViewModeControl` as their existing AppKit/SwiftUI ownership boundary. If a Pipeline call site changes, it may only apply common spacing/container semantics that leave native view roles, selectors, values, and delegates unchanged.
- [ ] Run all Task 1 selectors GREEN. Any behavior/persistence/audit/security regression stops the task and requires an independent diagnosis; no test relaxation is authorized.

### Task 3 — Regression evidence and independent acceptance package

**Allowed files:**

- Modify only when a failing green selector proves a production correction is necessary: the Task 2 file allowlist.
- Modify: `RekonPursuitUITests/RekonPursuitUITests.swift` only for deterministic assertions required to complete the Task 1 matrix.

- [ ] Run existing Contacts persistence/audit/validation coverage: `testVD206ContactsEditCancelSaveAndRelaunchContract`, `testVD206ContactChannelsEditorAndDetailActionsContract`, and `testVD206ContactsErrorAccessibilityContract`.
- [ ] Run existing Pipeline native-control/filter and canonical-edit coverage: `testVD204PipelineControlsRemainKeyboardDiscoverableAndStyled`, `testVD204PipelineNavySurfaceControlsRemainSemanticallyOperableInTableAndBoard`, `testVD204PipelineFiltersUseOnlyTheSessionLocalControlsAndExposeTruthfulNoResults`, and `testVD204PipelineOpenDetailsSavesAndRelaunchesCanonicalEditWithActivityEvidence`.
- [ ] Run existing Settings safety coverage: `testVD207SettingsRecoveryRetainsArchiveTruthAndRootOwnedCancellation`, `testVD207ProtectedExportEntryUsesRootDialogAndRetainsErrorUntilCancel`, `testVD207SettingsDocumentAndAISectionsStayAggregateAndUnavailable`, and `testVD207SettingsRelaunchKeepsFixtureTruthAndResetsLocalSelection`, plus lower-layer protected-export/archive selectors named in the VD2-07x brief.
- [ ] Inspect the signed result bundle’s test list and attachments. Every new and retained selected test executes once with no skip or expected failure. Confirm no attachment, label, value, log, or screenshot contains recovery-key material or document metadata.
- [ ] Build the app and UI test host using the configured Debug signing identity; inspect app, host, and test-bundle signatures with `codesign --verify --deep --strict` and `codesign -dvv`. Never build or launch this Data Protection Keychain workflow with `CODE_SIGNING_ALLOWED=NO`.
- [ ] Preserve an implementation review package with the exact source inventory, before/after control coverage, per-selector outcome, result-bundle summary, signature evidence, `git diff --check`, and explicit unchanged-native-file-panel statement. Independent Code Review, QA, Architect, Security/privacy, TPM, Delivery, then product-owner hands-on verification are required before acceptance.

## Required fixtures and acceptance scenarios

| Fixture/session | Proof | Non-happy-path proof |
| --- | --- | --- |
| `contacts` and unique relaunch session | Contact search/editor controls have the shared visual/focus surface; valid save persists and emits the existing activity evidence. | Invalid email keeps the draft and existing accessible validation; Cancel writes nothing. |
| `populated` | Pipeline search/stage controls and Add/Overview opportunity inputs retain their current bindings and canonical route. Activity search/AI filters remain local/informational. | Clear/no-result behavior, Add Cancel, canonical overview Back/no-save, and relaunch do not fabricate an opportunity or activity event. |
| `archive` | Existing Settings recovery/protected-export inputs display aligned chrome while root state and actions remain intact. | Empty/error/cancel paths retain current text/state and never show invented export success. |
| `document-relink` | Settings remains aggregate-only and document flow retains its current app-side entry point. | No filename, path, hash, bookmark, MIME type, or native panel representation enters UI evidence. |
| existing compact/wide host sizes | Labels, focus indication, picker selected values, multiline content, and actions remain readable/scrollable. | No control clipping; pre-existing VD2-08 debt assertions remain reported as debts, not removed or passed by proxy. |

## Verification commands

Use distinct generated paths under `/private/tmp`; remove only the paths generated for this task. Substitute the exact four new method names if their spelling differs only after the approved Task 1 implementation.

```sh
xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit -configuration Debug -destination 'platform=macOS,arch=arm64' \
  -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207bSharedFormControlAlignmentAcrossContactsPipelineAndActivity \
  -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207bOpportunityEditorsRetainBindingsValidationAndNoSaveBack \
  -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207bSettingsRecoveryFieldsRetainRootOwnershipAndFilePanelsRemainNative \
  -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207bCompactAndLargeTextControlLayout \
  -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD206ContactsEditCancelSaveAndRelaunchContract \
  -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD206ContactChannelsEditorAndDetailActionsContract \
  -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD206ContactsErrorAccessibilityContract \
  -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD204PipelineControlsRemainKeyboardDiscoverableAndStyled \
  -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD204PipelineNavySurfaceControlsRemainSemanticallyOperableInTableAndBoard \
  -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD204PipelineFiltersUseOnlyTheSessionLocalControlsAndExposeTruthfulNoResults \
  -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD204PipelineOpenDetailsSavesAndRelaunchesCanonicalEditWithActivityEvidence \
  -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207SettingsRecoveryRetainsArchiveTruthAndRootOwnedCancellation \
  -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207ProtectedExportEntryUsesRootDialogAndRetainsErrorUntilCancel \
  -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207SettingsDocumentAndAISectionsStayAggregateAndUnavailable \
  -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207SettingsRelaunchKeepsFixtureTruthAndResetsLocalSelection \
  -derivedDataPath /private/tmp/rekon-vd207b-dd \
  -resultBundlePath /private/tmp/rekon-vd207b.xcresult

xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit -configuration Debug -destination 'platform=macOS,arch=arm64' \
  -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testRefreshIncludesLifecycleAwareDocumentReferenceSummary \
  -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testCancellingReviewedProtectedExportClearsReviewWithoutWritingOrChangingActiveWorkspace \
  -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testPortableArchiveControlsStayDisabledThroughoutAwaitedVerificationAndRestore \
  -only-testing:RekonPursuitTests/PortableArchiveTests/testRetainedDataPurgeRejectsWrongKeyBeforeWritingJobOrLease \
  -only-testing:RekonPursuitTests/ProtectedExportTests/testExistingTargetIsRejectedWithoutOverwritingIt \
  -derivedDataPath /private/tmp/rekon-vd207b-core-dd \
  -resultBundlePath /private/tmp/rekon-vd207b-core.xcresult

xcodebuild build -project RekonPursuit.xcodeproj -scheme RekonPursuit -configuration Debug -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /private/tmp/rekon-vd207b-build-dd

git diff --check
```

## Accessibility-debt handoff evidence

The implementation/review record must list the following as still owned by `VD2-08`, with their test names, observed role/label/value behavior, platform/version, and signed result-bundle path: the Settings compact keyboard-focus handoff (`testVD207ReferenceTabsKeepKeyboardSelectionAtCompactWidth` and `testVD207SettingsSecondaryNavigationIsKeyboardOperableAtCompactWidth`), Settings AI semantic text (`testVD207SettingsDocumentAndAISectionsStayAggregateAndUnavailable`), Contacts accessibility/recovery automation debts, and the VD2-05 Board card-anchor semantic debt. VD2-07b cannot claim acceptance by omitting those tests, adding `XCTSkip`/`XCTExpectFailure`, weakening predicates, or changing the current debt scope.

## Release recommendation

The task is dependency-safe for independent pre-implementation review because `VD2-06` and `VD2-07` are accepted. Do **not** release implementation until the named Architecture, TPM, QA/test, Security/privacy, and Delivery gates approve this brief and its exhaustive inventory. Any inventory gap, native-panel interaction, behavior/persistence/audit change, secret/metadata disclosure, or attempt to close VD2-08 debt within this card is a release blocker.

## 2026-08-02 planning amendment — QA inventory and no-save contract

This amendment supersedes the Task 1 descriptions, the `populated` fixture's
"edit cancel" wording in the acceptance table, and any earlier statement that
representative controls prove the inventory. It changes neither the Objective,
Task 2/3 production allowlists, excluded work, native-panel boundary, nor the
VD2-08 debt handoff. It is planning-only; Task 1 remains the sole candidate
for release after fresh QA, Security/privacy, and Delivery approval.

### Amended Task 1 — exhaustive table-driven RED contract and safe baseline

**Allowed files remain:** `RekonPursuitUITests/RekonPursuitUITests.swift` is
the only writable product/test file; the prior Task 1 baseline files remain
read-only. No selector, fixture, route, accessibility-debt, native-panel,
privacy, signing, persistence, or audit failure is RED evidence.

The tests must define one table row for every control key below. A row contains
the listed current selector or deterministic label query, fixture/route,
`kind`, and expected existing role/label/value/enabled/selected behavior. The
row's final assertion is an *additive*, content-free projection keyed by that
control key. Its closed vocabulary is
`kind=<text|search|multiline|numeric|picker|checkbox|radioGroup>` and
`state=<idle|focused|disabled|error|selected|checked|unchecked>` as
applicable: the Pipeline checkbox uses `checkbox` with `checked` or
`unchecked`, and the Pipeline view switcher uses `radioGroup` with `selected`
for its current selection. The projection may be a narrowly necessary stable
test selector, but it must not replace or change the native element's
identifier, role, label, value, keyboard order, binding, delegate, or
target/action path. In particular, its attachment must not install a competing
focus owner or first responder, or replace the native accessibility element.
It must not contain input text, record IDs, recovery material, file or document
metadata, paths, or fixture data. A table failure message must name the
control key and expected projection. Date/toggle rows below are
preservation-only: assert their current label, enabled/selected value, and
route behavior, but do not expect or claim shared-surface styling.

| Key / current selector or deterministic label | Fixture and route | Required baseline and RED assertion |
| --- | --- | --- |
| `pipeline.search` / `opportunity-search`; `pipeline.stage` / `pipeline-stage-filter`; `pipeline.includeClosed` / `pipeline-include-closed`; `pipeline.viewMode` / `pipeline-view-mode` | `populated`, Pipeline in **both Table and Board** renderings | Preserve AppKit text-field, popup, checkbox, and radio-group roles; labels `Search opportunities`, `Stage`, `Include closed`, and `View`; current values/selection, delegates/bindings, and keyboard operation. Assert all four projections; checkbox and view mode are not omitted because they are native controls. |
| `contacts.search` / `contact-search`; `contacts.employerFilter` / label `Filter contacts by employer` | `contacts`, Contacts list | Preserve the current filter values, enabled state, no-results truth, and contact-list binding. The label-only Employer picker is a required projection row. |
| `contacts.name` / `contact-name`; `contacts.title` / `Title (optional)`; `contacts.workEmail` / `contact-work-email`; `contacts.personalEmail` / `contact-personal-email`; `contacts.mobilePhone` / `contact-mobile-phone`; `contacts.officePhone` / `contact-office-phone`; `contacts.linkedIn` / `contact-linkedin`; `contacts.instagram` / `contact-instagram`; `contacts.facebook` / `contact-facebook` | `contacts`, new and edit Contact editor | Preserve labels, current validation predicates, bindings, and enabled states, then assert each text/numeric-family projection (these are text controls even where the input is URL/phone shaped). |
| `contacts.employerSearch` / `contact-employer-search`; `contacts.newEmployer` / `New employer (optional)` | `contacts`, Contact editor | Exercise the existing tracked-employer-search branch and the existing new-employer branch separately; preserve their branch switch, suggestion/select behavior, and binding. Assert the projection only for the branch rendered. |
| `contacts.relationshipContext` / label `Relationship context (optional)`; `contacts.notes` / label `Notes (optional)` | `contacts`, Contact editor at collapsed and expanded sizes | Preserve TextEditor selection/caret, scrolling, expanded/minimum height, labels, and Expand/Collapse state; assert multiline projections. Successful save/relaunch/activity evidence and invalid-email draft retention plus Cancel/no-write are separate focused flows. |
| `add.title` / `opportunity-title`; `add.company` / `opportunity-company`; `add.url` / `Job URL (optional)`; `add.description` / label `Job description`; `add.notes` / label `Notes`; `add.minimum` / `Minimum (USD)`; `add.maximum` / `Maximum (USD)`; `add.location` / `Location (optional)`; `add.payPeriod`, `add.workArrangement`, `add.response`, `add.stage`, `add.nextAction` / their visible labels; `add.otherAction` / `opportunity-next-action` when selected | `populated`, Add Opportunity | Preserve every text, multiline, numeric, picker label/tag/type and selected-value disclosure. Toggle `Add applied date` and its `Applied date`, plus toggle `Add a due date` and its `Due`, are preservation rows: toggle them only to expose the listed paths and prove current labels/selection/enablement. Use existing Cancel to prove no row/activity write, then relaunch. |
| `overview.title` / `selected-opportunity-title`; `overview.company`, `overview.url`, `overview.description`, `overview.notes`, `overview.minimum`, `overview.maximum`, `overview.location` / their visible labels; `overview.payPeriod`, `overview.workArrangement`, `overview.stage`, `overview.nextAction` / their visible labels; `overview.otherAction` / `Other action` when selected | `populated`, canonical `OpportunityOverviewView` | Preserve bindings, picker tags/types and selected-value disclosure. `Add a due date` and conditional `Due` are preservation rows. After non-secret edits, activate the existing **`Back to Pipeline`** action—not a fictional Cancel—and prove it creates neither an opportunity nor an activity event; after relaunch, prove the original persisted record remains unchanged. `Save changes locally` is exercised separately for the retained save/audit regression. |
| `reschedule.dueDate` / `home-reschedule-due-date` | deterministic task with an existing reschedule route | Preservation-only DatePicker row: preserve `New due date`, selected value, enabled state, Cancel and `Save locally` behavior; do not assert shared styling. |
| `recovery.setupReentry`, `recovery.archiveReentry` / label `Re-enter the complete recovery key`; `recovery.retainedPurgeReentry`, `recovery.restoreReentry`, `settings.protectedExportReentry` / label `Recovery key` | `archive` plus each existing root-owned flow | The restore recovery field is an **included app-owned, root-owned sheet input**, not a native-panel element; only the preceding archive-selection action is an excluded native panel. Interact with the ready setup/archive/purge/protected-export inputs to assert empty/error/cancel/confirmation, root ownership, current enabled state, and no invented success. Current fixtures do not deterministically enter `awaitingRecoveryKey` without that excluded selection panel, so `recovery.restoreReentry` is a static source/selector coverage row for this card: verify the conditional root-sheet `TextField("Recovery key", ...)`, its existing cancel/verify callbacks, and the common text-family application in the source-to-selector review; do not claim interaction RED/GREEN for it or automate the panel. Never type, attach, log, query value of, screenshot, or otherwise record a recovery key. Every interactable rendered recovery input receives a non-secret text-family projection only if the projection itself contains no secret/value. |
| `overview.documentReferenceType` / `Reference type` | `document-relink`, canonical overview Manage menu | Preserve picker tags/type/selected-value disclosure and the existing app-side `choose-document-reference` trigger. The native chooser must not be queried, styled, wrapped, automated, or represented in evidence. |
| `reconcile.outcome`, `reconcile.classification`, `reconcile.reason`, `reconcile.confidence` / labels `Local outcome`, `Classification`, `Reason`, `Confidence`; `reconcile.evidence` / `Evidence or error reviewed` | `reconciliation`, Reconcile posting | Preserve four picker option/tag/type/selected-value contracts and multiline binding. Assert projections without recording document material; retain offline/no-network behavior. |
| `import.mapping.<CSVImportField case>` / each label generated by **every** `CSVImportField.allCases` case (including its current required-marker suffix); `import.duplicateDecision` / `Duplicate decision` | CSV review is conditional on `csvPreview`/`csvImportPlan`; no current deterministic visual fixture initializes either state | Retain every mapping case and duplicate decision in the exhaustive inventory. Because the sole current route to those states is `choose-csv-file` and its excluded native chooser, this card explicitly restricts these rows to static source/selector coverage: enumerate `CSVImportField.allCases`, the `ForEach` mapping picker, the duplicate-decision picker, their tags/types, and their common picker-style invocation in the source-to-selector review. The UI test may assert only the existing app-side `choose-csv-file` trigger; it must not query, style, wrap, automate, or represent the OS chooser, and it must not claim interaction RED/GREEN or selected-value proof for the unreachable conditional controls. A later separately approved fixture/launch seam is required before converting these rows to interaction evidence. |
| `activity.search` / `activity-search`; `ai.time` / `ai-ledger-time-filter`; `ai.feature` / `ai-ledger-feature-filter`; `ai.opportunity` / `ai-ledger-opportunity-filter`; `ai.route` / `ai-ledger-route-filter`; `ai.model` / `ai-ledger-model-filter`; `ai.completion` / `ai-ledger-completion-filter`; `ai.minimumCost` / `ai-ledger-min-cost-filter`; `ai.maximumCost` / `ai-ledger-max-cost-filter` | `populated`, Activity & AI | Preserve all eight local AI filter types/selected values and Activity search; prove invalid cost-range validation, clear/no-results truth, no request/provider/network action/ledger entry, and no persisted filter state. Assert every text/numeric/picker projection. |

Task 1 must keep these four top-level tests (renaming the second to state the
actual route semantics):

- [ ] `testVD207bSharedFormControlAlignmentAcrossContactsPipelineAndActivity()` runs the Pipeline, Contacts-list, Contacts-editor, and Activity/AI table rows, including both Pipeline view modes, Employer picker, checkbox, and view-mode control.
- [ ] `testVD207bOpportunityEditorsRetainBindingsValidationAndNoSaveBack()` runs Add, canonical overview, reschedule, reconciliation, and document-reference-type interaction rows; it records the CSV app-side trigger and the required static source/selector coverage, but does not claim conditional CSV control interaction proof. It separately proves Add Cancel/no-write and overview Back/no-save/relaunch; it never calls overview Back “Cancel.”
- [ ] `testVD207bSettingsRecoveryFieldsRetainRootOwnershipAndFilePanelsRemainNative()` runs every deterministically reachable recovery row and both native-boundary trigger assertions with no secret or document evidence; it records the restore input's required static root-sheet coverage without entering the native archive-selection panel.
- [ ] `testVD207bCompactAndLargeTextControlLayout()` runs wide and compact coverage for **every** table-listed multiline editor. Use the supported larger accessibility-text launch setting only after the host demonstrates it supports that setting. For each editor, prove label, focus cue, visible or scrollable content, validation text where applicable, and reachable Save, Back, or Cancel action without clipping.

Add focused deterministic helpers/tests when route setup would make those
top-level methods ambiguous: Pipeline native role/keyboard preservation;
Contacts successful save/relaunch/activity versus invalid-draft/Cancel;
Add Cancel/no-write versus overview Back/no-save; recovery root-dialog
error/cancel; CSV/reconciliation native boundary; and Activity/AI local-filter
truth. Helpers may share table data but must preserve an independently named
failure for each matrix key.

Before Task 2, run all four top-level tests and focused methods. For every
interaction row, the valid RED sequence is: named deterministic fixture/route
ready; existing role/label/value/enabled/selection/binding/no-write/privacy
assertions green; then exactly its absent additive projection fails. The three
explicit static-only groups—`recovery.restoreReentry`, every
`import.mapping.<CSVImportField case>`, and `import.duplicateDecision`—remain
exhaustive inventory and source-to-selector review requirements, but are not
valid interaction RED targets until a separately approved deterministic seam
exists. A missing selector, wrong workflow, native-panel interaction,
persistence/audit change, recovery or document disclosure, signing failure, or
VD2-08 failure blocks the card.

### Amended acceptance wording and verification selector

In the `populated` acceptance scenario, replace “edit cancel” with “canonical
overview Back/no-save.” The acceptance proof is: Add Cancel writes nothing;
canonical overview Back writes neither a record nor activity event and a
relaunch shows the original persisted record; Save changes locally continues
to use its existing save/audit regression. The first verification command must
select `testVD207bOpportunityEditorsRetainBindingsValidationAndNoSaveBack`
instead of the superseded `…AndCancel` name, plus any focused methods added
above. All other command, signing, result-bundle, privacy, native-panel, and
VD2-08 requirements remain unchanged.
