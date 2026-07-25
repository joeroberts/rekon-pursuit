# Rekon Pursuit MVP release handoff

## What works

- Native local macOS tracker: opportunities, fixed pipeline stages, descriptions, notes, tasks, Needs Attention, and local activity.
- Contacts, linked opportunities, interaction history, and follow-up tracking.
- CSV import with preview and duplicate decisions; warned CSV export.
- Manual posting reconciliation with URL, outcome, and evidence; it never changes a stage automatically.
- Manual PDF/DOCX references with filename, size, SHA-256 hash, and final-sent metadata. Files are not copied, parsed, edited, or uploaded.
- Encrypted local workspace, same-Mac encrypted backup and confirmed restore.
- Local Settings, including the persisted closed-opportunity visibility preference.

## Deliberately deferred

No portable/cross-Mac recovery, purge, Gmail, Calendar, AI/local-model execution, AI cost usage, document generation/editing, employer research, interviews, offer comparison, signing, notarization, or DMG distribution.

## Data and recovery

The active workspace remains on this Mac until records are deleted. CSV export is deliberately unencrypted and always warns before export. Same-Mac backups require the current Mac Keychain and restore replaces the current workspace only after confirmation.

## Verification and packaging

Focused local workflow, migration, backup/restore, and build checks passed during the delivered slices. `scripts/m0/build_unsigned_archive.sh` creates an unsigned `.app`; the current package is placed in `a local release directory outside the repository` outside the repository.
