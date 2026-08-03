# VD2-07b — Reference-faithful form visual amendment

**Status:** Planning amendment. This document replaces every ambiguous
visual-direction statement in `VD2-07b-shared-form-control-alignment.md`.
It changes no behavioral scope, implementation allowlist, or dependency.

## Controlling references

The product-owner references are the acceptance target for VD2-07b:

- `/Users/jroberts/Desktop/Codex Image Aug 2, 2026, 09_38_05 PM.png` —
  Contacts editor.
- `/Users/jroberts/Desktop/Codex Image Aug 2, 2026, 09_38_47 PM.png` —
  Opportunity editor.

The Activity & AI references supplied alongside them are controlling for the
later VD2-07c card only. They do not expand VD2-07b into an Activity-layout or
AI feature change.

## Replacement visual contract

Every app-owned form field in the existing VD2-07b inventory must preserve its
current role and behavior while presenting as the same restrained form family
visible in the controlling references:

1. Each field has a readable label **above** its control. A section heading
   has a subtle horizontal divider; it is not a field label or a decorative
   container.
2. A text field, picker, numeric field, and multiline editor is one compact
   control surface: deep-navy fill, quiet approximately 1px neutral/navy
   border, small consistent corner radius, and no second capsule surrounding
   the label plus input.
3. Idle controls remain quiet. Cyan is reserved for an actual keyboard focus
   indication and active selection; it is not a permanent thick outline or a
   substitute for control hierarchy. Focus must retain a non-color cue.
4. Existing grouped form sections use the references' compact vertical rhythm,
   restrained dividers, and consistent label-to-control spacing. Multiline
   fields remain visibly distinct by height without becoming detached cards.
5. Opportunity forms retain the reference's responsive layout: wide screens
   use the existing logical multi-column groups (for example compensation and
   logistics); compact screens stack those groups without clipping labels,
   selected values, text editors, validation, or primary actions.
6. Contacts retains a concise edit form within its detail panel. It must not
   become a tall series of nested outlined rows, embedded-label capsules, or
   unrelated card-like field groups.

## Explicit rejection criteria

Reject the implementation if any reviewed screen resembles the rejected
direction captured in the product-owner screenshot of the current New Contact
form, including any of the following:

- labels inside their own outlined row or fused into a label/input capsule;
- permanently cyan, thick, or high-chrome outlines on idle fields;
- a nested border around a field that already has a control border;
- vertically inflated, repetitive boxed rows that obscure section hierarchy;
- single-column expansion on wide opportunity layouts when the existing
  logical multi-column layout can fit; or
- a restyle that changes labels, placeholder wording, bindings, picker tags,
  validation, focus ownership, persistence, audit behavior, action order, or
  native-panel ownership.

## Required visual QA and test evidence

Task 1's additive selector matrix remains a behavior-preservation gate; it is
not proof of visual acceptance. Task 2/3 must add an independent visual
verification package. It is a required merge gate, not a request for another
product-owner decision.

### Deterministic signed-capture matrix

The visual test fixture must create one deterministic existing Contact and one
deterministic existing Opportunity, navigate from a clean launched app, and
record **all sixteen** signed screenshots below. Each run must write the
screenshots to one result bundle named
`VD2-07b-reference-faithful-visuals.xcresult`; the attachment name in that
bundle must exactly match the corresponding filename below. No capture may be
reused to stand in for another route, viewport, or state.

| Route | 1600 × 1000 wide | 860 × 640 compact |
| --- | --- | --- |
| Contacts — edit | `vd207b-contacts-edit-wide-idle.png`<br>`vd207b-contacts-edit-wide-focus.png` | `vd207b-contacts-edit-compact-idle.png`<br>`vd207b-contacts-edit-compact-focus.png` |
| Contacts — new | `vd207b-contacts-new-wide-idle.png`<br>`vd207b-contacts-new-wide-focus.png` | `vd207b-contacts-new-compact-idle.png`<br>`vd207b-contacts-new-compact-focus.png` |
| Opportunity — add | `vd207b-opportunity-add-wide-idle.png`<br>`vd207b-opportunity-add-wide-focus.png` | `vd207b-opportunity-add-compact-idle.png`<br>`vd207b-opportunity-add-compact-focus.png` |
| Opportunity — overview | `vd207b-opportunity-overview-wide-idle.png`<br>`vd207b-opportunity-overview-wide-focus.png` | `vd207b-opportunity-overview-compact-idle.png`<br>`vd207b-opportunity-overview-compact-focus.png` |

