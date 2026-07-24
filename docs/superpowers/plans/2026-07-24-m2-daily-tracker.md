# M2 — Daily Tracker MVP Brief

**State:** Released for completion and fresh independent review; **not accepted**. The latest P1 remediation records queue `Open` actions locally, but it has not passed a new independent Architecture, QA/Test, Security/Privacy, TPM, and Delivery gate. M3 (contacts/interactions) and M4 (CSV import) remain frozen and unreleased until M2 is accepted.

## Required M2 scope — Workstream B

M2 is the complete local-only opportunity workspace, pipeline, and daily loop. It must not be narrowed to the subset already implemented.

- Opportunity create, edit, search, and filter.
- Configurable stages and a pipeline presented in both board and table/list forms.
- A canonical opportunity record containing its stage/status history, next action, task/reminder state, and activity timeline.
- An active opportunity may have one next action with an optional due date. Closed and deleted opportunities never enter the queue.
- A deterministic Needs Attention queue with overdue, due-today, future, no-due-date, and manual-review items; within each bucket, use due date and then a stable task/opportunity ID tie-breaker.
- Queue actions: complete, snooze, reschedule, and open the canonical record. Every one changes only its intended record and appends the required local activity event.
- Local-only persistence, validation/recovery behavior, keyboard/accessibility baseline, and relaunch durability.

Contacts, interactions, CSV import, reconciliation, AI, integrations, portable backup/restore, and export are outside M2. They are assigned to M3, M4, or M5 and must remain unavailable until their own release gate.

## Current implementation evidence and gaps

Existing commits provide candidate evidence for pipeline creation, stage selection, optional-due next actions, deterministic queue ordering, complete/snooze/reschedule/open behavior, deleted/closed suppression, and local activity events. They do **not** prove M2 acceptance.

The fresh M2 gate must inspect the whole required scope above, including the prior P1: opening a queue item must append exactly one local activity event linked to the target opportunity/task. It must also verify that all M3/M4 UI remains unavailable and that the following Workstream-B requirements are either implemented and verified or explicitly remediated before acceptance:

1. opportunity editing plus search/filter;
2. configurable stage treatment and both required pipeline presentations;
3. canonical-record navigation and visible status/activity history;
4. deterministic manual-review bucket ordering and all queue actions, including arbitrary reschedule and open;
5. primary failure, empty, and keyboard/accessibility states.

## Acceptance evidence

1. Seed equal-priority overdue, due-today, upcoming, no-due-date, and manual-review items. Verify the documented order and stable tie-breaker across relaunch.
2. Create and edit an opportunity; search/filter it; change its stage; and verify its canonical record, stage history, and activity timeline persist after relaunch.
3. Complete, snooze, reschedule, and open each applicable queue item. Verify only the intended item changes and every action, including `Open`, appends the required local event.
4. Verify deletion suppresses the record and its queued action without leaking deleted content through normal views/search.
5. Verify M3 contacts/interactions and M4 CSV import are hidden/unreachable while M2 is pending.
6. Run focused local tests plus the macOS UI smoke. Use independent Architecture, QA/Test, Security/Privacy, TPM, and Delivery reviews to decide acceptance; do not self-certify from a passing build or narrow unit test.
