# M3 — Relationship Memory MVP Brief

**Released scope:** Local contact creation, local opportunity/contact links, and concise interaction notes associated with an opportunity. The UI must show linked contacts and interaction summaries on the selected opportunity record.

**Excluded:** CSV import, external people research, Gmail/Calendar, AI, documents, employer research, backup/restore, and export.

## Acceptance

1. Create a contact with name and employer locally; persist one redacted `contact_created` activity event.
2. Link a contact to one or more active opportunities; duplicate links are harmless and a new link persists one redacted `contact_linked` activity event.
3. Record a concise interaction note against an active opportunity; it persists and writes one redacted activity event.
4. Deleted opportunities cannot be linked or receive interactions, and existing linked content is not surfaced from the active record.
5. Activity events contain IDs and event kinds only—never contact names, employers, or interaction text. Run focused store/view-model tests plus the existing macOS UI smoke; commit and push.
