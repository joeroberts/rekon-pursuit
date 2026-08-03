# VD2-05 Board card-anchor accessibility — VD2-08 deferral addendum

**Date:** 2026-08-02  
**Decision source:** Product owner approval to defer the Board card-anchor
accessibility-semantic assertion to VD2-08.

## Bounded decision

VD2-05 retains the Board anchor in application state and keeps the nested card
root's identifier and `isAnchored` accessibility value. macOS XCTest does not
surface that custom value on the resulting `AXGroup`, so the current
checkpoint must not treat the inaccessible projection as a functional route or
state failure.

Only the `AXGroup` value predicates are deferred. The test suite must instead
prove the returned `pipeline-opportunity-<id>` button is the same, labeled,
hittable card and contained in the Screening lane before any horizontal Board
navigation. The existing direct card-body detail route, route identity, no-menu
guard, filters, query, Include Closed state, Board lane, mutation/no-write
contracts, drag payload, and relaunch checks remain VD2-05 requirements.

## VD2-08 acceptance requirements

1. Provide a stable macOS accessibility semantic for the selected/anchored
   Board card. The projection may use a different supported role or explicit
   semantic element, but it must not duplicate mutable Board state or bypass
   the existing `anchorID` source of truth.
2. Verify it in signed wide and compact UI runs after detail return, including
   the correct card identity, label, lane containment, filter, horizontal
   context, and action-menu separation.
3. Preserve the current Board's existing selector names and direct card-body
   route. Do not weaken the direct-route or persisted stage-movement coverage
   to accommodate the semantic repair.
4. Record a parseable signed result bundle with no skip, expected-failure, or
   test-only accessibility-state accommodation for this requirement.

## Non-goals

This addendum does not alter persisted stage movement, drag/drop, the Actions
menu hierarchy, details routing, search/filter state, recovery/export work,
or VD2-08 delivery status. VD2-08 remains Backlog until its existing
dependencies are accepted.

See the [QA deferral record](../reviews/VD2-05-board-anchor-accessibility-deferral-qa-2026-08-02.md) for the current-checkpoint evidence boundary.
