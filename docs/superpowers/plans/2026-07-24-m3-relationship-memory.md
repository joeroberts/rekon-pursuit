# M3 — Relationship Memory MVP Brief

**State:** M3-C1, Contacts foundation, is complete. It is not M3 acceptance. M3-C2 owns contact interactions; M3-C3 owns cross-record timelines and the full Workstream-C gate. M4 remains frozen.

## M3-C1 — Contacts foundation

**Outcome:** A user can keep a reusable local contact independently of a job, find it later, and explicitly associate or disassociate it with active opportunities.

**In scope:**

- Forward migration from schema v10 to v11 without data loss, using the existing verified-snapshot recovery pattern.
- A Contacts workspace with empty, validation, success, and workspace-unavailable states.
- Contact CRUD and local search/filter. Name is required; current employer, title, email, profile URL, relationship context, and notes are optional.
- Logical contact deletion, redacted tombstone/audit evidence, and suppression from normal search, discovery, and active links.
- Explicit many-to-many link/unlink to active opportunities. Duplicate link and absent unlink are harmless no-ops.
- A selected opportunity shows active linked contacts and read-only currently-unlinked contacts whose normalized current employer exactly matches its company. Linking is always explicit.
- Redacted activity entries contain only IDs, kind, actor/correlation, and time. Link/unlink events identify both opportunity and contact IDs.

**Excluded from C1:** Interaction capture, last/next-touch derivation, contact/opportunity timelines, external people research, Gmail/Calendar, AI, CSV, documents, employer-history entities, backup/restore, and export.

## C1 acceptance

1. Create an unlinked contact, search/filter it, edit it, and verify persistence across relaunch.
2. Link one contact to two active opportunities, unlink one, relaunch, and verify the other link remains.
3. Verify invalid/deleted contacts and deleted opportunities reject new mutations without a new event.
4. Verify activity/tombstone evidence is redacted and no contact text appears in the timeline.
5. Run focused migration/store/view-model tests and the macOS UI smoke, then commit and push.
