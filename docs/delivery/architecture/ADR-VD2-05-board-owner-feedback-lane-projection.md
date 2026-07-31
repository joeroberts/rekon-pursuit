# ADR-VD2-05 — Exact Board lane projection and origin-aware Add return

**Date:** 2026-07-31

**Status:** Accepted as a prerequisite for fresh VD2-05 pre-source gates; does not release implementation

**Decision owner:** Independent Architecture

## Context

The owner-approved VD2-05 Board correction requires Applied and Screening to be
separate visible lanes and separate drop targets, Add Opportunity Cancel/Escape
to return to the flow's true origin without saving, and each Board card to
expose one compact Option-C actions control.

The earlier VD2-04 fidelity decision intentionally grouped persisted Applied and
Screening opportunities into one visual Applied lane and prohibited active
drag/drop in that presentation slice. Persisted stage movement was subsequently
approved through the independent atomic transaction in
`ADR-VD2-05-stage-move-transaction.md`. Retaining the VD2-04 grouping alongside
the new owner direction would make the Board ambiguous, while expanding the
correction into Core or route persistence would violate the accepted data
boundary.

This decision resolves only that conflict and the presentation ownership needed
for the correction. Source and test implementation remains held until fresh
Architecture, QA, TPM, and Delivery gates accept the corrected package.

## Supersession boundary

This ADR supersedes only these clauses of
`ADR-VD2-04-pipeline-fidelity-lane-mapping.md`:

1. the four-primary-lane projection in which Applied contains both persisted
   Applied and Screening;
2. the corresponding grouped-lane interface, testability exception, and
   verification oracle; and
3. the prohibition on active Board drag/drop and the alternative that rejects
   drag/drop as outside VD2-04.

Those clauses are replaced only for the interactive VD2-05 Board by the exact
lane/drop and retained transaction decisions below. The VD2-04 dense Table,
`selectedTableID`, compact right drawer, inspector read boundary, existing
open/delete routes, navy/cyan surfaces, action hierarchy, responsive behavior,
accessibility continuity, and every other unrelated accepted VD2-04 contract
remain in force. This ADR does not reopen or redesign Table or its right drawer.

## Decision

### Exact lanes are a one-to-one presentation projection

`PipelineBoardLane` remains module-internal UI state in `PipelineView.swift`.
It is neither a Core model nor a second stage source of truth. Its contract is:

```swift
nonisolated enum PipelineBoardLane: CaseIterable, Hashable {
    case saved, applied, screening, interviewing, offer, closed

    var stage: PipelineStage { get }
    var dropTarget: PipelineStage { stage }
    func includes(_ stage: PipelineStage) -> Bool
    static func displayedLanes(includesClosed: Bool) -> [PipelineBoardLane]
}
```

`allCases.map(\.stage)` equals `PipelineStage.allCases` in canonical order.
`includes(_:)` is exactly `self.stage == stage`, and `dropTarget` is exactly
`stage`; neither may group, alias, or convert a value.

| Lane | Included persisted stage | Drop target | Default visibility |
| --- | --- | --- | --- |
| Saved | `Saved` | `.saved` | Visible |
| Applied | `Applied` | `.applied` | Visible |
| Screening | `Screening` | `.screening` | Visible |
| Interviewing | `Interviewing` | `.interviewing` | Visible |
| Offer | `Offer` | `.offer` | Visible |
| Closed | `Closed` | `.closed` | Only when Include closed is enabled |

The Board renders the first five lanes at readable fixed widths inside
horizontal scrolling and appends Closed only when requested. Applied and
Screening own distinct visual, count, empty-state, accessibility, and drop
containers. Every production drop delegate receives `lane.dropTarget`. A
persisted move to Screening therefore presents in `.screening`, never
`.applied`.

### ContentView owns live Pipeline context and Add origin

