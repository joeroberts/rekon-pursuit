# RP-R10 — Clean-state remediation acceptance

**State:** Accepted — final clean-state owner acceptance completed. No new feature or package release is authorized.
**Depends on:** Accepted `RP-R1a` through `RP-R9`, `UX-R1`, `UX-R2`, and `RP-R7b-2`. Post-remediation UX/design work remains out of scope.
**Blocks:** None. Acceptance confirms the complete remediation candidate; it does not release a Phase 2 capability, signing, notarization, DMG distribution, or the visual-design v2 work.

## Purpose

Establish whether the current candidate is a usable, local-first MVP when
started from a clean, disposable local workspace. This is a reconciliation and
hands-on acceptance task, not a feature, polish, recovery-mechanics, or test
coverage task.

The controlling delivery record already contains accepted evidence for each
preceding remediation slice. R10 adds one fresh, end-to-end owner workflow and
reconciles the candidate package facts to that evidence. It must not silently
turn prior acceptance into a new requirement or reopen deferred work.

## Bounded owner acceptance flow

Run the signed Debug candidate in an isolated, disposable workspace namespace
or through the already-shipped **Create separate local workspace** route. Do
not select, move, overwrite, reset, repair, or otherwise modify the product
owner's preserved workspace.

1. **Start clean and persist the core record.** Create a separate local
   workspace, create an opportunity with a next action, edit it, quit and
   relaunch, and confirm the same local record, stage, and action remain.
2. **Operate the daily loop.** Use Home/Needs Attention to open, complete or
   reschedule the action; confirm Pipeline reflects the resulting record and
   activity. Open the record, return to Pipeline, and confirm the app remains
   responsive.
3. **Bulk capture without silent overwrite.** Import a small disposable UTF-8
   CSV with title and company fields, map/validate it, explicitly resolve any
   presented duplicate, complete the import, and open one resulting
   opportunity from the concise report.
4. **Exercise the relationship and evidence surfaces.** Create a contact
   associated with a tracked employer, save it, attach one disposable PDF or
   DOCX reference to an opportunity, and open the reference once. The source
   file stays in place. This step proves the accepted local reference path; it
   does not require moving a file or performing relink again.
5. **Exercise conservative reconciliation.** On an opportunity with a valid
   public URL, record a local review outcome. If the owner chooses a closed
   outcome, explicitly confirm closure; otherwise leave it active. No
   automatic stage change is acceptable.
6. **Check truthful status and lifecycle boundaries.** In Activity & AI,
   verify a multi-word activity search returns matching local events and the
   AI ledger remains empty/read-only. In Settings, verify lifecycle summaries
   and existing recovery/archive/export/restore entry points are visible,
   without invoking a destructive restore, retained-data purge, or background
   expiry claim.

## Candidate-package reconciliation

Record only these reproducible facts:

- the exact commit under review and macOS/Xcode build command outcome;
- the signed Debug app identity, build configuration, and owner-observed open
  outcome. Its absolute local path may be shown directly to the owner for
  testing, but is not copied into repository evidence;
- whether the existing local archive/build artifact was produced by the
  repository's current build/archive workflow, recorded in the repository by
  artifact basename and date only; and
- known release boundary: Developer ID signing, notarization, and DMG
  distribution are explicitly not represented as complete.

R10 must not add CI, hosted test suites, coverage gates, a release installer,
or a new packaging workflow. If the current archive workflow cannot be run,
record that fact as a candidate-package limitation; do not block the usable
local Debug-app acceptance on it unless the existing candidate cannot build or
open.

## Required evidence and focused checks

- Build the existing macOS Debug target and open the resulting app.
- Run only the focused existing regression checks covering the primary
  workflow and high-risk lifecycle boundaries touched by R10 evidence. Do not
  create a new test harness or expand coverage.
- Capture a concise redacted acceptance record: pass/fail for the six owner
  steps above, package facts, exact commands/results, any issue, and the
  product-owner decision. Do not copy local record contents, paths, recovery
  keys, document contents, or export material into the repository.
- Regenerate the delivery dashboard together with the ledger only at the real
  R10 state transition.

## Stop conditions

Stop R10 and open one bounded corrective task if any of the following occurs:

- the app cannot build, launch, or remain responsive in the clean workspace;
- a core create/edit/relaunch, daily-action, CSV decision, contact save,
  document-reference, or reconciliation action loses or mutates data outside
  the user-selected action;
- a local-first boundary is violated by unexpected network/AI execution,
  private workspace overwrite, or unconfirmed destructive data change; or
- the owner rejects the candidate based on a material workflow defect.

Do not fix defects inside R10 merely to make its checklist pass. Record the
smallest corrective slice, return the dashboard to the appropriate actionable
state, and re-run only the affected R10 evidence after that slice is accepted.
Ordinary deferred polish, visual-design v2, Logs/AI tab refinement, advanced
log searching, and Phase 2 work are not R10 failures. Retained-data
purge/rebuild is not deferred: it must be accepted before R10 can begin.

## Acceptance criteria

- The six bounded owner checks pass in a clean, disposable local workspace,
  with data surviving relaunch where required.
- The current candidate builds and opens as the recorded signed Debug app.
- The delivery ledger, dashboard, task brief, and candidate-package record
  agree about what is accepted, deferred, and not shipped.
- No P0/P1 workflow, local-data, privacy, or irreversible-action defect is
  open; any lower-priority deferred work is explicitly recorded outside the
  candidate-acceptance claim.
- The product owner explicitly accepts the usable local-first MVP candidate.

## Required final gate

Planning, Architect, TPM, QA, Delivery Manager, and Security/Privacy each
review this exact acceptance boundary before R10 moves to **In progress**.
After the owner smoke, a fresh QA verifier and code/package reviewer confirm
the evidence before Delivery Manager records the final decision. Their review
is limited to whether the evidence supports the claim; it must not introduce
new feature scope.

## Final acceptance record

- **Product owner:** Accepted the completed clean-state candidate, including the
  final per-opportunity document-reference correction.
- **Fresh QA:** Approved after seven focused workflow regressions passed,
  including clean separate-workspace persistence, Home actions, CSV validation,
  reconciliation routing, multi-word activity search, scoped document refresh,
  and document opening.
- **Code/package review:** Approved the current candidate at `88444e7` after a
  Debug build and strict signature verification. The candidate is development
  signed (`Apple Development: jaroberts4@gmail.com (PT7GS96H3L)`) as bundle
  `com.rekonlabs.RekonPursuit`; it is not Developer ID signed, notarized, or a
  DMG distribution.
- **Delivery decision:** The remediation queue is accepted. Deferred UX polish,
  design v2, and Phase 2 work remain separately planned and are not included
  in this acceptance claim.
