# VD2-07 final pre-implementation architecture review

**Date:** 2026-08-01  
**Role:** Fresh independent Architect  
**Reviewed commits:** `efe1de6` (approved Settings IA design) and `5544c03` (final amended brief and implementation plan)  
**Prior architecture records reviewed:** `VD2-07-preimplementation-architecture-review-2026-08-01.md` and `VD2-07-preimplementation-architecture-recheck-2026-08-01.md`  
**Verdict:** **ACCEPT**

## Decision

The final brief and plan preserve the approved presentation-only extraction.
The unchanged global rail retains its five destinations, and the four Settings
sections are an ephemeral selector inside the existing Settings destination,
not an application route or persisted setting. `ContentView` remains the sole
owner of the `WorkspaceViewModel`, global route, recovery-key text, file-panel
flow, dialogs, alerts, destructive confirmation, and action dispatch.
`SettingsView` receives bounded, display-safe inputs and pre-existing action
closures only.

The final QA corrections are architectural-compatible. The selector's
selection/focus accessibility token adds no state or route; it reports the
existing local presentation state. The new root-modal seam maps existing
root-state facts to existing sheet, alert, and error visibility and invokes
only the existing clear, cancel, and dismiss closures. It retains no model,
recovery key, fixture value, or persistent state, and therefore does not move
modal or action ownership from `ContentView`.

## Evidence reviewed

| Contract | Evidence | Result |
| --- | --- | --- |
| Global rail remains unchanged | `AppShellView.swift` defines the five-entry `AppDestination.sidebarDestinations` collection and the existing `DailyRoute.settings`; the brief prohibits another `AppDestination`, `DailyRoute`, or persisted Settings selection. | Preserved. |
| Settings-local selector only | Design decision; brief §§ Required ownership/Required presentation; plan §§ Global Constraints and Task 2. `SettingsSection` is local `@State`, defaults to `.recoveryArchives`, and changes only the focused Settings panel. | Preserved. |
| Root ownership and bounded callbacks | Current `ContentView.swift` owns the route and Settings state/modifiers. The planned injection passes only display-safe facts and existing closures; the new file is prohibited from holding a model, store, route, sheet, alert, file panel, persistence call, or recovery key. | Preserved. |
| Final root-modal correction | `SettingsRootModalPresentation` derives only restore-sheet, restore-failure-alert, and protected-export-error presentation facts. `SettingsRootModalBindings` only clears/cancels or dismisses through caller-supplied existing closures. The Task-2 regression asserts cancellation/failure dismissal and unchanged active-workspace facts using an empty invalid entry. | Sound; no new behavior or ownership. |
| Data and privacy interfaces | Recovery sections receive summaries and fixed status values; archive summary construction does not retain checksum or fingerprint bytes. Document References receives `DocumentReferenceSummary` only, whose current contract contains only available/relink counts. AI & connections receives no configuration object or action surface. | Bounded. |
| Earlier architecture verification corrections | Both exact Task 1 and Task 2 commands include the mandatory fixture-host, document-summary, archive/restore, protected-export, expiry, purge, inactive-candidate, separate-workspace return, and relaunch selectors. The current named pre-existing selectors resolve in the target files specified by the commands; core archive/export tests are compiled in the `RekonPursuitTests` bundle. | Sound. |
| Final QA verification corrections | The compact selector prescription uses semantic focus and an accessibility value with the required `Selected`/`Not selected` first token and focused suffix, matching the RED/GREEN expectation. The plan also specifies the protected-export error surface and the root restore-cancellation/failure-dismissal regression without a recovery-key value. | Sound. |

The current project source phases support the planned two-target registration:
both the normal app and the UI-test host already compile the same app-facing
source topology, while their test bundles import the corresponding app module.
The plan's one new `SettingsView.swift` reference and one source membership in
each app target are consistent with that topology.

## ADR / deviation outcome

**No ADR is required.** The approved route, ownership, data-flow, privacy, and
recovery contracts are unchanged. The added modal-presentation seam is a
non-persistent observation/binding seam at the existing `ContentView` root,
not an architectural deviation. Any future change that gives `SettingsView` a
model, route, persistence responsibility, recovery-key value, modal ownership,
or broader data interface requires a new ADR before implementation continues.

## Task 1 release limitation

This **ACCEPT** clears the final Architecture plan-review gate only. It does
not release Task 1, authorize implementation, or establish test evidence.
Task 1 may be released only after a fresh independent QA/test acceptance of
the `5544c03` corrections, the separate Security/privacy, TPM, and Delivery
pre-implementation decisions, and a dependency-safe Delivery release. Task 1
remains test-only; Task 2 stays blocked until its signed Task-1 fixture result
is accepted with the exact allowed RED classification and all unchanged
baseline selectors passing.
