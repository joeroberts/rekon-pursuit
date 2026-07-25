# RP-R3 — CSV mapping and decision-safe import

**State:** Proposed — not released  
**Depends on:** `RP-R2` accepted  
**Blocks:** No task is released by this brief.

## Outcome

Turn the existing narrow CSV preview into a local, user-controlled import
flow: **map columns → validate rows → decide each duplicate → import → review
report**. A user can import a normal job-search spreadsheet without renaming
its headers, while no existing opportunity is changed unless the user both
chooses **Update selected fields** and selects the exact fields to replace.

## Scope and boundaries

- Preserve the accepted workspace gate, native file picker, R1b shell, and R2
  opportunity fields/history semantics. The selected file remains local; the
  import performs no network request, AI action, Gmail/Calendar action, or
  external upload.
- Replace the literal `title`/`company` header requirement with a mapping step.
  The app reads a UTF-8 CSV selected through the existing picker and does not
  retain the source path, a security-scoped bookmark, or raw CSV content after
  preview/import. The completed report retains redacted results and a source
  basename only. Resumable in-progress batches are explicitly deferred to
  `RP-R3a`.
- This task owns CSV mapping, deterministic validation, local duplicate
  comparison, per-row terminal decisions, an atomic commit, and a durable
  readable report. It does not add contact import, reconciliation, document
  handling, lifecycle/export changes, batch undo, or a general spreadsheet
  editor.
- Existing R2 fields must not be silently defaulted over an existing record.
  A blank CSV cell means “not mapped/no value” for an update; it is never an
  instruction to clear a stored field in this MVP.

## Field map and validation contract

The map screen lists every header from the selected file and lets the user map
at most one source column to each canonical field. The two required canonical
fields are **Job title** (`title`) and **Company** (`company`); both must be
mapped before validation can continue. Optional mappings are:

| Canonical field | Suggested header aliases | CSV value contract |
| --- | --- | --- |
| Job URL | `url`, `job url`, `posting url`, `link` | Trimmed http/https URL or blank; invalid nonblank value is a row error. |
| Job description | `description`, `job description` | Text or blank. |
| Notes | `notes`, `note` | Text or blank. |
| Compensation | `compensation`, `salary`, `pay` | Text or blank. |
| Location | `location`, `city`, `location/city` | Text or blank. |
| Work arrangement | `work arrangement`, `work mode`, `remote/hybrid` | Exact R2 values: `Not specified`, `On-site`, `Hybrid`, or `Remote`; blank means the R2 default for a new record and no update value. |
| Pipeline stage | `stage`, `status`, `pipeline stage` | Exact persisted `PipelineStage` value; blank means the R2 default for a new record and no update value. |
| Next action | `next action`, `follow up`, `follow-up` | Text or blank. |
| Due date | `due date`, `next action date`, `follow up date` | ISO calendar date `YYYY-MM-DD`, or blank. It is valid only with a mapped, nonblank Next action; convert to the app's deterministic local start-of-day convention. |
| Applied date | `applied date`, `application date`, `date applied` | ISO calendar date `YYYY-MM-DD`, or blank. |
| Response state | `response`, `response status` | Exact R2 `ResponseState` value; blank means the R2 default for a new record and no update value. |
| Response status date | `response date`, `response received date`, `response status date` | ISO calendar date required when a non-default response state is supplied; otherwise blank. |
| Stage changed date | `stage date`, `status date`, `stage changed date` | ISO calendar date or blank; new records use import command time when no value is supplied. |

Suggested aliases may preselect a mapping but never alter it without the
user's confirmation. A source column can be mapped only once; duplicate or
missing required mappings block the next step with plain-language recovery
copy. Parse quoted commas and escaped quotes; report malformed CSV syntax as
a file/row error rather than guessing. Preserve source row number for every
result. Do not interpret formulas, hyperlinks, or arbitrary text as commands.

Validation is deterministic and offline. A row is invalid when title or
company is blank after trimming, an assigned enum/date/URL value is invalid,
a due date has no nonblank next action, or a non-default response lacks its
response-status date. Invalid rows remain
visible with their source row number and reasons, cannot receive a decision,
and are counted in the final report. Valid rows carry only the fields actually
mapped and nonblank; no locale-dependent date parsing is permitted.

## Duplicate and update contract

After validation, derive advisory local candidates using this ordered,
explainable rule set: exact canonicalized job URL; otherwise normalized
title + company; otherwise no candidate. Matching never merges records. Show
the candidate's title/company and the match rationale. A valid noncandidate
row has the terminal decision **Create new opportunity**. Every candidate row
requires exactly one terminal decision:

1. **Update selected fields** — display a field-by-field before → CSV value
   comparison for only mapped, nonblank importable fields. The user selects
   one or more fields. Title and company identify the candidate and cannot be
   overwritten in this MVP. No selected field means no executable update.
2. **Keep separate** — creates a distinct opportunity with the validated
   imported values.
3. **Skip** — performs no opportunity mutation.

The architecture term **Create** is the noncandidate decision and is rendered
as **Create new opportunity**. A candidate may instead use **Keep separate**;
both create a distinct record but preserve different duplicate rationale.

