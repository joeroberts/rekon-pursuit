# VD2-05 Board Owner-Feedback Corrections Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give Applied and Screening exact Board lanes/drop targets, make Add Opportunity safely cancellable to its true origin, and replace redundant card controls with one accessible actions menu.

**Architecture:** Keep `PipelineStage`, `PipelineStageMoveRequest`, `StageMoveResult`, and `WorkspaceViewModel.changeStage(_:to:)` unchanged. A successor ADR first supersedes only VD2-04’s grouped-lane/inert-drop clauses; after fresh gates, `ContentView` owns live Pipeline state and an explicit Add origin, while `PipelineBoardView` consumes one-to-one lanes and one testable actions configuration.

**Tech Stack:** Swift/SwiftUI/AppKit, XCTest/XCUITest, macOS 14, existing signed Debug UI-test host.

## Global Constraints

- Canonical persisted stages remain exactly Saved, Applied, Screening, Interviewing, Offer, Closed.
- Core/store/schema/migrations, project/scheme, `AppShellView.swift`, visual theme, UI-test host/fixtures, dashboard, roadmap, evidence, and implementation/status files are read-only.
- This planning revision does not edit source, tests, the approved spec, or any ADR.
- Source/test work is blocked until the successor ADR exists and fresh Architecture, QA, TPM, and Delivery gates accept this corrected package.
- Return state is transient `ContentView` state only; no workspace, Core, preference, activity, history, task, refresh, or status write.
- Preserve successful-save behavior, Table/right drawer, ID-only drag validation, reconciliation, rollback/outcome copy, fixture isolation, and Reduce Motion.
- Use unique `/private/tmp` DerivedData/result paths; never use `CODE_SIGNING_ALLOWED=NO`.
- Stop after the signed Debug manual-first owner preview. No broad regression, final gates, status update, or successor release is authorized before owner approval.

## File and interface map

**Prerequisite architecture artifact (future Architect-owned task, not edited by this plan revision):**
`docs/delivery/architecture/ADR-VD2-05-board-owner-feedback-lane-projection.md`.

**Writable after re-gates:** `RekonPursuit/PipelineView.swift`, `RekonPursuit/PipelineBoardView.swift`, `RekonPursuit/ContentView.swift`, `RekonPursuit/WorkspaceViewModel.swift` only for draft reset, `RekonPursuitTests/RekonPursuitTests.swift`, and `RekonPursuitUITests/RekonPursuitUITests.swift`.

**Read-only:** every Global Constraints path, plus `RekonPursuitCoreTests/` and `RekonPursuitTests/WorkspaceViewModelTests.swift`.

```swift
nonisolated enum PipelineBoardLane: CaseIterable, Hashable {
    case saved, applied, screening, interviewing, offer, closed
    var stage: PipelineStage { get }
    var dropTarget: PipelineStage { stage }
    func includes(_ stage: PipelineStage) -> Bool
    static func displayedLanes(includesClosed: Bool) -> [PipelineBoardLane]
}

nonisolated struct PipelineBoardReturnContext: Equatable {
    let query: String
    let stageFilter: String
    let includesClosed: Bool
    let selectedOrAnchoredOpportunityID: String?
    let horizontalScrollLane: PipelineBoardLane?
}

nonisolated enum AddOpportunityOrigin: Equatable {
    case home
    case pipelineTable
    case pipelineBoard(PipelineBoardReturnContext)
}

nonisolated struct AddOpportunityCancelDestination: Equatable {
    let route: DailyRoute
    let showsBoard: Bool
    let boardContext: PipelineBoardReturnContext?
}

nonisolated struct PipelineCardActionsConfiguration: Equatable {
    let editTitle: String
    let moveTitle: String
    let moveTargets: [PipelineStage]
    static let canonical = Self(
        editTitle: "Edit opportunity",
        moveTitle: "Move to stage…",
        moveTargets: PipelineStage.allCases
    )
}

@MainActor func discardNewOpportunityDraft()
```

