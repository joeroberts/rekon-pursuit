# Home and Pipeline information architecture

## Decision

Home is the default launch destination. Its first section is **Needs
Attention**: due actions, a clear empty state when none exist, and a direct
path to the affected opportunity. It replaces Needs Attention as a top-level
sidebar destination.

Pipeline is the home for opportunity-management work. The sidebar retains
Home, Pipeline, Contacts, Activity & AI, and Settings. It does not contain
standalone Add Opportunity or Import CSV destinations. Pipeline exposes a
primary **Add opportunity** action and a secondary **Import CSV** action.

## UX-R1 amendment

- Apply the Rekon token layer consistently to navigation selection, primary
  actions, secondary actions, fields, borders, and empty states. Gray legacy
  controls must not masquerade as headings or primary actions.
- Make Home and Pipeline empty states responsive and centered within their
  available content regions, not at fixed screen coordinates.
- Preserve direct routes for the internal Add and Import flows so Back and
  Cancel remain predictable; this is a navigation simplification, not a
  removal of those workflows.

## UX-R2 requirements

- Add Opportunity is a Pipeline-owned flow with a clear title hierarchy,
  multiline expandable Job Description, and a responsive empty state/action.
- An omitted applied date is stored as the creation date. A user-selected date
  remains explicit and is never overwritten by a later edit.
- CSV is a Pipeline-owned, staged flow: choose, map, validate, review/decide,
  completion. Its actions have clear primary/secondary hierarchy; users can
  cancel, go back, start another import, or finish. Completion shows totals,
  exception rows by title/company, and View imported opportunities—not routine
  row-number success buttons.
- Contacts label free text as **How you know them**, with examples. It is not
  a dropdown. That field and Notes expand on demand.

## Deferred

Parsing a job posting URL into job details is a future, user-invoked connected
workflow. It is not part of UX-R1 or UX-R2 and must not silently fetch or
overwrite fields.