The Pipeline query, stage filter, Include closed flag, Board/Table mode,
selected-or-anchored opportunity ID, and horizontal lane are ephemeral live
state owned by `ContentView`, above the conditional Add route. `PipelineView`
receives bindings for those values; `PipelineBoardView` receives the anchor and
horizontal-lane bindings. Table-only row selection may remain view-local.

The Board snapshot and Add origin contracts are:

```swift
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
```

Each Add entry synchronously replaces the optional `ContentView` origin before
selecting `.addOpportunity`:

- Home captures `.home` and resolves Cancel/Escape to Home, Table false, and no
  Board context.
- Pipeline Table captures `.pipelineTable` and resolves to Pipeline, Table
  false, and no Board context.
- Pipeline Board captures `.pipelineBoard(context)` from the live bindings and
  resolves to Pipeline, Board true, and that exact context.

One shared cancel callback snapshots the origin, calls the pure draft discard,
applies the destination and any Board context, selects the destination route,
then clears the one-shot origin. The visible Cancel control and the platform
cancel keyboard shortcut invoke that same callback. There is no confirmation.
Every later Add entry replaces any earlier token, and a non-cancel departure
clears it so stale Board context cannot affect a later flow. Successful save
does not consume or reinterpret the token and retains its existing behavior.
`DailyRoute`, `DailyNavigationIntent`, and `AppShellView` need no change.

### Restored horizontal lane has explicit precedence

The Board binds its horizontal scroll position to the live lane ID. When the
Board appears or its anchor changes, horizontal resolution is exactly:

```swift
restoredHorizontalLane ?? anchorStage.map(PipelineBoardLane.forStage)
```

A non-nil restored lane therefore wins and cannot be overwritten by
anchor-derived scrolling. Only nil horizontal state may derive a lane from the
anchor. The anchor remains available for card identification and lane-local
vertical restoration. This permits, for example, a restored Offer position to
remain visible while a Screening opportunity remains the anchor. Accessibility
exposes the resolved horizontal lane and anchored-card state without persisting
either value.

### Draft discard is pure in-memory reset

`WorkspaceViewModel` may add only this cancel-specific method:

```swift
@MainActor
func discardNewOpportunityDraft()
```

It resets every Add-bound value to a new-form default: all Add text, canonical
`.saved` stage, due-date value and toggle, legacy and structured compensation,
`.year` pay period, location, `.notSpecified` work arrangement, application,
response, and stage dates, application toggle, `.noResponseRecorded` response,
`.noAction` action and custom text, and `addOpportunitySaveError`. Draft date
values are reset to the call's current time.

The method must not call `readyStore`, create, `refreshCounts`, or another store
or reader path. It must not change `statusMessage`, opportunities, activities,
history, tasks, projections, counts, selection/detail state, workspace
readiness, preferences, or route state. A private reset helper may be shared
only when successful-save observable behavior, refresh, and status semantics
remain unchanged.

### Option-C actions use one production-linked configuration

The card's top-right ellipsis menu is built from one internal canonical value:

```swift
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
```

Production construction and direct unit proof must invoke the same
`PipelineCardActionsMenuBuilder.makeMenu(configuration:edit:move:)` seam with
`.canonical`; a test-only shadow configuration or duplicate oracle is not
acceptable. The outer menu contains exactly Edit opportunity and Move to
stage… in that order. Move owns the six canonical stage children and identifies
the current exact stage. Choosing the current stage retains the existing no-op
result.

The control replaces both the card stage pill and full-width move control. Its
stable identifier is `pipeline-card-actions-<id>` and its accessibility label,
tooltip, and help are `Actions for <opportunity title>`. It remains keyboard
focusable with a visible focus ring and sufficient hit target. Card body and
Edit invoke the existing details route. Move constructs the unchanged typed
`PipelineStageMoveRequest`; destructive actions remain in details. The existing
keyboard shortcut and post-move focus restoration target the actions control.

## Retained data, transaction, audit, and security boundaries

