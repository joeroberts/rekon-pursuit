# VD2-07x baseline-repair prerequisite — Delivery release

**Date:** 2026-08-01  
**Role:** Independent Delivery Manager  
**Verdict:** **ACCEPT — release the baseline-repair prerequisite only.**

## Release decision

Architecture, QA, and Security/privacy each accepted the amended four-path prerequisite, and the independent TPM has released that prerequisite subject to this Delivery decision. The Task 1 report establishes the three real baseline blockers: the fixture epoch disagrees with its declared May 6 UTC instant, the existing Settings-local buttons do not expose the required compact keyboard-focus semantics, and the unavailable AI text has the wrong accessibility role. Each has one bounded repair and a red-to-green contract. This release authorizes a fresh implementer for that repair only.

This is **not** acceptance of VD2-07x Task 1, release of Task 2, rendering of the approved reference-faithful Settings UI, or authorization to checkpoint the current dirty worktree.

## Evidence inspected

- The amended prerequisite plan and task brief retain an identical ordered set of **43 unique selectors** to the controlling Task 1 matrix: 24 Core/ViewModel, nine fixture-host, and ten UI selectors.
- The Architecture recheck, QA recheck, and Security/privacy recheck each record **ACCEPT**. The TPM release records **ACCEPT** for this prerequisite only.
- The current pre-repair anchors match the reviewed causes:
  - `VisualFixtureLaunchConfiguration.fixedNow` is still `1_746_057_600` despite the May 6 comment; the direct ISO-UTC host assertion is not yet present.
  - `SettingsView.sectionSelector(_:)` still lacks the allowed plain-button/focus-effect/explicit-label modifiers; the two temporary compact-test guarded continuations are still present.
  - The AI unavailable `Text` still carries its explicit accessibility label, while the UI test still has the existing `Any` query only.
- The four source/test targets all have filesystem modification times before the accepted rechecks and TPM release (latest target: `RekonPursuitUITests/RekonPursuitUITests.swift` at 16:32:03; earliest recheck: 16:58:16). Current content inspection confirms the reviewed pre-repair anchors; no source/test change has occurred since those records.
- The real Git index is empty. `RekonPursuit/SettingsView.swift` and `RekonPursuitUITestHostTests/RekonPursuitUITestHostTests.swift` remain untracked; `RekonPursuit/RekonVisualTheme.swift` and `RekonPursuitUITests/RekonPursuitUITests.swift` are tracked but contain unrelated dirty hunks. `git diff --check` is clean. The prescribed no-index whitespace checks on the two untracked files produce no whitespace diagnostics (their status `1` denotes a normal no-index difference, not a whitespace failure).

## Authorized implementation boundary

The fresh implementer may author only the following repair hunks and must leave every change unstaged:

| Path | Authorized hunk only |
| --- | --- |
| `RekonPursuit/RekonVisualTheme.swift` | Replace only the `fixedNow` numeric literal with `1_746_532_800`. |
| `RekonPursuit/SettingsView.swift` | Add only the approved existing Button focus/label modifiers in `sectionSelector(_:)`; remove only the explicit AI-unavailable `Text` accessibility label. |
| `RekonPursuitUITestHostTests/RekonPursuitUITestHostTests.swift` | Add only the direct ISO-UTC assertion to the existing fixed-time host test. |
| `RekonPursuitUITests/RekonPursuitUITests.swift` | Remove only the two temporary compact guarded continuations, if present; add only the explicit AI `StaticText` assertions beside the existing `Any` query and all existing assertions. |

The implementer must first demonstrate the direct ISO assertion and additive AI role assertion red against the current code, then make only the allowlisted repairs. It must run the two focused command groups and the literal 43-selector matrix in `docs/delivery/task-briefs/VD2-07x-baseline-repair-prerequisite.md`.

The matrix is eligible for acceptance only with 24 Core/ViewModel passes, nine fixture-host passes, and seven UI passes (the six ordinary methods plus `testVD207ReferenceRecoveryDoesNotInventExportSuccess`). The only remaining failures may be the three designated reference methods, containing exactly the 24 declared `VD2-07x RED: unrendered visual selector ...` activities (10 Recovery, two compact-tab, 12 other-section). Any other failure, skip, expected failure, or result-bundle finalization failure blocks acceptance. A parseable signed Debug result bundle is required; terminal output is insufficient.

## Worktree and integration constraints

- Do not change `ContentView`, `WorkspaceViewModel`, Core/persistence, fixtures beyond the one literal, global navigation, project/signing configuration, or any Task 2 visual surface. Do not add a fixture/demo export success, path/key/document metadata, test workaround, result-bundle workaround, or network capability.
- Do not stage, commit, reset, restore, reformat, or broad-stage any file. Preserve all unrelated user-owned hunks.
- The untracked-file condition is not resolved by this release. After independent post-implementation acceptance only, Delivery must perform the prescribed scratch-index preflight against a copied temporary index, inspect the complete cached diff and whitespace checks, and leave the real index unchanged.
- If the exact repair hunks cannot be isolated without staging either untracked file in full, record this prerequisite **unreleasable on the current worktree**. Do not work around that by broad staging. The only recovery is a separately reviewed, owner-authorized baseline integration or a clean approved base, followed by fresh preimplementation gates.

## Next gate

After implementation, require fresh independent code review and QA verification of the isolated diff and exact matrix classification, followed by Architecture, Security/privacy, TPM, and Delivery acceptance before another Task 1 acceptance attempt. Task 2 remains blocked until those gates are complete.
