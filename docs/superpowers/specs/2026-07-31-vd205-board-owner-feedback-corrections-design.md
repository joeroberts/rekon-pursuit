# VD2-05 Board Owner-Feedback Corrections Design

**Date:** 2026-07-31  
**Status:** Approved design direction; implementation not yet started  
**Scope:** Three product-owner corrections discovered during the manual-first VD2-05 Board preview

## Objective

Make the interactive Board semantically unambiguous and easy to leave or edit:

1. render `Applied` and `Screening` as separate lanes and separate drop targets;
2. provide an explicit, non-saving return from Add Opportunity to the same Board context; and
3. replace the card's redundant stage chip and separate full-width move control with one compact overflow-actions menu.

This correction does not change the six persisted `PipelineStage` values, stage-move transaction semantics, recovery behavior, activity/history requirements, or the accepted Table/right-drawer design.

## 1. Exact stage-to-lane mapping

The Board exposes five primary open lanes in canonical order:

1. Saved
2. Applied
3. Screening
4. Interviewing
5. Offer

Closed remains a conditional sixth lane shown only when **Include closed** is enabled.

Each lane contains exactly its namesake persisted stage and accepts a drop only for that stage. In particular:

- an `Applied` opportunity appears only in Applied, and dropping on Applied requests `.applied`;
- a `Screening` opportunity appears only in Screening, and dropping on Screening requests `.screening`;
- the Board never groups, aliases, or silently converts either stage.

The presentation remains horizontally scrollable at supported widths. Adding a lane must not compress cards below their readable width.

## 2. Add Opportunity cancellation and Board return

Add Opportunity gains a clearly visible **Cancel** action near the primary save action. Escape uses the same cancel action through the platform cancel keyboard shortcut.

Cancel:

- performs no opportunity, activity, history, or task write;
- clears the transient Add Opportunity draft and any draft-only validation error;
- returns to Pipeline in Board mode when the flow was entered from Board; and
- restores the prior query, stage filter, Include closed value, selected/anchored opportunity, and horizontal Board position.

The return is immediate and does not require a discard-confirmation dialog. Existing successful-save behavior is unchanged by this correction.

Board return context is presentation state owned above the conditional Add Opportunity route. It is not persisted to the local workspace and must not enter Core or the activity log.

## 3. Opportunity-card actions

Remove both of these controls from every Board card:

- the stage chip in the card's top-right corner; and
- the separate full-width **Move stage** control below the card.

The exact lane now communicates the card's stage. A compact top-right ellipsis button replaces both controls. Its tooltip and accessibility label are **Actions for _opportunity title_**.

The menu contains only:

1. **Edit opportunity** — opens the existing opportunity details/edit route for that record.
2. **Move to stage…** — opens the existing six-stage menu in canonical order: Saved, Applied, Screening, Interviewing, Offer, Closed.

The current exact stage remains identifiable in the Move submenu, and choosing it retains the existing no-op behavior. Closing continues through the existing reconciliation guard. Delete and other destructive actions remain inside opportunity details.

Clicking the rest of the card continues to open opportunity details. The existing keyboard route to the first move control is retargeted to the first card-actions control; keyboard users can open the menu and reach both actions without using a pointer.

## State and data boundaries

- `PipelineStage` and persisted opportunity records remain unchanged.
- The Board lane enum becomes a one-to-one presentation projection over the six canonical stages.
- Existing `WorkspaceViewModel.changeStage` and Core transaction/rollback/recovery contracts remain the sole stage-mutation path.
- The actions menu may submit only the same typed `PipelineStageMoveRequest` used by drag-and-drop.
- Add-flow return context and Board scroll restoration are ephemeral UI state.
- No new dependency, schema, migration, provider, network, document, AI, or security boundary is introduced.

## Failure and accessibility behavior

- Stage-move success, no-op, blocked-close, unavailable-record, write-failure, and projection-failure feedback remain visible and unchanged in meaning.
- A rejected or failed menu move leaves the card in its source lane.
- Canceling Add Opportunity must remain available even when the draft is invalid.
- The ellipsis control has a stable accessibility identifier, meaningful label, tooltip, keyboard focus indication, and sufficient hit target.
- Each lane has a unique accessible name and count; Applied and Screening must never share an accessibility container.
- Reduce Motion continues to suppress only spatial relocation animation, not focus restoration or outcome text.

## Acceptance evidence

Focused proof must establish:

1. a pure one-to-one lane mapping and exact drop target for every canonical stage;
2. five default open lanes plus conditional Closed, with Applied and Screening cards in distinct containers;
3. successful persisted moves into both Applied and Screening, including relaunch and exactly one new subject transition/activity per real move;
4. the ellipsis menu opens Edit and the six-stage Move submenu, while card-body opening still works;
5. the removed stage chip and full-width move control are absent;
6. Cancel and Escape return to the same Board context with the unsaved draft discarded and zero persistent writes; and
7. retained failure, invalid-payload, keyboard, focus, Reduce Motion, Table/right-drawer, and signed-app behavior remains intact.

Following the established manual-first sequence, implementation produces a signed Debug preview for product-owner review before broad regression, independent post-implementation gates, delivery-dashboard updates, and final VD2-05 product-owner acceptance.

## Explicitly out of scope

- custom or reorderable pipeline stages;
- changing the canonical six-stage model;
- destructive actions in the card menu;
- redesigning the opportunity form or accepted Table/right drawer;
- changing successful-save navigation;
- reopening accepted VD2-01 through VD2-04 work beyond regressions caused by this correction.