Production menu construction must call one internal `PipelineCardActionsMenuBuilder.makeMenu(configuration: .canonical, edit:move:)`; the unit test calls that same builder/configuration. Production drops must pass `lane.dropTarget`, whose implementation is exactly `stage`.

---

### Task 0: Successor ADR prerequisite

**Files:**
- Create later by Architect: `docs/delivery/architecture/ADR-VD2-05-board-owner-feedback-lane-projection.md`
- Read-only now: approved spec and `ADR-VD2-04-pipeline-fidelity-lane-mapping.md`

**Consumes:** approved correction design and rejected Task 1 gates.
**Produces:** one accepted architecture decision; no source/test release.

- [ ] **Step 1: Author the successor decision**

The Architect records that the new ADR supersedes only VD2-04’s four-primary-lane grouping and inert-drop clauses. It establishes five default exact lanes plus conditional Closed and exact namesake drop targets, while preserving VD2-04 Table/right-drawer and every unrelated accepted presentation contract.

- [ ] **Step 2: Verify the decision boundary**

The Architect states that no `PipelineStage`, persistence, schema, transaction, audit/history, reconciliation, fixture, project, or security contract changes. Any broader ADR change is rejected.

### Task 1: Fresh pre-source gates

**Files:** gate reports and Delivery release record only; no source/test edit.

**Consumes:** Task 0 successor ADR and this corrected plan/brief.
**Produces:** named Task 2 release only.

- [ ] **Step 1: Re-run independent gates**

Architecture verifies origin/scroll precedence and successor-ADR consistency. QA verifies executable drop/menu/context/zero-write oracles. TPM verifies the held Board repair and this correction are reconciled without advancing roadmap/status. Delivery may release Task 2 only after all three accept; any reject holds all source/test work.

### Task 2: RED/GREEN—origin, live context, exact lanes, pure reset

**Files:**
- Modify: `RekonPursuit/PipelineView.swift`
- Modify: `RekonPursuit/PipelineBoardView.swift` solely to remove its obsolete private `dropTarget` declaration and make any compile-only direct reference adjustment required to resolve the canonical property; no Board rendering, menu, scroll, focus, or interaction behavior
- Modify: `RekonPursuit/ContentView.swift`
- Modify: `RekonPursuit/WorkspaceViewModel.swift` only for `discardNewOpportunityDraft()`
- Test: `RekonPursuitTests/RekonPursuitTests.swift`

**Consumes:** Task 1 release.
**Produces:** exact pure contracts and live route-surviving state.

- [ ] **Step 1: Write three failing tests**

Add exact selectors:

```swift
func testVD205PipelineBoardLaneStageAndDropTargetsAreOneToOneAndCanonical()
func testVD205AddOpportunityOriginResolvesHomeTableAndExactBoardContext()
@MainActor func testVD205DiscardNewOpportunityDraftIsExhaustivePureAndWriteFree() throws
```

The lane test asserts `allCases.map(\.stage) == PipelineStage.allCases`, `lane.dropTarget == lane.stage` for all six, `includes(stage) == (lane.stage == stage)`, five default lanes, and conditional sixth Closed.

The origin test uses non-default query `"Product"`, filter `"Screening"`, Include closed `true`, anchor `"fixture-screening-id"`, and horizontal lane `.offer`. It proves exact `Equatable` round-trip and destinations: Home → Home/Table false/no context; Table → Pipeline/Table false/no context; Board → Pipeline/Board true/exact context. It also proves every new Add entry replaces the prior token.

The reset test opens an isolated store, seeds a subject, and snapshots `store.opportunities()`, `activityEvents()`, `stageHistory(forOpportunityID:)`, `needsAttention()`, all published arrays/counts/selection, and workspace readiness. Fill every Add field, including non-empty title/company, malformed `jobURL`, stage/nextAction/due date, description/notes, legacy and structured compensation, pay period, location/work arrangement, application/response/stage dates, response state, action type/custom text, and toggles. Explicitly call `createOpportunity()`. Rely on the existing pre-store URL validation already proved by `WorkspaceViewModelTests.testInvalidJobURLShowsAddOpportunitySaveErrorWithoutWriting`: require `addOpportunitySaveError == "Enter an absolute http or https job URL with a host."` and require the store opportunities/activity plus every persisted/projection snapshot to remain unchanged. Then snapshot that validation `statusMessage`, invoke `discardNewOpportunityDraft()`, and assert exact defaults:

