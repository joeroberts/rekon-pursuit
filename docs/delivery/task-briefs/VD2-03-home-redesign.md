# VD2-03 — Home redesign

## Outcome

Deliver the Home screen in the approved Visual Design v2 hierarchy using live
workspace data only.

## Contract

- Needs Attention is first and uses incomplete task reminders from the active
  workspace.
- Snapshot metrics are derived at read time: non-closed opportunities, applied
  opportunities in the local calendar week, and interviewing opportunities.
- Upcoming actions are incomplete reminders not already shown in the first
  three attention cards.
- Open, snooze, reschedule, and complete use the existing persistent task
  commands and retain their activity evidence.
- Empty states must remain truthful and offer only the existing add-opportunity
  route.

## Verification

- Unit coverage for the read-only dashboard projection and calendar-week
  boundaries.
- Focused unit and UI tests for Home routing and task actions.
- Independent review and QA before product-owner hands-on verification.

## Gate evidence

- Independent code review found no material issues in the closure-protected
  reconciliation route or Home action treatment.
- Independent QA passed the focused Home projection/calendar-boundary and
  reconciliation-fixture checks. The scoped `xcodebuild` run and
  `git diff --check` passed; only pre-existing Swift actor-isolation warnings
  were observed in test fixtures.
- The broad UI suite was intentionally not run. Product-owner hands-on
  verification remains the acceptance gate: confirm live Needs Attention,
  truthful snapshot/upcoming data, and the normal task actions; a
  reconciliation item must open Reconcile posting and must not expose direct
  completion.
