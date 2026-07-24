# M2 — Daily Tracker MVP Brief

**Released scope:** Local-only opportunity pipeline, next actions, and the Needs Attention queue. Contacts, CSV, interactions, all integrations, AI, backup/restore, and export remain out of scope.

## MVP semantics

- Stages: `Saved`, `Applied`, `Screening`, `Interviewing`, `Offer`, `Closed`.
- An active opportunity may have one next action and optional due date. Closed and deleted opportunities never enter the queue.
- Queue order: overdue; due today; future due date; no due date. Within a bucket, sort due date then stable opportunity/task ID.
- Complete marks only that action complete and records one activity event. Snooze moves only that action one day and records one activity event. A stage update records one activity event.

## Acceptance

1. Add an opportunity with stage and next action; it persists after relaunch.
2. The queue follows the declared order with deterministic fixture data.
3. Complete, snooze, and stage changes affect only their intended record and append one event each.
4. M1 deletion continues to remove the record and its queued action.
5. Run focused local store/view-model tests and the existing macOS UI smoke; commit and push the slice.