```swift
title/company/jobURL/jobDescription/notes/compensation/minimum/maximum/location/nextAction/actionCustomText == ""
stage == .saved
compensationPayPeriod == .year
workArrangement == .notSpecified
responseState == .noResponseRecorded
actionType == .noAction
hasApplicationDate == false
hasDueDate == false
addOpportunitySaveError == nil
applicationDate/responseEffectiveDate/stageChangedAt/dueAt are within the call's before/after Date.now bounds
```

Assert every original store/published/selection/readiness snapshot is unchanged and `statusMessage` still equals the post-validation value captured immediately before discard. This unit arrangement exercises `addOpportunitySaveError`; it is distinct from the computed `jobURLWarning` used by signed UI tests.

- [ ] **Step 2: Run exact RED**

```bash
xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit -destination 'platform=macOS' \
  -derivedDataPath /private/tmp/rekon-vd205-feedback-red-unit-20260731-dd \
  -resultBundlePath /private/tmp/rekon-vd205-feedback-red-unit-20260731.xcresult \
  -only-testing:RekonPursuitTests/RekonPursuitTests/testVD205PipelineBoardLaneStageAndDropTargetsAreOneToOneAndCanonical \
  -only-testing:RekonPursuitTests/RekonPursuitTests/testVD205AddOpportunityOriginResolvesHomeTableAndExactBoardContext \
  -only-testing:RekonPursuitTests/RekonPursuitTests/testVD205DiscardNewOpportunityDraftIsExhaustivePureAndWriteFree
```

Expected: failure only for absent exact lane/drop, origin/destination, and discard contracts. For the lane selector, the valid RED is that the current `dropTarget` is private/inaccessible and still implements the obsolete Applied → Screening mapping; do not add a second declaration before capturing RED.

- [ ] **Step 3: Implement minimal contracts**

Define the single canonical internal `PipelineBoardLane.dropTarget` in `PipelineView.swift` as `stage`. In the same GREEN implementation, remove the obsolete private `dropTarget` declaration from `PipelineBoardView.swift`; its existing direct `lane.dropTarget` use resolves to the canonical property. Make only a compile-required direct-reference adjustment if the compiler requires one. Do not change Board rendering, menu, scroll, focus, drop-delivery, or interaction behavior in Task 2.

`ContentView` owns live `pipelineQuery`, `pipelineStageFilter`, `pipelineIncludesClosed`, `showsPipelineBoard`, `pipelineAnchorID`, `pipelineHorizontalLane`, and optional `addOpportunityOrigin`. `PipelineView` receives bindings for all except origin; `selectedTableID` stays local.

Every entry calls `beginAddOpportunity(origin:)` before selecting Add: Home passes `.home`; Pipeline reads `showsPipelineBoard` and passes `.pipelineTable` or a synchronously captured `.pipelineBoard(context)`. Each entry overwrites the token. Sidebar/other non-cancel departure clears it so stale Board context cannot affect later Add. Successful save neither consumes nor reinterprets it.

`cancelAddOpportunity()` snapshots the origin locally, calls discard, applies the exact destination/context, selects the destination, then clears the token. Cancel and Escape call this one callback.

Implement discard as a pure in-memory reset with the exhaustive defaults from Step 1. It must not call `readyStore`, `create`, `refreshCounts`, or mutate status/projections/selection/readiness. A private reset helper may be shared after successful create, but successful save retains its current refresh/status behavior.

- [ ] **Step 4: Run exact GREEN**

Re-run Step 2 with `green-unit` paths and all three selectors. Require three passes, signed test bundle, `git diff --check`, and zero new diff in every read-only path.

### Task 3: RED/GREEN—scroll precedence, exact Board, production-linked actions

**Files:**
- Modify: `RekonPursuit/PipelineBoardView.swift`
- Modify: `RekonPursuit/PipelineView.swift`
- Test: `RekonPursuitTests/RekonPursuitTests.swift`

