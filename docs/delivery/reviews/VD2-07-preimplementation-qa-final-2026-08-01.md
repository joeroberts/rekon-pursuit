# VD2-07 Settings information architecture — final pre-implementation QA review

**Date:** 2026-08-01  
**Role:** Fresh independent QA/test owner  
**Reviewed commits:** `efe1de6` (approved design) and `5544c03` (corrected brief/plan evidence)  
**Supersedes for QA plan-coverage purposes:** `VD2-07-preimplementation-qa-review-2026-08-01.md` and `VD2-07-preimplementation-qa-recheck-2026-08-01.md`  
**Verdict:** **ACCEPT** — the final brief and test-first plan are internally consistent with the live targets, fixture host, and current pre-extraction interfaces. This is a plan-gate decision only; it does not release Task 1 or prove a future RED/GREEN run.

## Scope and current state

This review covered the approved design, the current brief and implementation plan, the two preceding QA records, the live `ContentView` Settings surface, `WorkspaceViewModel` action/state interfaces, every named existing selector, the UI-test launcher/focus helper, the fixture host, project target membership, and the `RekonPursuit` scheme. `git show --stat` confirms that `efe1de6` adds the design only and `5544c03` changes only the VD2-07 brief and plan. There is no `SettingsView.swift` or VD2-07 production/test extraction in the working tree.

The review did not modify product source, fixtures, the plan, the task brief, the project, the Git index, or delivery status. This record is the sole review artifact created.

## Runner and existing-selector validation

The `RekonPursuit` scheme's `TestAction` includes the three required bundles: `RekonPursuitTests`, `RekonPursuitUITests`, and `RekonPursuitUITestHostTests` (`RekonPursuit.xcodeproj/xcshareddata/xcschemes/RekonPursuit.xcscheme:25-71`). The core archive and protected-export files are members of the `RekonPursuitTests` source phase (`RekonPursuit.xcodeproj/project.pbxproj:568-582`), so both Task commands' `RekonPursuitTests/PortableArchiveTests/...` and `RekonPursuitTests/ProtectedExportTests/...` selectors resolve to the correct bundle.

The Task 1 and Task 2 commands each include every mandatory unchanged lower-layer contract named by the brief:

- document-summary refresh;
- archive creation/restore busy state, restore scope, malformed-key and verification-failure handling, both awaited cancellation paths, and disabled controls;
- protected-export review error, parent-identity binding, changed-source no-write, existing-target no-overwrite, and the Task-1 reviewed-cancel no-write/current-workspace regression;
- fixed-boundary expiry, successful retained-data purge, wrong-key no-write, and inactive restore preserving the source; and
- selected separate-workspace relaunch and return-to-preserved-workspace recovery.

The exact Task 1 selector list is at `docs/superpowers/plans/2026-08-01-vd207-settings-information-architecture.md:426-458`; Task 2 repeats that baseline at `:1054-1088` and adds only the two intended post-extraction presentation/binding selectors. The live existing method names match their target/source locations in `RekonPursuitTests/WorkspaceViewModelTests.swift`, `RekonPursuitCoreTests/PortableArchiveTests.swift`, and `RekonPursuitCoreTests/ProtectedExportTests.swift`.

Both commands also execute the complete current fixture-host/recovery baseline: explicit live-store denial, launch isolation, per-run temporary roots, fixed time/reduced motion, archive construction/catalogue/time-zone truth, document-relink setup, and recovery-only navigation denial. The host uses the UUID-qualified `REKON_VISUAL_FIXTURE_SESSION` and `VisualFixtureLaunchConfiguration.fixedNow` (`RekonPursuitUITests/RekonPursuitUITests.swift:4-35`, `RekonPursuit/RekonVisualTheme.swift:1343-1510`). No new fixture identity, launch parsing, or recovery-key transport is authorized.

I ran the signed Debug projection of Task 1 containing every currently implemented lower-layer and fixture-host selector, using `/private/tmp/rekon-vd207-qa-preimpl-baseline-dd` and `/private/tmp/rekon-vd207-qa-preimpl-baseline.xcresult`. The result contains 26 passes and zero skips for those 18 lower-layer and eight fixture-host tests. It also records the configured Apple Development signing identity. The UI runner did not reach its one existing recovery-only selector because macOS timed out while enabling XCTest automation; see the release limitation below.

