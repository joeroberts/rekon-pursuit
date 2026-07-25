# M3 — Relationship Memory MVP Brief

**State:** M3-C1, Contacts foundation, and M3-C2, local contact interactions, are complete. It is not M3 acceptance. M3-C3 owns cross-record timelines and the full Workstream-C gate. M4 remains frozen.

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

## M3-C2 — Local contact interactions

**Outcome:** A user can log a local interaction with a reusable contact and use its last/next-touch information without any connected service.

**In scope:**

- Forward migration from schema v11 to v12. Existing legacy opportunity-only interaction rows remain readable; no historical row is discarded or rewritten with invented contact data.
- New interactions require an active contact; their opportunity reference is optional and can only be an opportunity already explicitly linked to that contact.
- A contact interaction has a fixed local type (`Call`, `Email`, `Meeting`, or `Note`), required summary, occurred-at time, and optional next-touch time.
- The selected contact shows a local interaction history and derived last-touch/next-touch values. New interaction creation is atomic with a redacted `interaction_recorded` activity event linked to the contact and optional opportunity.
- Invalid, deleted, or unlinked records reject new interaction mutations without writing a row or activity event. Deleted contacts suppress their interaction history from active views while retained rows preserve recovery/audit integrity.

**Excluded from C2:** Editing/deleting interactions, cross-record opportunity timelines, provider-synchronized correspondence/calendar events, follow-up-task automation, AI, CSV, documents, external research, backup/restore, and export.

## C2 acceptance

1. Migrate a v11 fixture containing legacy interactions without losing its rows, then create and relaunch a new contact interaction.
2. Log a contact-only interaction and one linked to an already-linked active opportunity; verify type, summary, time, optional next touch, and exactly one associated redacted activity event.
3. Verify a contact cannot attach an interaction to an unrelated, deleted, or missing opportunity and that rejected attempts leave no interaction or activity row.
4. Verify the Contacts workspace displays interaction history plus derived last/next touch after relaunch and provides a clear empty/validation/workspace-unavailable state.
5. Run focused migration/store/view-model/UI checks, then commit and push. C3 remains unreleased.
