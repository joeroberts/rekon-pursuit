# VD2-04 Pipeline Fidelity Rebuild Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver an information-dense, mockup-faithful Pipeline Table and Board while preserving all current data and behavior.

**Architecture:** Keep `PipelineView` the sole Pipeline presentation owner. Add only pure/reversible Board lane presentation mapping and view-local visual components; continue using existing `Opportunity`, `PipelineStage`, `WorkspaceViewModel`, routing closures, and Pipeline navy-control primitives. Tests establish mapping and accessibility/layout contracts before each presentation slice.

**Tech Stack:** Swift, SwiftUI, XCTest/XCUITest, existing Rekon theme and signed macOS Debug test host.

## Global Constraints

- Presentation, hierarchy, and responsive layout only; do not change models, stores, persistence, routes, activity, Import CSV, or Board workflow.
- Four desktop visual lanes are Saved, Applied (Applied + Screening), Interviewing, and Offer; Closed is a secondary fifth lane only with Include closed on.
- Preserve existing IDs, native accessibility roles, keyboard behavior, right drawer, no-radio selection, one sidebar control, and compact View-label behavior.
- Keep `Add opportunity` as the only gradient primary action; no literal gray Pipeline chrome or new dependencies.
- Run signed Debug tests without `CODE_SIGNING_ALLOWED=NO`; automation passes require signed-product visual review.
- Expand the deterministic `pipeline` fixture only through its current `#if REKON_UI_TEST_HOST` seed seam and its test-host tests. Do not alter product models, stores, persistence semantics, routes, activity, Import CSV, or Board behavior.

---

## File structure

- `RekonPursuit/PipelineView.swift` — Task 2's file-scope, module-internal
  pure `PipelineBoardLane` testability seam; later dense table, inspector, and
  Board lane/card presentation.
- `RekonPursuit/RekonVisualTheme.swift` — existing Pipeline visual seam only if a needed semantic style cannot be expressed by current primitives.
- `RekonPursuit/RekonVisualTheme.swift:VisualFixtureWorkspace.seedFixtureIfNeeded` — existing `#if REKON_UI_TEST_HOST` fixture seam compiled into `RekonPursuitUITestHost`; test-host-only deterministic Pipeline fixture inventory.
- `RekonPursuitUITestHostTests/RekonPursuitUITestHostTests.swift` — test-host-only Pipeline fixture inventory contract.
- `RekonPursuitTests/RekonPursuitTests.swift` — pure Board mapping and stable presentation-state tests.
- `RekonPursuitUITests/RekonPursuitUITests.swift` — signed fixture accessibility/layout assertions and named Table/Board captures.
- `docs/delivery/evidence/visual-design-v2/VD2-04-owner-handoff-2026-07-30.md` — final independent evidence, risks, and owner request.

### Task 1: Release implementation gates

**Files:**

- Modify: `docs/delivery/task-briefs/VD2-04-pipeline-fidelity-rebuild.md` only if review identifies an approved clarification
- Modify: Delivery Manager ledger only after all gate decisions are received

**Consumes:** approved fidelity spec. **Produces:** recorded Architect lane/interface decision; TPM scope release; QA fixture/capture strategy; Delivery Manager authorization for Task 2.

- [ ] **Step 1: Architect releases the presentation interface**

Record that the lane mapping is view-local and reversible:

```swift
enum PipelineBoardLane: CaseIterable {
    case saved, applied, interviewing, offer, closed
    func includes(_ stage: PipelineStage) -> Bool
}
```

- [ ] **Step 2: QA releases the RED acceptance set**

Require the `pipeline` fixture to exercise every primary stage, Screening, a
closed opportunity, selection, due date, and next action; name four captures
`vd204-fidelity-wide-table`, `vd204-fidelity-compact-table-drawer`,
`vd204-fidelity-wide-board`, and `vd204-fidelity-compact-board`.

- [ ] **Step 3: TPM and Delivery Manager record scope and release Task 2**

Record that VD2-05 stays blocked and no drag/drop, persistence, activity,
import, or route work is authorized. Do not start Task 2 until all four gate
records exist.

### Task 2: Establish the deterministic fixture, then write and prove RED fidelity contracts

**Files:**

