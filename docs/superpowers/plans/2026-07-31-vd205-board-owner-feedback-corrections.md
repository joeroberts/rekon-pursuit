# VD2-05 Board Owner-Feedback Corrections Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Board stages unambiguous, Add Opportunity safely cancellable back to Board, and Board card actions compact and accessible.

**Architecture:** Preserve Core and `WorkspaceViewModel.changeStage(_:to:)` as the only stage mutation boundary. Make `PipelineBoardLane` one-to-one with `PipelineStage`; lift only ephemeral Pipeline context from `PipelineView` to `ContentView`, above the Add route; and retain the typed `PipelineStageMoveRequest` for drag and menu moves.

**Tech Stack:** Swift/SwiftUI/AppKit, XCTest/XCUITest, macOS 14, existing signed Debug UI-test host.

## Global Constraints

- Retain exactly six canonical persisted stages: Saved, Applied, Screening, Interviewing, Offer, Closed.
- No Core, store, schema, migration, provider, network, document, AI, security, test-host, project-file, dashboard, roadmap, evidence, or implementation-status change is released here.
- If inspection proves a read-only path is needed, stop for Architecture/QA/TPM/Delivery authorization; do not expand scope.
- Return context is transient UI state only: never Core, workspace, activity/history/task log, preferences, or launch arguments.
- Preserve Table/right drawer, successful-save navigation, ID-only drag validation, reconciliation guard, rollback/outcome copy, Reduce Motion, fixture isolation, and signing.
- Use unique `/private/tmp` DerivedData/result bundles and never set `CODE_SIGNING_ALLOWED=NO`.
- The signed manual-first preview is the stop: no broad regression, independent post-implementation gates, status changes, or owner acceptance in this task.

## File structure and interfaces

**Writable:** `RekonPursuit/PipelineView.swift` (lane projection and bindings); `RekonPursuit/PipelineBoardView.swift` (exact drop targets, scroll binding, card actions); `RekonPursuit/ContentView.swift` (route-surviving return context and cancel callback); `RekonPursuit/WorkspaceViewModel.swift` (only a no-store draft reset if necessary); `RekonPursuitTests/RekonPursuitTests.swift`; `RekonPursuitUITests/RekonPursuitUITests.swift`.

**Read-only:** `RekonPursuit/AppShellView.swift`; `RekonPursuitCore/Workspace/WorkspaceModels.swift`; `RekonPursuitCore/Workspace/WorkspaceStore.swift`; Core/VM tests; `RekonPursuit.xcodeproj/project.pbxproj`; `RekonPursuit/RekonVisualTheme.swift`; `RekonPursuitUITestHost/`; dashboard/roadmap/evidence/status files.

```swift
nonisolated enum PipelineBoardLane: CaseIterable, Equatable {
    case saved, applied, screening, interviewing, offer, closed
    var stage: PipelineStage { get }
    func includes(_ stage: PipelineStage) -> Bool
    static func displayedLanes(includesClosed: Bool) -> [PipelineBoardLane]
}

nonisolated struct PipelineBoardReturnContext: Equatable {
    var query: String
    var stageFilter: String
    var includesClosed: Bool
    var selectedOrAnchoredOpportunityID: String?
    var horizontalScrollLane: PipelineBoardLane?
}

@MainActor func discardNewOpportunityDraft()
```

`ContentView` owns the context. `PipelineView` binds query/filter/Include closed/anchor; `PipelineBoardView` binds `horizontalScrollLane` through the horizontal `.scrollPosition(id:)`, using lane IDs. The card’s AppKit menu has exactly two top-level titles—`Edit opportunity`, `Move to stage…`—and the latter has canonical six-stage children.

---

### Task 1: Approve the presentation-only boundary

**Files:**
- Modify: this plan only if a gate correction is approved.
- Read-only: controlling spec/VD2-05 plan/brief and the listed source/tests.

