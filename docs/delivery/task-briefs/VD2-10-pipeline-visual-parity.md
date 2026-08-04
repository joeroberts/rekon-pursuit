# VD2-10 — Opportunities visual parity: controls, Table, and Board

## Purpose and release boundary

Implement the product-owner feedback in [GitHub issue #16](https://github.com/joeroberts/rekon-pursuit/issues/16): bring the Opportunities controls, Table, and Board to parity with the supplied references without reopening the accepted VD2-04/VD2-05 behavior.

Controlling references are `sceenshots/pipeline.png` (Table) and
`sceenshots/pipeline2.png` (Board), the issue, and the owner comparison captures in the VD2-10 handoff conversation. The visible product term remains **Opportunity/Opportunities**; stable internal identifiers and routes remain unchanged.

## Preconditions

- VD2-04 and VD2-05 are accepted.
- `VD2-10` is the dashboard's next dependency-safe task.
- This task is presentation-only. It must not change the model, store,
  migration, activity, import, filtering truth, routing, persistence, or any
  VD2-05 stage-movement contract.

## Binding product decisions

- Keep **Include closed**. It is an intrinsic-width native checkbox plus label
  with a sufficiently large hit target; it must never be put in a narrow
  fixed-width box or clip its label.
- Restore compact, quiet Search and Stage controls, with the search icon inside
  Search; use clear icon-led Table/Board equal segments with a visible active
  state; retain existing native semantics and identifiers.
- Keep Import CSV as the restrained secondary action and Add opportunity as the
  sole gradient primary action.
- On wide layouts, group Search/Stage/Include closed on the leading side and
  Table/Board/actions on the trailing side. Compact layouts may deliberately
  reflow but must not overlap, clip, or hide controls.
- Retain the Table's dense columns, local selection, compact right drawer,
  inspector, and Open details behavior while correcting hierarchy, metadata,
  selected-row treatment, labels, and actions.
- Board lane headers use a materially larger icon/name/count hierarchy.
  Remove the inert **lane-header** ellipsis only; retain per-card actions.
- Board cards have a uniform visual height and controlled truncation/layout;
  preserve card actions, drag/drop, keyboard movement, reduced-motion,
  filtering, Close behavior, and Add/Cancel return context.
- Closed appears solely through the existing Include closed control.

## File boundary

| File | Responsibility |
| --- | --- |
| `RekonPursuit/PipelineView.swift` | Toolbar, Table, inspector, responsive layout. |
| `RekonPursuit/PipelineBoardView.swift` | Lane header and card presentation. |
| `RekonPursuit/RekonVisualTheme.swift` | Pipeline-scoped native visual primitives only when required. |
| Existing Pipeline tests | Preserve/adjust only existing assertions affected by intentional presentation changes. |

No Core/model/store/routing/dashboard/fixture/project or unrelated-screen change is authorized.

## Delivery sequence

1. Record wide and compact Table/Board baseline renders from the deterministic
   `pipeline` fixture and compare them with the controlling references.
2. Apply toolbar/Table parity using the existing Pipeline-native visual seam.
3. Apply Board parity serially, reusing the same scoped primitives and removing
   only the inert lane ellipsis.
4. Run the retained targeted behavior selectors, a Debug macOS build, and
   `git diff --check`; inspect refreshed wide/compact captures against the
   references.
5. Obtain independent code-review, QA, architecture, TPM, and delivery
   approval before dashboard acceptance.

## Required regression evidence

Retain the existing focused selectors for Table fidelity/selection/drawer,
Pipeline controls, Board lane mapping, Board actions and keyboard move, and
Closed-filter locality. Do not introduce a new test framework, fixture,
behavior test suite, schema migration, or accessibility project. Visual
fidelity is demonstrated with the specified Table and Board renders; existing
tests remain the behavior regression safety net.

## Acceptance

1. Opportunities controls match the references and Include closed never clips.
2. Table retains all accepted behavior while its visual hierarchy matches the
   reference.
3. Board retains its exact-stage and interaction contracts; headers are
   readable, lane ellipses are absent, and cards are uniform in size.
4. Wide and compact views remain usable without overlap, clipping, or hidden
   controls.
5. Targeted behavior tests, Debug build, visual inspection, and independent
   gates are green before acceptance.
