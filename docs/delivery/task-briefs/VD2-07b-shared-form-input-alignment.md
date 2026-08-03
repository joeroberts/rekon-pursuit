# VD2-07b — Shared form-input visual alignment

**Status:** Backlog. This record establishes the product-owner-approved scope only. No implementation, release, or acceptance is represented here.

## Objective

Make every app-owned form input use one coherent Rekon presentation: the dark inset surface, restrained border, label and section spacing, and cyan focused state shown in the approved Contacts, Pipeline, and protected-export references.

## In scope

- Inventory every app-owned input surface before implementation so the visual system applies consistently rather than screen by screen.
- Apply the shared presentation to single-line text, search, secure/recovery-key, selection, and multiline inputs in:
  - Contacts, including the master-list search and contact editor;
  - Pipeline opportunity add/edit forms; and
  - Settings protected-export dialogs.
- Keep the visual language consistent across equivalent inputs: inset navy fill, subtle unfocused border, cyan focused outline, compact control height, explicit field labels, and grouped section dividers.
- Preserve the native macOS save/open panels as native controls; their chrome is not part of this task.

## Non-goals and boundaries

- No new fields, changed copy, workflow, navigation, route, data model, persistence, validation, recovery/export semantics, or file-panel behavior.
- No migration, fixture, test-host, signing, entitlement, networking, or project-graph change.
- No accessibility remediation or acceptance campaign. The deferred accessibility work remains owned by `VD2-08`.
- No global visual restyling unrelated to app-owned form inputs.

## Required implementation boundaries

- Reuse the established Rekon visual tokens and existing control semantics. The implementation must not create screen-specific variants where one shared form-input presentation can serve equivalent controls.
- Existing bindings, validation messages, save enablement, keyboard shortcuts, accessibility identifiers, and focus ownership remain behaviorally unchanged.
- Any selector or input type that cannot use the shared presentation without changing its native semantics must be recorded for product-owner direction rather than silently redesigned.

## Acceptance target

The Contacts editor/search, Pipeline opportunity forms, and protected-export dialogs visibly share the approved input system while their current interactions and data outcomes remain unchanged. A later independently released implementation brief will define the focused regression evidence and owner visual handoff.

## Dependencies and release state

`VD2-06` and `VD2-07` are recorded dependencies. This task remains Backlog until the normal independent Planning, Architecture, QA, TPM, and Delivery gates release a bounded implementation slice. Creating this task neither changes the current delivery state nor releases `VD2-08`.
