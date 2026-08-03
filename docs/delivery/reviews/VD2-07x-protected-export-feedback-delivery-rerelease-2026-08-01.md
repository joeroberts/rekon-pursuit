# VD2-07x protected-export destination feedback — Delivery re-release

**Date:** 2026-08-01
**Role:** Fresh independent Delivery Manager recheck
**Verdict:** **RELEASE** — one fresh implementer may begin Task 1 under the protected hunk-isolation controls below.

## Recheck result

The prior Delivery **HOLD** is superseded only for the hunk-isolated Task 1
boundary defined in
`VD2-07x-protected-export-feedback-hunk-isolation-2026-08-01.md`. The accepted
Architecture, TPM, Security/privacy, and final QA preimplementation gates
remain controlling.

At this recheck:

- `RekonPursuitCore/Workspace/ProtectedExportWorker.swift` remains clean and
  retains the recorded worker anchors (classification at lines 30–45 and
  initializer at 47–52).
- `RekonPursuitCoreTests/ProtectedExportTests.swift` remains clean, with the
  permitted append seam immediately before its line-108 class closing brace.
- `RekonPursuitTests/WorkspaceViewModelTests.swift` remains dirty only in its
  pre-existing hunks; the protected feedback insertion seam is unchanged
  between the closing brace at current line 690 and
  `testExternalFolderLeaseIsRetainedForTheOpenedStoreThenReleasedOnClose` at
  line 692.
- `RekonPursuit/WorkspaceViewModel.swift` remains a pre-existing dirty file,
  but needs no feedback-task source edit: its existing controlled-error mapper
  already returns `ProtectedExportWorkerError.errorDescription`.
- There are no staged task paths and no active agent editing the three
  effective task paths or the isolated model-test seam.

## Effective task boundary and staging

The effective implementation paths are exactly:

1. `RekonPursuitCore/Workspace/ProtectedExportWorker.swift`
2. `RekonPursuitCoreTests/ProtectedExportTests.swift`
3. one new feedback-only insertion hunk in
   `RekonPursuitTests/WorkspaceViewModelTests.swift`, between current lines
   690 and 692.

`RekonPursuit/WorkspaceViewModel.swift` is inspection-only and must receive
**no source edit or staged diff**. All other planning-gate exclusions remain
in force.

Patch-only staging is mandatory. Do not use whole-file or bulk staging
(`git add .`, `git add -A`, `git add -u`, `git commit -a`, or `git add <source
path>`). After accepted GREEN and regression evidence, stage only with:

```bash
git add -p -- RekonPursuitCore/Workspace/ProtectedExportWorker.swift
git add -p -- RekonPursuitCoreTests/ProtectedExportTests.swift
git add -p -- RekonPursuitTests/WorkspaceViewModelTests.swift
```

Split any combined hunk. Before a commit boundary, confirm the cached path
list contains exactly those three paths, the cached `WorkspaceViewModel.swift`
diff is empty, the model-test diff is only the stated insertion, and
`git diff --check` passes.

## Required evidence and gate sequence

The implementer follows the accepted Step 0 inert-scaffold baseline, executable
assertion-RED, minimal GREEN, and fresh regression sequence, retaining and
inspecting each result bundle's resolved test list and summary. Every selected
test must execute once with zero skips and zero expected failures; RED may fail
only on intended assertions. The final evidence also includes the task-scoped
diff inspection and `git diff --check`.

After implementation, release proceeds only through separate code review, QA
verification, Architecture deviation review if needed, Security/privacy
verification, then Delivery completion recording. The implementer cannot fill
any of those independent review or verification roles.

## Exact concurrency rule and automatic HOLD triggers

**No concurrent edit may overlap the worker, view model, or their tests without
Delivery-approved hunk isolation.** For this release, no concurrent work may
edit either clean core path, the lines-690/692 model-test seam, or any
protected-export hunk in `WorkspaceViewModel.swift`. Any such edit, any change
to the recorded anchors, any `WorkspaceViewModel.swift` source edit by this
task, or inability to isolate the three paths with patch-only staging
immediately returns this release to **HOLD** pending a fresh Delivery recheck.
