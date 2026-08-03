# VD2-05 Persisted Pipeline Stage Movement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Persist one validated Pipeline stage move with exactly one audit and
history record, render it only from a committed local projection, and give
pointer, keyboard, and VoiceOver users equal safe recovery paths.

**Architecture:** `WorkspaceStore` is the sole writer. A typed Core outcome
contains a post-transition `PipelineStageMoveProjection` read within the same
transaction; `WorkspaceViewModel` maps it once to `StageMoveResult` and only
applies the projection for `.persisted`. `PipelineBoardView` consumes this
already-approved command and never writes or relocates a record on its own.

**Tech Stack:** Swift/SwiftUI/AppKit, existing encrypted SQLCipher store,
XCTest/XCUITest, and the signed macOS UI-test host.

## Global constraints

- Execute the exact slices in order: **contracts → transactional Core + VM →
  Board interaction → independent proof/handoff**. No label in this plan means
  something different in the task brief or future delivery release.
- Preserve accepted VD2-04 Board/Table/inspector/control/route/filter behavior,
  four primary lane mapping, exact Screening chip, and optional Closed lane.
- No schema/data/migration, network, external dependency, cloud, bulk/undo,
  fabricated data, route, CSV, Contacts, Settings, or VD2-06–08 work.
- A drag payload is only an opportunity ID. Status/AX text contains no record
  facts, paths, keys, SQL, or raw error details.
- Use signed Debug outputs and UUID-session isolated encrypted fixtures. Never
  disable signing and never use a personal workspace.
- Delivery alone updates dashboard/roadmap/SDD at actual gate transitions.

## File structure and interfaces

- `RekonPursuitCore/Workspace/WorkspaceModels.swift`: Core outcome, commit,
  and projection types.
- `RekonPursuitCore/Workspace/WorkspaceStore.swift`: one transaction command
  plus an internal constructor-scoped test failure dependency.
- `RekonPursuitCoreTests/WorkspaceStoreTests.swift`: physical test-source
  group for the exact transaction and close/reopen rollback evidence. It is
  compiled into the `RekonPursuitTests` test target; focused selectors use
  `RekonPursuitTests/WorkspaceStoreTests`.
- `RekonPursuit/WorkspaceViewModel.swift`: public `StageMoveResult`, mapping,
  committed-array/count/selection application, redacted outcome state.
- `RekonPursuitTests/WorkspaceViewModelTests.swift`: Core-boundary outcome and
  projection-selection contracts.
- `RekonPursuit/PipelineBoardView.swift`: focused Board interaction surface.
- `RekonPursuit/PipelineView.swift`: delegates only the existing Board region.
- `RekonPursuit.xcodeproj/project.pbxproj`: conditional Task 3 registration
  only; one `PipelineBoardView.swift` file reference in the existing
  `RekonPursuit` group and one source-build membership in each of the existing
  `RekonPursuit` and `RekonPursuitUITestHost` targets.
- `RekonPursuit/RekonVisualTheme.swift`: test-host-only sealed fixture factory
  under `#if REKON_UI_TEST_HOST`, if required.
- `RekonPursuitTests/RekonPursuitTests.swift` and
  `RekonPursuitUITests/RekonPursuitUITests.swift`: pure and signed UI proof.

```swift
struct PipelineStageMoveProjection: Equatable {
    let opportunities: [Opportunity]
    let activityEvents: [ActivityEvent]
    let needsAttention: [TaskReminder]
    let stageHistoryForTransition: [StageHistoryEntry]
}

struct PipelineStageMoveCommit: Equatable {
    let opportunityID: String
    let from: PipelineStage
    let to: PipelineStage
    let projection: PipelineStageMoveProjection
}

@discardableResult
func changeStage(_ opportunity: Opportunity, to target: PipelineStage) -> StageMoveResult
```

Core owns no selection. The VM replaces selected history only where its
currently selected ID equals `commit.opportunityID`; otherwise selection and
history stay untouched. The Core transaction never calls public lock-taking
readers while holding the workspace lock.

---

### Task 1: Contracts only — approve the exact transaction and test-host seams

**Files:** documentation/gate records only; no production or test source edit.

**Consumes:** VD2-04 owner acceptance.
**Produces:** accepted Architecture/QA/TPM/Delivery contracts and a release of
the **Transactional Core + VM slice (Task 2)** only.

