# RP-R4 — Local reconciliation contract and workflow states

**State:** Released for implementation  
**Depends on:** `RP-R3` accepted  
**Blocks:** `RP-R5`

## Outcome

Replace the opportunity record’s unstructured manual posting note with a
durable, local-only reconciliation workflow. A user can record what they
reviewed, see what requires follow-up, and explicitly close an opportunity
only after reviewing the captured evidence.

## Scope

- Persist a structured local reconciliation result: URL snapshot, timestamp,
  outcome, classification, reason, confidence, evidence/error, linked review
  task, and closure state.
- Retain legacy `posting_checks` history through a lossless v19 migration.
- Provide local recording, chronological history, a deduplicated review task,
  an explicit closure-confirmation sheet, and activity evidence.
- A manual `Closed suggested` result is permitted but never changes stage.
  Only explicit confirmation changes stage to `Closed`; it atomically completes
  the linked reconciliation task and records stage/activity history.

## Hard boundaries

- **No network work:** no URLSession, provider adapter, URL reachability,
  HTTP request, transport entitlement, scheduled checking, or automatic check.
  `RP-R5` owns the direct public-URL request.
- No AI, contacts, documents, export/lifecycle, or general UI redesign.
- No automatic closure. A blocked page, changed URL, inaccessible source,
  failure, or offline state is manual review, never closure evidence.

## Local contract

Every new result has an absolute `http` or `https` URL with a host and one
allowed tuple. Reject malformed URLs, `file:`, `javascript:`, custom schemes,
credential-bearing URLs, `localhost`, and literal loopback, link-local, or
private-network IP hosts. Preserve the valid user-saved URL as entered; do not
silently strip query data or normalize it into a different URL. R5 additionally
owns DNS and redirect-target validation before any request.

| Outcome | Classification | Required detail | Review task |
| --- | --- | --- | --- |
| `Still open` | `Confirmed` | evidence; high, medium, or low confidence | none |
| `Possibly closed` | `Ambiguous` | evidence; low or medium confidence | create/reuse |
| `Closed suggested` | `Confirmed` or `Ambiguous` | evidence; confidence | create/reuse until explicit confirmation |
| `Needs manual review` | `Ambiguous`, `Failed`, or `Offline unchecked` | evidence or error; confidence may be not recorded | create/reuse |

Reasons are `manual review`, `changed URL`, `access blocked`, `source failed`,
`offline — check not run`, or `other`. `Offline unchecked` is a truthful local
record: it makes no request and preserves all earlier results.

One active reconciliation-review task is deduplicated per active opportunity.
Each material result, task creation/reuse, and closure confirmation is atomic
with its redacted local activity event. Invalid tuple, missing required detail,
invalid URL, inactive opportunity, or injected persistence failure writes
nothing.

The v19 migration adds `reconciliation_reviews`, keyed one-to-one to an active
opportunity and holding its dedicated `task_reminders.id`, plus
`reconciliation_results` for immutable result history. A unique
`opportunity_id` constraint prevents it from ever selecting or completing the
ordinary next-action reminder. Every migrated result retains its
`legacy_posting_check_id` and `legacy_status` alongside the original URL,
evidence, and timestamp. Legacy `Still open`, `Possibly closed`, and `Needs
manual review` map to the matching local outcome. Legacy `Closed` becomes
`Closed suggested` with `closure_confirmed_at = NULL`, while its original
`legacy_status = Closed` remains readable, so historic manual notes are never
misrepresented as confirmed closure or altered without provenance.
Migration history records the v19 checksum; foreign keys and a review-task
index are required. An injected migration failure must retain the v18 schema,
rows, and verified snapshot.

## UX

The opportunity record states plainly that no online check runs in R4. It
offers **Record local review**, **Record offline — check not run**, **Open
review action**, and **Confirm closure…**. The confirmation view shows the
captured URL, evidence, time, and a Keep active alternative. History shows
plain-language outcome, classification/reason, confidence, timestamp,
evidence/error, task state, and closure state.

The existing `Link` may open the user-saved posting in the system browser for
manual review. It is not an in-app request and must not create or update a
reconciliation result.

## Focused verification

- A v18 fixture with legacy posting rows migrates losslessly, including every
  legacy ID and status; an injected v19 migration failure retains the v18
  state and verified snapshot.
- Valid and invalid taxonomy tuples prove no partial write on rejection.
- Repeated manual-review/offline results reuse one review task.
- A closure suggestion does not change stage; cancel/Keep active does not
  change stage; only explicit confirmation closes and completes the linked
  task atomically.
- An injected failure leaves no result, task, activity, or stage residue.
- A scoped source/entitlement check proves R4 adds no `URLSession`,
  `URLRequest`, `NWConnection`, or `Network` transport path and no
  network-client entitlement.
- A Debug macOS build and isolated smoke prove record → Needs Attention →
  open → cancel/confirm → relaunch history. No network is exercised.

## Gate

Planning, Architect, Security/Privacy, TPM, QA, and Delivery Manager must
approve this local-only boundary before implementation. Dashboard state moves
to In progress only when Delivery releases the task.
