# VD2-07x protected-export destination feedback — TPM preimplementation gate

**Date:** 2026-08-01
**Role:** Fresh independent TPM preimplementation review
**Verdict:** **RELEASE** — one bounded VD2-07x implementation slice, subject to the release controls below.

## Scope and dependency decision

The owner-approved correction is dependency-safe as one TDD slice within the
active `VD2-07` work item. It changes only the controlled classification and
retained feedback for an already-existing protected-export flow:

1. an invalid final filename maps to `invalidDestinationName`;
2. a parent/open-inspection or pre-create non-`EEXIST` failure after a valid
   suffix maps to `destinationUnavailable`; and
3. every post-create failure remains `outputMayRemainAfterFailure`.

It has no dependency on a new Settings surface, fixture, route, persistence
record, save-panel behavior, or VD2-08 acceptance work. The existing export
worker/store and view-model controlled-error boundary are sufficient. The
deterministic, default-`.none` worker seam makes the new pre-write cases
testable without host-permission or volume-state dependencies.

`VD2-07` is recorded as `in_progress` in `docs/delivery/dashboard-status.json`.
`VD2-08` is `backlog` and blocked on acceptance of VD2-03 through VD2-07. This
slice neither releases nor closes VD2-08, and it must not alter the three
accessibility debts assigned there.

## Authorized implementation boundary

The fresh implementer may change only these paths:

| Path | TPM-authorized purpose |
| --- | --- |
| `RekonPursuitCore/Workspace/ProtectedExportWorker.swift` | Controlled error split, pre-write classification, and default-safe internal fault seam. |
| `RekonPursuitCoreTests/ProtectedExportTests.swift` | Deterministic worker/store cases and preserved export-security regressions. |
| `RekonPursuit/WorkspaceViewModel.swift` | Exhaustive controlled-error mapping only if compiler-required; preserve save-panel behavior. |
| `RekonPursuitTests/WorkspaceViewModelTests.swift` | Exact retained-message and no-success contracts. |

`RekonPursuit/ContentView.swift` is inspection-only. Settings views,
accessibility work, fixtures, project/signing files, persistence/schema,
dashboard, roadmap, and every VD2-08 item are expressly out of scope. The
implementation commit must contain only the four authorized source/test paths;
this gate record itself is preimplementation evidence and is not an
implementation-commit input.

## Required release controls

Release one fresh implementer only after the independent Architecture, QA,
Security/privacy, and Delivery preimplementation records accept the same
boundary. Do not run this implementation in parallel with any task editing the
same worker, view model, or test files; if such work is active, Delivery must
first establish a reviewed hunk-isolation/integration sequence or hold the
implementation.

The implementer must follow RED → minimal GREEN and retain evidence for:

- exact invalid-name and unavailable-folder literals in retained correction
  state;
- no review, output, verified-export row/activity, or success on either
  pre-write failure;
- unchanged `destinationExists`, parent identity binding, `O_NOFOLLOW`,
  `O_EXCL`, no-overwrite, verified read-back, and real-write-only success;
- post-create failure classified only as `outputMayRemainAfterFailure`;
- the focused command and the listed protected-export/view-model regression
  command passing with zero skips and zero expected failures; and
- `git diff --check` before review/commit.

After implementation, a separate code reviewer and QA verifier must assess
the result; Architecture must approve any material seam/API deviation, and
Security/privacy must verify the filesystem and disclosure invariants before
Delivery records completion. The implementer may not serve in either review or
verification role.

## Risks and stop conditions

- Reclassifying any failure after `created == true` as folder-unavailable would
  falsely suggest a safe retry; reject it.
- Changing Darwin flags, parent identity binding, save-panel filtering/default
  name, or no-overwrite behavior is a scope breach requiring a new decision.
- Including raw paths, `errno`, security-scope state, recovery material, or
  keys in copy, tests, logs, or activity is a privacy breach and blocks
  release.
- Any Settings/ContentView redesign or accessibility repair belongs to its
  controlling VD2-07x visual slice or to VD2-08, not this correction.

## TPM release conclusion

**RELEASE.** This is a single, dependency-safe protected-export feedback
correction under VD2-07x. It may start only as the bounded four-path TDD slice
described above, after the named independent preimplementation gates are
recorded and with the postimplementation review sequence preserved. It does
not authorize VD2-08 or unrelated Settings work.
