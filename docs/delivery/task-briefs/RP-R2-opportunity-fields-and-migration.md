# RP-R2 — Opportunity fields and safe migration

**State:** Released for implementation  
**Depends on:** `RP-R1b` accepted  
**Blocks:** `RP-R3` and `RP-R5`

## Outcome

Make the canonical local opportunity record usable for the missing core tracker
data: compensation, location/work arrangement, response state with local
history, application date, and pipeline-status-change date. Existing
workspaces must open and retain every current record unchanged.

## Scope and boundaries

- Preserve all accepted R1a workspace/recovery and R1b shell behavior. This is
  a local SQLite migration plus real create/edit/relaunch UI; it creates no
  network request, entitlement, picker, integration, AI execution, or new
  workspace lifecycle behavior.
- Do **not** implement CSV column mapping, update-existing, or import policy
  (`RP-R3`); reconciliation (`RP-R4/R5`); contacts; documents; or a mockup
  redesign. Add fields to the existing Add opportunity form and selected
  opportunity record only.
- Do not infer an application, response, or status date from a URL, stage,
  correspondence, or import. The user supplies each date. Legacy records get
  safe defaults described below.

## Data and migration contract

Advance `WorkspaceMigrations.currentVersion` from 15 to 16 in one verified
transaction/snapshot migration. Add nullable `compensation`, `location`, and
`application_date`; add non-null `work_arrangement` defaulting to
`Not specified`, non-null `response_state` defaulting to `No response
recorded`, and nullable `stage_changed_at`. Backfill legacy
`stage_changed_at = created_at`; do not manufacture response-history or
activity rows for legacy data. Record a version-16 checksum in
`migration_history`; failed migration retains the existing verified snapshot
and reports the existing safe-open failure state.

Add `opportunity_response_history(id, opportunity_id, from_state,
to_state, occurred_at)` with an opportunity/time index. It records only an
explicit response-state change, never a view/load or migration. The response
state set is fixed for MVP: `No response recorded`, `Awaiting response`,
`Response received`, and `Declined`. Response state never changes pipeline
stage, tasks, or next action.

`Opportunity` and `CreateOpportunity` gain default-safe properties for these
fields. The create/update store command trims text, preserves absent optional
dates, and commits the record change, stage history when the stage changes,
response history when the response state changes, and corresponding activity
events in one transaction. A stage change writes its user-selected
`stage_changed_at`; a metadata-only edit preserves it. Use
`opportunity_response_changed` for a response-state change and retain the
existing `opportunity_stage_changed` / `opportunity_updated` meanings. One
save may legitimately emit both distinct material-change events.

## UI decisions

In the existing Add opportunity and selected-record forms, present a compact
“Job details” group: Compensation (optional free text), Location (optional),
Work arrangement picker, Applied date toggle/date picker, current response
picker, and Status changed date picker. Default status date for a new record
is today; the user can change it before saving. Show the selected record’s
response history, newest first, with state and date; its empty state says no
response has been recorded. Keep stage and next-action controls where they
are. The data is local-only and uses plain-language labels, not color alone.

## Test-first implementation tasks

1. **Migration/model/store contract.** First add failing core tests for a
   version-15 database migrating to 16 (legacy fields retained, nullable
   fields empty, status date equals legacy creation date, no fabricated
   history/activity), and for a failed version-16 migration retaining its
   snapshot. Then add the model, migration, row mapping, and all query-column
   updates. Test fresh creation, relaunch/readback, and the existing
   contact-opportunity query so no projection drops fields.
2. **Atomic editing and history.** First add failing store tests that create
   and update every new field, change response state twice, and change stage
   with an explicit status date. Assert exact response-history order,
   stage-history date, expected activity kinds, preserved task behavior, and
   rollback leaves neither field change nor history/event on an injected
   failure. Implement the smallest command/store changes to pass.
3. **View-model and forms.** First add focused view-model tests covering new
   draft defaults, selected-record loading, save, refresh/relaunch, and the
   response-history empty/nonempty states. Add the bindings and fields to the
   existing forms; no new page or shell API. Verify disabled workspace-gate
   behavior still prevents mutation.
4. **Focused acceptance.** Build Debug macOS and run the focused core and
   view-model tests. In the existing isolated temporary app: create a
   synthetic opportunity with all fields; save; edit compensation, response,
   and status date; relaunch; confirm values and response history persist;
   confirm Pipeline and Needs Attention still refresh. Record only synthetic
   data and no local paths.

## Acceptance and evidence

- A version-15 workspace opens at schema 16 without loss; legacy records have
  empty optional values, `Not specified`, `No response recorded`, a status
  date equal to creation date, and no invented response rows/events.
- New and edited values persist through store reopen/relaunch. Response
  history is chronological, immutable, and local; saving metadata alone
  creates neither response nor stage history.
- Every material response/stage change has an atomic local activity event;
  existing stage/task/Needs Attention semantics remain unchanged.
- Both forms expose the fields and history with usable empty/default states.
- Evidence is committed under
  `docs/delivery/evidence/remediation/RP-R2/`; include focused command
  results and a redacted isolated manual-smoke record. No coverage target or
  hosted-test expansion is introduced.

## Risks and gates

- SQLite projections currently enumerate opportunity columns in several
  queries; the implementer must update every projection and mapper together.
- “Status change date” is recorded as the effective date of the current
  pipeline stage, not an invented response timestamp. This is the smallest
  reversible interpretation of the approved “application/status dates”
  requirement; response changes carry their own user-selected history date.
- Fresh Implementer → separate Code Reviewer and QA verifier → Architect
  review → TPM/Delivery acceptance. Security/Privacy review is not required
  unless implementation expands storage scope, entitlements, or data egress.