- [ ] **Step 1: Publish the transaction contract**

Record `StageMoveStoreOutcome`, `PipelineStageMoveCommit`, the four projection
fields, same-stage-before-Close ordering, and private in-transaction reads.
Reject the unsafe sequence below:

```swift
try store.changeStage(opportunityID: id, to: target)
try refreshCounts()
return .persisted
```

- [ ] **Step 2: Publish deterministic test contracts**

Record Core-only test injection:

```swift
enum StageMoveFailurePoint { case beforeWrite, beforeProjectionRead }
```

Record a sealed `REKON_UI_TEST_HOST` fixture enum/factory. UI tests select an
enum fixture using the existing fixture argument; they never pass a failure
point, SQL, path, record ID, or arbitrary value at launch. Its cases are
`pipeline`, `stage-move-blocked-close`, `stage-move-unavailable`,
`stage-move-write-failure`, and `stage-move-projection-failure`.

- [ ] **Step 3: Reconcile gates and release Task 2**

Architecture, QA, TPM, and Delivery independently accept this package. Delivery
states that the first implementation release is **Task 2, transactional Core
+ VM only**, and that Board interaction is still blocked.

### Task 2: Transactional Core + view-model result

**Files:**

- Modify: `RekonPursuitCore/Workspace/WorkspaceModels.swift`
- Modify: `RekonPursuitCore/Workspace/WorkspaceStore.swift`
- Modify: `RekonPursuitCoreTests/WorkspaceStoreTests.swift` (execute through
  the `RekonPursuitTests/WorkspaceStoreTests` target selector)
- Modify: `RekonPursuit/WorkspaceViewModel.swift`
- Modify: `RekonPursuitTests/WorkspaceViewModelTests.swift`

**Consumes:** accepted Task 1 contracts.
**Produces:** sole typed persistence command; no Board interaction change.

- [ ] **Step 1: Write the failing Core contracts**

Add these tests, each comparing exact baseline opportunities, activities,
subject history, and relevant task projection after closing and reopening the
encrypted store:

```swift
func testStageMoveCommitsStageAuditHistoryAndProjectionTogether() throws
func testStageMoveSameStageIncludingClosedIsNoOpWithoutAuditOrHistory() throws
func testStageMoveCloseWithUnconfirmedReconciliationRollsBack() throws
func testStageMoveUnavailableRecordRollsBack() throws
func testStageMoveWriteFailureRollsBackEveryStageArtifactAfterReopen() throws
func testStageMoveProjectionReadFailureRollsBackEveryStageArtifactAfterReopen() throws
func testCommittedStageMoveSurvivesEncryptedStoreReopen() throws
```

- [ ] **Step 2: Run the failing Core contracts**

Run the two new success/after-projection-read tests in a signed Debug bundle.
Expected: missing typed command/projection/failure seam only; cache, fixture,
signing, compilation, or database setup failure is invalid RED evidence.

- [ ] **Step 3: Implement the exact Core transaction**

Use private query helpers inside the existing transaction lock:

```swift
// availability → precise same-stage no-op → Close guard
try transaction {
    try inject(.beforeWrite)
    try writeStageActivityAndHistory()
    try inject(.beforeProjectionRead)
    projection = try readPrivateCommittedProjection()
}
return .persisted(PipelineStageMoveCommit(..., projection: projection))
```

Do not manufacture a successful outcome after a throwing read/commit.

- [ ] **Step 4: Write the failing view-model contracts**

```swift
func testChangeStageAppliesOnlyCommittedProjectionAndSelectedHistory() throws
func testChangeStageNoOpKeepsProjectionAndCounts() throws
func testChangeStageBlockedKeepsProjectionAndCounts() throws
func testChangeStageUnavailableKeepsProjectionAndCounts() throws
func testChangeStageFailureKeepsProjectionAndMapsToFailed() throws
```

The first test moves the selected subject and verifies exact stage, lane count,
activity, attention count, and subject history all derive from the committed
projection. The last proves a thrown store/projection error is `.failed`, not
`.unavailable`, with no broad refresh.

- [ ] **Step 5: Implement `StageMoveResult` mapping**

```swift
@discardableResult
func changeStage(_ opportunity: Opportunity, to target: PipelineStage) -> StageMoveResult {
    // map the single Core outcome; apply projection only for .persisted
}
```