**Consumes:** approved Board Owner-Feedback Corrections Design.
**Produces:** Architecture, QA, TPM, and Delivery acceptance; Task 2 release only.

- [ ] **Step 1: Record immutable contracts**

Record that `PipelineStage`, `PipelineStageMoveRequest`, `StageMoveResult`, and `WorkspaceViewModel.changeStage(_:to:)` remain unchanged and remain the sole writer path. Record that Core, project registration, fixture data, dashboard, and status are not authorized.

- [ ] **Step 2: Approve return ownership**

Approve capture before Board → Add routing:

```swift
PipelineBoardReturnContext(
  query: query, stageFilter: stageFilter, includesClosed: includesClosed,
  selectedOrAnchoredOpportunityID: pipelineAnchorID,
  horizontalScrollLane: boardHorizontalScrollLane
)
```

Cancel restores it only when Add began from Board. Home Add and Table Add retain their existing behavior.

- [ ] **Step 3: Release the next dependency-safe task**

Architecture verifies no persistence contract change; QA accepts the selectors/zero-write oracle; TPM verifies dependencies; Delivery releases Task 2. No source/test edit precedes all four decisions.

### Task 2: Test first—exact lanes and zero-write draft discard

**Files:**
- Modify: `RekonPursuit/PipelineView.swift`
- Modify: `RekonPursuit/ContentView.swift`
- Modify: `RekonPursuit/WorkspaceViewModel.swift` only for draft reset
- Modify: `RekonPursuitTests/RekonPursuitTests.swift`

**Consumes:** Task 1 approval.
**Produces:** pure lane/context/draft contracts.

- [ ] **Step 1: Write failing unit tests**

Replace the grouped-lane test with:

```swift
func testVD205PipelineBoardLaneMappingIsOneToOneAndCanonical() {
  XCTAssertEqual(PipelineBoardLane.allCases.map(\.stage), PipelineStage.allCases)
  XCTAssertEqual(PipelineBoardLane.displayedLanes(includesClosed: false),
                 [.saved, .applied, .screening, .interviewing, .offer])
  XCTAssertEqual(PipelineBoardLane.displayedLanes(includesClosed: true),
                 [.saved, .applied, .screening, .interviewing, .offer, .closed])
  for lane in PipelineBoardLane.allCases {
    for stage in PipelineStage.allCases { XCTAssertEqual(lane.includes(stage), lane.stage == stage) }
  }
}
@MainActor func testDiscardNewOpportunityDraftClearsOnlyTransientAddFieldsAndError()
```

The second test fills every Add field and error, invokes the reset, and proves default fields/error plus unchanged opportunities, activities, history, task/count projections. Add a pure context round-trip equality test for query/filter/Include closed/anchor/scroll lane without a workspace.

- [ ] **Step 2: Run RED**

Run:

```bash
xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit -destination 'platform=macOS' \
  -derivedDataPath /private/tmp/rekon-vd205-feedback-red-unit-20260731-dd \
  -resultBundlePath /private/tmp/rekon-vd205-feedback-red-unit-20260731.xcresult \
  -only-testing:RekonPursuitTests/RekonPursuitTests/testVD205PipelineBoardLaneMappingIsOneToOneAndCanonical \
  -only-testing:RekonPursuitTests/RekonPursuitTests/testDiscardNewOpportunityDraftClearsOnlyTransientAddFieldsAndError
```

Expected: only absent exact lane/reset behavior; signing, fixture, database, or host failure is invalid RED.

- [ ] **Step 3: Implement the minimal presentation/reset boundary**

Make `stage` a total exact switch, `includes` equality, and five open plus conditional Closed ordering. Bind the lifted context through Pipeline/Board. Implement `discardNewOpportunityDraft()` by resetting exactly the existing post-save Add draft values/error, but never call `readyStore`, `create`, `refreshCounts`, or update `statusMessage`. Factor existing successful reset only if its observable success behavior remains unchanged.

