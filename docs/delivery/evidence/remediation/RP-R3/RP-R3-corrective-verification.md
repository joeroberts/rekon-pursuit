# RP-R3 corrective-pass verification

Date: 2026-07-25

Corrective pass adds deterministic local-Gregorian date parsing, strict duplicate/selected-field decision validation, coupled task/stage/response selection guards, per-row and batch redacted activity, and reopenable completed-report mapping and row details.

Focused verification passed:

- Debug build with `xcodebuild`.
- `testVersionSixteenToSeventeenMigrationAndFailureKeepSnapshot`: real v16 schema migrates to v17; injected v17 failure leaves the v16 schema/data and verified snapshot.
- `testMixedImportFailureLeavesPriorReportAndOpportunityAfterReopen`: injected import failure rolls back the new batch; a prior opportunity and completed report survive close/reopen unchanged.
- CSV selected-field decision tests remain green.
- Blank mapped cells are rejected at both UI selection and store-command boundaries; they cannot clear an existing field or task due date.
- The final R3 audit contains exactly one redacted source-row/outcome event for each material row plus one batch-completed event.
- Exact canonicalized job URL deterministically takes precedence over title/company matching; ties use ascending local opportunity ID.

Deferred scope remains RP-R3a only: raw-file drafts and Undo Import.