- `PipelineStage`, `Opportunity`, and persisted records remain unchanged.
- `PipelineStageMoveRequest`, `StageMoveResult`, and
  `WorkspaceViewModel.changeStage(_:to:)` remain unchanged.
- `WorkspaceStore` remains the sole stage writer. Drag and menu moves use the
  same Board submission path and the accepted
  `ADR-VD2-05-stage-move-transaction.md` command/projection.
- A real move still writes the stage, exactly one activity event, and exactly
  one history row atomically. Same-stage no-op, reconciliation-blocked Close,
  unavailable, write failure, and projection failure semantics are unchanged.
- No optimistic card relocation is introduced. A rejected or failed move leaves
  the committed card in its source lane.
- Return context, Add origin, anchor, and scroll lane are session-only UI state.
  They do not enter Core, the workspace, preferences, activity/history/task
  logs, launch arguments, fixtures, or recovery data.
- No new schema, migration, dependency, provider, network, document, AI,
  credential, entitlement, or security/privacy boundary is introduced.
- Core/store/models/Core tests/view-model tests, project and scheme,
  `AppShellView.swift`, visual theme, UI-test host and fixtures, dashboard,
  roadmap, evidence, and status files remain read-only for this correction.

## Failure, motion, and accessibility consequences

- Existing success, no-op, blocked, unavailable, write-failure, and
  projection-failure feedback retains its meaning and remains visible.
- Reduce Motion suppresses only spatial relocation animation; focus restoration
  and outcome text remain.
- Cancel remains enabled for an invalid draft and clears its draft-only error.
- Applied and Screening never share an accessibility container, name, or count.
- The Board exposes its resolved horizontal lane, and the anchor remains
  independently observable, so restored-lane precedence is executable rather
  than inferred from a screenshot.

## Rejected alternatives

1. **Keep Screening grouped under Applied.** Rejected because it violates the
   owner-approved one-to-one semantics and makes Applied an ambiguous drop.
2. **Persist Board return context or Add origin.** Rejected because route return
   is session presentation state and does not belong in workspace or preference
   storage.
3. **Let the anchor always control horizontal position.** Rejected because it
   overwrites the captured Board viewport and cannot restore both requested
   context fields.
4. **Use separate production and test menu descriptions.** Rejected because the
   test could pass while the AppKit menu diverges from the approved Option-C
   contract.
5. **Add a second stage writer for menu or drop movement.** Rejected because it
   would bypass the accepted transaction, reconciliation, audit, and rollback
   boundary.
6. **Reopen Table/right-drawer design.** Rejected because those VD2-04 contracts
   are accepted and unrelated to this owner correction.

## Required verification and release effect

Before implementation may proceed, fresh independent Architecture, QA, and TPM
gates must accept this ADR with the corrected plan/brief, and Delivery must
release the named next task. This ADR alone does not release source or tests.

Focused proof must exercise the production declarations and establish:

1. canonical one-to-one `stage`, `includes`, and `dropTarget` behavior; five
   default lanes and conditional Closed;
2. distinct Applied/Screening containers and persisted moves to each, including
   relaunch and exactly one activity/history transition per real move;
3. Home, Table, and exact Board origin/destination resolution, stale-token
   replacement/clearing, shared Cancel/Escape, exhaustive draft clearing, and
   zero store/projection/status writes;
4. restored horizontal lane precedence over an anchor-derived lane;
5. production consumption of `.canonical`, exactly two ordered outer actions,
   the ordered six-stage submenu/current state, existing body/Edit routing, and
   absence of the old controls; and
6. retained failure, reconciliation, invalid payload, keyboard, focus, Reduce
   Motion, signed-product, Table, and right-drawer behavior.

The terminal implementation result remains the focused signed Debug
manual-first owner preview. Broad regression, final post-implementation gates,
delivery status changes, and later release remain outside this decision until
owner approval.
