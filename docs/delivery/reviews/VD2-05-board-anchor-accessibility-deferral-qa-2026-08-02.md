# VD2-05 Board card-anchor accessibility deferral — QA record

**Date:** 2026-08-02  
**Role:** Independent QA/accessibility review  
**Verdict:** **APPROVED DEFERRAL TO VD2-08**

## Decision and scope

The product owner explicitly approved deferring the Board card-anchor
accessibility-semantic observation to VD2-08. This is a narrow accessibility
test-contract decision, not a waiver of the Board's functional return state.

On macOS, the nested `PipelineOpportunityMoveCard` root is projected as an
`AXGroup`; XCTest can reliably discover it by identifier, but does not retain
its custom `accessibilityValue` as `Anchored`. The Board continues to retain
the actual anchor ID and restore the selected product detail context. The
correct production card-level identifier and `isAnchored` value remain in the
view source; this deferral does not remove them.

## Retained current-checkpoint contract

The direct Board-card route test and the shared Cancel/Escape context helper
must continue to prove, after returning from detail and before any horizontal
scroll:

1. the same `pipeline-opportunity-<id>` button exists;
2. its identifier and `Product Designer` label are stable;
3. it is hittable; and
4. its frame is contained by the `pipeline-board-lane-screening` frame.

Those functional selectors replace only the unobservable `AXGroup` value
assertions. Existing checks for canonical detail routing, no Actions menu,
search query, Screening filter, horizontal lane, Include Closed, Offer
navigation, no-write behavior, fixture data, and relaunch stability remain
required.

The direct body-route repair remains part of the current VD2-05 correction:
the card button has a rectangular content shape so a visible, non-menu card
body click routes to the existing opportunity detail. It is not deferred.

## VD2-08 required regression closure

VD2-08 must deliver a macOS-stable semantic contract for the selected Board
card anchor. Its regression evidence must verify the restored card's selected
or anchored state through an accessible role/value or equivalent explicit
semantic projection, while preserving the existing card identifier, label,
direct-route behavior, action-menu behavior, drag payload contract, and Board
return context. It must run signed wide and compact UI tests without skip,
expected-failure, or test-only state.

## Verification status

This record approves the bounded deferral only. Signed UI execution is not
claimed by this document; the local provisioning profile must be restored and
the coordinator must retain parseable result evidence before the current
checkpoint can be declared green.
