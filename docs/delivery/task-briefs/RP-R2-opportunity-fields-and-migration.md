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
recorded`, and nullable `stage_changed_at`. `work_arrangement` accepts only
the persisted values `Not specified`, `On-site`, `Hybrid`, and `Remote`;
unknown database values fail safely as unreadable data rather than silently
becoming another value. Backfill legacy
`stage_changed_at = created_at`; do not manufacture response-history or
activity rows for legacy data. Record a version-16 checksum in
`migration_history`; failed migration retains the existing verified snapshot
and reports the existing safe-open failure state.

Add `opportunity_response_history(id, opportunity_id, from_state,
to_state, occurred_at)` with index `(opportunity_id, occurred_at DESC, id
DESC)` and query ordering `occurred_at DESC, id DESC`. It records only an
explicit response-state change, never a view/load or migration. The response
state set is fixed for MVP: `No response recorded`, `Awaiting response`,
`Response received`, and `Declined`. Response state never changes pipeline
stage, tasks, or next action. The response effective date is explicitly
provided by the user when changing response state; it is not inferred from
the save time and applies **only** to response-history `occurred_at`.
The corresponding local activity event always uses the actual save/action
`now`, preserving an honest audit timestamp.

`Opportunity` and `CreateOpportunity` gain default-safe properties for these
fields. The create/update store command trims text, preserves absent optional
dates, and commits the record change, stage history when the stage changes,
response history when the response state changes, and corresponding activity
events in one transaction. A form-based stage change writes its user-selected
`stage_changed_at`; a metadata-only edit (including applying then clearing an
application date) preserves it and writes no stage/response history. Use
`opportunity_response_changed` for a response-state change and retain the
existing `opportunity_stage_changed` / `opportunity_updated` meanings. One
save may legitimately emit both distinct material-change events. The existing
one-click quick `changeStage` path has no date prompt, so it must use the
current event time as the identical value for `stage_changed_at`, the
stage-history row, and the stage-change activity event; CSV-created
opportunities use `CreateOpportunity`'s R2
defaults only and do not acquire mapping/update behavior.

The Add form's persisted-response baseline is `No response recorded`. If a
new opportunity is saved with any other response state, show the response
effective-date control and atomically write exactly one transition from that
baseline plus one `opportunity_response_changed` activity event at actual
save time; the normal `opportunity_created` event remains the creation audit.

## UI decisions

In the existing Add opportunity and selected-record forms, present a compact
“Job details” group: Compensation (optional free text), Location (optional),
Work arrangement picker, Applied date toggle/date picker, current response
picker, and a response-effective-date picker whenever the selected response
differs from the persisted response—including a reset to `No response
recorded`. Label that control **Response received date** when `Response
received` is selected and **Response status date** otherwise. Each response
transition uses its selected date for the history/event. Include a **Stage
changed date** picker. Default stage date for a new record is
today; the user can change it before saving. The stage-date control affects
only pipeline stage history; response dates affect only response history. Show the selected record’s
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
   and update every new field, change response state twice with explicit
   response effective dates (including a reset to `No response recorded`, a
   create-from-baseline non-default response, and identical-date IDs/tie
   ordering), and
   change stage with an explicit stage date. Assert exact response-history order,
   stage-history date, actual-now activity timestamps distinct from selected
   response effective dates, expected activity kinds, preserved task behavior, and
   rollback leaves neither field change nor history/event on an injected
   failure. Implement the smallest command/store changes to pass.
3. **View-model and forms.** First add focused view-model tests covering new
   draft defaults, selected-record loading, save, application-date
   save→clear→reopen, and the response-history empty/nonempty states. Assert
   application-date clearing creates only the normal metadata-update activity,
   never a response or stage-history row/event. Add the bindings and fields to the
   existing forms; no new page or shell API. Verify disabled workspace-gate
   behavior still prevents mutation.
4. **Focused acceptance.** Build Debug macOS and run the focused core and
   view-model tests. In the existing isolated temporary app: create a
   synthetic opportunity with all fields; save; edit compensation, response,
   Response received date, reset response to `No response recorded` with its
   selected response-status date, and edit Stage changed date; relaunch;
   confirm values and response history persist;
   confirm Pipeline and Needs Attention still refresh. Record only synthetic
   data and no local paths.

## Acceptance and evidence

- A version-15 workspace opens at schema 16 without loss; legacy records have
  empty optional values, `Not specified`, `No response recorded`, a status
  date equal to creation date, and no invented response rows/events.
- New and edited values persist through store reopen/relaunch. Response
  history is deterministically newest-first by `occurred_at DESC, id DESC`,
  immutable, and local; saving metadata alone creates neither response nor
  stage history.
- Every material response/stage change has an atomic local activity event;
  every response transition, including reset, has its selected effective date;
  existing stage/task/Needs Attention semantics remain unchanged. A form-based
  stage edit uses its selected Stage changed date, while one-click quick stage
  change uses the same current timestamp for current stage, stage history, and
  stage activity.
- Creating with a non-default response writes exactly one history transition
  from `No response recorded`; its history date is the selected response date
  while its response activity event uses actual save time.
- Both forms expose the fields and history with usable empty/default states.
- Evidence is committed under
  `docs/delivery/evidence/remediation/RP-R2/`; include focused command
  results and a redacted isolated manual-smoke record. No coverage target or
  hosted-test expansion is introduced.

## Risks and gates

- SQLite projections currently enumerate opportunity columns in several
  queries; the implementer must update every projection and mapper together.
- “Stage changed date” is the effective date of the current pipeline stage,
  never a response timestamp. The separately explicit Response received date
  is the user-selected effective date for that response-history event. This
  is the smallest reversible interpretation of the approved
  “application/status dates” requirement.
- Fresh Implementer → separate Code Reviewer and QA verifier → Architect
  review → TPM/Delivery acceptance. Security/Privacy review is not required
  unless implementation expands storage scope, entitlements, or data egress.
