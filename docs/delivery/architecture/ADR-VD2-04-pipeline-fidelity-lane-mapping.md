# ADR-VD2-04: Pipeline fidelity presentation and reversible Board lane mapping

**Status:** Accepted for fidelity-rebuild implementation  
**Date:** 2026-07-30  
**Decision owner:** Independent architecture review

## Context

The owner-approved Pipeline fidelity specification requires the desktop Board
to read as four useful recruiting-workspace lanes rather than the current six
equal-width stage columns. The underlying `PipelineStage` model remains six
precise values: `Saved`, `Applied`, `Screening`, `Interviewing`, `Offer`, and
`Closed`. `Opportunity.stage` is persisted and used by filtering, routing,
activity, and existing opportunity workflows.

The same specification requires Table to become a dense aligned presentation
with a richer selected-opportunity inspector. The existing `PipelineView`
already owns only ephemeral search/filter/selection state and receives
opportunity-opening and deletion closures from `ContentView`; it must not
become a second source of model or route truth.

## Decision

### Board lanes are a view-local, reversible projection

Add a module-internal, presentation-only `PipelineBoardLane` at file scope in
`PipelineView.swift`, immediately before `PipelineView`. It is deliberately
*not* `private`: `RekonPursuitTests` imports the app module with `@testable`
and must exercise the actual mapping implementation rather than duplicate it
as a test-only oracle. The type remains unavailable outside the app module and
is not a model, persistence, or workflow API.
It enumerates the four primary desktop lanes and the conditional secondary
Closed lane:

| Lane | Included persisted stage(s) | Exact card stage shown |
| --- | --- | --- |
| Saved | `Saved` | `Saved` |
| Applied | `Applied`, `Screening` | `Applied` or `Screening` |
| Interviewing | `Interviewing` | `Interviewing` |
| Offer | `Offer` | `Offer` |
| Closed (secondary) | `Closed` | `Closed` |

The interface is pure and has no side effects:

```swift
enum PipelineBoardLane: CaseIterable {
    case saved, applied, interviewing, offer, closed

    func includes(_ stage: PipelineStage) -> Bool
    static func displayedLanes(includesClosed: Bool) -> [PipelineBoardLane]
}
```

`PipelineView` obtains the rendered lane sequence from the pure
`displayedLanes(includesClosed:)` helper, which renders `.saved`, `.applied`,
`.interviewing`, and `.offer` always, appending `.closed` only when
`includesClosed` is true.
It filters the already-visible opportunities with `lane.includes(opportunity.stage)`.
Thus a `Screening` card lives in the Applied *visual lane* while continuing to
show the `Screening` chip/value. No lane selection writes a stage; no card is
coerced to a display-only or persisted pseudo-stage.

### Dense Table and inspector remain presentation components

The table surface and inspector are view-local SwiftUI components consuming an
`Opportunity` value and the existing `open`/`delete` closures. Their allowed
responsibilities are column layout, metadata hierarchy, responsive visibility,
and calling those closures. The retained contracts are:

- `selectedTableID` remains the one selection authority for Table and the
  compact right drawer; it is not persisted.
- An opportunity card or selected-row action sets the existing `anchorID` and
  calls the existing `open(opportunity)` route closure. It does not alter the
  opportunity or stage.
- Context Delete remains the existing `delete(opportunity)` closure.
- The inspector reads title, company, stage, locality, next action, due date,
  and existing identity/owner presentation only from `Opportunity` and
  current view-model data. It does not synthesize or write facts.
- Compact presentation preserves the existing in-place right drawer rather
  than creating a modal or below-list details region.

The fidelity slice may add stable accessibility identifiers needed for the
approved Table/Board contracts, but it preserves the existing Pipeline IDs,
native accessibility control roles, keyboard semantics, and canonical details
route.

### Task 2 testability exception

Task 2 is authorized to add the exact pure `PipelineBoardLane` declaration and
its two pure implementations in `PipelineView.swift`, before any Table or
Board layout work. This is a testability-enabling production seam, not a
visual implementation: no `PipelineView` call site may consume it until Task
4 is released. The mapping unit test must name and call this real type; a
test-only shadow mapping, duplicate switch, or compile-only unresolved-symbol
"RED" is prohibited.

Because a correct pure seam necessarily makes its direct mapping test pass,
Task 2 records that mapping test as a **GREEN testability contract**. The
Table/Board UI contracts remain intentionally RED until their corresponding
presentation tasks. This is the only exception to the otherwise RED-first
Task 2 sequence.

## Invariants and boundaries

- Do not modify `PipelineStage`, `Opportunity`, `WorkspaceViewModel`, store
  persistence, filters, activity/audit behavior, import behavior, or routes.
- Do not introduce drag/drop, stage-moving, lane-changing, or fake state
  mutation. Mockup-style drop placeholders are inert only.
- Do not omit Closed-filter semantics: Closed is excluded through the existing
  filter when off and becomes exactly one secondary lane when on.
- Do not lose precise `Screening` semantics by rendering it as `Applied` on a
  card, in accessibility output, or in an open/details route.
- Retain the prior VD2-04 contracts: navy/cyan Pipeline surfaces, Import as an
  outlined secondary action, Add opportunity as the sole gradient primary
  action, no row radio glyph, single-line/omitted compact View label, right
  drawer, and exactly one sidebar action.

## Alternatives rejected

1. **Change the persisted stage model to four stages.** Rejected: it destroys
   the meaningful Screening state and would change filtering, history, and
   data behavior outside this presentation slice.
2. **Keep six equal Board lanes and style them more heavily.** Rejected: it
   cannot satisfy the owner-approved composition, which calls for four useful
   primary lanes and avoids the empty narrow-column layout.
3. **Use a separate Board-specific status field or copied Board data.**
   Rejected: it creates divergence and another source of truth for existing
   opportunity state.
4. **Add drag/drop to make the Board resemble the mockup.** Rejected: it
   changes workflow and is explicitly outside VD2-04.
5. **Replace the compact drawer with a modal inspector.** Rejected: the
   approved compact-details contract requires the right-hand drawer.

## Required verification

Before the fidelity slice can be accepted, tests and signed-product captures
must prove that:

1. `.applied.includes(.screening)` is true while `Screening` remains the card
   stage; each other stage maps only to its documented lane.
2. Closed is not rendered with Include closed off and appears solely as the
   secondary Closed lane when the existing control is enabled.
3. Table and inspector layout changes leave selection, right-drawer geometry,
   open route, context delete, search, and filters intact.
4. Board cards retain their opening/anchor path and do not invoke a stage or
   persistence mutation.
5. Independent QA inspects signed wide and compact Table/Board captures
   against the approved mockups before product-owner acceptance.

This ADR authorizes only the VD2-04 presentation mapping and component
boundary. It does not accept VD2-04, release VD2-05, or authorize a workflow
change.
