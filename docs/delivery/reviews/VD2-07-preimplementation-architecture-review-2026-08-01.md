# VD2-07 pre-implementation architecture review

**Date:** 2026-08-01
**Role:** Independent Architect
**Reviewed commits:** `efe1de6` (approved Settings IA design) and `ec0b5ce` (task brief and implementation plan)
**Verdict:** **NEEDS CHANGE**

## Architecture decision

The proposed implementation shape is architecturally acceptable. It preserves
the fixed, serial `ContentView` seam: `ContentView` retains the sole
`WorkspaceViewModel`, global-route, dialog/alert, recovery-key-text,
destructive-confirmation, and recovery-sheet ownership; `SettingsView` has
only ephemeral local selection plus display-safe values and callbacks. The
secondary selector is correctly not an `AppDestination`, `DailyRoute`, or
persisted preference, so the five-destination global rail remains unchanged.

The data and callback interfaces are also correctly bounded:

- `SettingsRecoveryPresentation` reduces catalogue rows to display text and
  omits checksum/fingerprint material.
- Document References receives only `DocumentReferenceSummary`, not a
  `DocumentReference`, path, bookmark, hash, filename, or byte count.
- AI & connections has no configuration object or control, preserving the
  default-off consent boundary for AI, cloud, Gmail, Calendar, and network
  work.
- Retained-data purge remains correctly visible as an accepted existing
  capability; the dashboard records `RP-R7b-2` as accepted.

This matches the current implementation seam: `ContentView` selects Settings
from the unchanged `DailyRoute`, while the current private Settings view owns
the recovery/export/purge/restore sheets that the plan explicitly moves to
the `ContentView` modifier chain. `WorkspaceViewModel` remains read-only for
this task and already supplies the archive, export, purge, restore, document
summary, and separate-workspace lifecycle contracts.

## Required changes before implementation release

The verification plan does not yet prove all contracts the approved task brief
requires. This is a release-blocking plan defect, not a request for production
behavior or architecture changes.

1. Add every lower-layer regression named as mandatory by the task brief to
   both the Task 1 RED baseline and Task 2 GREEN command. The brief requires
   expiry, positive purge safety, inactive restore, and separate-workspace
   return/relaunch evidence, but the commands run only the invalid-key purge
   selector. They omit:

   - `testExpiryAtBoundaryRemovesOnlyVerifiedMatchingRegularArchive`
   - `testRetainedDataPurgeRemovesDeletedOpportunityReconciliationAndTombstoneMaterial`
   - `testVerifiedArchiveRestoresIntoANewInactiveWorkspaceWithoutChangingSource`
   - `testRelaunchPrefersSelectedSeparateWorkspaceAndRetainsOpportunity`
   - `testReturnToPreservedRecoveryClosesSeparateStoreAndChangesOnlySelector`

2. Expand the Settings UI contract tests to exercise the presentation-to-root
   action path, not only action existence. Because the refactor relocates all
   sheets and alerts to `ContentView`, the focused suite must prove each
   applicable no-secret entry point reaches the existing root-owned modal,
   and that cancellation leaves the current workspace unchanged. It must
   cover the protected-export review/cancel path and the retained-data-purge
   confirmation/cancel path at minimum, while relying on the existing
   lower-layer restore tests for the picker/security-scope sequence. No test
   may type, store, attach, log, or screenshot a recovery key.

3. Make the archive-fixture test prove the stated fixed-clock catalogue
   contract, not just filename and `Verified`: assert the fixed created and
   expiry dates, lifecycle text, and the retained purge control's existing
   enabled/disabled predicate. Preserve the current busy/disabled regression
   evidence in the same declared test run.

4. Strengthen the document and AI absence assertions. Exact-element lookups
   for `fixture-resume.pdf`, `fixture-document-hash`, and three hypothetical
   connection-control identifiers can pass when sensitive text or a new
   control is rendered under a different surrounding label/identifier. Check
   the selected Document panel for no document action controls and no
   descendant label/value containing each fixed fixture metadata sentinel;
   check that the AI panel contains its factual unavailable text and no
   actionable child controls. Keep the type boundary and source-diff review
   as the primary non-disclosure controls.

## Evidence

| Contract | Evidence reviewed | Result |
| --- | --- | --- |
| Fixed ContentView ownership | Design §§ Components/Data flow; brief §§ Exact boundary/Required ownership; plan §§ Architecture/File structure/Task 2; current `ContentView.swift` Settings view and modifier chain | Preserved by the planned extraction. |
| Unchanged global rail and local-only sub-navigation | Design §§ Decision/Components; brief §§ Required presentation; `AppShellView.swift` `AppDestination.sidebarDestinations` and `DailyRoute` | Preserved by the plan. |
| Recovery/export/purge/restore safety | Design §§ Recovery/Data flow; `WorkspaceViewModel.swift` public operations and current sheets | Implementation boundary preserves it, but the planned test commands are incomplete. |
| Document privacy | Design § Document references; brief § Required ownership; `DocumentReferenceSummary` and `DocumentReference` contracts | Type boundary is sound; negative UI proof needs strengthening. |
| AI/cloud consent boundary | Design § AI & connections; plan Global Constraints | Preserved by the intended no-control presentation; negative UI proof needs strengthening. |
| Serial shared seam | Brief § Serial release sequence; plan Tasks 1–3 | Preserved: no parallel implementation release is authorized. |

## ADR / deviation

**No ADR is required.** The approved ownership and routing architecture is
unchanged. The required work is to correct verification coverage in the task
brief/plan before a release decision.

## Release limitation

VD2-07 is **not released**. Do not start Task 1 or implementation until the
plan is amended to close the four verification gaps above, this architecture
review is re-issued as ACCEPT, and the separate QA/test, Security/privacy,
TPM, and Delivery pre-implementation approvals are recorded. This review
does not authorize any dashboard, roadmap, progress-ledger, source, project,
or persistence change.
