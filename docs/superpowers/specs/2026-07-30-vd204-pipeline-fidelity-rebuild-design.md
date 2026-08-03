# VD2-04 Pipeline fidelity rebuild

## Decision

The supplied Pipeline mockups are the structural visual baseline, not merely a
color reference. VD2-04 remains open until its Table and Board are recognizably
the same information-dense workspace at desktop size.

This rebuild retains the existing data model and stage values. It changes only
presentation, hierarchy, and responsive layout; it does not add Board
drag/drop, alter opportunity stages, mutate persistence, or change routes.

## Board presentation mapping

The Board has four primary visual lanes at normal desktop width:

| Visual lane | Underlying stages | Card treatment |
| --- | --- | --- |
| Saved | `Saved` | Saved chip and saved visual accent. |
| Applied | `Applied`, `Screening` | Cards retain their precise stage chip so Screening is never lost. |
| Interviewing | `Interviewing` | Interview stage and next-action hierarchy. |
| Offer | `Offer` | Offer stage and next-action hierarchy. |

`Closed` is absent while the existing Include closed filter is off. When it is
on, Closed becomes a fifth, visually secondary lane rather than changing the
four primary lanes. The mapping is presentation-only and remains reversible.

## Table

Replace the current vertically stacked `List` summaries with a dense table
surface. At desktop widths it shows Role, Employer, Stage, Next action, and
Due date as aligned columns, with employer mark, location/work arrangement,
stage chip, selected-row cyan/violet treatment, and a result-count footer.

At narrower widths the table can collapse metadata deliberately, but it must
not revert to an unstructured tall-card list. The approved compact right drawer
remains the details presentation.

## Inspector and toolbar

The inspector gains the mockup hierarchy: close affordance when compact,
employer mark/identity, title, company/location, stage chip, structured
facts, and a secondary outlined `Open details` action. It must not become a
modal or alter the canonical details route.

Toolbar controls use the existing navy/cyan native-control seam but regain the
mockup's spacing, search/stage/view icons, and clear primary/secondary action
hierarchy. `Add opportunity` remains the sole gradient primary action.

## Board

Each lane has an icon, name, count, optional lane menu affordance, compact
rich cards, and an `Add opportunity` affordance. Cards show employer identity,
precise stage chip, location/work arrangement, next action, due date, and any
existing owner/avatar data. Empty lanes remain intentionally designed rather
than becoming oversized blank columns.

The visual language may include mockup-style drop placeholders as inert visual
states only; no drag/drop behavior is introduced in VD2-04.

## Constraints and verification

- Preserve all existing IDs, native accessibility roles, keyboard behavior,
  right drawer, no-radio row selection, one sidebar control, Import route, and
  existing data/store behavior.
- Do not introduce literal gray chrome or reapply styles outside Pipeline.
- Add red-first layout/semantic contracts, then independently verify signed
  Desktop Table and Board captures against the supplied mockups at normal and
  compact sizes.
- Acceptance rejects: stacked card-list Table, narrow empty six-lane Board,
  missing table columns/inspector hierarchy, wrapped View label, row radio,
  below-list details, duplicate sidebar control, or changed Board workflow.