Update published arrays/counts and conditional selected history only from the
commit. Do not call `refreshCounts()` or another throwing reader afterward.

- [ ] **Step 6: Verify Task 2 GREEN**

Run all seven Core and five VM tests plus retained stage/audit/history/rollback
tests in signed Debug. Inspect result summary and signatures; run
`git diff --check`. Fresh code review, QA, Architecture, TPM, and Delivery must
accept before Task 3 release.

### Task 3: Board interaction and sealed UI-test scenarios

**Files:**

- Create: `RekonPursuit/PipelineBoardView.swift`
- Modify: `RekonPursuit/PipelineView.swift`
- Modify: `RekonPursuit.xcodeproj/project.pbxproj` **only after** fresh
  Architecture, QA, TPM, and Delivery gates and Delivery's successor
  content-manifest/project-baseline release; see Step 0.
- Modify: `RekonPursuit/RekonVisualTheme.swift` only behind
  `#if REKON_UI_TEST_HOST` for sealed scenario routing
- Modify: `RekonPursuitTests/RekonPursuitTests.swift`
- Modify: `RekonPursuitUITests/RekonPursuitUITests.swift`

**Consumes:** accepted Task 2 typed result.
**Produces:** native drag/drop plus keyboard/VoiceOver equivalent; cards move
only after `.persisted`.

- [ ] **Step 0: Rebaseline and register the required Board source in both app targets**

  The original release's five-file boundary is insufficient because the
  required new source is absent from the explicit Xcode project. Do not edit
  the project until fresh Architecture, QA, TPM, and Delivery reviews accept
  the narrow amendment and Delivery issues a successor release with a new
  content manifest. The original manifest remains preserved as evidence of
  the held release; it is not edited or retroactively broadened.

  Before the first project edit, Delivery records the byte count, SHA-256, and
  `git hash-object -w` blob of `project.pbxproj`, verifies the file parses,
  and verifies both app targets exist. The implementer must reproduce those
  three values and prove `PipelineBoardView.swift` is absent. The only allowed
  structural change is: one new `PBXFileReference` for
  `PipelineBoardView.swift` in the existing `RekonPursuit` group; exactly two
  new `PBXBuildFile` entries referencing that one file reference; and exactly
  one new source-build entry in each existing `RekonPursuit` and
  `RekonPursuitUITestHost` `PBXSourcesBuildPhase`. Do not change a build
  setting, signing value, target, dependency, product, framework, resource,
  scheme, or any existing project object.

  After registration, inspect the zero-context project diff and prove the
  exact object/membership counts above, `plutil -lint` succeeds,
  `xcodebuild -list -project RekonPursuit.xcodeproj` still lists both app
  targets, and signed Debug builds of both `RekonPursuit` and
  `RekonPursuitUITestHost` compile the new file. Record the baseline-relative
  structural diff, before/after SHA-256 and blobs, signed build/result
  evidence, and manifest preservation in the handoff. Any other project diff,
  parse/build failure, or baseline/manifest drift is a stop condition for
  Delivery; do not fold the Board source into `PipelineView.swift`.

- [ ] **Step 1: Write failing pure interaction contracts**

```swift
func testStageMovePayloadContainsOnlyOpportunityID() throws
func testEmptyOversizedMalformedAndUnknownPayloadNeverInvokesCommand() throws
func testCancelledAndOutsideDropNeverInvokesCommand() throws
func testNonPersistedResultsKeepSourceLane() throws
func testPersistedResultUsesExactStageChipAndBoardLane() throws
func testReduceMotionDisablesSpatialMoveAnimationButKeepsFeedback() throws
```

- [ ] **Step 2: Add sealed test-host scenario routing**

Add typed enum cases/factory only under `REKON_UI_TEST_HOST`. The factory
injects fixed dependencies itself; normal product builds do not compile it and
do not parse test failure controls. The unavailable scenario uses the canonical
store to remove the fixture subject immediately before the command; it does
not create a new stage writer.

- [ ] **Step 3: Implement focused Board interaction**

Give each card `pipeline-stage-move-card-<id>` and an identified
`pipeline-move-stage-<id>` control. Use an ID-only native payload. Validate
payload and target before this sole call:

