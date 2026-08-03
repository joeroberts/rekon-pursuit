# Final-review documentation alignment fix

## Scope

Resolved the sole final-review P2 documentation finding in
`docs/delivery/roadmap.md`. The Shipped MVP boundaries now distinguish the
accepted R1 lifecycle and recovery facts from still-unreleased future product
work, retain explicit user control for reconciliation closure, and describe
the accepted durable document-reference behavior. The M5 history row now
identifies Post-MVP refinement as the active planned phase.

No dashboard JSON, generated HTML, task state, or future Backlog card changed.

## Verification

- `PYTHONDONTWRITEBYTECODE=1 python3 -` alignment assertion — passed: eight
  accepted-R1/current-phase facts present and four stale phrases absent.
- `PYTHONDONTWRITEBYTECODE=1 python3 scripts/delivery/render_dashboard.py --check`
  — passed: dashboard source and generated HTML are current.
- `git diff --check` — passed.

## Commit

Recorded in the final-fix commit for this documentation-only correction.
