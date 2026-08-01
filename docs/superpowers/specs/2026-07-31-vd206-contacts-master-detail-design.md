# VD2-06 — Contacts Master/Detail Redesign

**Status:** Product-owner-approved design; ready for implementation planning and independent pre-implementation gates

**Product-owner approval:** 2026-07-31, covering the recommended approach and the layout, interaction/data-flow, accessibility/error, and verification sections.

## Purpose

Recompose Contacts as an adaptive, read-first master/detail workspace that
matches the approved Rekon Pursuit visual language while preserving existing
contact persistence, validation, employer association, activity evidence, and
canonical opportunity routing.

The controlling visual reference for this card is:

`/Users/jroberts/Downloads/rekon_pursuit_contacts.png`

The reference controls composition, hierarchy, density, and visual direction.
Its fictional names, employers, titles, counts, and relationship details are
not product data and must never be introduced into the application.

## Scope and boundaries

In scope:

- a scrollable contact master list and read-first detail panel;
- adaptive wide and compact-window behavior;
- contact search and employer filtering;
- explicit new, edit, save, cancel, and delete flows;
- progressive disclosure for notes and linked opportunities;
- explicit management of opportunity associations;
- accessibility, validation, persistence-failure, and empty states;
- focused regression coverage for changed Contacts behavior.

Out of scope:

- new contact, employer, opportunity, activity, or relationship data fields;
- fictional avatars, company marks, relationship facts, or counts;
- changes to contact persistence schemas or canonical opportunity editing;
- unrelated changes to the app shell, Home, Pipeline, Settings, or the deferred
  VD2-05 automation debt.

## Approved approach

Use an adaptive read-first split view.

- At wide widths, the contact list remains visible on the left and the selected
  contact's read-first detail remains visible on the right.
- At compact widths, selecting a contact replaces the list with the detail
  view and exposes a clear **Back to Contacts** control. Detail must never be
  stacked beneath the list.
- Editing and contact creation occur in the detail region rather than in a
  modal sheet or an always-editable form.

This approach was selected over an always-editable split and a sheet-based
editor because it most closely matches the approved reference, preserves
context, and reduces accidental writes.

## Layout and responsive contract

- The Contacts title and **New contact** action establish the top hierarchy.
- Search and employer filtering sit above the contact master list.
- The contact list scrolls independently from the detail panel so selection
  does not reposition the whole screen.
- A selected row uses the approved restrained cyan-to-violet treatment with a
  non-color selection cue; rows must not rely on broad gray fills.
- The read-first detail presents only available persisted fields: initials
  derived from the name, name, employer, title, email, profile, relationship
  context, notes, and linked-opportunity count or content.
- Empty selection is represented by a restrained prompt inside the detail
  region. Compact layouts return to the list instead of displaying an empty
  detail below it.
- The existing app shell, navigation, and semantic Rekon theme remain the
  system seams. VD2-06 must not create a competing local visual system.

## Interaction contract

### Selection and viewing

- Selecting a contact changes only ephemeral selection state and opens its
  read-first detail.
- Contact email and profile controls appear only when persisted values exist
  and use the existing validated values and platform opening behavior.
- Notes remain progressively disclosed rather than occupying permanent detail
  space.

### New and edit

- A compact pencil button in the detail panel's upper-right corner enters edit
  mode for the selected contact.
- **New contact** opens a blank editor in the same detail region.
- Save uses the existing `WorkspaceViewModel` validation and persistence path.
- Cancel discards the in-memory draft without writing. Editing returns to the
  same contact's read-first detail; cancelling creation returns to the previous
  selection at wide widths or the contact list at compact widths.
- Validation and store failures retain the draft, state what failed, and keep
  recovery actions available. They must not imply a successful save.

### Delete

- Delete is removed from every contact-list row.
- An overflow menu beside the pencil action contains **Delete contact**.
- Delete continues through the existing destructive confirmation owned by the
  canonical container. Cancellation leaves the contact and selection intact;
  successful deletion returns to a valid list or empty state.

### Related opportunities

- **View related opportunities** is an inline disclosure in the detail panel.
- Its count and contents are derived only from real persisted associations.
- Expanding it lists the linked opportunities and provides an **Open** action
  that enters the existing canonical opportunity route.
- Browsing and opening do not change associations.
- Association changes remain behind a separate explicit **Manage** action and
  continue to use the existing link/unlink commands and employer-association
  rules.

## Ownership and data-flow contract

- `ContentView` remains the sole owner of `WorkspaceViewModel`, route state,
  destructive confirmations, and canonical opportunity navigation.
- An extracted `ContactsView` may own ephemeral presentation state such as
  selection, compact navigation, disclosure, and local editor mode.
- Contact drafts use the existing view-model draft and validation contract.
  The presentation layer must not create a second workspace model or write
  directly to the store.
- Existing employer filtering, employer association, contact interaction
  history, validation, activity/audit evidence, and relaunch persistence remain
  behaviorally intact.

## Accessibility and failure-state contract

- Keyboard navigation covers search, employer filter, contact selection,
  detail actions, disclosures, related opportunities, and form controls.
- Focus moves predictably into detail or edit mode and returns to the initiating
  control after Save or Cancel where that control still exists.
- VoiceOver identifies contact rows, selection state, action purpose,
  disclosure state, validation errors, and related-opportunity counts.
- Selection, stage/status facts, validation, and errors use text or semantic
  controls in addition to color.
- Supported window resizing and larger accessibility text must preserve primary
  actions through wrapping, truncation, or scrolling without clipping.
- Explicit truthful states cover: no contacts, no search results, no selection,
  no related opportunities, invalid email/profile, association failure, store
  failure, deletion cancellation, and deletion completion.

## Verification and owner-review sequence

Verification is proportional to the Contacts slice:

1. Add focused lowest-layer tests for changed selection, draft cancellation,
   validation, association, and routing behavior where those contracts are not
   already covered.
2. Add focused UI evidence for wide master/detail, compact list-to-detail/back,
   New/Edit/Cancel, progressive disclosure, and safe delete behavior.
3. Run independent code review, QA/accessibility verification, architectural
   effect review, and proportional security/privacy verification.
4. Build and launch a normally signed Debug app for product-owner hands-on
   review before any broad VD2-08 whole-app acceptance campaign.
5. Record VD2-06 acceptance only after the product owner explicitly accepts the
   signed build. VD2-07 remains blocked until that acceptance is recorded and
   the owner authorizes successor work.

## Acceptance boundary

VD2-06 is acceptable when the signed application demonstrates that:

- wide and compact Contacts layouts match this approved interaction model;
- real contacts can be searched, filtered, selected, viewed, created, edited,
  cancelled, saved, and deleted without unintended writes;
- linked opportunities disclose progressively, open canonically, and change
  associations only through explicit management;
- validation, persistence, activity/audit, employer association, and relaunch
  behavior remain intact;
- focused automated evidence and independent reviews report no unresolved
  release-blocking defect; and
- the product owner explicitly records acceptance after manual review.