- Modify: `RekonPursuit/PipelineView.swift` — only a file-scope,
  module-internal `PipelineBoardLane` enum with pure `includes(_:)` and
  `displayedLanes(includesClosed:)`; no `PipelineView` body/call site or
  presentation work
- Modify: `RekonPursuit/RekonVisualTheme.swift:1682-1737` — only the existing `#if REKON_UI_TEST_HOST` `VisualFixtureWorkspace.seedFixtureIfNeeded` Pipeline branch; it is source-linked to the test host, not product runtime behavior
- Modify: `RekonPursuitUITestHostTests/RekonPursuitUITestHostTests.swift:363-429`
- Modify: `RekonPursuitTests/RekonPursuitTests.swift`
- Modify: `RekonPursuitUITests/RekonPursuitUITests.swift`

**Interfaces:**

- Consumes: `PipelineStage`, the current signed `pipeline` fixture seam, and retained Pipeline IDs.
- Produces: `testVD204PipelineFixtureCoversEveryFidelityStageWithCardMetadata`, a GREEN real-seam `PipelineBoardLane.includes(_:)` contract, and intentionally RED UI tests named `testVD204PipelineFidelityTableContract` and `testVD204PipelineFidelityBoardContract`.

- [ ] **Step 1: Write the failing test-host fixture-inventory test**

Add this to `RekonPursuitUITestHostTests.swift`; it is the first Task 2
contract and must precede visual-contract work:

```swift
@MainActor
func testVD204PipelineFixtureCoversEveryFidelityStageWithCardMetadata() throws {
    let configuration = try XCTUnwrap(VisualFixtureLaunchConfiguration(
        arguments: ["RekonPursuit", VisualFixtureLaunchConfiguration.argument, VisualFixtureID.pipeline.rawValue],
        environment: [VisualFixtureLaunchConfiguration.fixtureSessionEnvironmentKey: "vd2-04-fidelity-inventory-\(UUID().uuidString)"]
    ))
    defer { VisualFixtureWorkspace.teardown(configuration: configuration) }

    let model = VisualFixtureWorkspace.makeViewModel(configuration: configuration)
    model.start()
    defer { model.teardown() }

    let requiredStages: Set<PipelineStage> = [.saved, .applied, .screening, .interviewing, .offer, .closed]
    XCTAssertEqual(Set(model.opportunities.map(\.stage)), requiredStages)
    for opportunity in model.opportunities {
        XCTAssertFalse(opportunity.title.isEmpty)
        XCTAssertFalse(opportunity.company.isEmpty)
        XCTAssertFalse((opportunity.location ?? "").isEmpty)
        XCTAssertNotEqual(opportunity.workArrangement, .notSpecified)
        XCTAssertFalse(opportunity.nextAction.isEmpty)
        XCTAssertNotNil(opportunity.dueAt)
    }
    XCTAssertEqual(model.filteredOpportunities(query: "", stage: "All stages", includesClosed: false).count, 5)
}
```

- [ ] **Step 2: Run the fixture test to prove RED**

Run:

```bash
xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuitUITestHost \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:RekonPursuitUITestHostTests/RekonPursuitUITestHostTests/testVD204PipelineFixtureCoversEveryFidelityStageWithCardMetadata \
  -resultBundlePath /tmp/rekon-vd204-pipeline-fidelity-fixture-red.xcresult
```

Expected: the test launches the signed test host and fails only because the
current Pipeline fixture lacks the required Saved and Offer inventory and/or
required card metadata. Do not proceed on a compilation, fixture-isolation,
or signing failure.

- [ ] **Step 3: Implement the minimum test-host-only fixture expansion**

In the existing `#if REKON_UI_TEST_HOST` Pipeline branch of
`VisualFixtureWorkspace.seedFixtureIfNeeded`, seed exactly one deterministic
record for each inventory item below. Preserve the current fixed `now`,
UUID-session encrypted temporary root, and one-time seeding/relaunch logic.
Do not touch `Opportunity`, `PipelineStage`, `WorkspaceStore`, persistence,
routing, activity, Import CSV, or production-source conditional paths.

