# VD2-05 — Core-suite evidence-repair Slice A delivery release

**Date:** 2026-07-31  
**Role:** Fresh independent Delivery Manager  
**Decision:** **COMPLETE — Slice A accepted after implementation; Slice B is
released separately under the exact accepted plan.**

## Pre-implementation gates independently verified

| Gate | Evidence | Decision |
| --- | --- | --- |
| Planning | `docs/superpowers/plans/2026-07-31-vd205-core-suite-evidence-repair.md`; `docs/delivery/task-briefs/VD2-05-core-suite-evidence-repair.md` | Approved bounded, test-only repair with a serial Slice A → Slice B dependency. |
| Architecture | `.superpowers/sdd/2026-07-30-vd205-persisted-pipeline-stage-movement/core-suite-plan-architecture-final-rereview.md` | ACCEPT; no ADR impact; permits release only after the remaining gates. |
| QA | `.superpowers/sdd/2026-07-30-vd205-persisted-pipeline-stage-movement/core-suite-plan-qa-rereview.md` | ACCEPT; requires the retained RED, Slice A signed evidence, and all post-implementation reviews. |
| Security/privacy | `.superpowers/sdd/2026-07-30-vd205-persisted-pipeline-stage-movement/core-suite-plan-security-gate.md` | ACCEPT; preserves encrypted fixture/recovery, v22 no-bookmark, signing, and scope controls. |
| TPM | `.superpowers/sdd/2026-07-30-vd205-persisted-pipeline-stage-movement/core-suite-plan-tpm-gate.md` | ACCEPT; names Slice A as the sole dependency-safe next release and withholds Slice B/downstream work. |
| Dependency | `docs/delivery/roadmap.md` | VD2-04 is accepted; VD2-05 remains in progress and has no released successor. |

## Action-expectation amendment gates independently verified

The original four-selector follow-up bundle at
`/private/tmp/rekon-vd205-core-suite-slice-a-green-20260731-019fb19c.xcresult`
is retained as RED: four executed, three passed, and only
`testUpdateOpportunityReplacesItsNextActionAndWritesOneActivityEvent` failed
because the full-value expected `Opportunity` remained `.noAction` / `nil`
while the unchanged compatibility contract produced `.other` /
`"Prepare recruiter call"`.

| Gate | Evidence | Decision |
| --- | --- | --- |
| Planning | Amended controlling plan, task brief, and fourth amendment in `core-suite-repair-planning-report.md` | Authorizes exactly two additional expected-value lines and replaces the prior four-selector GREEN requirement with the exact six-selector matrix. |
| Architecture | `.superpowers/sdd/2026-07-31-vd205-core-suite-evidence-repair/task-1-action-contract-amendment-architecture-gate.md` | ACCEPT; no contract or ADR change. |
| QA | `.superpowers/sdd/2026-07-31-vd205-core-suite-evidence-repair/task-1-action-contract-plan-qa-gate.md` | ACCEPT; exact two-line boundary and six-selector acceptance contract are executable. |
| Security/privacy | `.superpowers/sdd/2026-07-31-vd205-core-suite-evidence-repair/task-1-action-contract-amendment-security-gate.md` | ACCEPT; test-only expectation correction with no production, persistence, migration, signing, or entitlement impact. |
| TPM | `.superpowers/sdd/2026-07-31-vd205-core-suite-evidence-repair/task-1-action-contract-amendment-tpm-gate.md` | ACCEPT; releases only the amendment and prescribed evidence run. |

## Authorized permanent implementation scope

Only `RekonPursuitCoreTests/WorkspaceStoreTests.swift` may receive these
permanent Slice A changes:

1. In `testStageMoveCommitsStageAuditHistoryAndProjectionTogether`, replace
   the two positional stage assertions with immutable-ID lookups for the moved
   and unrelated rows in both the commit projection and reopened store. Assert
   moved `.screening` and explicitly retain unrelated `.saved` in both places.
2. In `testUpdateOpportunityReplacesItsNextActionAndWritesOneActivityEvent`,
   add only `stageChangedAt: now` to the specified stale update call. Preserve
   every other argument and assertion.