“Wide” and “compact” mean the literal app-frame sizes in the table, set before
route navigation and asserted by the UI test before each capture. The test
must fail if the resulting application frame differs from the requested frame
by more than 2 points in either dimension. It must use a fixed locale,
calendar, content-size category, and fixture content; test-state timestamps
and randomly generated labels may not appear in the captured form area.

### Required route prelude and geometry checks

Before every capture, the UI test must prove the route is fully settled:

1. Launch cleanly, install the deterministic fixture, set the literal frame,
   navigate to the named route, and wait for its title plus the primary form
   action to exist and be hittable.
2. For `*-idle`, do not leave a text input as first responder. For `*-focus`,
   click the named first editable field (Contacts: `Name`; Opportunity: `Job
   title`), type a deterministic single character, and keep that field focused
   at capture time. The capture and assertion must prove keyboard focus by the
   active insertion caret or the platform focus indicator; an outline alone is
   insufficient evidence.
3. Assert that each sampled label's frame ends above its associated control
   (`label.maxY <= control.minY`), that neither intersects, and that the
   control is a single surface rather than a containing label/control capsule.
   Sampling must include Name, a contact information field, and Relationship
   context/Notes on Contacts; and Job title, a single-line field, a multiline
   field, and a picker on Opportunity.
4. Assert visible action access: the route's primary and cancel/back action
   frames are within the app frame or reachable by the route's documented
   scroll action. Assert no sampled label, value, validation message, text
   editor, picker, or primary action is clipped or overlaps another sampled
   element.
5. On wide Opportunity captures, assert the existing compensation and
   logistics groups use at least two visible columns where their controls fit;
   on compact captures, assert those peer controls stack in reading order with
   no horizontal overlap. These assertions must be made from live element
   frames, not inferred from screenshots.

### Screenshot comparison checklist and merge evidence

An independent QA verifier must inspect the sixteen finalized attachments in
`VD2-07b-reference-faithful-visuals.xcresult` against the controlling Contacts
and Opportunity references. Its signed report must record pass/fail, with a
capture filename for every verdict, for:

- labels above controls and no embedded-label or label/input capsule;
- one quiet, compact control surface at idle, with no nested border or
  permanently cyan/high-chrome outline;
- focused control's restrained cyan focus indication plus a non-color focus
  cue and visible caret/keyboard-focus proof;
- section titles/dividers, label-to-control spacing, vertical rhythm, and
  multiline-editor height matching the reference family;
- concise Contacts detail-panel geometry rather than repetitive boxed rows;
- responsive Opportunity columns at 1600 × 1000 and non-overlapping compact
  stacking at 860 × 640; and
- retained labels, values, validation, keyboard behavior, and accessible
  actions.

The report must cite the finalized result-bundle path and the executed test
command. A selector-only GREEN result, an implementer self-review, or an
uninspected screenshot set cannot satisfy this gate. The VD2-07b PR is not
eligible to merge until an independent QA comparison records all sixteen
captures and accepts the checklist; this gate does not require waiting for a
further product-owner approval.

## Non-scope invariants

This amendment authorizes presentation only. It does **not** authorize any
new state, state ownership, persistence, audit event, feature, filter,
preference, routing, AI/provider/network behavior, file-panel behavior, or
native macOS panel styling/automation. Existing labels, bindings, identifiers,
validation, callbacks, keyboard behavior, and root-owned recovery/dialog
ownership remain unchanged.
