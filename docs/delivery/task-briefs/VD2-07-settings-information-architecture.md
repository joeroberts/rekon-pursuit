# VD2-07 — Settings Information Architecture Task Brief

**Status:** Planning complete. Implementation is not released. A Delivery Manager may release only Task 1 after the independent pre-implementation approvals listed below are recorded.

## Controlling artifacts

- `docs/superpowers/specs/2026-08-01-vd207-settings-information-architecture-design.md`
- `docs/superpowers/specs/2026-07-28-visual-design-v2-design.md`
- `docs/superpowers/plans/2026-07-28-visual-design-v2.md` (Task 7)
- `.superpowers/sdd/2026-08-01-vd207-settings-ia/preimplementation-tpm-release-gate.md`
- `docs/delivery/handoffs/VD2-06-to-VD2-07-codex-handoff-2026-08-01.md`
- `docs/delivery/task-briefs/RP-R9-lifecycle-aware-settings.md`
- `docs/architecture/specification.md`

## Objective

Extract the current Settings presentation into `SettingsView.swift` and provide Settings-local sub-navigation for **Workspace**, **Recovery & archives**, **Document references**, and **AI & connections**. The default is **Recovery & archives**. The change must preserve the existing global app rail and every current local recovery, archive, protected-export, purge, restore, document, and AI safety contract.

## Exact implementation boundary

| Path | Allowed change |
| --- | --- |
| `RekonPursuit/ContentView.swift` | Remove the private Settings view; retain sole `WorkspaceViewModel`, global-route, sheet, alert, file-panel, destructive-confirmation, and recovery-return ownership; pass display-safe values and action closures to `SettingsView`. |
| `RekonPursuit/SettingsView.swift` | Create the local selected-section state and the four focused presentation sections. It must not read a store, own a global route, persist selection, create a sheet, hold recovery-key text, or invoke a model action directly. |
| `RekonPursuit.xcodeproj/project.pbxproj` | Register the one new Swift file in exactly the existing `RekonPursuit` and `RekonPursuitUITestHost` source phases. No other project-graph, build, entitlement, signing, target, resource, or scheme change is allowed. |
| `RekonPursuitUITests/RekonPursuitUITests.swift` | Add the deterministic fixture-driven Settings navigation, compact/keyboard, recovery/archive, document-redaction, AI-unavailable, and global-rail regression selectors described below. |

`WorkspaceViewModel.swift`, `RekonPursuitCore/**`, migrations, persistence, test-host launch parsing, fixture identities, app routes, app-shell navigation, and all recovery/export/archive/document/AI behavior are read-only for this task. Existing lower-layer tests are required regression evidence; no production recovery mechanism is introduced to make presentation testing easier.

## Required ownership and interfaces

`ContentView` continues to own the existing state currently declared with the Settings view: `generatedRecoveryKey`, `reentry`, `recoveryKeyCopied`, `archiveRecoveryReentry`, `isPresentingArchiveCreation`, `protectedExportReentry`, `isPresentingProtectedExport`, `retainedDataPurgeReentry`, `isPresentingRetainedDataPurge`, and `portableArchiveRestoreKey`. It retains the existing recovery-key enrollment, portable-archive creation, protected-export, retained-data-purge, portable restore, and restore-failure sheets/alert without copy or behavioral changes.

`SettingsView` owns only this non-persisted local presentation state:

```swift
private enum SettingsSection: CaseIterable, Hashable {
    case workspace
    case recoveryArchives
    case documentReferences
    case aiConnections
}

@State private var selectedSection: SettingsSection = .recoveryArchives
```

The root and focused sections consume display-safe data and callbacks, not a store or recovery key. The bounded callback surface is:

```swift
let returnToPreservedWorkspaceRecovery: () -> Void
let beginRecoveryKeyEnrollment: () -> Void
let presentArchiveCreation: () -> Void
let presentProtectedExport: () -> Void
let presentRetainedDataPurge: () -> Void
let cancelRetainedDataPurge: () -> Void
let choosePortableArchiveForRestore: () -> Void
```

The Recovery section may receive only the enrolled flag, action-disabled/busy flags, durable purge status text, a `restoreReady` flag, and archive display summaries containing archive ID, display filename, created date, expiry date, and lifecycle text. The Document section may receive only `DocumentReferenceSummary`. It must never receive `DocumentReference`, a path, bookmark, source hash, filename, or byte count. The AI section receives no configuration object and exposes no control.

## Required presentation and behavior

- Keep the existing global rail: Home, Pipeline, Contacts, Activity & AI, and Settings. Settings local selection is not an `AppDestination`, `DailyRoute`, or a persisted preference.
- Place a semantically distinct secondary selector below `Settings`. It has stable identifiers `settings-section-workspace`, `settings-section-recovery-archives`, `settings-section-document-references`, and `settings-section-ai-connections`; its container is `settings-secondary-navigation`. The active selector exposes a non-color accessibility value of `Selected` and the selected panel has a stable `settings-section-*-panel` identifier.
- At the compact host width (860×640 effective shell), the selector and active section remain visible, operable, and vertically stacked; wide remains a readable desktop surface. Changing local selection must leave `sidebar-settings` selected and must not navigate away from Settings.
- Workspace shows the current local-retention explanation and, only while the existing `usingSeparateLocalWorkspace` fact is true, the existing `return-to-preserved-workspace-recovery` action.
- Recovery & archives preserves exactly the current setup, archive, protected export, retained-data purge, and restore controls, identifiers, disabled predicates, busy copy, durable catalogue/lifecycle wording, cancellation behavior, destructive confirmation, and inactive-candidate restore result. The existing purge action remains visible when enrolled; it is disabled under its existing predicate.
- Document references state only `availableCount` and `relinkRequiredCount`. They expose no file access controls or metadata.
- AI & connections retains the factual MVP wording: the Activity & AI ledger is read-only and empty; no AI request, cost, model runtime, cloud, Gmail, or Calendar integration is configured.