3. In that test's full-value expected `Opportunity`, add only:

   ```swift
   actionType: .other,
   actionCustomText: "Prepare recruiter call"
   ```

   Preserve `nextAction: "Prepare recruiter call"`, `stageChangedAt: now`,
   default `typedActionEdited: false`, every other request/expected field, and
   every separate assertion. Before and after this two-line amendment, record
   the test-file SHA-256 and compare the final diff with the captured
   follow-up baseline.

No production, migration, schema, project, signing, entitlement, UI, Board,
or other test change is authorized by this record. The pre-existing dirty
worktree is a baseline, not Slice A evidence; implementation must retain a
fresh changed-path/diff comparison against that baseline.

## Required execution evidence before Slice A can be signed GREEN

The implementer must preserve both recorded RED bundles and run the amended
plan's exact fresh signed Debug six-selector Slice A matrix using
`/private/tmp/rekon-vd205-core-suite-slice-a-action-green-20260731-dd` and
`/private/tmp/rekon-vd205-core-suite-slice-a-action-green-20260731.xcresult`:

- `testStageMoveCommitsStageAuditHistoryAndProjectionTogether`
- `testUpdateOpportunityReplacesItsNextActionAndWritesOneActivityEvent`
- `testUpdateRejectsMissingEffectiveDatesWithoutWriting`
- `testHistoriesUseExplicitDateThenIdentifierForDeterministicTies`
- `testLegacyCompensationAndActionTextRemainAvailableAsCompatibilityValues`
- `testStructuredCompensationAndOtherActionPersistWithoutChangingStageHistory`

The `xcresulttool` summary and detailed records must show exactly six passed,
zero failed, zero skipped, with every selector enumerated once. Without
disabling signing, retain strict verification and identity inspection for the
generated app, host executable, and nested test bundle. Record SHA-256 values
for the pre/post amendment test source, app executable, test-bundle executable,
and result `Info.plist`. Before requesting post-implementation review, prove
the follow-up delta is exactly the two authorized lines, perform the
changed-path/source-scope scan, and require `git diff --check` to pass.

## Slice A completion gate

Slice A is complete. The accepted implementation source is
`RekonPursuitCoreTests/WorkspaceStoreTests.swift` at SHA-256
`c482870a0648a1129f9fceecc325e126c0f412b35b96d7a1acc2476483ae88d0`.
Both the implementer and independent QA signed bundles report exactly six
passed, zero failed, and zero skipped, with each required selector enumerated
once. The app, host executable, and nested XCTest bundle signatures and
identities verify; the prescribed hashes and baseline-relative diff are
accepted; and `git diff --check` is clean.

| Post-gate | Evidence | Decision |
| --- | --- | --- |
| Code Review | `.superpowers/sdd/2026-07-31-vd205-core-suite-evidence-repair/task-1-slice-a-code-review.md` | ACCEPT; no findings. |
| QA | `.superpowers/sdd/2026-07-31-vd205-core-suite-evidence-repair/task-1-action-contract-post-implementation-qa.md` | ACCEPT; independently reproduced signed 6/6. |
| Architecture | `.superpowers/sdd/2026-07-31-vd205-core-suite-evidence-repair/task-1-slice-a-post-implementation-architecture.md` | ACCEPT; no contract, production, or ADR impact. |
| Security/privacy | `.superpowers/sdd/2026-07-31-vd205-core-suite-evidence-repair/task-1-action-contract-post-implementation-security.md` | ACCEPT; no production, persistence, recovery, signing, entitlement, or privacy change. |
| TPM | `.superpowers/sdd/2026-07-31-vd205-core-suite-evidence-repair/task-1-slice-a-post-implementation-tpm-gate.md` | ACCEPT; Slice A may close and Slice B is the sole eligible successor. |

The prior Slice B hold is satisfied. Delivery releases Slice B only in
[the Slice B release record](VD2-05-core-suite-slice-b-delivery-release-2026-07-31.md).

## Current holds

- **VD2-05 Task 2 acceptance:** withheld.
- **Full signed Core and ViewModel evidence:** withheld pending completed and
  independently accepted Slice B.
- **Board / Task 3, card relocation, drag/drop, keyboard workflow mutation:**
  withheld.
- **Owner handoff and VD2-06, VD2-07, VD2-08:** withheld.

Slice A completion and the separate Slice B release are neither Task 2
acceptance nor a Board, owner, status-advancement, or Visual Design successor
release.
