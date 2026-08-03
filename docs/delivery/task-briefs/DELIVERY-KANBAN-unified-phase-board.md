# DELIVERY-KANBAN — Unified phase board

## Decision

The delivery dashboard is one filterable, file-local Kanban view over the
repository-controlled phase catalog. Remediation R1 remains accepted historical
evidence. Post-MVP refinement is the active phase, and every future remediation
cycle is modeled as its own phase rather than being added to historical R1.

Creating the Backlog cards is a dashboard-model transition, not a release or task-status transition; no UX-D10/D11/D12, DESIGN-V2, or Phase 2–3 delivery work is authorized by this brief.

## Scope

In scope:

- The canonical JSON phase catalog, phase membership, and Backlog cards.
- Generated `index.html` and `remediation.html` projections, including the
  default active-phase selector and a non-default selector view.
- One ledger record of the board-model boundary and roadmap wording that keeps
  the serial delivery order explicit.

Out of scope:

- Any product implementation, release, task activation, owner action, or
  blocker for UX-D10, UX-D11, UX-D12, DESIGN-V2, or Phases 2a–3.
- Any revision of accepted Remediation R1 facts or evidence.
- Dashboard editing, persistence, network access, browser storage, or selector
  writes to JSON, ledger, roadmap, URL, or task state.

## Ordered phase catalog

| Order | Phase | Lifecycle | Depends on |
| --- | --- | --- | --- |
| 1 | Remediation R1 | Historical | None |
| 2 | Post-MVP refinement | Active | Remediation R1 |
| 3 | Phase 2a — Privacy and AI foundation | Planned | Post-MVP refinement |
| 4 | Phase 2b — Connected workflow | Planned | Phase 2a |
| 5 | Phase 2c — Intelligence and documents | Planned | Phase 2b |
| 6 | Phase 3 — Decision support | Planned | Phase 2c |

Historical cards are Accepted. Planned cards are Backlog and cannot require
user action. A phase becomes active only after its dependency phases are
historical with Accepted cards.

## Card/status catalog

| Card | Phase | Status | Release boundary |
| --- | --- | --- | --- |
| UX-D10 | Post-MVP refinement | Backlog | Separate UX polish brief after protected-export reliability work. |
| UX-D11 | Post-MVP refinement | Backlog | Separate planning/release; no AI execution, network capability, or new ledger data. |
| UX-D12 | Post-MVP refinement | Backlog | Define local-search ranking, matching, and empty state before a separate release. |
| DESIGN-V2 | Post-MVP refinement | Backlog | Separate visual-design brief; accepted remediation evidence is unchanged. |
| P2A-1 | Phase 2a | Backlog | Follows accepted Post-MVP refinement and approved privacy/AI contracts. |
| P2B-1 | Phase 2b | Backlog | Follows accepted Phase 2a and separately approved connection/privacy gates. |
| P2C-1 | Phase 2c | Backlog | Follows accepted Phase 2b and approved provider/license/source policy. |
| P3-1 | Phase 3 | Backlog | Follows accepted Phase 2c and scoring, consent, and retention decisions. |

## Acceptance checks

1. `dashboard-status.json` has the exact six-phase serial catalog, with
   `post_mvp_refinement` as `activePhaseId`, and every accepted R1 task has
   `phaseId: remediation_r1`.
2. The eight listed cards are Backlog with `needsUserAction: false`; no future
   card is presented as released, active, blocked, or awaiting owner action.
3. `python3 scripts/delivery/render_dashboard.py` regenerates both static pages;
   the unit suite and `--check` pass.
4. Opening `index.html` starts on Post-MVP refinement. Selecting a different
   phase changes only cards, counts, summary, and attention; refresh returns to
   Post-MVP refinement and selector interaction writes no repository files.
5. The remediation ledger records this model expansion and the roadmap states
   that Phase 2a follows accepted Post-MVP refinement and Phase 3 follows
   Phase 2c.

## Release boundary

The JSON contract is a controlled release gate, not a release mechanism. The
ledger remains the detailed accepted R1 evidence authority and the roadmap
remains the sequencing authority. A future card may leave Backlog only after a
separate approved brief and its required Planning, Architecture, TPM, QA,
Delivery, review, and acceptance gates. Ordinary serial dependency is Backlog,
not Blocked; Blocked requires a material intervention.
