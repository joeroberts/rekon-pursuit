# Unified delivery Kanban dashboard design

## Decision

The local delivery dashboard becomes one Kanban board for every delivery
phase: remediation cycles and product phases alike. It remains a generated
`file://` page with one canonical, versioned JSON source; it does not add
SQLite, a server, or a second roadmap store.

## Scope

- Add an explicit delivery phase to every existing remediation task. The
  accepted current cycle is named `Remediation R1`; a later remediation is a
  new phase (for example, `Remediation R2`), never work silently added to the
  historical R1 lane.
- Add the approved post-MVP cards:
  - `UX-D11` — Logs and AI Ledger tabs
  - `UX-D12` — Refine log-search semantics
  - `UX-D10` — Protected-export success confirmation polish
  - `DESIGN-V2` — Richer visual language and board experience
  - Phase 2a privacy and AI foundation
  - Phase 2b connected workflow
  - Phase 2c intelligence and documents
  - Phase 3 decision support
- Add ordered phase metadata and `activePhaseId` to the canonical JSON.
- Render a phase selector. The dashboard opens on the configured active phase;
  the user can select any phase locally without changing source data.
- Continue to use the existing five lanes inside the selected phase. Counts,
  active task, next eligible task, and attention queue are derived only from
  the selected phase.
- Render the phase label on every card. The label supplements the existing
  work-type classification; it does not replace task IDs, statuses, or
  evidence.

## Phase model

| ID | Label | Lifecycle | Dependencies | Default state |
| --- | --- | --- | --- | --- |
| `remediation_r1` | Remediation R1 | Historical | None | Accepted historical delivery phase |
| `post_mvp_refinement` | Post-MVP refinement | Active | Remediation R1 | Its cards are planned Backlog work |
| `phase_2a` | Phase 2a — Privacy and AI foundation | Planned | Post-MVP refinement | Future Backlog |
| `phase_2b` | Phase 2b — Connected workflow | Planned | Phase 2a | Future Backlog |
| `phase_2c` | Phase 2c — Intelligence and documents | Planned | Phase 2b | Future Backlog |
| `phase_3` | Phase 3 — Decision support | Planned | Phase 2c | Future Backlog |

Each future remediation cycle receives a distinct phase ID, display label,
and its own cards. `workType` remains independent of phase so cards can say
what they are (for example, **Remediation**, **UX refinement**, or
**Workflow**) without overloading the Kanban lane name.

The selected phase is view state only. Changing it must not update JSON,
ledger, task status, or attention state. A 30-second page refresh returns the
view to `activePhaseId`, ensuring the open file reflects the latest committed
operational state.

Exactly one phase has lifecycle `active`, and it must equal `activePhaseId`.
Historical phases contain accepted cards only. Planned phases contain Backlog
cards only and never create an attention item. A phase may become active only
when every declared dependency is historical and all of that phase's cards are
accepted. Dependencies must refer to known, distinct phase IDs and form no
cycles. These constraints make each remediation cycle repeatable rather than
encoding a single, one-time remediation sequence.

## Data contract

`dashboard-status.json` gains:

```json
{
  "activePhaseId": "post_mvp_refinement",
  "phases": [{
    "id": "post_mvp_refinement",
    "label": "Post-MVP refinement",
    "lifecycle": "active",
    "dependsOnPhaseIds": ["remediation_r1"]
  }],
  "tasks": [{ "id": "UX-D11", "phaseId": "post_mvp_refinement" }]
}
```

Every task must declare a valid `phaseId`. `activeTaskId` and
`nextEligibleTaskId` may be `null` when the selected phase has no released
work. Future tasks use `backlog`, not `blocked`; a phase dependency is normal
sequencing, not an intervention-required impediment.

The ledger remains the detailed evidence record. A real task transition still
updates JSON, ledger, and generated HTML together. Adding the future queue is
a dashboard-model transition and records its boundary once; switching browser
filters is not a delivery transition.

## Rendering and interaction

The existing static Python renderer validates phase IDs, selected active phase,
and task phase membership before writing HTML. It embeds all phase data into
the page. A small browser-local control filters cards and recalculates summary
counts without network access or a persistent browser database. The five lanes
retain their exact order and colors.

The summary identifies the selected phase. For a phase with no active or
eligible task, it truthfully says so rather than promoting a task from another
phase. The attention queue only considers the selected phase, so future
Backlog work does not create alerts.

## Out of scope

- No SQLite database, server, cloud project-management integration, plugin, or
  app feature.
- No change to accepted remediation evidence.
- No release of UX-D10/D11/D12, Visual Design v2, or Phase 2 work.
- No dashboard drag/drop editing; delivery state remains a controlled
  repository update.

## Focused verification

1. JSON validation rejects unknown/missing phase IDs and invalid
   `activePhaseId`.
2. Generated HTML opens directly from `file://`, starts on Post-MVP refinement,
   and contains all six selectable phases.
3. Selecting each phase filters cards, summary counts, and attention queue to
   that phase only; it does not mutate source state.
4. Existing remediation cards remain visible under the Remediation R1 filter with
   their accepted statuses and evidence links intact.
5. Existing dashboard `--check` determinism and 30-second refresh behavior
   remain intact.
