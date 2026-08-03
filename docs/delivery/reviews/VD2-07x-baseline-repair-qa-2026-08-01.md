# VD2-07x baseline-repair prerequisite — QA review

**Verdict:** NEEDS CHANGE

**Review scope:** draft `VD2-07x-baseline-repair-prerequisite` task brief and implementation plan, the controlling amended Task 1 brief, current worktree source/tests, Task 1 report, terminal log, and requested result bundle. No source or test was changed by this review.

## What is verified

1. The repair matrix has **43 unique selectors** and is in the same literal order as the controlling Task 1 matrix: 10 UI, 9 UI-test-host, and 24 Core/ViewModel selectors. A direct ordered comparison of the two markdown commands returned status `0`; no duplicate selector was found.
2. The fixture-date cause is real. `RekonPursuit/RekonVisualTheme.swift:1349` currently declares `1_746_057_600` while its comment requires May 6 at noon UTC. `date -u -r 1746057600` returns `2025-05-01T00:00:00Z`; the proposed `1_746_532_800` returns `2025-05-06T12:00:00Z`. The planned direct ISO-UTC assertion is a valid test-first regression contract and preserves the existing 30-day expiry computation.
3. The compact focus cause is real. `RekonPursuit/SettingsView.swift:235-247` has `@FocusState`, `.focusable()`, `.focused`, and the Space handler, but lacks the `.buttonStyle(.plain)`, `.focusEffectDisabled(true)`, and explicit label sequence used by the working Contacts row at `RekonPursuit/ContactsView.swift:264-276`. The Task 1 compact log records values remaining `Not selected` rather than `Not selected; Keyboard focus`, followed by failed Space selection. The current reference compact test also contains both prohibited `guard section.exists else { continue }` paths at `RekonPursuitUITests/RekonPursuitUITests.swift:2793,2805`.
4. The Task 1 execution record is not release evidence. The terminal log records 24/24 Core/ViewModel and 9/9 host passes, then 10 UI tests with 45 failures. The requested result bundle has no `Info.plist`; `xcresulttool get test-results summary` exits 64. The plan correctly says this must remain an infrastructure-evidence limitation and cannot be represented as a verified signed matrix.

## Blocking corrections

### 1. Make the UI classification mathematically and textually exact

The brief's matrix classification at `docs/delivery/task-briefs/VD2-07x-baseline-repair-prerequisite.md:142` says both “seven ordinary UI selectors” and that `testVD207ReferenceRecoveryDoesNotInventExportSuccess` passes. There are only 10 UI selectors total: three must fail intentionally, leaving seven green. Of those seven, six are non-reference UI selectors and `testVD207ReferenceRecoveryDoesNotInventExportSuccess` is the seventh. The current wording implies eight green UI methods and therefore 41 green selectors, contradicting the plan's correct 40-green count at `docs/superpowers/plans/2026-08-01-vd207x-baseline-repair-prerequisite.md:51`.

Amend the brief and plan to require exactly:

- 24 Core/ViewModel passes;
- 9 fixture-host passes;
- 7 UI passes, consisting of the six ordinary UI selectors plus `testVD207ReferenceRecoveryDoesNotInventExportSuccess`;
- 3 UI failures only: Recovery (10 declared activities), compact tabs (2), and other Settings sections (12), for exactly 24 `VD2-07x RED: unrendered visual selector ...` activities;
- 40 passed selectors and 3 intentionally visual-red methods, with no other failure, skip, or expected failure.

### 2. Restore a real static-text regression contract before removing the AI accessibility override

The draft claims that the existing aggregate/AI test already makes `app.staticTexts["settings-ai-connections-unavailable"]` pass. The current signed source does not make that query: `RekonPursuitUITests/RekonPursuitUITests.swift:3006-3010` uses `app.descendants(matching: .any)` only. The same `.any` query is in `HEAD`; it cannot prove that removing the `Text` accessibility label restores the intended static-text role. The historical terminal log supports the suspected role defect, but it is not a substitute for a currently committed failing test contract.

Amend the UI-test allowlist and TDD steps so the repair first adds an explicit `app.staticTexts["settings-ai-connections-unavailable"]` existence/label assertion alongside the existing aggregate, no-control, and disclosure assertions. It must fail with the current override, then pass after removing only `AIConnectionsSettingsSection`'s explicit `.accessibilityLabel(...)` at `RekonPursuit/SettingsView.swift:414`. Keep the existing `.any` query and every existing assertion; this adds role coverage and does not relax the acceptance surface.

### 3. Resolve the untracked `SettingsView.swift` integration gate before release

`git status --short` shows `RekonPursuit/SettingsView.swift` as untracked. The draft correctly says an unsplittable new-file hunk must reject a candidate index, but it supplies no executable resolution. Since this prerequisite and the unaccepted Task 1 seam both touch that same untracked file, ordinary `git diff --check` will not prove its hunk isolation, and a later `git add -p` may be unable to separate the authored repair from pre-existing user work.

Before releasing an implementer, Delivery must record a clean integration approach that preserves user changes and can produce a checkpoint containing only the allowed repair hunks. If no such approach is available, the prerequisite remains unreleasable; it must not be folded into a broad new-file stage.

## Non-blocking confirmations

- The date literal, existing compact keyboard contracts, removal of the guarded continuations, and the proposed modifier-only focus repair are properly bounded and do not relax the four-section behavior.
- The two documents use the controlling matrix's exact selector order and count.
- The runner treatment is appropriate: retain terminal/bundle artifacts outside the repository, report the missing parseable result separately, and do not change product or test behavior to conceal it.

## QA release condition

After the three corrections above, rerun fresh Architecture, Security/privacy, TPM, Delivery, and QA preimplementation reviews. A fresh implementer may then execute the amended test-first task. This review does not approve implementation yet.