```swift
let result = model.changeStage(opportunity, to: target)
present(result) // never directly mutate the card or Board arrays
```

Expose all six exact targets, current-stage state, live redacted outcome text,
focus behavior, and transient hover only. Clear hover on accepted, invalid,
cancelled, and failed completion. Reduce Motion removes spatial animation.

- [ ] **Step 4: Write failing signed UI contracts**

```swift
func testVD205BoardNativeDragSavedToScreeningPersistsAndRelaunches() throws
func testVD205BoardKeyboardMoveFocusesControlAndCompletes() throws
func testVD205BoardMenuExposesExactTargetsAndCurrentStageAXState() throws
func testVD205BoardNoOpBlockedUnavailableFailedCancelAndInvalidRetainSource() throws
func testVD205BoardClosedFilterStaysSessionLocalDuringMove() throws
func testVD205BoardHistoryContainsExactlyOneNewSubjectTransition() throws
func testVD205BoardReduceMotionHasNoSpatialTransitionAndRetainsFocus() throws
```

The success path is Saved → Screening. Closed success enables Include closed
before target assertion. Each failure case gets a new UUID session.

- [ ] **Step 5: Verify Task 3 GREEN and retained regression**

Run pure tests and signed UI tests at wide and compact sizes. Inspect AX tree,
drag evidence, keyboard navigation (no pointer menu tap), relaunch, History
subject ID + one new matching event/history record, and all retained VD2-04
Table/Board/filter/drawer/no-radio/toolbar/route-return suites. Run
`git diff --check`. Fresh code review and QA acceptance is mandatory.

### Task 4: Independent proof, governance, and owner handoff

**Files:** test/evidence/dashboard records only after Delivery release; no
workflow implementation change.

**Consumes:** accepted Task 3.
**Produces:** owner-handoff package; VD2-05 remains unaccepted until owner
approval.

- [ ] **Step 1: Capture the fixed signed states**

Attach:

```text
vd205-board-wide-persisted-move
vd205-board-compact-keyboard-move
vd205-board-close-reconciliation-blocked
vd205-board-local-failure-recovery
```

The first shows source/Screening target/count/chip. The second shows focused
keyboard action and result. The third shows retained source plus redacted
reconciliation direction. The fourth shows unchanged source plus local-not-
changed copy. No external dialog, data leak, or unrelated fixture session.

- [ ] **Step 2: Complete independent verification**

Fresh QA reruns Core/VM/pure/UI/relaunch tests, signs and inspects bundles,
AX hierarchy, native-drag evidence, VoiceOver manual review, and a signed
Reduce Motion launch. Fresh Architecture confirms the ADR, TPM confirms scope,
Security/Privacy confirms local encryption/payload/error/fixture/audit
properties, and Code Review confirms the single writer/no optimistic move.

- [ ] **Step 3: Delivery handoff**

Delivery records the independent gates and evidence, updates dashboard,
roadmap, rendered dashboard, and SDD only to **awaiting owner acceptance**,
and keeps VD2-06–08 Backlog. Request explicit product-owner acceptance; do not
mark VD2-05 accepted without it.

## Self-review

- **Coverage:** contracts explicitly cover persisted, no-op, Close block,
  unavailable, write/projection failure, rollback/reopen, audit/history,
  selection, native drag, keyboard, VoiceOver, Reduce Motion, Closed filter,
  captures, retained VD2-04 regression, governance, and owner approval.
- **Fixture isolation:** no production launch controls can choose a failure;
  only sealed test-host enum scenarios route fixed dependencies.
- **Sequence:** every task and release uses contracts → Core+VM → Board → proof,
  so no Board UI can run ahead of a truthful persistence result.

---

## Board Task 3 review-repair plan — 2026-07-31

**Goal:** Repair the five rejected Board Task 3 acceptance items without
changing the accepted Core/VM transaction, Board design, project graph, or
product scope.

**Released repair files:** `RekonPursuit/PipelineBoardView.swift`,
`RekonPursuit/RekonVisualTheme.swift` only inside `#if REKON_UI_TEST_HOST`,
`RekonPursuitTests/RekonPursuitTests.swift`, and
`RekonPursuitUITests/RekonPursuitUITests.swift`. `PipelineView.swift` and
`project.pbxproj` must match their pre-repair final hashes. No boundary
expansion is permitted.

