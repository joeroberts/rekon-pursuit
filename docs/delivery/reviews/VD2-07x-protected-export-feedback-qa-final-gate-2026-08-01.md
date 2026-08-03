# VD2-07x protected-export destination feedback — QA final preimplementation gate

**Date:** 2026-08-01  
**Role:** Fresh independent final preimplementation QA/test gate  
**Scope:** Reconciled the controlling design and diagnosis, Architecture, TPM,
Security/privacy, initial QA, QA re-gate, amended plan, task brief, worker,
store injection seam, test target, and command feasibility. No production,
test, project, dashboard, roadmap, or prior review artifact was changed.

## Verdict: ACCEPT

The amended sequence resolves the re-gate's only blocking defect without
weakening test-first delivery:

1. **Step 0 is inert and testable.** It introduces only the approved internal,
immutable `ProtectedExportWorkerFaultMode`, private `let faultMode`, and
default-`.none` initializer assignment. It has no branch, error/copy change,
production injection, persistence, or runtime-selectable behavior. Its
dedicated focused baseline command and fresh result bundle prove existing
behavior remains green before any new test is added.
2. **Step 1 is executable assertion-RED, not compilation-RED.** The scaffold
makes `faultMode:` construction available to test code, while worker assertions
use the exact proposed `LocalizedError.errorDescription` strings rather than
the absent new enum cases. Invalid-name and owner model-copy assertions fail
against current copy; the unplaced valid-suffix fault modes take their current
ordinary path and fail assertions for the required controlled outcome. Thus the
new source compiles and every intended RED failure can be attributed solely to
missing classification, copy, or fault placement.
3. **Step 2 is minimal GREEN.** It adds only the two controlled cases, their
approved static copy, and the four Architecture/Security-approved placements.
It preserves the existing no-follow/no-overwrite operations, parent binding,
review digest/fingerprint, scoped-access lifetime, verified-write-only audit
transaction, and the `created == true` may-remain catch boundary.

## Feasibility and coverage reconciliation

`xcodebuild -list -project RekonPursuit.xcodeproj` confirms the real unit-test
target is `RekonPursuitTests`. Both
`RekonPursuitCoreTests/ProtectedExportTests.swift` and
`RekonPursuitTests/WorkspaceViewModelTests.swift` are source members of that
target, so every documented `-only-testing:RekonPursuitTests/...` selector has
the correct target prefix. `WorkspaceStore` already supports an injected
`ProtectedExportWorker`, allowing both worker and view-model tests to use the
immutable test-only modes without a store/view-model production parameter.

The three commands form a complete and non-overlapping evidence sequence:

| Evidence stage | Required proof | Gate result |
| --- | --- | --- |
| Step 0 baseline | Existing focused security, binding, no-overwrite, retained-correction, no-success, and real-write presentation behavior remains green after the inert scaffold. | Complete specification present. |
| Step 1 RED | Five worker and five model selectors compile, run once, and fail only assertions for absent classification/copy/placements; no skips or expected failures. | Complete specification present. |
| Step 3 GREEN/regression | The same focused selectors pass, then regression proves real encryption/read-back, binding, source-change no-file behavior, existing-byte preservation, verified event/activity rows, retained non-success, and filename-only real-write success. | Complete specification present. |

Each stage requires its own explicitly named, fresh non-existing
DerivedData/result-bundle paths, plus resolved-test-list and summary inspection.
The RED selector set includes both parent failures, pre-create confirmation,
and post-create owner feedback; the regression set includes the added
verified-event/activity assertion. No selector, target, state, audit, or
result-bundle gap remains.

## Mandatory release conditions

1. Release only a fresh implementer, and only for the four authorized
source/test paths in the task brief; no concurrent edit may overlap the worker,
view model, or their tests without Delivery-approved hunk isolation.
2. Step 0 must be evidenced before new RED tests are added: its focused
baseline bundle must show every selected test ran once and passed, with zero
skipped or expected-failure tests. Do not create the implementation commit
until the later GREEN and regression evidence is accepted.
3. RED must compile after the scaffold and preserve a result bundle showing
only intended assertion failures, once per selected test, with zero skips or
expected failures. Core tests must continue to use error-description assertions
until GREEN supplies the enum cases.
4. GREEN and the fresh regression bundle must each show every selected test ran
once and passed, with zero skipped or expected-failure tests. Review the
bundles' resolved lists and summaries, not only process exit codes.
5. Verify exact state/evidence boundaries: pre-write failures have no output,
review as applicable, verified export row, filtered verified activity, or
success; pre-create retains its valid review; post-create leaves a possible
file and is only may-remain; ordinary write yields exactly one verified export
and one filtered verified activity; existing target bytes and literal
no-overwrite copy remain unchanged.
6. Postimplementation reviewers must independently verify all Architecture and
Security/privacy invariants, including fixed fault placement, unchanged Darwin
flags and binding, no production non-default mode, no disclosure, and a clean
`git diff --check`. Delivery may then record the separate code-review, QA,
Architecture, and Security/privacy completion gates.

## Checks performed

- Inspected the controlling design/diagnosis and all named preimplementation
  Architecture, TPM, Security/privacy, initial-QA, and QA re-gate records.
- Inspected the amended plan and task brief, current worker state machine,
  existing focused tests, `WorkspaceStore` worker injection, and Xcode target
  membership.
- Preserved the pre-existing dirty worktree and changed only this final-gate
  record.
