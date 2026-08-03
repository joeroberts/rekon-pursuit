# VD2-07x Save-panel leaf authority — Delivery implementation release

**Date:** 2026-08-01  
**Role:** Fresh independent Delivery Manager  
**Verdict:** **RELEASE** — exactly one fresh Implementer may begin the single
bounded TDD slice below.

## Preconditions verified

- ADR-005 is accepted and defines the exact transient Save-panel leaf as the
  sole external-write authority; it explicitly rejects a parent-directory
  continuity claim, broader authority, bookmarks, entitlement changes, and a
  new two-step picker.
- The current plan and task brief require an executable canonical-leaf RED,
  direct exclusive leaf creation, no-overwrite and conservative post-create
  handling, verification-before-evidence, three independently inspected result
  bundles, and a signed Debug owner-native smoke.
- Fresh independent Architecture re-gate 3, QA re-gate 2, Security/privacy
  re-gate 3, and TPM re-gate 3 each record **ACCEPT**. The TPM records this as
  dependency-safe within VD2-07 and authorizes this Delivery release without a
  new owner decision.
- The current `git diff -U0 -- RekonPursuitTests/WorkspaceViewModelTests.swift`
  has no hunk overlapping current lines 692–863. Its dirty hunks are outside
  the protected feedback island (the first later preimage hunk is at line
  1048). The current island contains the two obsolete parent-review tests,
  the pre-descriptor confirm feedback test, and its adjacent helpers.
- `git diff --check` completed with exit code 0 for the current worktree.
- The dashboard source of truth still lists VD2-07 as `in_progress`; VD2-08
  retains the deferred accessibility closure. This release does not authorize
  a dashboard, Settings visual, accessibility, Pipeline/Kanban, entitlement,
  signing, schema, persistence, or ViewModel-source change.

## Exact released boundary

The Implementer may author and stage changes only in this atomic set:

1. `RekonPursuitCore/Workspace/ProtectedExportWorker.swift`
2. `RekonPursuitCoreTests/ProtectedExportTests.swift`
3. Only the clean protected-export feedback-test island and adjacent helpers
   at current `RekonPursuitTests/WorkspaceViewModelTests.swift:692-863`.

Within the model-test island, remove only the two parent-authority review
tests, rename/reassert the direct selected-leaf pre-descriptor confirm test,
and retain the conservative post-descriptor test and its exact public copy.
`RekonPursuit/WorkspaceViewModel.swift` and `WorkspaceStore` are
inspection-only. All pre-existing dirty hunks, including the dirty portions of
the same model-test file, remain user work and are not part of this release.

Immediately before editing the model test file, rerun:

```bash
git diff -U0 -- RekonPursuitTests/WorkspaceViewModelTests.swift
```

If any hunk overlaps current lines 692–863, stop and return the slice to
Delivery for a new integration plan. Do not run concurrent work against the
worker, core tests, or this model-test island.

Patch-only staging is mandatory after the required verification. Use
`git add -p` on each of the three authorized paths, split a combined hunk if
needed, and confirm the cached diff contains only the authorized worker, core
tests, and feedback-island hunk. Do not use broad staging or a whole-file
model-test stage.

## Required implementation evidence

The fresh Implementer follows the accepted plan and brief exactly:

1. Add the executable decomposed-Unicode canonical-leaf assertion RED using
   `Cafe\u{301}.rekonexport`; it must fail only because the current worker
   still uses the v1 parent identity, not because of compilation, skips,
   signing, fixtures, or an unrelated assertion.
2. Add the constrained test-only worker fault coverage, including direct-leaf
   pre-descriptor failure, post-descriptor may-remain failure, and the
   `beforeEvidenceCommit` fault after successful package verification but
   before the evidence transaction. Preserve immutable review data and prove
   locator-only, digest-only, and fingerprint-only substitutions reject before
   output/evidence.
3. Preserve separate result bundles and inspect both the summary and resolved
   tests for each:

   | Phase | DerivedData | Result bundle |
   | --- | --- | --- |
   | RED | `/private/tmp/rekon-vd207x-save-panel-leaf-red-dd` | `/private/tmp/rekon-vd207x-save-panel-leaf-red.xcresult` |
   | GREEN | `/private/tmp/rekon-vd207x-save-panel-leaf-green-dd` | `/private/tmp/rekon-vd207x-save-panel-leaf-green.xcresult` |
   | Regression | `/private/tmp/rekon-vd207x-save-panel-leaf-regression-dd` | `/private/tmp/rekon-vd207x-save-panel-leaf-regression.xcresult` |

   Every selected test must execute once with zero skips and zero expected
   failures. GREEN and regression must pass; RED may contain only the intended
   canonical-leaf behavior assertion failure. Run `git diff --check` after
   GREEN and regression as an additional check.
4. Do not claim the sandbox repair complete from unit tests. After independent
   post-implementation gates, build the configured signed Debug app, verify
   its signature and effective existing entitlements, and perform the actual
   one-step `NSSavePanel` owner smoke in a fresh Documents child folder. Keep
   only redacted filename-safe evidence; never retain or share a recovery key,
   raw path, entitlement dump, export data, or workspace database.

## Post-implementation hold points

The Implementer is not permitted to review or verify its own work. When it
has recorded the three result bundles, the slice pauses for fresh, separate:

1. Code Review;
2. QA/test verification;
3. Architecture verification against ADR-005;
4. Security/privacy verification; and
5. TPM milestone review.

Only then may the signed owner-native smoke occur. A fresh Delivery Manager
must record the inspected technical evidence and redacted owner result before
any completion decision. VD2-07 and its Kanban/dashboard card remain **In
progress** until that owner-native confirmation is recorded. Any source-boundary
overlap, authority expansion, test-evidence defect, or owner-smoke failure
returns this release to **HOLD**.
