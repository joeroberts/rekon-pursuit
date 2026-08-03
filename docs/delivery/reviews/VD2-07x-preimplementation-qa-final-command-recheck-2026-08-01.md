# VD2-07x — Pre-implementation QA final command recheck

**Date:** 2026-08-01  
**Role:** Fresh independent QA/test reviewer  
**Verdict:** **ACCEPT**

## Scope and method

Independently rechecked the amended Task 1 brief, amended reference-faithful
plan, and both prior QA rechecks. I extracted the two literal fenced matrices
from the brief, checked their `zsh` syntax without executing tests, compared
their selector lists and normalized command text, and inspected the project,
scheme, test-source membership, and test declarations. No source, test,
fixture, project, index, or commit was changed.

## Command and selector results

- Both literal matrices begin with executable `xcodebuild`, have no leading
  diff marker, and pass `zsh -n`.
- Each matrix contains exactly 43 unique `-only-testing` selectors. Their
  ordered selector-list SHA-256 is identical:

  ```
  9846aa9024488a5f489d31f6ba1323a63ccda3b5587e28d859582b58268f0274
  ```

- After normalizing only the explicitly distinct output values, the two
  commands are byte-for-byte identical. Task 1 writes only to
  `/private/tmp/rekon-vd207x-task-1-red-dd` and
  `/private/tmp/rekon-vd207x-task-1-red.xcresult`; Task 2 writes only to
  `/private/tmp/rekon-vd207x-task-2-green-dd` and
  `/private/tmp/rekon-vd207x-task-2-green.xcresult`.

## Target, class, and method routing

`xcodebuild -list` and the shared `RekonPursuit` scheme expose and execute the
three prefixes used by the matrices:

| Prefix | Selectors | Verified class/source routing |
| --- | ---: | --- |
| `RekonPursuitUITests` | 10 | `RekonPursuitUITests` in `RekonPursuitUITests.swift` |
| `RekonPursuitUITestHostTests` | 9 | `RekonPursuitUITestHostTests` in `RekonPursuitUITestHostTests.swift` |
| `RekonPursuitTests` | 24 | `WorkspaceViewModelTests`, plus `PortableArchiveTests` and `ProtectedExportTests`, all compiled into `RekonPursuitTests.xctest` |

The project has no `RekonPursuitCoreTests` target. The seven selectors that
exercise Core test-source files correctly use `RekonPursuitTests`; both files
are members of that target's Sources phase. The scheme lists all three test
bundles as non-skipped testables.

Thirty-five selected methods already have matching declarations. The remaining
eight are the deliberate Task-1 test-first methods: four reference UI methods
in `RekonPursuitUITests` and four protected-export event methods in
`WorkspaceViewModelTests`. Their exact declarations and owning classes are
specified in both the brief and plan, and both source files are already target
members. They must be added before the brief's post-event matrix invocation;
this is expected pre-implementation state, not an invalid selector route.

## RED and zero-skip rules

The brief and plan agree that Task 1 permits RED only for explicitly named,
unrendered visual-selector assertions: 24 declared assertions (22 unique IDs)
across the Recovery (10), compact-tab (2), and Workspace/Document/AI (12)
groups. Only these three methods may fail, only through the exact
`VD2-07x RED: unrendered visual selector` activity/assertion message:

1. `testVD207ReferenceRecoveryDashboardKeepsRailAndUsesCardComposition`
2. `testVD207ReferenceTabsKeepKeyboardSelectionAtCompactWidth`
3. `testVD207ReferenceOtherSettingsSectionsUseTruthfulInformationalCards`

`testVD207ReferenceRecoveryDoesNotInventExportSuccess` remains green. Fixture,
rail, route, accessibility/focus, copy, operation, event/root-presentation,
cancel/failure, and lower-layer assertions are not RED-eligible. Task 1
requires zero skips and zero expected failures; Task 2 requires all 43
selectors to run once with zero failures, skips, and expected failures.

## Release decision

The two prior command blockers are repaired: the command name is executable
and all seven Core-source selectors now address the real `RekonPursuitTests`
bundle. The signed matrices are ready for Task 1's test-first implementation
and subsequent result-bundle verification. This is an artifact/command
approval only; it is not evidence that the Task 1 implementation or either
matrix result has passed.