Changing mapping or leaving the decision page invalidates all existing
decisions and requires review again. The import button stays disabled until
every valid row has a terminal decision and every update has selected fields.
The UI must state that imported values change local data only after the final
Import action.

## Persistence, activity, and report contract

Persist the completed report/rows and its mapping/decisions so it survives
relaunch. Commit all eligible creates, selected-field updates, skips, row
outcomes, and report summary in one SQLite transaction; an error commits none
of that batch and leaves both the existing workspace and earlier reports
unchanged. Use the R2 command clock once for the complete import command.

For a create, use the same R2-safe creation semantics: stage history is
written using the mapped stage date or import command time; a mapped
non-default response writes one response transition using its explicit date.
For an update, change only the user-selected fields. A selected stage change
uses the mapped stage date, or the import command time when absent; a selected
response-state change requires and uses the mapped response-status date.
Other mapped R2 dates and metadata are updated only when selected. Next action
and due date are a coupled task-reminder pair: a due date cannot be imported
without a nonblank next action; when selected on update, the pair atomically
creates, updates, or removes the corresponding task according to the existing
R2 task semantics. Existing task, stage/response history, and activity
behavior must remain consistent with R2; no stage/response history is created
when that value was not selected or did not change.

Write one redacted activity event per materially created, updated, kept-
separate, or skipped row plus a batch summary/event. Activity contains IDs,
event kind, source row number, mapping/decision outcome, and time—not raw CSV
cell contents. The report displays source filename (basename only), completion
time, mapping summary, created, updated, kept-separate, skipped, invalid, and
failed counts, per-row outcome/reason, duplicate rationale, and the linked
local opportunity for rows that created or updated one. The report must be
usable after relaunch without reopening the source file. Bounded Undo Import
is explicitly deferred to `RP-R3a`.

## Implementation tasks

1. **Import domain and durable schema.** Add focused failing core tests for
   standard `title`/`company` and nonstandard-header maps, source-row
   preservation, quoted cells, and
   precise invalid-row reasons. Define the mapping, validated-row, candidate,
   decision, selected-field, and report types in the import domain. Migrate
   the local database for durable batch/row/decision/report state without
   changing existing R2 opportunity values. Keep migration failure behavior
   aligned with the existing safe-open/snapshot contract.
2. **Mapping and validation.** Implement deterministic header discovery,
   user-controlled mapping, alias suggestion, UTF-8 CSV parsing, and the
   field contracts above. Add focused tests for required title/company maps;
   duplicate source-column selection; invalid URL/enum/ISO date; blank
   required values; a due date without next action; and a non-default response
   without a response-status date.
   Do not add a broad parser test matrix or a new dependency.
3. **Candidate review and atomic command.** Add focused store tests proving
   that a candidate cannot commit without a terminal decision, an update
   cannot commit without explicitly selected fields, a reimport cannot
   overwrite fields by default, task reminders remain coupled to selected
   Next action/due-date changes, and an injected mixed-batch failure leaves no
   create/update/report/activity residue while a seeded earlier completed
   report and opportunity survive reopen unchanged. Implement candidate rationale,
   row decisions, selected-field updates, R2 stage/response date semantics,
   per-row redacted activity, and durable report persistence in the smallest
   transaction boundary.
4. **Local wizard and report.** Replace the current import panel with the
   four visible steps: Map, Validate, Review duplicates, and Report. Use the
   existing file picker and workspace gate. Add focused view-model tests for
   map edits resetting decisions, disabled import until complete review, an
   explicit selected-field update and report reload after reopening the
   workspace. Verify manually with a synthetic CSV having standard and
   nonstandard headers, one invalid row, one duplicate update, one
   keep-separate row, and one new row.

## Acceptance and evidence

- A user can map both a normal `title`/`company` CSV and one whose headers are
  not literal matches, validate rows, review each duplicate, complete the
  import, and reopen the durable report entirely locally.
- Title/company and the R2 core fields listed in the map table import with
  their stated validation/default semantics. Invalid values never create or
  mutate an opportunity.
- A duplicate has no default merge path. An existing opportunity changes only
  through **Update selected fields** with at least one explicitly selected
  field; unrelated values, blank cells, title, and company remain unchanged.
- A transaction failure leaves both prior opportunity data and prior import
  reports intact. A successful batch has per-row redacted audit evidence and
  a clear report for creates, updates, keeps, skips, and invalid rows.
- Record only focused build/test results plus a redacted isolated manual smoke
  under `docs/delivery/evidence/remediation/RP-R3/`. No hosted CI, coverage
  target, integration, or Phase 2 capability is introduced.

## Risks and gate

- This task touches the R2 opportunity schema and activity semantics; its
  implementer must preserve R2's explicit stage/response-date and atomicity
  rules rather than using the old `CreateOpportunity` shortcut blindly.
- Exact field-update behavior is the material data-loss risk. Code Reviewer,
  QA, Architect, TPM, and Delivery Manager must approve the brief before
  release, with QA/Code Review/Architect rechecking the completed slice.
- `RP-R3` remains proposed until the R2 acceptance record is completed. This
  brief does not release itself or any downstream remediation task.
- Product owner decision, 2026-07-25: ship the core CSV workflow before
  resumable raw-file drafts or executable Undo Import. Those recovery/history
  behaviors are a separately planned `RP-R3a`, not R3 acceptance work.
