# Rekon Pursuit

Rekon Pursuit is a local-first macOS job tracker from RekonLabs. This MVP stores opportunities and a redacted local activity history in an encrypted workspace on your Mac. Active records can be deleted; workspace data otherwise remains on-device until you delete it.

## MVP limitations

This build has no portable backup, restore, purge, Gmail, Calendar, cloud AI, or external research. It can export active opportunities as an explicitly warned, unencrypted CSV, and it records PDF/DOCX document references by filename, size, and SHA-256 hash without copying or processing their contents. Do not rely on this MVP as a recoverable archive.

## Repository map

- `docs/` — approved product, architecture, and delivery artifacts.
- `design/` — brand assets and browser-openable workflow mockups.
- `RekonPursuit/` — native macOS application source (created with the first implementation slice).
- `scripts/` — repeatable build, test, and packaging commands.

See [the implementation handoff](docs/implementation-handoff.md) before starting application work.
