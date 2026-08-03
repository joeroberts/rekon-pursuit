# VD2-07 Task 1 — TPM continuation review

**Date:** 2026-08-01
**Role:** Fresh independent Technical Program Manager
**Verdict:** **ACCEPT** — Task 1 evidence and all non-Delivery continuation gates are accepted. Task 2 is **not released yet**.

## Decision and release recommendation

The Task 1 execution is dependency-safe and its five UI failures have the
required **intended RED** classification. The fresh QA and Architecture
continuation decisions are both **ACCEPT**, and this TPM decision completes the
remaining non-Delivery continuation approval.

**Release recommendation:** Delivery may release **Task 2 only** after it
creates the plan-mandated, hunk-isolated Task 1 checkpoint and records an
explicit Task 2 continuation decision in the same Delivery action or a paired
Delivery record. A checkpoint commit alone is not a substitute for the
Delivery continuation decision required by the serial release table. Once
Delivery performs both actions, no additional planning, QA, Architecture, or
TPM gate is outstanding for Task 2.

The checkpoint must stage only these six Task 1 additions, run
`git diff --cached --check`, and commit as
`test: define VD2-07 Settings presentation contracts`:

- The five named `testVD207Settings...` methods in
  `RekonPursuitUITests/RekonPursuitUITests.swift`.
- `testCancellingReviewedProtectedExportClearsReviewWithoutWritingOrChangingActiveWorkspace`
  in `RekonPursuitTests/WorkspaceViewModelTests.swift`.

It must preserve the retained Task 1 result bundle, summary/test tree,
UUID-qualified fixture sessions, and project-file SHA-256. It must not stage
the already-dirty files wholesale or authorize any Task 2 production/project
change before the explicit continuation release.

## Independent gate audit

| Gate | Evidence | TPM assessment |
| --- | --- | --- |
| Task 1 pre-implementation Architecture, QA/test, Security/privacy, TPM, and Delivery gates | Final pre-implementation Architecture, QA, and Security/privacy reviews are **ACCEPT**; the prior TPM record is **ACCEPT**; the Delivery record released Task 1 only. | Satisfied for Task 1. |
| Task 1 test scope | Implementer report and independent code review identify exactly five UI RED methods plus one protected-export cancellation/no-write unit regression, in the two permitted test paths only. | Satisfied. No Task 1 production, fixture, project, store/model, route, signing, or delivery-ledger change is attributed. |
| Signed intended RED | Direct `xcresulttool` inspection of `/private/tmp/rekon-vd207-task-1-red.xcresult` reports 33 executed: 28 passed, 5 failed, 0 skipped, and 0 expected failures. | Satisfied. |
| RED failure boundary | The five failed tests are the five named UI methods. Their diagnostics are only absent `settings-section-recovery-archives`, `settings-section-document-references`, or `settings-archive-summary-*` selector/panel queries after the existing Settings rail is reached. | Valid intended RED; no build, signing, runner, fixture-launch, global-rail, accessibility infrastructure, or unchanged-baseline failure is present. |
| Lower-layer and fixture baseline | Recovery-only UI, eight fixture-host proofs, the existing WorkspaceViewModel safety selectors plus the new cancellation regression, four archive-core selectors, and three protected-export-core selectors each passed once. Fresh QA independently reran the exact signed matrix with the same 28/5/0 result. | Satisfied. |
| Independent post-implementation review | Code Review, QA verification, and Architecture continuation records each return **ACCEPT**. | Satisfied. |
| Delivery checkpoint and continuation decision | The Task 1 report records no staged hunk or commit. Current index inspection is empty for the named paths; both files remain modified in the shared worktree and current `HEAD` predates the required checkpoint. | Pending; Delivery-owned. |

## Scope, sequencing, and risks

- Task 2 remains limited to the approved `SettingsView.swift` extraction,
  narrow `ContentView` ownership move, two existing-target source-phase
  registrations, and the named Task 2 tests. It must preserve local-only
  non-persisted selection; root-owned model, key, route, sheet, alert, picker,
  destructive-confirmation, and cancellation flow; document aggregate-only
  display; and the no-control AI surface.
- The intentionally dirty shared worktree is the active delivery risk. The
  required hunk-isolated checkpoint, cached whitespace check, and exact staged
  diff are mandatory before Task 2 starts.
- Task 3 remains blocked pending Task 2 GREEN and its separate Code Review,
  QA, Architecture, Security/privacy, TPM, and Delivery decisions. Product
  owner review remains later.
- **VD2-08 remains Backlog and blocked.** Its three accepted accessibility/
  recovery automation debts remain open and are outside VD2-07 scope.

## Final TPM recommendation

**ACCEPT the Task 1 continuation evidence. Do not start Task 2 yet.** Require
Delivery to issue the clean or hunk-isolated Task 1 checkpoint and explicitly
release Task 2 immediately afterward; a bare checkpoint without that Delivery
continuation decision is insufficient. No other dependency-safe task is
released, and VD2-08 remains blocked.