- [ ] **Step 4: Run GREEN and enforce path scope**

Re-run Step 2 with `green-unit` derived/result paths; require both pass. Run `git diff --check` and inspect diffs for every read-only path; any read-only change stops the release.

### Task 3: Test first—exact Board targets and Option-C actions

**Files:**
- Modify: `RekonPursuit/PipelineBoardView.swift`
- Modify: `RekonPursuit/PipelineView.swift`
- Modify: `RekonPursuitTests/RekonPursuitTests.swift`

**Consumes:** Task 2.
**Produces:** five readable open lanes, exact targets, ellipsis menu.

- [ ] **Step 1: Write failing Board contracts**

Update persisted Screening presentation to expect `.screening`, add Applied expectation `.applied`, and add:

```swift
func testVD205CardActionsContainOnlyEditAndCanonicalMoveSubmenu() {
  XCTAssertEqual(PipelineCardAction.topLevelTitles, ["Edit opportunity", "Move to stage…"])
  XCTAssertEqual(PipelineCardAction.moveTargets, PipelineStage.allCases)
}
```

Add a focus assertion that Shift-Command-M targets `focusedActionsOpportunityID`, not the removed full-width move control.

- [ ] **Step 2: Run RED**

```bash
xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit -destination 'platform=macOS' \
  -derivedDataPath /private/tmp/rekon-vd205-feedback-red-board-20260731-dd \
  -resultBundlePath /private/tmp/rekon-vd205-feedback-red-board-20260731.xcresult \
  -only-testing:RekonPursuitTests/RekonPursuitTests/testPersistedResultUsesExactStageChipAndBoardLane \
  -only-testing:RekonPursuitTests/RekonPursuitTests/testVD205CardActionsContainOnlyEditAndCanonicalMoveSubmenu
```

Expected: only grouped Screening projection and absent actions contract.

- [ ] **Step 3: Implement exact Board semantics**

Use `lane.stage` as every drop delegate target; retain payload validation and the one `submit` call. Applied/Screening receive distinct container/count IDs and unique accessible names. Bind the horizontal scroll to the context lane ID without shrinking readable cards (270 open / existing 230 Closed only if visual review retains it).

Replace the pill and `PipelineStageMoveMenuControl` with compact top-right `PipelineCardActionsMenuControl`: identifier `pipeline-card-actions-<id>`; label/tooltip `Actions for <title>`; visible focus; sufficient hit frame. It contains only Edit (existing `open`) and a Move submenu in canonical order/current-stage state. Every Move creates the unchanged typed request; card body still opens details. Retarget focus shortcut and post-move focus to actions. Keep all failure/no-op/invalid/outside/reduce-motion behavior.

- [ ] **Step 4: Run GREEN**

Re-run Step 2 with `green-board` paths; require pass. Run `git diff --check`; verify production has no stage-pill, `pipeline-board-card-stage-`, full-width `PipelineStageMoveMenuControl`, or `pipeline-move-stage-` control.

### Task 4: Test first—signed UI proof and manual-first stop

**Files:**
- Modify: `RekonPursuit/ContentView.swift`
- Modify: `RekonPursuit/PipelineView.swift`
- Modify: `RekonPursuit/PipelineBoardView.swift`
- Modify: `RekonPursuitUITests/RekonPursuitUITests.swift`

**Consumes:** Tasks 2–3.
**Produces:** signed preview for owner review only.

- [ ] **Step 1: Write failing signed UI tests**

```swift
func testVD205BoardRendersExactAppliedAndScreeningLanesAndDropTargets() throws
func testVD205BoardActionsMenuEditsAndMovesWithoutStageChipOrFullWidthMoveControl() throws
func testVD205BoardCancelReturnsToBoardWithDraftDiscardedAndNoWrites() throws
func testVD205BoardEscapeCancelsToSameBoardContextWithoutWrites() throws
```

