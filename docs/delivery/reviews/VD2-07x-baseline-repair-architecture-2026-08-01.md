# VD2-07x baseline-repair prerequisite — Architecture review

**Reviewer:** Independent Architecture

**Verdict:** NEEDS CHANGE

## Scope and boundary assessment

The three proposed production repairs are appropriately narrow and do not require an ADR once the two contract defects below are corrected.

- The fixture repair changes only the incorrect `fixedNow` epoch in `RekonPursuit/RekonVisualTheme.swift`. The current literal `1_746_057_600` resolves to `2025-05-01T00:00:00Z`, while the required replacement `1_746_532_800` resolves to `2025-05-06T12:00:00Z`. The fixture remains UTC and its archive expiry is derived using the existing calendar; no production clock, store, persistence, or fixture-routing interface changes.
- `SettingsView.sectionSelector(_:)` already owns `selectedSection` and `focusedSection`. Adding the existing Contacts button surface pattern (`.buttonStyle(.plain)`, focus binding, Space handler, focus-effect suppression, and explicit accessible label/value/identifier) changes only local keyboard semantics. It introduces no route, model, persistent state, callback, or layout ownership.
- Removing the explicit accessibility label from the existing AI `Text` preserves its visible truthful local-only/unavailable copy, identifier, and no-control boundary. It introduces no capability, connection, or metadata exposure.
- The baseline plan deliberately excludes `WorkspaceViewModel` and `ContentView`. The existing protected-export event remains model-owned and root-projected (`WorkspaceViewModel.swift:301`, `ContentView.swift:523-534`); Settings still receives display-safe values and callbacks only. The prerequisite therefore neither broadens the export boundary nor invents success state.
- The plan correctly retains the approved reference cards, dialog, global rail, data models, and persistence as Task 2 work. It also correctly treats the incomplete result bundle as an infrastructure-evidence limitation rather than a reason to change product behavior.

## Required changes before implementation

1. **Make the UI pass count internally consistent.** The literal matrix names ten UI methods: four reference methods and six ordinary Settings methods. With the three declared reference methods failing and `testVD207ReferenceRecoveryDoesNotInventExportSuccess` passing, the qualifying result is **six ordinary UI methods plus the default-success reference method = seven UI passes total**. The draft brief currently requires “seven ordinary UI selectors and `testVD207ReferenceRecoveryDoesNotInventExportSuccess`” at `VD2-07x-baseline-repair-prerequisite.md:141`, which describes eight passes and is impossible for that ten-method matrix. Reword this criterion and the corresponding plan text to state the exact seven-total result.

2. **Restore a real static-text regression contract for the AI role repair, and authorize that exact test hunk.** Current source at `RekonPursuitUITests/RekonPursuitUITests.swift:3006` queries the AI element through `app.descendants(matching: .any)`, not `app.staticTexts`. The plan claims the existing test will prove a static-text role after removing the overriding label, but the current allowlist permits only removal of the temporary compact-test guards in that test file. As written, the AI source change would not be proved by the current selector query. Amend the brief/plan to permit only the exact AI query replacement to `app.staticTexts["settings-ai-connections-unavailable"]` (while retaining its current identifier, copy, no-control assertions, and all other tests), then require it to fail before removal and pass after removal. Do not broaden the test-file allowlist beyond this predicate replacement and the two guard removals.

## Evidence inspected

- Approved reference design: `docs/superpowers/specs/2026-08-01-vd207-reference-faithful-recovery-screen-design.md` — confirms unchanged root ownership, local non-persisted tabs, safe export facts only, and no capability invention.
- Task 1 report: `.superpowers/sdd/2026-08-01-vd207-reference-faithful-recovery-screen/task-1-report.md` — confirms the May 1 archive value, compact-focus failure, and incomplete-result-bundle limitation.
- Baseline plan and brief: `docs/superpowers/plans/2026-08-01-vd207x-baseline-repair-prerequisite.md` and `docs/delivery/task-briefs/VD2-07x-baseline-repair-prerequisite.md`.
- Source: `RekonPursuit/RekonVisualTheme.swift:1349`, `RekonPursuit/SettingsView.swift:198-247,408-417`, `RekonPursuit/ContactsView.swift:264-280`, `RekonPursuitUITests/RekonPursuitUITests.swift:2777-2825,3003-3016`, `RekonPursuit/WorkspaceViewModel.swift:298-302,1333-1403`, and `RekonPursuit/ContentView.swift:357-370,523-534`.
- Recorded terminal evidence: `/private/tmp/rekon-vd207x-task-1-red-terminal.log` and `/private/tmp/rekon-vd207x-task-1-compact-terminal.log`.

## Risk and release condition

The production implementation is architecturally low risk once the two deterministic test/criterion corrections are made. Do not release a fresh implementer until the amended brief preserves the four-file production/test boundary and states the exact seven-pass/three-RED UI classification. No source or test files were changed by this review; nothing was staged or committed.
