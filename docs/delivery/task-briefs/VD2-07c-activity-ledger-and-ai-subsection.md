# VD2-07c — Activity & AI submenu, ledger viewport, and AI placeholder

**Status:** Backlog. This record establishes the product-owner-approved scope only. No implementation, release, or acceptance is represented here.

## Objective

Update the existing **Activity & AI** destination to the approved reference: a Settings-style local submenu, a bounded Activity ledger viewport, and a truthful non-functional AI assistant placeholder. The screen remains a local, private workspace surface.

## In scope

- Retain **Activity & AI** as one main-sidebar destination. Directly below its page title, add horizontal local navigation for **Activity ledger** and **AI assistant**; **Activity ledger** is selected by default.
- Use the same restrained cyan icon/text treatment and cyan indicator line as Settings for the selected local subsection. At narrow window widths, do not use the old generic full-width underline behavior.
- On the **Activity ledger** page, keep the heading and one **Local activity ledger** work area.
- Restyle the Activity search field to match the approved dark application form controls: deep navy fill, thin muted blue-gray border, a small leading search icon, rounded corners, muted placeholder text, and no generic gray fill or oversized bright-blue focus ring.
- Render activity as structured rows: event-type icon at left, event label in the middle, and timestamp right-aligned.
- Contain the structured rows in their own vertically scrolling ledger viewport. The viewport resizes with the window but never grows beyond the equivalent height of 50 rows; activity history must not make the outer page unbounded.
- Keep every retained activity entry. Users can scroll to older entries, and search queries the entire retained ledger rather than a visible or initial subset.
- On **AI assistant**, replace the existing form with only this non-functional placeholder:
  - **AI assistant coming soon**
  - **AI-powered workspace assistance will be available here in a future update.**
  - **Your workspace remains local and private.**

## Non-goals and boundaries

- No activity deletion, retention-policy change, store/schema/migration change, or altered activity-event content.
- No AI form, buttons, provider settings, execution, model activity, cost calculation, cloud connection, Gmail/Calendar integration, network request, or new AI ledger data.
- No global-rail redesign, unrelated form styling, or accessibility remediation campaign. Deferred accessibility work remains owned by `VD2-08`.

## Required implementation boundaries

- The full existing activity history remains the source of truth. A bounded, window-resizing viewport must not discard, hide permanently, or otherwise restrict retained entries.
- Search operates across the retained ledger. Search results follow the same independently scrollable viewport rule, including access to older matching entries.
- Preserve the existing global Activity & AI route, activity bindings, and local-only truth boundaries.
- Preserve the Rekon visual language: dark navy/black surfaces, subtle card borders, white/light-blue typography, cyan and violet accents, selected purple sidebar item, and lower-left sidebar line decoration.

## Acceptance target

The Activity page matches the approved two-subsection reference. Its selected-subsection cue remains restrained and correct at narrow widths. The ledger alone scrolls, its viewport responds to the window without exceeding a 50-row-equivalent height, and all retained history remains accessible by scrolling/searching. The AI assistant subsection contains only the three approved placeholder statements and exposes no AI control or network-capable behavior.

## Dependencies and release state

`VD2-02` and `VD2-07` are recorded dependencies. This task remains Backlog until independent Planning, Architecture, QA, TPM, and Delivery gates release a bounded implementation slice. Creating this task does not release `VD2-08` or change the delivery state of any existing work item.
