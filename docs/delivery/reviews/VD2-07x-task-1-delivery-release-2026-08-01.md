# VD2-07x Reference-faithful Settings — Task 1 delivery release

**Date:** 2026-08-01
**Role:** Independent Delivery Manager
**Verdict:** **ACCEPT — RELEASED: Task 1 only.**

## Delivery decision

The approved VD2-07x reference-faithful Settings design, amended plan, and
amended Task 1 brief are dependency-safe for the first, test-first slice.
This release authorizes only the deterministic visual RED contract and the
minimal protected-export event/root-projection seam that Task 1 specifies. It
is not implementation acceptance, does not authorize reference panel, tab,
card, responsive-layout, or success-dialog rendering, and does not advance
VD2-07x beyond Task 1.

## Gate audit

| Required gate | Evidence reviewed | Delivery result |
| --- | --- | --- |
| Approved design | `docs/superpowers/specs/2026-08-01-vd207-reference-faithful-recovery-screen-design.md` is product-owner approved and supersedes the prior Settings visual-composition direction. | ACCEPT |
| Amended plan and Task 1 brief | `docs/superpowers/plans/2026-08-01-vd207-reference-faithful-recovery-screen.md` and `docs/delivery/task-briefs/VD2-07x-reference-faithful-settings.md` bound Task 1 to the event/token/root seam and test-first RED only. | ACCEPT |
| Architecture | `docs/delivery/reviews/VD2-07x-preimplementation-architecture-recheck-2026-08-01.md` records **ACCEPT** for the token, store lifetime, safe filename-only projection, and root ownership. | ACCEPT |
| QA | `docs/delivery/reviews/VD2-07x-preimplementation-qa-final-command-recheck-2026-08-01.md` records **ACCEPT**: both literal matrices are executable, contain the same 43 unique selectors, and route to real test bundles. | ACCEPT |
| Security/privacy | `docs/delivery/reviews/VD2-07x-preimplementation-security-privacy-recheck-2026-08-01.md` records **ACCEPT** after the deterministic in-flight cancellation correction and narrow payload requirements were added. | ACCEPT |
| TPM | `docs/delivery/reviews/VD2-07x-preimplementation-tpm-release-2026-08-01.md` records **ACCEPT — release Task 1 only**. | ACCEPT |
| Upstream dependency | VD2-06 is accepted; the current delivery records identify VD2-07 as next up and VD2-08 as blocked pending VD2-07 acceptance. | ACCEPT for this Task 1 release |

The earlier VD2-07x Architecture, QA, QA-command, and Security/privacy
**NEEDS CHANGE** reviews are historical blockers, not approvals. Their
respective accepted rechecks above are the controlling closure evidence; this
release relies on those rechecks and not on a reinterpretation of the earlier
reviews.

## Exact Task 1 authoring allowlist

Only the following authored hunks are permitted:

| Path | Permitted Task 1 hunk |
| --- | --- |
| `RekonPursuit/WorkspaceViewModel.swift` | Filename-only protected-export success event, opaque operation-token invalidation lifecycle, and local test-injected creation closure whose default uses the unchanged store API. |
| `RekonPursuit/ContentView.swift` | Root presentation projection and root-only success dismissal callback; no overlay and no export-sheet close in Task 1. |
| `RekonPursuit/SettingsView.swift` | `SettingsRootModalPresentation` safe event projection and root-binding helper only; no view body, reference selector, card, panel, or dialog rendering. |
| `RekonPursuitTests/WorkspaceViewModelTests.swift` | Only `testVerifiedProtectedExportPublishesSafeSuccessAndRootPresentationOnlyAfterRealWriting`, `testProtectedExportSuccessRemainsNilForEveryNonSuccessBranch`, `testCancellingConfirmedProtectedExportInvalidatesInFlightOperation`, and `testProtectedExportSuccessClearsForEveryWorkspaceTransition`. |
| `RekonPursuitUITests/RekonPursuitUITests.swift` | Only `testVD207ReferenceRecoveryDashboardKeepsRailAndUsesCardComposition`, `testVD207ReferenceRecoveryDoesNotInventExportSuccess`, `testVD207ReferenceTabsKeepKeyboardSelectionAtCompactWidth`, and `testVD207ReferenceOtherSettingsSectionsUseTruthfulInformationalCards`. |
| `RekonPursuitUITestHostTests/RekonPursuitUITestHostTests.swift` | Only the existing `testVD207SettingsRecoveryPresentationPreservesBusyDisabledAndInactiveCandidateContracts` pure presentation-state test extension. |

