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
verification package with deterministic Contacts and Opportunity fixtures at
wide and compact widths:

- capture signed app screenshots of the Contacts edit/new route and
  Opportunity add/overview route in idle and keyboard-focused states;
- compare each capture directly to the two controlling references, recording
  pass/fail for label placement, single-surface construction, border/focus
  hierarchy, section/divider rhythm, multiline treatment, and responsive
  column behavior;
- execute the existing compact/large-text UI checks and confirm no clipping
  or action inaccessibility; and
- require independent QA visual acceptance against these product-owner-approved
  references before the PR is eligible to merge. Do not wait for an additional
  product-owner review; a selector-only GREEN result cannot waive a visual
  mismatch.

## Non-scope invariants

This amendment authorizes presentation only. It does **not** authorize any
new state, state ownership, persistence, audit event, feature, filter,
preference, routing, AI/provider/network behavior, file-panel behavior, or
native macOS panel styling/automation. Existing labels, bindings, identifiers,
validation, callbacks, keyboard behavior, and root-owned recovery/dialog
ownership remain unchanged.
