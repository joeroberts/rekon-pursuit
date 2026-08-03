# VD2-07x baseline-repair prerequisite — Architecture recheck

**Date:** 2026-08-01  
**Reviewer:** Fresh independent Architecture recheck  
**Verdict:** **ACCEPT**

## Decision

The amended baseline-repair brief and plan correct both defects identified in
the prior architecture review without broadening ownership or masking an
unverified UI result. The prerequisite may proceed to the remaining
independent preimplementation gates. This acceptance is for the narrowly
allowlisted repair only; it is not a release of Task 2 visual rendering or a
claim that the current dirty worktree is checkpointable.

No ADR is required. The repair preserves the existing Settings-local state,
root-owned export presentation seam, global rail, data boundaries, and
fixture-only clock ownership.

## Recheck of the required corrections

| Prior required correction | Current evidence | Result |
| --- | --- | --- |
| Make the UI pass count internally consistent. | The plan states 40 green selectors: 24 Core/ViewModel, nine fixture-host, and seven UI (`docs/superpowers/plans/2026-08-01-vd207x-baseline-repair-prerequisite.md:52`). The brief's matrix acceptance repeats exactly seven UI passes: the six ordinary UI methods plus `testVD207ReferenceRecoveryDoesNotInventExportSuccess` (`docs/delivery/task-briefs/VD2-07x-baseline-repair-prerequisite.md:148-155`). Three named reference methods remain RED solely for their 10 + 2 + 12 declared visual-selector activities. | Correct. The total is internally consistent: 24 + 9 + 7 = 40 pass, with three of ten UI methods intentionally RED. |
| Restore a real static-text regression contract and authorize only its exact test hunk. | The brief and plan retain the current `app.descendants(matching: .any)` query and assertions, then add the explicit `app.staticTexts["settings-ai-connections-unavailable"]` predicate beside it (`task brief:32,66-79`; `plan:47-48,129-146`). The allowlist permits only that additive predicate plus the two compact guard removals in `RekonPursuitUITests/RekonPursuitUITests.swift`. Current source confirms the AI `Text` still has the overriding accessibility label and the existing test still uses only the `Any` query (`RekonPursuit/SettingsView.swift:408-417`; `RekonPursuitUITests/RekonPursuitUITests.swift:3003-3016`). | Correct. The new role predicate is genuinely RED before removal of the label and exercises the exact source repair, while the existing truth/no-control assertions remain. |

## Architecture and source-boundary evidence

- The proposed fixture replacement is exact: the current `1_746_057_600`
  value resolves to `2025-05-01T00:00:00Z`; required
  `1_746_532_800` resolves to `2025-05-06T12:00:00Z`. The existing comment
  already specifies the latter date (`RekonPursuit/RekonVisualTheme.swift:1349`).
  A direct ISO-UTC assertion prevents the comment/literal drift from recurring.
- `SettingsView` already owns only `selectedSection` and `focusedSection`.
  The authorised selector additions match the existing semantic button
  pattern in `ContactsView` (`SettingsView.swift:196-245`,
  `ContactsView.swift:264-280`) and do not add a route, model, persistence,
  callback, or layout owner.
- The AI repair removes only the `Text`'s explicit accessibility label; it
  keeps its identifier and truthful local-only/unavailable copy. It neither
  introduces a connection nor exposes document or recovery metadata.
- The Task 1 report remains the authoritative reason for this prerequisite:
  all 24 Core/ViewModel and nine host selectors completed, but the UI matrix
  was blocked by the May-1 fixture output and compact/aggregate Settings
  behavior. The repair stays outside `WorkspaceViewModel`, `ContentView`,
  and Core/persistence (`.superpowers/sdd/2026-08-01-vd207-reference-faithful-recovery-screen/task-1-report.md`).

## Scratch-index integration gate

The plan's integration preflight is architecturally safe and accurately scoped:

- It first copies the real index to a temporary path and applies
  `git add -N`/`git add -p` only with `GIT_INDEX_FILE` set to that copy;
  all inspection commands use the same temporary index
  (`plan:179-191`). The real index is therefore not modified.
- It checks exactly the four allowlisted paths, rejects extra or inseparable
  hunks, and requires ordinary plus no-index whitespace checks for the two
  currently untracked paths.
- It explicitly labels a partial scratch entry for `SettingsView.swift` or
  the host-test file as boundary evidence only, prohibits compiling it, and
  prohibits calling it a build checkpoint (`plan:193-195`; task brief:164-166).
- Current index evidence confirms the condition is real: only
  `RekonPursuit/RekonVisualTheme.swift` and
  `RekonPursuitUITests/RekonPursuitUITests.swift` are tracked among the four
  repair paths; `RekonPursuit/SettingsView.swift` and
  `RekonPursuitUITestHostTests/RekonPursuitUITestHostTests.swift` remain
  untracked in this dirty worktree. The plan correctly declares the repair
  unreleasable here if clean partial isolation cannot be evidenced without
  fully staging either untracked file.

`git diff --check` over the tracked repair paths and the two specified
no-index whitespace checks completed without whitespace diagnostics during
this recheck. No source or test file was changed, staged, or committed.

## Release condition

Proceed only with the existing four-file allowlist, red-to-green proof for
each added contract, and the named signed matrix. A complete parseable signed
result bundle remains required for delivery evidence; the scratch index can
prove hunk boundaries, not compilation or test execution. Any need to stage
an untracked file in full requires the separately reviewed, owner-authorized
baseline integration specified by the plan.