Every other path is out of scope, including project/scheme/signing/entitlement,
fixture/host/launch-parser, Core/store/schema/migration, recovery/export
semantics, documents, AI/connections/network, dashboard, roadmap, progress,
generated evidence, and unrelated dirty baseline work.

## Dirty-baseline and staging control

At this release the source worktree is dirty: `git status --short
--untracked-files=all` reports 106 modified or untracked entries, and the
cached diff is empty. All six Task 1 allowlist paths already contain
pre-existing modified or untracked work. In particular,
`RekonPursuit/SettingsView.swift` is an untracked 377-line Settings source
file with existing local-section/panel implementation. That previous Settings
code is unaccepted baseline work; it is neither VD2-07x Task 1 evidence nor
authorized visual composition.

**No whole-file staging is permitted.** Do not use `git add .`, `git add -A`,
or stage an entire allowlist file. Preserve a pre-authoring baseline for every
allowlist path, isolate only the permitted Task 1 hunks, inspect the staged
name list/diff/whitespace, and retain the baseline comparison for review.
The pre-existing untracked `SettingsView.swift` and
`RekonPursuitUITestHostTests/RekonPursuitUITestHostTests.swift` must never be
attributed wholesale to Task 1; any index operation on them requires
hunk-level isolation after the captured baseline. Do not reset, reformat, or
alter unrelated dirty work.

## Required Task 1 result classification

Run the literal Task 1 signed Debug matrix in the amended brief, without
editing its selector list, to these exact output paths:

```
/private/tmp/rekon-vd207x-task-1-red-dd
/private/tmp/rekon-vd207x-task-1-red.xcresult
```

The result summary and full test list must prove that all 43 unique selectors
run exactly once (ordered-list SHA-256
`9846aa9024488a5f489d31f6ba1323a63ccda3b5587e28d859582b58268f0274`). There
must be zero skips and zero expected failures. All fixture-host, rail, route,
accessibility/focus, archive/purge/restore, workspace-transition,
operation/event/root-presentation, cancellation/failure, and lower-layer
selectors must be green.

Task 1 permits RED only in these three methods, and only in the declared
visual-selector activities/assertions whose message begins exactly
`VD2-07x RED: unrendered visual selector`:

1. `testVD207ReferenceRecoveryDashboardKeepsRailAndUsesCardComposition`
2. `testVD207ReferenceTabsKeepKeyboardSelectionAtCompactWidth`
3. `testVD207ReferenceOtherSettingsSectionsUseTruthfulInformationalCards`

Those three methods contain the 24 declared visual assertions (22 unique
identifiers) across the Recovery, compact-tab, and other-section groups. The
fourth reference method,
`testVD207ReferenceRecoveryDoesNotInventExportSuccess`, is green in Task 1.
No compile, signing, runner, fixture-launch, route, focus, copy, operation,
event, error/cancel, or generic timeout failure is RED evidence. A matrix that
does not meet this exact classification is **NEEDS CHANGE**, not a Task 1
completion checkpoint.

## Downstream holds

- **Task 2:** blocked pending Task 1's hunk-isolated implementation review,
  clean cached-diff/whitespace evidence, and the exact signed 43-selector
  Task 1 classification above, followed by fresh independent Architecture,
  QA, Security/privacy, TPM, and Delivery continuation decisions.
- **Task 3:** blocked pending Task 2's complete green 43-selector matrix,
  reference/real-export visual evidence, signed-build checks, and its
  independent gates.
- **VD2-08:** remains Backlog and blocked until VD2-07 is accepted in full;
  this release does not absorb its existing accessibility/recovery debts.

No dashboard, roadmap, progress ledger, project, source, test, index, or
commit was changed by this delivery release. This record is the sole release
artifact created for VD2-07x Task 1.