## Planned presentation-test contract

| Requirement | Final-plan evidence and interface check |
| --- | --- |
| Local navigation, rail retention, and relaunch default | The five Task-1 UI methods exercise the Recovery default, all four local selectors, retained `sidebar-settings` selection, and a same-UUID-session relaunch that resets only local section state while re-reading the document aggregate (`plan:191-417`). The live launcher accepts the `session` override and removes only its UUID-qualified root. |
| Compact keyboard semantics | The selector uses `@FocusState`, `.focusable()`, `.focused`, and `.onKeyPress(.space)`, yielding exactly `Not selected; Keyboard focus` before Space and `Selected; Keyboard focus` after it (`plan:626-651`). This matches the existing focus-helper contract, which searches the target accessibility value for `Keyboard focus` (`RekonPursuitUITests/RekonPursuitUITests.swift:71-90`), while retaining the required non-color selection token and selected trait. |
| Archive truth, busy state, and retained-data purge presentation | The archive fixture test fixes the filename/created/expiry/lifecycle accessibility value, enrolled action availability, root-owned archive/export/purge dialog cancellation, and protected-export empty-entry error (`plan:251-298`). The Task-2 host-only `SettingsRecoveryPresentation` regression covers the live disabled predicates, archive/export/purge/restore busy text, retained-purge status pass-through, restore progress, and inactive-candidate text (`plan:854-945`). The display seam has no store, fixture, recovery key, checksum, or signing-fingerprint property. The `cancelRetainedDataPurge` callback remains bounded in the brief and injected only from `ContentView`; the post-Task-2 source review must confirm the existing visible `Cancel purge` control uses it while busy. |
| Document and AI absence | The planned Settings boundary receives only `DocumentReferenceSummary`, never a `DocumentReference` or access metadata; the AI section receives no configuration object (`brief:49-61`). Its selected-panel UI test verifies `0 available · 1 require relinking`, rejects seeded filename/hash/content-type strings in labels and values, and requires no actionable descendant control types in either Document or AI panels (`plan:300-341`). |
| Root modal bindings and active-workspace safety | The Task-2 `WorkspaceViewModelTests` regression constructs the exact live `PortableArchiveRestoreDependencies` interface, cancels an awaiting restore, dismisses an invalid-entry failure alert, observes the protected-export error then cancel, and reasserts unchanged active opportunity IDs throughout (`plan:947-1034`). It uses only an empty invalid entry: no recovery key is generated, typed, logged, attached, or displayed. The Task-1 asynchronous protected-export regression separately verifies that canceling a real in-memory reviewed export clears state without output creation or active-workspace change (`plan:381-417`). The named root presentation/binding helpers are internal app-module seams, compatible with the existing `@MainActor @testable import RekonPursuit` unit-test pattern. |
| No implementation scope change | The file allowlist limits implementation to the extracted Settings presentation, narrow root ownership move, two source-phase entries, and named test files; it keeps model, core, fixtures, launch parsing, routes, persistence, signing, and network behavior read-only (`brief:21-30`, `plan:24-40`). |

The planned `PortableArchiveRestoreDependencies` closure signatures, `WorkspaceViewModel` error/cancel methods, test-class `@MainActor` isolation, and existing `@testable` target imports were checked against their current live definitions. The new test snippets are conceptually compatible with those interfaces; the plan introduces neither a test-host route nor a product test switch to make a modal state reachable.

## Release limitation

This approval clears the QA **pre-implementation plan-coverage** gate only. The signed baseline invocation was **not** a qualifying Task-1 RED result: the xcresult reports 26 passed tests and one system failure, `Timed out while enabling automation mode`, before any UI test method ran. That is an external macOS XCTest automation initialization failure, not a Settings selector, fixture, signing, or lower-layer failure. Per the brief, a UI-runner failure cannot be classified as the required absent-selector RED.

Task 1 remains unreleased until the system UI automation session can initialize and the exact Task-1 command records all current baseline selectors once as passed plus only the five intended Settings selector/panel absences as RED. Task 2 remains blocked pending that accepted Task-1 result and the required separate Architecture, Security/privacy, TPM, and Delivery decisions. Final acceptance still requires the Task-2 signed GREEN result, attachment inspection, independent implementation reviews, and explicit product-owner hands-on verification.
