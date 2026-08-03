# VD2-07x protected-export destination feedback — Delivery release gate

**Date:** 2026-08-01  
**Role:** Fresh independent Delivery Manager preimplementation release  
**Verdict:** **HOLD**

## Scope and release decision

This is one dependency-safe Task 1 only. The planning amendment, controlling
design, diagnosis, accepted Architecture, TPM, Security/privacy, and final QA
records define a bounded worker-classification and retained-feedback slice.
The initial QA gate and QA re-gate each recorded **NEEDS CHANGE**; their four
RED-feasibility corrections are incorporated in the amended plan/brief and
the later fresh QA final gate is **ACCEPT**. They therefore do not remain a
test-strategy blocker.

Delivery cannot release a fresh implementer in this worktree yet. The current
uncommitted changes already overlap two of Task 1's authorized paths and its
protected-export state boundary:

- `RekonPursuit/WorkspaceViewModel.swift` has active changes at the protected
  export review/confirm/error flow (including the task's 1318–1367 region).
- `RekonPursuitTests/WorkspaceViewModelTests.swift` has active protected-export
  test additions and changes in the task's feedback-test region.

The final QA gate prohibits concurrent overlapping ViewModel/test edits without
Delivery-approved hunk isolation. No such isolation is recorded. No active
implementer was found, but the overlapping dirty state itself prevents the
required conflict-free release confirmation.

## Preimplementation gate matrix

| Prerequisite | Evidence | Outcome |
| --- | --- | --- |
| Controlling design and diagnosis | Owner-approved design; diagnosis approves the smallest safe split | Pass |
| Planning/task brief | Amended one-task TDD plan and brief contain the QA RED scaffold sequence | Pass |
| Architecture | `...architecture-gate-2026-08-01.md` — **ACCEPT** | Pass |
| TPM | `...tpm-gate-2026-08-01.md` — **RELEASE** as one bounded slice | Pass subject to controls |
| Security/privacy | `...security-pregate-2026-08-01.md` — **ACCEPT** | Pass subject to controls |
| Initial QA and re-gate | Both **NEEDS CHANGE**; corrective requirements incorporated | Superseded by final QA acceptance |
| Final QA | `...qa-final-gate-2026-08-01.md` — **ACCEPT** | Pass |
| Dependency/conflict check | Active uncommitted protected-export ViewModel and test edits overlap the task | **Fail — release blocker** |

## Authorized implementation paths

Only these paths may be changed by Task 1:

1. `RekonPursuitCore/Workspace/ProtectedExportWorker.swift`
2. `RekonPursuitCoreTests/ProtectedExportTests.swift`
3. `RekonPursuit/WorkspaceViewModel.swift` — compiler-required exhaustive controlled-error mapping only
4. `RekonPursuitTests/WorkspaceViewModelTests.swift`

`RekonPursuit/ContentView.swift` is inspection-only. Project files, Settings,
accessibility, persistence/schema, service/store APIs, dashboard, roadmap, and
all other paths are unauthorized.

## Required implementation evidence once released

- Step 0's inert fault-mode scaffold first passes the named focused baseline
  suite; its fresh result bundle must show every selected test once, with zero
  skips and expected failures.
- Compilable assertion-RED uses exact `LocalizedError.errorDescription` and
  owner-copy assertions, then preserves its result bundle proving only intended
  assertion failures.
- Fresh GREEN and regression bundles must each show all selected tests once,
  passing with zero skips and expected failures; inspect their resolved lists
  and summaries, not only `xcodebuild` exit status.
- Tests prove exact copy and retained state, no pre-write file/event/verified
  activity/success, retained review on pre-create failure, post-create
  may-remain behavior, byte-preserved existing target, and verified real-write
  event/activity evidence.
- Postimplementation reviewers independently verify the fixed fault placements,
  unchanged Darwin flags/binding, no production-selectable fault mode, no
  diagnostic disclosure, authorized changed paths, and clean `git diff --check`.

## Known risks and release condition

The task is security-sensitive: classifying any post-`openat` fault as a safe
folder correction could mislead the owner about a file that may remain. The
fault seam must stay immutable, worker-only, default-`.none`, and test-only;
no overwrite/retry, raw diagnostics, or scope expansion is permitted.

Release only after the owner of the existing protected-export ViewModel/test
changes completes or explicitly isolates those hunks and Delivery rechecks a
clean non-overlapping Task 1 boundary. Then release one fresh implementer for
this single task, followed by separate code-review, QA, Architecture, and
Security/privacy gates.