**Consumes:** Task 2 bindings and exact lanes, including the single internal `PipelineBoardLane.dropTarget == stage` declared in `PipelineView.swift`; `PipelineBoardView.swift` no longer has a private duplicate.
**Produces:** exact Board rendering/drop/scroll and Option-C actions.

- [ ] **Step 1: Write failing direct contracts**

Add/update:

```swift
func testVD205PersistedAppliedAndScreeningPresentInTheirExactLanes()
func testVD205RestoredHorizontalLaneWinsOverAnchorDerivedLane()
@MainActor func testVD205ProductionMenuBuilderConsumesCanonicalActionsConfiguration()
```

The first proves Applied → `.applied` and Screening → `.screening`, consuming Task 2's already-tested exact `dropTarget == stage` interface without redefining it. The second proves resolver precedence `restoredLane ?? anchorStage.map(PipelineBoardLane.forStage)`, specifically restored Offer wins over a Screening anchor. The menu test invokes the same production builder and asserts exactly two ordered outer items and one ordered six-stage submenu from `.canonical`.

- [ ] **Step 2: Run RED**

```bash
xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit -destination 'platform=macOS' \
  -derivedDataPath /private/tmp/rekon-vd205-feedback-red-board-20260731-dd \
  -resultBundlePath /private/tmp/rekon-vd205-feedback-red-board-20260731.xcresult \
  -only-testing:RekonPursuitTests/RekonPursuitTests/testVD205PersistedAppliedAndScreeningPresentInTheirExactLanes \
  -only-testing:RekonPursuitTests/RekonPursuitTests/testVD205RestoredHorizontalLaneWinsOverAnchorDerivedLane \
  -only-testing:RekonPursuitTests/RekonPursuitTests/testVD205ProductionMenuBuilderConsumesCanonicalActionsConfiguration
```

Expected: grouped Screening, anchor override, and old one-level menu fail.

- [ ] **Step 3: Implement Board and menu**

Bind lane IDs to horizontal `.scrollPosition(id:)`. A non-nil bound restored lane is applied first and cannot be overwritten by anchor `onAppear`/change; only nil horizontal state derives `PipelineBoardLane.forStage(anchor.stage)`. Anchor remains for card marking and lane-local vertical scroll. Board region keeps identifier `pipeline-board-region` and publishes exact AX value `Horizontal lane: <lane title>`; the anchored card publishes `Anchored`.

Use fixed readable lane widths in horizontal scrolling. Render distinct lane/count/empty/drop containers for Applied and Screening. Every drop delegate receives `lane.dropTarget`.

Build the compact top-right `pipeline-card-actions-<id>` from `PipelineCardActionsConfiguration.canonical`: ellipsis image; label, tooltip, and AX help `Actions for <title>`; focus ring and sufficient hit target. Outer menu is exactly Edit and Move; Move owns the six targets/current state. Edit/card body call existing `open`; Move creates the unchanged typed request. Remove stage pill and full-width control. Shift-Command-M and post-move focus target actions.

Add identifier `add-opportunity-url-warning` to the existing derived warning. Do not create a failure fixture.

- [ ] **Step 4: Run GREEN**

Re-run Step 2 with `green-board` paths. Require three passes and `git diff --check`. Verify production lacks `pipeline-board-card-stage-` and `pipeline-move-stage-`; positive menu-builder/card proof must precede absence checks.

### Task 4: Signed UI proof and manual-first stop

**Files:**
- Modify: the four authorized production files only as required by Tasks 2–3
- Test: `RekonPursuitUITests/RekonPursuitUITests.swift`

**Consumes:** Task 3.
**Produces:** focused signed preview evidence.

- [ ] **Step 1: Write four failing signed selectors**

```swift
func testVD205BoardRendersExactAppliedAndScreeningLanesAndDropTargets() throws
func testVD205BoardActionsMenuEditsAndMovesWithoutOldControls() throws
func testVD205BoardCancelRestoresExactOriginContextAndWritesNothing() throws
func testVD205BoardEscapeRestoresExactOriginContextAndWritesNothing() throws
```

