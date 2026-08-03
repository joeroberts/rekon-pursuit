# VD2-07x — Pre-implementation QA recheck

**Date:** 2026-08-01
**Role:** Fresh independent QA/test reviewer
**Verdict:** **NEEDS CHANGE**

## Scope and method

Rechecked the approved VD2-07x design, amended implementation plan, amended
Task 1 brief, and the original QA review. Mechanically extracted both signed
matrix selector sets from the Task 1 brief. Each contains 43 selectors and the
ordered selector-set SHA-256 is identical:

```
f0e0107cc2f94ab36a4425b767ee8f7eb101f6d46f7ca320cf8e3aeb32a6ff2d
```

No source, test, fixture, project, index, commit, or existing delivery artifact
was changed. This was a pre-implementation artifact review; no matrix was run.

## Blocking correction

Both commands designated as the exact, verbatim signed matrices begin with the
literal command `+xcodebuild`, at Task 1 brief lines 188 and 243.
`whence -w +xcodebuild` reports `none`, while `whence -w xcodebuild` reports
`command`. Consequently, executing either matrix verbatim fails before any
selector runs, violating the stated one-run, zero-skip acceptance requirement.

Remove only the leading `+` from both command lines, then submit the amended
brief for a fresh QA recheck before Task 1 release. The matrix commands must
remain otherwise byte-for-byte equivalent after normalizing only their distinct
DerivedData/result-bundle paths.

## Confirmed coverage once the command is repaired

- Fixture-host and deterministic-state coverage is present in the nine host
  selectors: live-store denial, explicit/isolation/per-run launch roots, fixed
  time and reduced motion, archive construction/catalogue/time-zone truth,
  document-relink fixture, and safe recovery presentation state.
- Recovery UI, rail/default/keyboard behavior, fixture recovery gate, relaunch,
  and root-modal dismissal are included. The compact contract proves all four
  local sections are hittable and keyboard reachable before either compact
  visual selector may be RED.
- The four reference methods cover Recovery, Workspace, Document references,
  and AI & connections. The brief retains aggregate-only Document facts,
  unavailable/non-actionable AI facts, and no sensitive label/value disclosure.
- Lower-layer archive expiry, purge, wrong-key rejection, inactive restore,
  busy/disabled controls, verification/restore cancellation, and separate
  workspace return/relaunch selectors are all in both matrices.
- Protected-export coverage includes real-write-only safe event/root projection
  and Done dismissal, exhaustive invalid/cancel/review/stale/write-failure
  branches, gated in-flight cancellation, workspace-transition invalidation,
  existing error/cancel UI behavior, destination binding, source-change, and
  no-overwrite contracts.
- The Task 2 evidence procedure requires eight signed-host wide/compact section
  attachments plus a separate signed normal-Debug real-export-success dialog
  image; it specifies reference comparison and a sensitive-content inspection.

## RED/green classification

The amended brief satisfies the original QA requirement structurally: only 24
explicitly declared, unrendered visual-selector assertions may fail in Task 1
(10 Recovery, 2 compact-tab, and 12 Workspace/Document/AI assertions; 22
unique identifiers because the compact tab identifiers repeat). Fixture, rail, route,
focus, copy, operation, event, cancel/failure, root-presentation, and baseline
failures are explicitly disallowed as RED. The startup success-absence method
is green. Task 1 requires only the three visual-reference methods to fail via
the exact `VD2-07x RED: unrendered visual selector` activity/message; all other
selectors must execute once with zero skip and zero expected failure. Task 2
requires all 43 selectors to execute once with zero failure, skip, or expected
failure.

## Release recommendation

**Do not release Task 1** until the two executable names are corrected and a
fresh QA check confirms the repaired verbatim commands retain the audited
43-selector parity and the stated RED/green result-bundle rules.