| Precise stage | Required fixture record facts |
| --- | --- |
| Saved | title/company, nonempty locality, specified work arrangement, next action, due date |
| Applied | title/company, nonempty locality, specified work arrangement, next action, due date; remains the edit-safe canonical record |
| Screening | title/company, nonempty locality, specified work arrangement, next action, due date |
| Interviewing | title/company, nonempty locality, specified work arrangement, next action, due date |
| Offer | title/company, nonempty locality, specified work arrangement, next action, due date |
| Closed | title/company, nonempty locality, specified work arrangement, next action, due date; remains excluded unless existing Include closed is on |

- [ ] **Step 4: Run the fixture test to prove GREEN**

Run the Step 2 command again, replacing the result bundle with:

```text
/tmp/rekon-vd204-pipeline-fidelity-fixture.xcresult
```

Expected: PASS in the configured signed `RekonPursuitUITestHost`. Inspect
that exact six-stage inventory is test-host isolated and the existing
cross-field/edit-safe Pipeline fixture test remains green.

- [ ] **Step 5: Establish the minimum real pure mapping seam, then its GREEN contract**

At file scope immediately before `PipelineView`, add the exact internal
production type released in the ADR:

```swift
enum PipelineBoardLane: CaseIterable {
    case saved, applied, interviewing, offer, closed

    func includes(_ stage: PipelineStage) -> Bool
    static func displayedLanes(includesClosed: Bool) -> [PipelineBoardLane]
}
```

It must be nonisolated by construction, pure, and unused by `PipelineView`
until Task 4. This narrowly enables a genuine `@testable` unit test. It is
not a test-only oracle or a Board implementation. A test written before this
real symbol exists would fail to compile and is not acceptable RED evidence;
the mapping contract is therefore GREEN on its first valid invocation.

```swift
func testVD204PipelineBoardLaneMappingRetainsPreciseStages() {
    XCTAssertTrue(PipelineBoardLane.saved.includes(.saved))
    XCTAssertTrue(PipelineBoardLane.applied.includes(.applied))
    XCTAssertTrue(PipelineBoardLane.applied.includes(.screening))
    XCTAssertFalse(PipelineBoardLane.applied.includes(.interviewing))
    XCTAssertTrue(PipelineBoardLane.closed.includes(.closed))
    XCTAssertEqual(PipelineBoardLane.displayedLanes(includesClosed: false), [.saved, .applied, .interviewing, .offer])
    XCTAssertEqual(PipelineBoardLane.displayedLanes(includesClosed: true), [.saved, .applied, .interviewing, .offer, .closed])
}
```

- [ ] **Step 6: Write failing Table and Board UI contracts**

Assert stable accessibility elements for the five table headings, result
footer, selected inspector identity/stage/facts/open action, compact drawer,
four Board lane headers/counts/add affordances, rich card values, and Closed
visibility controlled by `pipeline-include-closed`. Attach the four named
screenshots before any import dialog is opened.

- [ ] **Step 7: Run the focused visual tests to prove RED**

Run:

```bash
xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:RekonPursuitTests/RekonPursuitTests/testVD204PipelineBoardLaneMappingRetainsPreciseStages \
  -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD204PipelineFidelityTableContract \
  -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD204PipelineFidelityBoardContract \
  -resultBundlePath /tmp/rekon-vd204-pipeline-fidelity-red.xcresult
```

Expected: the real pure mapping contract is GREEN; the Table and Board UI
contracts FAIL only because their fidelity presentation elements do not yet
exist. The fixture inventory is already GREEN; investigate any signing,
fixture, compilation, or unrelated failure before proceeding.

- [ ] **Step 8: Preserve retained VD2-04 tests**

Run the existing compact drawer, no-radio, toolbar-label, control-semantic,
and single-sidebar-toggle tests. Do not delete or weaken any test.

### Task 3: Implement dense Table and inspector

**Files:**

- Modify: `RekonPursuit/PipelineView.swift:134-204,251-327`
- Modify only if needed: `RekonPursuit/RekonVisualTheme.swift`
- Test: `RekonPursuitTests/RekonPursuitTests.swift`
- Test: `RekonPursuitUITests/RekonPursuitUITests.swift`

**Interfaces:**

