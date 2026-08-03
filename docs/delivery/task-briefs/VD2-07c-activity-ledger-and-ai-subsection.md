# VD2-07c — Activity ledger viewport and AI assistant subsection

**Status:** Backlog. This record establishes the product-owner-approved scope only. No implementation, release, or acceptance is represented here.

## Objective

Recompose the existing Activity & AI destination into two local subsections: a window-resizing Activity ledger and a truthful AI assistant placeholder. The screen must remain a local, private workspace surface.

## In scope

- Add local, non-persisted selection between **Activity ledger** and **AI assistant** while retaining the existing global Activity & AI rail destination.
- Make **Activity ledger** the default subsection. Keep its search field and make every retained activity event searchable and scroll-accessible.
- Constrain the ledger to its own vertical scrolling viewport. The viewport must consume the available window height and resize with the window so the outer page does not grow with activity history.
- Use a bounded rendering window of at most 50 activity rows at a time. This is a presentation/performance boundary only: retained activity entries are never deleted, truncated from storage, or made unavailable. Older entries remain reachable through the ledger scroll/search experience.
- Replace the current AI-usage filter form with the approved **AI assistant coming soon** placeholder: future-update wording plus the truthful statement that the workspace remains local and private.

## Non-goals and boundaries

- No activity deletion, retention-policy change, store/schema/migration change, or altered activity-event content.
- No AI execution, model/provider selection, model activity, cost calculation, cloud connection, Gmail/Calendar integration, network request, or new AI ledger data.
- No new AI configuration form. The existing Activity & AI AI-usage filter grid is replaced only by the approved unavailable placeholder.
- No global-rail redesign, route persistence, unrelated form styling, or accessibility remediation campaign. Deferred accessibility work remains owned by `VD2-08`.

## Required implementation boundaries

- The full existing activity history remains the source of truth. Presentation code may window or lazily materialize rows, but it must not discard entries from the model or store.
- Search operates across the retained ledger, not merely an initial 50-entry subset. Its displayed result window remains bounded while older matching entries stay reachable.
- The local subsection selection must not become a new global route or persisted preference.
- Preserve existing event bindings, identifiers where the corresponding Activity ledger control remains, and all current local-only truth boundaries.

## Acceptance target

At any supported window height, the Activity page frame remains stable while the ledger alone scrolls; expanding activity history does not elongate the page. A user can search or scroll to retained older activity despite the bounded row-rendering window. The AI subsection contains only the approved coming-soon/local-private placeholder and exposes no functional AI configuration or network-capable control.

## Dependencies and release state

`VD2-02` and `VD2-07` are recorded dependencies. This task remains Backlog until independent Planning, Architecture, QA, TPM, and Delivery gates release a bounded implementation slice. Creating this task does not release `VD2-08` or change the delivery state of any existing work item.