**Evidence classification:** the existing signed QA 6/7 result is the only
product-behavior RED. Invalid-payload receives one exact signed pre-seam
integration RED. History and Reduce Motion are proof gaps validated by
mutation/control runs, not product REDs. VD2-04 is an evidence-order rejection.

### Repair Task 1: Preserve the exact six pure selectors and truthful native success

**Files:**
- Modify: `RekonPursuit/PipelineBoardView.swift`
- Modify: `RekonPursuitTests/RekonPursuitTests.swift`
- Modify: `RekonPursuitUITests/RekonPursuitUITests.swift`

- [ ] Preserve all six existing pure selector names. Add provider-delivery
  identity assertions inside
  `testPersistedResultUsesExactStageChipAndBoardLane`: the same provider/target
  delivery is accepted once, its duplicate is rejected, and a distinct
  provider requesting its actual current stage is accepted and maps to
  `Already in Screening.`. Do not add a seventh selector and do not call this
  proof strengthening a product RED.
- [ ] Bind the authentic RED to
  `/tmp/rekon-vd205-qa-final-ui7-20260731-sol-fallback.xcresult` and
  `testVD205BoardNativeDragSavedToScreeningPersistsAndRelaunches`: the committed
  card is in Screening but the outcome is `Already in Screening.`.
- [ ] Add a Board-owned gate keyed only by native provider object identity plus
  target for the lifetime of that delivery. Suppress the repeated callback
  before `submit`; never deduplicate independent providers, later gestures, or
  menu commands by opportunity ID/stage.
- [ ] Focused GREEN the existing pure selector and existing signed native-drag
  selector. Require retained `Moved to Screening.` plus an independent new
  same-stage request returning `Already in Screening.`.

  Use fresh Derived Data/result roots with prefixes
  `rekon-vd205-repair-provider-green-<uuid>` for
  `RekonPursuitTests/RekonPursuitTests/testPersistedResultUsesExactStageChipAndBoardLane`
  and `rekon-vd205-repair-native-green-<uuid>` for
  `RekonPursuitUITests/RekonPursuitUITests/testVD205BoardNativeDragSavedToScreeningPersistsAndRelaunches`.
  There is no new pure product RED: the latter selector's accepted QA 6/7
  bundle is the sole product-behavior RED for this item.

### Repair Task 2: Exact invalid-provider pre-seam RED and GREEN

**Files:**
- Modify: `RekonPursuit/PipelineBoardView.swift`
- Modify: `RekonPursuit/RekonVisualTheme.swift` (`REKON_UI_TEST_HOST` only)
- Modify: `RekonPursuitUITests/RekonPursuitUITests.swift`

- [ ] First change only
  `testVD205BoardNoOpBlockedUnavailableFailedCancelAndInvalidRetainSource` to
  launch the existing sealed `pipeline` fixture, open the Board, assert the
  Applied lane/drop target and Saved subject exist, then require
  `pipeline-invalid-drag-empty`. Run the exact command below before adding the
  source. Valid RED fails at that missing-source assertion only.

```sh
VD205_REPAIR_RUN_ID="$(uuidgen | tr '[:upper:]' '[:lower:]')"
VD205_REPAIR_DD="/tmp/rekon-vd205-repair-invalid-red-${VD205_REPAIR_RUN_ID}-dd"
VD205_REPAIR_RESULT="/tmp/rekon-vd205-repair-invalid-red-${VD205_REPAIR_RUN_ID}.xcresult"
test ! -e "$VD205_REPAIR_DD"
test ! -e "$VD205_REPAIR_RESULT"
xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit \
  -configuration Debug -destination 'platform=macOS,arch=arm64' \
  -parallel-testing-enabled NO \
  -derivedDataPath "$VD205_REPAIR_DD" \
  -resultBundlePath "$VD205_REPAIR_RESULT" \
  -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD205BoardNoOpBlockedUnavailableFailedCancelAndInvalidRetainSource
```

- [ ] Add four fixed UI-host-only `utf8PlainText` drag sources under the
  existing sealed `pipeline` fixture: empty, 129-byte oversized, malformed
  `[0xFF, 0xFE]`, and unknown ID
  `00000000-0000-4000-8000-000000000999`. No launch value supplies payload
  data. Add read-only UI-host AX observation at the actual drop delegate for
  provider deliveries, validation rejections, and command dispatches.
