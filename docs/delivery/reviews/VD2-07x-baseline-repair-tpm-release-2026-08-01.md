# VD2-07x baseline-repair prerequisite — TPM release

**Date:** 2026-08-01
**Role:** Independent TPM
**Verdict:** **ACCEPT — TPM releases the baseline-repair prerequisite only, subject to the separate Delivery release.**

## Release decision

The Task 1 report proves three baseline defects that prevent an honest pre-visual matrix result: the fixture epoch conflicts with its declared date, the local Settings selectors do not expose the required compact keyboard-focus semantics, and the AI-unavailable element has the wrong accessibility role. The amended prerequisite gives each defect one narrow, test-first repair and does not absorb the approved reference-faithful Settings rendering.

Architecture, QA, and Security/privacy have each accepted the amended four-path prerequisite in their fresh rechecks. From sequencing and scope control, a **fresh implementer** may be released for this repair once the separate independent Delivery release is recorded. This is the sole work eligible before the next Task 1 matrix attempt; Task 2 remains blocked.

## Authorized implementation boundary

The implementer may change only these authored hunks:

| Path | Allowed repair |
| --- | --- |
| `RekonPursuit/RekonVisualTheme.swift` | Correct only `VisualFixtureLaunchConfiguration.fixedNow` to the already-declared May 6 UTC instant. |
| `RekonPursuit/SettingsView.swift` | Restore the existing local selector focus modifiers/label and remove only the AI unavailable `Text` accessibility-label override. |
| `RekonPursuitUITestHostTests/RekonPursuitUITestHostTests.swift` | Add the direct ISO-UTC fixture-time assertion. |
| `RekonPursuitUITests/RekonPursuitUITests.swift` | Remove only the two temporary compact guarded continuations and add the explicit AI `StaticText` role assertion while retaining the existing `Any` query and all current assertions. |

It must first prove the time and AI role assertions RED, make only the allowlisted repairs, then run both focused commands and the unchanged 43-selector signed matrix. No reference tab strip, hero, card, icon, colour, responsive layout, export-success dialog, export/root/event logic, global rail, fixture route, project configuration, signing, entitlement, persistence, or network work is authorized.

## Matrix and downstream gates

The prerequisite can be accepted only with all of the following evidence:

- 24/24 Core/ViewModel and 9/9 fixture-host selectors pass.
- Exactly seven UI selectors pass: the six ordinary Settings methods plus `testVD207ReferenceRecoveryDoesNotInventExportSuccess`.
- Exactly three reference UI methods are RED, with precisely the 24 declared `VD2-07x RED: unrendered visual selector ...` activities (10 Recovery, 2 compact-tab, 12 other-section). No other failure, skip, or expected failure is eligible.
- The signed Debug result bundle is parseable. Terminal output alone does not complete this evidence; a repeated finalization stall is a tooling blocker to record and escalate separately, not a reason to weaken tests or modify product behavior.
- A fresh QA verifier confirms the classification. Separate code review, Architecture, Security/privacy, TPM, and Delivery decisions must then accept the restored Task 1 checkpoint before Task 2 can be released.

## Dirty-worktree and delivery risk

The shared worktree is materially dirty. The two source/test paths that carry the Settings-focus and host-test repair are untracked, while the two tracked paths also contain unrelated changes; Task 1 event/root hunks remain unaccepted and out of this task. The implementer must record the baseline, leave all work unstaged, and must not broad-stage, reset, reformat, or take ownership of pre-existing work.

After independent implementation acceptance, Delivery—not the implementer—must perform the stipulated temporary-index hunk-isolation preflight. The real index must remain untouched. If the permitted repair hunks cannot be isolated without staging either untracked file in full, this prerequisite is unreleasable on this worktree; the only permitted recovery is a separately reviewed, owner-authorized baseline integration or a clean approved base, followed by fresh preimplementation gates. A scratch partial index is boundary evidence only, never build or test evidence.

## Dependency statement

This TPM release opens one bounded prerequisite before another Task 1 matrix attempt. It does **not** accept Task 1, release Task 2, or make any visual work eligible. Task 2 remains held until the repair's independent evidence and untracked-file decision are accepted, the Task 1 event/root slice is reviewed against the exact matrix, and all required continuation gates are recorded.
