# VD2-07 pre-implementation architecture recheck

**Date:** 2026-08-01  
**Role:** Fresh independent Architect  
**Reviewed commits:** `efe1de6` (approved Settings IA design) and `c14053b` (amended task brief and implementation plan)  
**Supersedes for architecture release-gate purposes:** `VD2-07-preimplementation-architecture-review-2026-08-01.md`  
**Verdict:** **ACCEPT**

## Decision

The amended plan closes every architecture-blocking verification gap identified
by the prior review without changing the approved architecture. It remains a
presentation extraction: `ContentView` owns the sole `WorkspaceViewModel`,
global rail/route, recovery-key strings, file panels, sheets, alerts,
destructive confirmation, and action dispatch. `SettingsView` owns only its
non-persisted `.recoveryArchives`-default local selector and receives
display-safe presentation values plus bounded closures.

The plan retains the five-destination global rail and explicitly prohibits an
`AppDestination`, `DailyRoute`, or persisted Settings selection. Its source
boundary keeps recovery, archive/export/purge/restore, document, AI, cloud,
Gmail, Calendar, persistence, fixtures, and routing behavior read-only.

## Recheck evidence

| Required correction | Evidence reviewed | Result |
| --- | --- | --- |
| Every mandatory lower-layer and fixture selector runs in both Task 1 RED and Task 2 GREEN commands | The two commands in `docs/superpowers/plans/2026-08-01-vd207-settings-information-architecture.md` include, once each, all brief-mandated document-summary; archive/restore busy, verification, cancellation, and disabled-state; protected-export review/error/no-overwrite/cancellation; expiry; both purge-safety; inactive-restore; separate-workspace return/relaunch; and all nine fixture/recovery-only selectors. The command selector sets are paired; the Task 2-only presentation-state test is correctly absent from the pre-extraction RED run. | **Covered** |
| Root-owned action, modal, and cancellation evidence | `testVD207SettingsRecoveryRetainsArchiveTruthAndRootOwnedCancellation` enters the archive, protected-export, and retained-purge root dialogs from Settings and cancels each without entering a recovery key; it reasserts the unchanged archive truth after every cancel. `testCancellingReviewedProtectedExportClearsReviewWithoutWritingOrChangingActiveWorkspace` separately proves reviewed-export cancellation clears review state without a destination write or active-workspace change. The Task 2 extraction moves the existing sheets/alert and all bindings/model calls verbatim to `ContentView`. | **Covered** |
| Fixed-clock archive and disabled/busy presentation evidence | The archive fixture test asserts the verified durable filename and exact fixed created/expiry/lifecycle accessibility value, plus the enrolled non-busy predicates. Both runners include the fixed-time, archive-construction, archive-catalogue, and calendar-boundary fixture tests. `testVD207SettingsRecoveryPresentationPreservesBusyDisabledAndInactiveCandidateContracts` covers all retained disabled predicates, archive/export/purge/restore busy copy, purge status pass-through, and inactive restore candidate copy in the Task 2 GREEN command. | **Covered** |
| Panel-scoped Document and AI absence checks | `testVD207SettingsDocumentAndAISectionsStayAggregateAndUnavailable` queries the selected Document panel's descendants for label/value metadata sentinels and asserts zero buttons, menu buttons, links, checkboxes, switches, and text fields. It likewise requires the selected AI panel's factual unavailable copy and zero actionable child-control kinds. The planned interface passes `DocumentReferenceSummary` only and no AI configuration object. | **Covered** |
| Unchanged `ContentView`, global rail, and local-state bounds | The design and brief require the existing global rail and a Settings-local, non-persisted selector. The plan gives `SettingsView` no model, store, route, file panel, sheet, alert, persistence call, or recovery-key text; its only state is `selectedSection`. Its explicit `ContentView` injection and verbatim modifier-move instructions retain the existing root ownership. UI coverage reasserts selected `sidebar-settings`, compact keyboard operation, and a relaunch reset to Recovery & archives. | **Covered** |

The test commands require signed Debug execution, result bundles, per-selector
no-skip evidence, attachment inspection, project-structure checks, and strict
signature verification. These are appropriately deferred execution evidence;
this is a plan review, not proof that the implementation or tests are already
green.

## ADR / deviation

**No ADR is required.** The approved ownership, data-flow, privacy, and routing
architecture is unchanged. The amendments add verification coverage and a
display-only presentation seam; they do not authorize an ownership, storage,
navigation, recovery, document, or network deviation. Any later deviation from
the `ContentView`-root / Settings-local boundary requires a new ADR before
implementation continues.

## Release limitation

This **ACCEPT** removes only the prior Architecture plan-coverage blocker. It
does not release Task 1 or implementation. A Delivery Manager may release only
the next dependency-safe task after the separate QA/test, Security/privacy,
TPM, and Delivery pre-implementation decisions are recorded. Task 2 remains
blocked until an independent QA verifier accepts the Task 1 signed fixture
result and its exact RED classification. Final delivery still requires the
specified independent review, signed Debug evidence, Security/privacy review,
TPM/Delivery gate, and explicit product-owner hands-on decision.