- [ ] Before dragging, bind the subject ID, Saved/current-stage source, absent
  outcome, and that subject's activity/history counts. Drag each fixed source
  to the real Applied lane. GREEN requires AX counts deliveries 4, rejections
  4, commands 0; no live outcome; source still Saved; and equal activity/history
  counts after same-session relaunch. Preserve the direct cancel/outside drag.
- [ ] Use the same command with result name prefix
  `rekon-vd205-repair-invalid-green`; retain its activity tree proving each
  source-to-lane gesture. Verify fixed source/instrumentation identifiers and
  strings are absent from the production app product.

### Repair Task 3: Subject-bound History and deterministic Reduce Motion proof

**Files:**
- Modify: `RekonPursuit/PipelineBoardView.swift`
- Modify: `RekonPursuitUITests/RekonPursuitUITests.swift`

- [ ] Strengthen
  `testVD205BoardHistoryContainsExactlyOneNewSubjectTransition` to capture the
  ID-bound canonical activity/history baseline before dispatch, return to
  Board, move Saved → Screening, relaunch the same UUID session, reopen that
  ID-bound view, and require exactly baseline + 1 matching activity and
  baseline + 1 Saved → Screening history. Prove test sensitivity with a
  reversible expected-`+2` mutation failure, then restore `+1`. Record this as
  mutation RED plus focused GREEN, never as a product RED.
- [ ] Drive the Board's actual spatial animation from one decision branch:
  normal policy selects `.easeInOut(duration: 0.2)` and Reduce Motion selects
  `nil`. Under `REKON_UI_TEST_HOST` only, that same branch updates read-only AX
  counters `pipeline-stage-move-motion-observation`; no argument or persisted
  value controls the counters and production semantics remain unchanged.
- [ ] In
  `testVD205BoardReduceMotionHasNoSpatialTransitionAndRetainsFocus`, first run
  a normal-mode Saved → Screening native control move and require executed 1 /
  suppressed 0. In a fresh normal `pipeline` session with Reduce Motion on,
  keyboard-focus the move control, prove the card starts in Saved, native-drag
  to Screening, and require executed 0 / suppressed 1, `Moved to Screening.`,
  Applied/Screening placement, and restored menu-control keyboard focus. A
  normal-branch execution makes the reduced assertion fail.
- [ ] Validate sensitivity with a reversible test mutation that launches the
  reduced assertion leg with Reduce Motion off; retain its executed-1 failure,
  restore Reduce Motion on, and record focused GREEN. This is mutation RED for
  the observation, not a product-behavior RED. Keep the local-failure capture
  in its non-happy-path selector; do not reuse it as motion evidence.

  Use fresh result/Derived Data prefixes
  `rekon-vd205-repair-history-mutation-<uuid>`,
  `rekon-vd205-repair-history-green-<uuid>`,
  `rekon-vd205-repair-motion-mutation-<uuid>`, and
  `rekon-vd205-repair-motion-green-<uuid>` with their unchanged existing
  History and Reduce Motion selector identities.

### Repair Task 4: Combined and ordered final-source proof

**Files:** none beyond Repair Tasks 1–3.

- [ ] After the last edit, run exactly the six existing pure selectors, then
  exactly the seven existing Board UI selectors. Require 6/6 and 7/7 with zero
  skips/expected failures; inspect activity trees, AX counters/hierarchy, and
  all four fixed captures.
- [ ] Only then run the unchanged retained VD2-04 12-selector inventory, then
  `WorkspaceStoreTests` 114/114, then `WorkspaceViewModelTests` 91/91 from the
  same final source tree. The old 12/12 bundle is historical, not RED/GREEN.
- [ ] Verify signed app/host/test products, production absence of UI-host seams,
  source/executable/XCTest/result hashes, project registration counts/source
  memberships, all Task 2 hashes, successor manifest preservation outside the
  four repair paths, and `git diff --check`.
- [ ] Return the amended pre-repair package to fresh QA, Architecture, and
  Security/privacy. Only after their acceptance may Delivery release a fresh
  Implementer. Fresh post-implementation Code Review and QA still precede
  Architecture, Security/privacy, TPM, and Delivery acceptance. Do not update
  status or request owner handoff.
