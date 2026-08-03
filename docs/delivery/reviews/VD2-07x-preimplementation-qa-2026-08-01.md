# VD2-07x — Pre-implementation QA review

**Date:** 2026-08-01
**Role:** Independent QA/test reviewer
**Verdict:** **NEEDS CHANGE**

## Scope and method

Reviewed the approved VD2-07x design, implementation plan, Task 1 brief, the
referenced detailed Task 1 brief, current Settings/ContentView/model seams,
the signed scheme, UI-test launcher, fixture host, and relevant current
archive/export/restore tests. No production code, test, fixture, project,
index, commit, dashboard, or progress file was changed.

The brief correctly states the desired classification rule: a compile,
signing, fixture/host, rail, route, accessibility-query, or baseline-safety
failure is a blocker, not an allowed RED. The current command cannot support
that rule because it does not execute enough of the baseline to detect those
regressions.

## Blocking corrections

1. Restore the complete mandatory safety and fixture baseline to the exact
   signed Task 1 command, and retain it unchanged in Task 2. The current
   matrix at `VD2-07x-reference-faithful-settings.md:209-228` runs only the
   four new UI tests, two existing Settings UI tests, one presentation-state
   test, two ViewModel export tests, and three protected-export tests. It
   omits all of the following required live selectors:

   - `testRefreshIncludesLifecycleAwareDocumentReferenceSummary`, the seven
     portable-archive/restore busy, verification, cancellation, and disabled
     controls regressions, and both separate-workspace return/relaunch
     regressions in `RekonPursuitTests/WorkspaceViewModelTests.swift`;
   - `testExpiryAtBoundaryRemovesOnlyVerifiedMatchingRegularArchive`,
     `testRetainedDataPurgeRemovesDeletedOpportunityReconciliationAndTombstoneMaterial`,
     `testRetainedDataPurgeRejectsWrongKeyBeforeWritingJobOrLease`, and
     `testVerifiedArchiveRestoresIntoANewInactiveWorkspaceWithoutChangingSource`
     from the `RekonPursuitTests` target;
   - the eight existing fixture-host proofs for live-store denial, launch
     isolation, per-run roots, fixed time/reduced motion, archive construction
     and timestamp truth, and the document-relink fixture; and
   - `testRecoveryFixtureShowsOnlyRecoveryActionsAndDoesNotOpenAWorkspace`,
     `testVD207SettingsRelaunchKeepsFixtureTruthAndResetsLocalSelection`, and
     `testVD207SettingsRootModalBindingsDismissWithoutChangingActiveWorkspace`.

   These are already named as normative by the incorporated VD2-07 task brief
   and directly cover the approved design's archive, purge, restore,
   separate-workspace, fixture, and non-persisted-selection requirements.
   Without them, a fixture or lower-layer safety regression can pass the new
   narrow command and be misreported as a permitted missing-reference RED.

2. Make the real-success event an exhaustive state-transition contract, not a
   single happy-path assertion. The proposed unit test must independently show
   `protectedExportSuccess == nil` before review, after a destination cancel,
   invalid confirmation/re-entry, review failure, stale/source-changed write
   failure, and write failure; it must also show that a fresh review and
   `cancelProtectedExport()` clear a *previous* success. Each path must assert
   no output where applicable and unchanged active workspace IDs. A test using
   one fixed non-existent destination cannot also exercise destination
   cancellation or review failure unless it constructs deterministic separate
   subcases/models. The existing lower-layer no-overwrite/source-change tests
   do not observe the new event.

3. Add a test-first positive presentation proof for the root-owned dialog.
   `testVD207ReferenceRecoveryDoesNotInventExportSuccess` proves only absence
   on startup; it would still pass if the dialog were never presented. Before
   Task 1 is released, the plan needs an executable, non-secret route that
   derives the event from a real injected-destination write, proves the root
   presentation becomes true only then, verifies safe filename plus `Selected
   local folder`, and proves Done clears only that presentation with unchanged
   workspace IDs. It must also prove cancel/error leave the dialog absent and
   error text accessible. The route may not be a fixture default, demo switch,
   simulated-success state, URL/key transport, or a test-only product control.
   The chosen approach needs Architecture and Security/privacy concurrence
   because the current fixture host exposes no such real-write dialog path.

4. Strengthen the four UI contracts beyond identifier presence.

   - The compact test must prove all four labeled tabs remain present and
     reachable in the compact layout, while retaining the exact focus/Space
     semantics; one focused Document references tab is insufficient.
   - Recovery must retain the fixed archive timestamp/lifecycle assertion and
     additionally verify the truthful not-enrolled, enrolled/no-archive, and
     verified-archive overview states plus action enabled/busy behavior. The
     pure display-state test should cover those three facts using safe
     `SettingsArchiveSummary` values.
   - Workspace needs assertions for `Local workspace`, `Active`, `Local only`,
     the recovery assurance, and a disabled/no-action return card when no
     separate workspace is active. Its existing separate-workspace regressions
     must remain in the matrix for the converse state.
   - Document references must assert the exact `0 available · 1 require
     relinking` aggregate for the deterministic fixture, both count-card
     values, privacy wording, and rejection of `fixture-resume.pdf`,
     `fixture-document-hash`, `application/pdf`, and path sentinels in labels
     and values. Card identifiers alone do not establish aggregate-only data.
   - AI & connections must assert `AI activity` / `No activity recorded`,
     `Connection status` / `Offline`, and the three named unavailable status
     cards in addition to the existing no-actionable-descendant check. The
     current four word checks do not cover all required unavailable facts.

5. Make the permitted RED mechanically distinguishable. Each new reference
   test must first establish a ready deterministic fixture, the selected
   `sidebar-settings` rail, and the applicable existing panel/summary truth.
   Then record each missing reference selector/card in a separately named
   assertion activity. The result-bundle review must show every requested test
   executed once with no skip/expected failure, and failures only with the
   declared missing-selector/card assertion messages. This prevents a failed
   launch, focus query, rail regression, wrong fixture, or a generic timeout
   from being accepted merely because it occurred in one of the three RED
   methods.

6. Define actual visual evidence, rather than relying on attachment export
   from tests that currently create no Settings attachments. Task 2 must retain
   named wide and compact signed-app screenshots for all four sections and a
   real-success dialog, with the global rail, active cyan tab/rule, hierarchy,
   card layout, disabled/unavailable treatment, and dialog hierarchy visible.
   Compare each against the approved references and inspect every image for
   recovery keys, absolute paths, document names, hashes, bookmarks, checksums,
   MIME types, and other document metadata. The current fallback only says to
   capture an image if no attachment exists; it does not define the required
   views, dialog path, comparison, or redaction review.

## Release recommendation

**Do not release VD2-07x Task 1.** Amend the Task 1 brief and plan with the
full signed baseline, exhaustive event/error/cancel/no-write tests, positive
root-dialog proof, strengthened four-section assertions, unambiguous RED
classification, and concrete signed visual-evidence procedure. Submit the
revised artifacts for a fresh independent QA review before Delivery considers
release.
