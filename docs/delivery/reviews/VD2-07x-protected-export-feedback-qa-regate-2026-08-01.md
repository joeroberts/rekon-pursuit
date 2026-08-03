# VD2-07x protected-export destination feedback — QA re-gate

**Date:** 2026-08-01  
**Role:** Fresh independent QA/test re-gate  
**Scope:** Amended RED/GREEN plan and task brief only. No production, test,
project, dashboard, or prior-review file was changed.

## Verdict: NEEDS CHANGE

The amendment now specifies every substantive state, evidence, retention, copy,
selector-target, and result-bundle requirement from the initial QA gate. It is
not yet releasable because the stipulated RED suite cannot compile and execute
against the current source in the order stated.

## Re-gate findings

| Prior QA requirement | Re-gate result |
| --- | --- |
| Deterministic default-safe worker-only modes at the exact pre/post-write boundaries | Specified by the plan and brief. |
| Invalid name, both parent failures, and pre-create confirmation prove no final output, verified-export row, or filtered verified activity | Specified, including the required real successful review before confirmation and no assertion about total activity. |
| Failed-review and failed-confirm correction state | Specified: exact error and status copy, retained root error, nil/retained review as appropriate, nil success, and false root-success presentation. |
| Post-create boundary | Specified: final file remains, zero verified evidence, only may-remain classification/copy, no success. |
| Real success/audit and existing-target regression | Specified: receipt-versus-bytes and exactly one verified event/activity; byte-for-byte existing-file preservation, literal no-overwrite copy, and no success. |
| Correct test target and result evidence procedure | Uses `RekonPursuitTests`, not the source-group name; focused and regression commands name the added feedback tests and require fresh bundles, resolved-list/summary inspection, one execution each, zero skips/expected failures, and `git diff --check`. |

## Blocking RED feasibility defect

The current worker has neither `ProtectedExportWorkerFaultMode` nor its
`faultMode:` initializer. It also has only
`ProtectedExportWorkerError.invalidDestination`; it does not declare
`.invalidDestinationName` or `.destinationUnavailable`.

Consequently, the Step 1 tests cannot compile as written before the intended
implementation exists: construction with `faultMode:` and assertions naming
either new error case are unresolved symbols. The focused `xcodebuild` command
therefore cannot be valid RED evidence in its stated sequence; it cannot reach
an intended failing assertion until this compile dependency is resolved.

An error-description assertion is required for a genuine pre-classification
RED assertion if the new error cases are still absent. For example, the
invalid-name worker test must assert the exact proposed controlled
`errorDescription` (and fail against today's old invalid-destination copy),
rather than name `.invalidDestinationName`. The same strategy can assert the
exact unavailable-folder copy at the worker boundary. Naming the new enum cases
would require adding those production cases before RED and would no longer test
the requested absent-case state.

The fault modes remain a separate compile dependency: exact immutable enum,
stored property, and default-`.none` initializer scaffolding must exist before
tests can construct deterministic workers. The modes may initially have no
branch placements, so each valid-suffix test runs the ordinary path and fails
its expected unavailable/may-remain assertion. That is executable RED. The
later minimum GREEN change adds the approved placements and classification.

## Exact corrective requirements

1. Amend Step 1 to add a narrowly scoped **pre-RED compilation scaffold** in
   `ProtectedExportWorker.swift`: exactly the architecture-approved immutable
   `ProtectedExportWorkerFaultMode`, private stored property, and default-`.none`
   initializer. It must preserve production construction and may not add a
   global, mutable, environment, service/store, or filesystem-adapter seam.
2. While the two new controlled error cases are absent, write executable RED
   worker assertions against the exact proposed `LocalizedError.errorDescription`
   (not unresolved `.invalidDestinationName` or `.destinationUnavailable`
   cases). Keep the model tests' exact error/status-copy assertions. The tests
   must fail today for the intended old classification/copy or ignored fault
   modes, never for compilation, skip, or expected failure.
3. State that the next GREEN step adds only the two cases, exact copy, and the
   four approved placements: parent-open before `open`, parent-inspection after
   successful `open` with descriptor close, exclusive-create after identity
   guard before `openat`, and post-create after descriptor assignment plus
   `created = true`. Preserve the original Darwin flags/order, binding, and
   catch state machine.
4. Re-run the amended focused RED command only after the test sources compile,
   preserve/inspect its bundle, then run fresh GREEN and regression bundles.
   The recorded RED outcome must be assertion failures solely from missing
   classification/copy/placements, with every selected test run once and no
   skips or expected failures.

## Checks performed

- Inspected the controlling design, diagnosis, Architecture and TPM gates,
  initial QA gate, amended plan, brief, current worker, view-model retention
  path, root rendering, current tests, and `WorkspaceStore` injection seam.
- `xcodebuild -list -project RekonPursuit.xcodeproj` confirms the test target is
  `RekonPursuitTests`; there is no `RekonPursuitCoreTests` target.
- `git diff --check` completed cleanly in the assigned worktree. Its unrelated
  pre-existing changes were not modified or used as evidence.

**Release condition:** Do not release an implementer until the plan and brief
incorporate the four corrective requirements and a fresh QA re-gate accepts the
executable RED sequence.