Lane test proves five default and conditional sixth Closed, distinct containers, Saved → Applied and a fresh-session Saved → Screening, relaunch, and exactly one new history/activity transition per real move. Actions test proves `pipeline-card-actions-<id>` role/label, two top-level actions, six submenu labels/current state, card body plus Edit detail route, removed controls absent, and Shift-Command-M/Space submenu keyboard use.

Cancel/Escape tests capture nonempty query, stage filter, Include closed, anchor, and horizontal lane; enter Add from Board; populate draft plus draft-only error; Cancel or Escape; assert Board/context/scroll restoration, blank reopened form, and baseline-equal opportunity/activity/history/task counts after relaunch. Escape must activate the same cancel callback.

- [ ] **Step 2: Run signed RED**

```bash
xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit -destination 'platform=macOS' \
  -derivedDataPath /private/tmp/rekon-vd205-feedback-red-ui-20260731-dd \
  -resultBundlePath /private/tmp/rekon-vd205-feedback-red-ui-20260731.xcresult \
  -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD205BoardRendersExactAppliedAndScreeningLanesAndDropTargets \
  -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD205BoardActionsMenuEditsAndMovesWithoutStageChipOrFullWidthMoveControl \
  -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD205BoardCancelReturnsToBoardWithDraftDiscardedAndNoWrites \
  -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD205BoardEscapeCancelsToSameBoardContextWithoutWrites
```

Require named behavior failures only; verify signed product/host/test bundle with `codesign --verify --deep --strict --verbose=2`.

- [ ] **Step 3: Implement shared cancellation routing**

On Board Add, capture context then route Add. Pass `cancel: cancelAddOpportunity` into Add view. Render visible `Cancel` beside Save with `cancel-add-opportunity` and `.keyboardShortcut(.cancelAction)`. Shared callback resets draft, restores captured context, clears the one-shot marker, and immediately selects Pipeline without confirmation. Do not alter successful-save behavior.

- [ ] **Step 4: Run signed GREEN and retained focused proof**

Re-run Step 2 with unique `green-ui` paths. Then, separately, run retained signed selectors: `testVD205BoardNoOpBlockedUnavailableFailedCancelAndInvalidRetainSource`, `testVD205BoardClosedFilterStaysSessionLocalDuringMove`, `testVD205BoardHistoryContainsExactlyOneNewSubjectTransition`, and `testVD205BoardReduceMotionHasNoSpatialTransitionAndRetainsFocus`; update only their control identifiers to actions. Require zero skipped and inspect result summary/details/signatures plus `git diff --check`.

- [ ] **Step 5: Build signed Debug preview and stop**

Manually inspect wide/compact Board: horizontal readability, separate Applied/Screening headings/counts/drop zones, card body/Edit/Move paths, cancel/escape restored state, and Reduce Motion focus/outcome. Hand off the signed preview to the owner. Do not run broad regression or delivery updates.

## Self-review

- [x] Spec coverage: Tasks 2–4 cover lane/drop mapping; default/conditional lane count; persisted move/history; menu/card/body/keyboard/AX; removed controls; Cancel/Escape context and zero writes; retained outcomes/motion/Table.
- [x] Placeholder scan: no TBD/TODO or undefined follow-up work.
- [x] Type consistency: `PipelineBoardLane.stage`, `PipelineBoardReturnContext.horizontalScrollLane`, `discardNewOpportunityDraft()`, and `PipelineCardAction` use one spelling throughout.
- [x] Scope: Core/persistence/project/test-host/status remain read-only and deviations stop work.

## Execution handoff

Plan saved to `docs/superpowers/plans/2026-07-31-vd205-board-owner-feedback-corrections.md`. Delivery must use the repository’s fresh Implementer → independent Code Reviewer/QA → Architecture/TPM/Delivery gate sequence, releasing one dependency-safe task at a time.

