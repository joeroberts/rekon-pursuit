# VD2-04 navy-surface correction — Task 1 baseline attestation

**Date:** 2026-07-30  
**Role:** Independent Delivery Manager / baseline auditor  
**Decision:** The reported test-file diff of **1,137 insertions and 387
deletions** is accumulated Visual Design v2 worktree state. The **387
deletions are not authorized Task 1 changes** and must not be restored,
reset, or otherwise modified as part of the navy-surface correction.

## Evidence inspected

| Evidence | Finding |
| --- | --- |
| `git diff --numstat -- RekonPursuitTests/RekonPursuitTests.swift RekonPursuitUITests/RekonPursuitUITests.swift` | Shows `111/345` in the unit target and `1026/42` in the UI target: 1,137 additions and 387 deletions in total. Git compares the committed July 29 baseline with all later shared, uncommitted VD2 work; it does not isolate Task 1. |
| `docs/delivery/task-briefs/VD2-04-pipeline-navy-surface-correction.md` lines 97–134 and `VD2-04-navy-surface-delivery-release.md` lines 19–26 | Task 1 authorizes only two test files and only the navy presentation RED contract plus the semantic-operation/capture contract. It authorizes no deletion, fixture-host migration, or prior-regression rewrite. |
| `RekonPursuitTests/RekonPursuitTests.swift` lines 137–148 | The precise Task 1 unit delta is `testVD204PipelineNavySurfacePresentationContract()`: the ten semantic fill/outline/width/opacity assertions. |
| `RekonPursuitUITests/RekonPursuitUITests.swift` lines 430–528 | The precise Task 1 UI delta is `testVD204PipelineNavySurfaceControlsRemainSemanticallyOperableInTableAndBoard()`: wide/compact Table and Board semantics, normal activation, and four pre-import screenshot attachments. |
| `RekonPursuitUITestHostTests/RekonPursuitUITestHostTests.swift` and `RekonPursuitUITestHost/BootstrapApp.swift` | The deleted unit-fixture contracts are retained in the dedicated fixture-host target. The host source predates the Task 1 release (mtime 13:50), its tests predate it (13:58), while the Task 1 brief was recorded at 16:33. The original `testVisualFixtureCurrentProcessRequiresTheXCTestEnvironment` is intentionally replaced by the dedicated-host equivalent `testVisualFixtureCurrentProcessIsAvailableOnlyInTheDedicatedTestHost`; this is a fixture-host infrastructure migration, not Task 1. |
| `docs/delivery/task-briefs/VD2-02-app-shell-and-navigation.md` and `docs/superpowers/plans/2026-07-30-vd204-pipeline-feedback-correction.md` | Existing Visual Design v2 work explicitly uses a dedicated `RekonPursuitUITestHost` and its test target for isolated fixture behavior and compact/wide test windows. |

## Baseline conclusion

The 345 removed unit-test lines predominantly correspond to fixture launch,
cleanup, symlink-safety, deterministic-clock, fixture-content, archive, and
document-relink contracts that now live in the dedicated fixture-host test
target. The remaining unit/UI replacements concern earlier VD2 shell,
navigation, Home, Pipeline table/inspector, compact-toolbar, and routing work.
The sole old UI method deleted from the committed baseline,
`testPopulatedFixtureCanOpenAnOpportunityAndSafelyReturnToPipeline`, is
superseded by the retained table-selection/open-details return test; it is not
a Task 1 change.

This conclusion is based on current contents, named task boundaries, and file
timestamps. Since the shared worktree has no intermediate commit separating
every VD2 slice, it is **not** a claim that the total historic diff is already
accepted; it is a scope finding only.

## Allowed Task 1 delta and verification mandate

1. Do not restore, reset, or delete any existing shared-worktree source or
   test work to make the Task 1 diff appear small.
2. Treat only the two named methods above as Task 1 additions. Any edit beyond
   those methods in either test file requires a new Delivery Manager release.
3. Before Task 1 can be recorded complete or Task 2 released, run and retain
   signed-Debug evidence for the two Task 1 tests **and** all retained focused
   regressions named by the brief: compact drawer, no-radio row selection,
   compact View presentation, native control discoverability/activation,
   app-owned sidebar action, return routing, and filter locality. The
   dedicated fixture-host test suite must also remain green for the migrated
   isolation and cleanup contracts.
4. A passing Task 1 subset is not evidence that the retained 387-line
   baseline remains valid; independent QA/code review must verify that whole
   retained suite before presentation implementation is accepted.

No commit, dashboard transition, source change, test change, reset, or restore
was performed by this audit.