## Deterministic fixture and regression matrix

Every UI run uses the existing UUID-qualified `REKON_VISUAL_FIXTURE_SESSION` and the fixed `VisualFixtureLaunchConfiguration.fixedNow`; it never opens a personal workspace or uses a real recovery key in test source, labels, screenshots, result attachments, logs, or evidence.

| Fixture | Settings proof | Required assertions |
| --- | --- | --- |
| `populated` | Not enrolled | Default Recovery panel, `set-up-recovery-key`, all four local selectors, semantic keyboard selection, and unchanged selected global Settings rail. |
| `archive` | Enrolled with a verified archive created at the fixed clock | Existing archive/export/purge/restore identifiers, fixed durable archive filename/date/expiry/lifecycle summary, and non-busy enabled/disabled predicates. |
| `document-relink` | One active relink-required document reference | Aggregate `0 available · 1 require relinking` surface after local selection, with no source filename, hash, bookmark, path, or document command in Settings. |
| `recovery` | Recovery-only unopened workspace | Existing onboarding regression: no global destinations, including Settings, are exposed. It is not converted into a Settings fixture. |

The following already-present lower-layer contracts are required before and after the presentation extraction. Their use is regression evidence, not authority to change their implementations:

- document summary refresh: `testRefreshIncludesLifecycleAwareDocumentReferenceSummary`;
- restore scope, verification failure, cancellation, inactive candidate, and disabled controls: `testPortableArchiveRestoreKeepsSecurityScopeUntilExplicitConfirmationCompletes`, `testPortableArchiveVerificationFailureRemainsVisibleUntilDismissed`, `testCancellingAwaitedPortableArchiveRestoreReleasesScopeExactlyOnceAfterWorkerFinishes`, and `testPortableArchiveControlsStayDisabledThroughoutAwaitedVerificationAndRestore`;
- protected-export error/no-overwrite: `testProtectedExportReviewFailureRemainsVisibleForCorrection` and `testSourceRevisionChangeRejectsReviewedExportWithoutCreatingAFile`;
- archive expiry, purge, no-key-write, and inactive restore: `PortableArchiveTests` selectors `testExpiryAtBoundaryRemovesOnlyVerifiedMatchingRegularArchive`, `testRetainedDataPurgeRemovesDeletedOpportunityReconciliationAndTombstoneMaterial`, `testRetainedDataPurgeRejectsWrongKeyBeforeWritingJobOrLease`, and `testVerifiedArchiveRestoresIntoANewInactiveWorkspaceWithoutChangingSource`;
- separate-workspace return/relaunch: `testRelaunchPrefersSelectedSeparateWorkspaceAndRetainsOpportunity` and `testReturnToPreservedRecoveryClosesSeparateStoreAndChangesOnlySelector`.

## Serial release sequence

| Task | Deliverable | Dependency-safe release condition |
| --- | --- | --- |
| 1 | Focused fixture-driven Settings UI RED plus baseline lower-layer GREEN | Independent Architecture, QA/test, Security/privacy, TPM, and Delivery approve this brief and plan. Task 1 introduces no production code. |
| 2 | Extracted Settings presentation, ContentView-owned sheets, and minimal two-target source registration | A fresh QA verifier accepts Task 1’s fixture isolation, exact RED classification, and lower-layer baseline. Architecture, TPM, and Delivery approve continuation. |
| 3 | Focused Settings GREEN, signed Debug smoke, source/project-graph evidence, and review package | Task 2 is GREEN; separate Code Reviewer, QA verifier, Architect, Security/privacy verifier, TPM, and Delivery issue their independent decisions. |
| 4 | Owner handoff | Delivery records all accepted evidence and requests hands-on product-owner verification. No dashboard, roadmap, or progress-ledger update is made by an implementer. |

## Acceptance evidence

Before Task 2 begins, preserve the Task 1 `.xcresult`, fixture sessions, exact selectors, and the current project-file SHA-256. A RED is valid only when the existing signed test host launches a ready named fixture and fails because the new named Settings selector/panel is absent. A build, fixture, signing, test-host, global-rail, or accessibility-query failure is a blocker, not RED evidence.

After Task 2, run the focused UI and lower-layer selectors with a unique `-derivedDataPath` and `-resultBundlePath`; confirm every requested selector executed once with no failure or skip. Then build the normal app and the UI test host using the configured Debug signing identity, verify the app, host, and test-bundle signatures with `codesign --verify --deep --strict`, record `codesign -dvv`, inspect the project structural diff, and run `git diff --check`. Never use `CODE_SIGNING_ALLOWED=NO` for this work.

Product-owner hands-on review checks wide and compact Settings: global rail persists, local selector is keyboard operable, default is Recovery & archives, archive/export/purge/restore entry points are present and truthful, canceling a selected path does not change the current workspace, document counts disclose no metadata, and AI/cloud/Gmail/Calendar stay clearly unavailable.

## Non-goals and explicit stop

Do not add or change lifecycle, recovery-key, archive, protected-export, purge, restore, expiry, document, AI, cloud, Gmail, Calendar, budget, or network behavior. Do not add storage, migrations, test-only product switches, new Settings routes, persisted Settings selection, recovery-key fixtures, or document metadata. Do not absorb or mark resolved the three accepted VD2-08 accessibility/recovery automation debts.

This brief authorizes planning evidence only. VD2-07 implementation remains blocked until the independent pre-implementation approvals and a dependency-safe Delivery release are recorded.
