# M4 — Local CSV Import MVP Brief

**State:** Frozen and unreleased. This candidate M4 scope may be released only after M2 and M3 are accepted and the TPM/Delivery Manager records an explicit M4 release decision.

**Candidate scope when released:** Choose a local UTF-8 CSV, preview rows using required `title` and `company` columns, report invalid rows, and import valid opportunities into the encrypted local workspace.

**Rules:** Existing title/company matches are visible duplicate candidates. Before import, the user explicitly selects **Skip** or **Keep separate** for each candidate; no candidate is silently skipped, merged, or overwritten. A durable local import report shows imported, skipped, duplicate-kept, and invalid row counts after import. Each import decision appends a redacted activity event containing only the decision kind and identifiers—never CSV content. The import is local-only; no file content, job data, or telemetry leaves the Mac. Invalid/missing-required-column input makes no changes.

**Excluded:** Column mapping, updates/overwrites, batch undo, employer research, Gmail/Calendar, AI, documents, recovery/restore, and export.

## Acceptance

1. Selecting a valid CSV presents the valid/invalid-row preview before any writes.
2. Duplicate candidates require an explicit row-level choice; import creates only the rows permitted by those choices through the existing command layer, persists the resulting report, and appends its redacted audit events atomically.
3. Invalid input or cancellation leaves the workspace unchanged.
4. Run focused importer/view-model tests and the macOS UI smoke; commit and push.