- Consumes: Task 2 Table UI contract and existing `selectedTableID`, `anchorID`, `open`, and `delete` behavior.
- Produces: desktop/compact dense table and `PipelineInspector` hierarchy; no new data API.

- [ ] **Step 1: Re-run Table contract and verify RED**

Run the Task 2 Table `-only-testing` command. Expected: missing table header,
footer, and/or inspector hierarchy assertions—not an application behavior
failure.

- [ ] **Step 2: Implement an aligned dense table surface**

Replace the tall stacked summary row with Role, Employer, Stage, Next action,
and Due date columns. Render employer identity and locality under their
appropriate compact text; render a stage chip, selected cyan/violet row, and
result-count footer. Use deliberate width rules to hide metadata at compact
width rather than restoring a card list.

- [ ] **Step 3: Implement the inspector hierarchy**

Render compact close affordance, employer mark/identity, title,
company/location, stage chip, structured facts, and an outlined `Open
details` button. Keep `pipeline-inspector-drawer`, existing inspector/open
identifiers, right-drawer geometry, context delete, and canonical `open`
closure unchanged.

- [ ] **Step 4: Run Table and retained regression tests**

Run Task 2's Table test plus the existing compact drawer, no-radio,
single-line View label, keyboard discoverability, and sidebar toggle tests.
Expected: PASS. Then run `git diff --check`.

### Task 4: Implement Board and complete independent visual gates

**Files:**

- Modify: `RekonPursuit/PipelineView.swift:207-248,330-351`
- Modify only if needed: `RekonPursuit/RekonVisualTheme.swift`
- Modify: `RekonPursuitUITests/RekonPursuitUITests.swift`
- Modify: `docs/delivery/evidence/visual-design-v2/VD2-04-owner-handoff-2026-07-30.md`

**Interfaces:**

- Consumes: `PipelineBoardLane.includes(_:)`, visible opportunities, Include closed filter, and Task 2 Board contract.
- Produces: information-dense mapped Board lanes and signed visual evidence; preserves card `open`/anchor behavior.

- [ ] **Step 1: Implement the view-local Board mapping**

Implement the Architect-released `PipelineBoardLane` and enumerate its four
primary cases. Append `.closed` only when the existing `includesClosed` is
true. Filter lane cards by `includes(_:)`; do not mutate an opportunity stage
or alter Board movement behavior.

- [ ] **Step 2: Build lane and card presentation**

Each lane needs icon, label, count, optional menu visual, add affordance, and
intentional empty state. Cards need employer identity, exact stage chip,
location/work arrangement, next action, due date, and existing owner/avatar
data when present. Retain `pipeline-board-region` and
`pipeline-opportunity-<id>` identities and app-owned navy/cyan surfaces.

- [ ] **Step 3: Run signed fidelity and regression verification**

Run:

```bash
xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:RekonPursuitTests/RekonPursuitTests/testVD204PipelineBoardLaneMappingRetainsPreciseStages \
  -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD204PipelineFidelityTableContract \
  -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD204PipelineFidelityBoardContract \
  -resultBundlePath /tmp/rekon-vd204-pipeline-fidelity.xcresult
```

Expected: PASS. Also run the complete pre-existing VD2-04 focused list from
the navy-surface task brief and inspect the four capture attachments.

- [ ] **Step 4: Complete independent gates and handoff evidence**

A fresh Code Reviewer reviews spec compliance/no behavior changes; a fresh QA
verifier reruns signed tests and inspects wide/compact captures; Architect
confirms mapping/records any ADR; TPM confirms scope; Security/privacy verifies
high-risk paths untouched. Delivery Manager records all evidence and risks,
requests owner acceptance, leaves VD2-04 in progress until that acceptance,
and leaves VD2-05 blocked.

## Self-review

- Spec coverage: Tasks 1–4 cover release gates, test-host-only deterministic
fixture coverage for Saved/Applied/Screening/Interviewing/Offer/Closed, RED
tests, dense Table, inspector, four/five-lane Board, responsive states,
signed captures, and final independent acceptance gates.
- Placeholder scan: no TBD/TODO or deferred implementation steps.
- Interface consistency: Task 2 defines `PipelineBoardLane.includes(_:)`; Task
4 is its only presentation consumer, and all other behavior remains existing
PipelineView inputs.