Lane oracle, in one selector: default IDs/counts saved/applied/screening/interviewing/offer and no Closed; Include closed adds exactly Closed/count; Senior Product Manager is only in Applied and Product Designer only in Screening with distinct accessible names; fresh sessions perform native Saved → Applied and Saved → Screening, assert exact outcome/containment, relaunch stage, and +1 subject activity/history each.

Actions oracle first proves rendered card/actions control, `.menuButton`, exact label, tooltip (hover), keyboard focus after Shift-Command-M, and top-right frame. It then asserts ordered outer `["Edit opportunity", "Move to stage…"]`, ordered canonical submenu/current state, and card-body/Edit detail routing in independent attempts; only then assert old identifiers/control absent.

Cancel and Escape use identical postconditions but distinct invocation. Before Add, record search value `Product`, stage selection `Screening`, Include closed, Product Designer anchor, and scroll to Offer. Assert `pipeline-board-region.value == "Horizontal lane: Offer"` and anchor card value `Anchored` after return, proving restored lane beats Screening anchor. Populate malformed URL and assert the computed `jobURLWarning` text `Use an absolute http or https URL with a host. Imported legacy URLs are preserved until changed.` at `add-opportunity-url-warning`; also populate a next action and due date. Do not click Save in either signed UI test: this oracle is the derived warning, not `addOpportunitySaveError`. Cancel clicks enabled `cancel-add-opportunity`; Escape sends Escape while that control is visible/enabled. Reopen Add and prove fields/warning cleared.

Zero-write oracle captures before and same-session-relaunch after: summed Board card/lane counts, subject activity/history counts, number of `home-attention-*` cards, and `home-active-opportunities` value. All values must be equal.

- [ ] **Step 2: Run signed RED then GREEN**

Run the four selectors together with unique `red-ui` paths, implement only named behavior, then repeat with `green-ui` paths. RED is valid only for absent behavior; GREEN is exactly four pass/zero skip. Inspect result summary/details and verify app/host/test-bundle signatures using `codesign --verify --deep --strict --verbose=2`.

- [ ] **Step 3: Preserve the retained matrix**

Retarget only obsolete helper identifiers and run these signed selectors unchanged in meaning:

```text
testVD205BoardKeyboardMoveFocusesControlAndCompletes
testVD205BoardMenuExposesExactTargetsAndCurrentStageAXState
testVD205BoardNoOpBlockedUnavailableFailedCancelAndInvalidRetainSource
testVD205BoardClosedFilterStaysSessionLocalDuringMove
testVD205BoardHistoryContainsExactlyOneNewSubjectTransition
testVD205BoardReduceMotionHasNoSpatialTransitionAndRetainsFocus
```

This retains keyboard/menu activation; same-stage no-op; blocked Close; unavailable/write/projection failure; invalid/cancelled/outside drag source retention; Closed locality; exactly-one transition across relaunch; and Reduce Motion focus/text. Require six pass/zero skip, signatures, and `git diff --check`.

- [ ] **Step 4: Manual-first preview and stop**

Inspect signed wide/compact preview for readable horizontal five-lane Board, exact Applied/Screening areas, menu/card routes, Home/Table/Board Cancel/Escape destinations, restored Offer-over-Screening precedence, and Reduce Motion. Hand off to owner and stop; do not run broad regression or update delivery state.

## Self-review

- [x] Successor ADR and fresh Architecture/QA/TPM/Delivery re-gates precede source/test work.
- [x] Home/Table/Board origins, stale-token replacement/clearing, live Pipeline ownership, and horizontal-over-anchor precedence are exact.
- [x] Draft reset enumerates every Add-bound field and proves store/projection/status immutability.
- [x] Drop target equals stage; production menu builder consumes the tested canonical configuration.
- [x] URL warning, context, anchor, scroll, zero-write, retained matrix, RED/GREEN commands, and manual stop are executable.
- [x] No placeholders or type/name mismatches remain; read-only boundaries are explicit.
