# VD2-07 amended pre-implementation QA/test recheck

**Date:** 2026-08-01  
**Role:** Fresh independent QA/test owner  
**Reviewed artifacts:** `efe1de6` (approved Settings IA design), `c14053b` (amended brief and plan), `docs/delivery/reviews/VD2-07-preimplementation-qa-review-2026-08-01.md`, the current task brief and implementation plan, the live UI-test harness, fixture host, current Settings source, project test-target membership, and every referenced existing selector.  
**Verdict:** **NEEDS CHANGE**

## Decision

The amendment closes most of the prior review's concrete runner and fixture gaps. It is not yet safe to release Task 1 because the proposed compact keyboard test cannot pass against its own prescribed accessibility contract, and the plan still lacks presentation-level proof for the moved restore/error modal bindings.

## Corrections now concretely planned

### Mandatory lower-layer and fixture baseline coverage — resolved

Both exact runner commands now include every mandatory existing lower-layer selector:

- document summary refresh;
- archive busy, verification, cancellation, disabled-control, expiry, retained-purge, no-key-write, and inactive-restore contracts;
- protected-export destination-binding, revision/no-write, existing-target/no-overwrite, review-error, and the new reviewed-cancellation/no-write/current-workspace regression; and
- selected separate-workspace relaunch and return-to-preserved-recovery behavior.

The Task 1 RED command lists them at
`docs/superpowers/plans/2026-08-01-vd207-settings-information-architecture.md:379-397`; the Task 2 GREEN command repeats them at `:791-809`. The live methods exist in `RekonPursuitTests/WorkspaceViewModelTests.swift`, `RekonPursuitCoreTests/PortableArchiveTests.swift`, and `RekonPursuitCoreTests/ProtectedExportTests.swift`. The latter two source files are members of the `RekonPursuitTests` test target, so the commands' `RekonPursuitTests/...` selector prefix is correct.

Both commands also include the required fixture-host isolation, per-run root, fixed-clock/reduced-motion, archive construction/catalogue/time-zone, and document-relink setup checks (`plan:371-378` and `:782-789`). Their live selectors are present in `RekonPursuitUITestHostTests/RekonPursuitUITestHostTests.swift:35-62,146,357,573-647`. The unchanged recovery-only fixture gate is run in both commands and its live test still proves no normal route, including Settings, is exposed (`RekonPursuitUITests/RekonPursuitUITests.swift:2147-2167`).

### Relaunch, redaction, no-write, and active-workspace evidence — resolved in the plan

The planned `testVD207SettingsRelaunchKeepsFixtureTruthAndResetsLocalSelection` uses one explicit UUID-qualified session, terminates and relaunches the same `document-relink` fixture, verifies the default Recovery section, and rechecks the unchanged document aggregate (`plan:283-317`). It is named in both commands (`:369` and `:780`). The existing harness accepts a session override and removes only that session root (`RekonPursuitUITests/RekonPursuitUITests.swift:4-35`).

The new protected-export unit regression uses an in-memory generated key without logging or attaching its display value, then proves review clears, the output path remains absent, and active workspace facts are unchanged (`plan:320-356`). It is explicitly required in both commands (`:388` and `:800`). The archive UI RED avoids typing a recovery key and adds no attachment while checking root-owned archive, protected-export, and purge entry/cancel paths (`plan:191-237`); document absence checks are panel-scoped and enumerate actionable child-control kinds (`:240-280`).

The Task 2 pure `SettingsRecoveryPresentation` contract is appropriately isolated from fixture creation and keys, and covers the derived disabled/busy, retained-purge-status, restore-progress, and inactive-candidate values (`plan:666-757`). It is correctly Task-2-only because `SettingsView.swift` does not exist before the extraction.

## Required changes

### P1 — Make compact keyboard-focus evidence compatible with the selector accessibility contract

Task 1's compact test calls the existing `tabToKeyboardFocus` helper, which succeeds only when the target's accessibility value contains `Keyboard focus` (`plan:173-185`; live helper: `RekonPursuitUITests/RekonPursuitUITests.swift:71-90`). The Task 2 implementation prescription instead gives every secondary-selector button an accessibility value of exactly `Selected` or `Not selected` (`plan:550`), and the same test then requires exactly `Selected` after Space (`plan:186`). Unlike the global rail, the planned local selector has no `@FocusState`/focus marker or other focus-accessibility behavior (`AppShellView.swift:253-379` shows the rail's explicit `Keyboard focus` value).

Therefore the focused GREEN command would fail its compact focus assertion even if the local selector is keyboard-operable. Amend both Task 1 and Task 2 with one exact, non-conflicting observable focus contract and matching assertions. It must preserve the active control's non-color selected state while allowing automation to prove semantic keyboard focus and Space activation at compact width; update the RED expectation, selector implementation, and GREEN assertion together.

### P1 — Add presentation-level restore/error/cancel proof for the moved root bindings without a recovery-key value

The archive UI method opens and cancels only the archive-creation, protected-export, and purge sheets (`plan:220-236`). It does not exercise the restore sheet's cancellation binding or the portable-restore failure alert; it also does not render a protected-export error. Task 2 instructs the implementer to move those bindings verbatim (`plan:639-664`), while the pure presentation seam stops at busy/status/inactive text (`:666-757`). The listed lower-layer tests prove model-state cancellation and failures but cannot prove that `ContentView` still presents and dismisses the moved sheet/alert after extraction.

Add a fixture-safe, recovery-key-free presentation test/seam that explicitly verifies the retained restore cancellation and failure-alert dismissal bindings, plus the error surface required for the moved protected-export flow. It must prove the current workspace remains unchanged and must not type, record, attach, screenshot, or log a recovery-key value. Put the resulting selector(s) and exact assertions in the Task 1 RED/unchanged-baseline evidence where they can exist before extraction, and in the Task 2 GREEN command after the root bindings move. Keep the existing lower-layer no-write/current-workspace selectors as the companion persistence proof.

## Scope and limitations

This is a pre-implementation plan recheck. No implementation, fixture, launch parsing, brief, plan, specification, dashboard, roadmap, project configuration, test source, or Git index entry was changed. No test suite was run because the five new UI tests, the new protected-export regression, and the Task-2 presentation seam have not been implemented; this verdict is based on the current executable selector locations and the amended plan's exact commands and prescribed assertions.

Task 1 remains unreleased until the two P1 corrections are incorporated and a fresh independent QA recheck accepts them.
