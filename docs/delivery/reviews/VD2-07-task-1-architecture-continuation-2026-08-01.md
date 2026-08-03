# VD2-07 Task 1 — architecture continuation review

**Date:** 2026-08-01  
**Role:** Fresh independent Architect  
**Verdict:** **ACCEPT**

## Decision

The six Task-1 test-only contracts remain compatible with the approved
Settings information architecture. They require a retained global rail and a
Settings-local selector only; they do not introduce a route, persisted
selection, model/store ownership, recovery-key transport, or production-code
change. The Task-2 extraction may proceed on the architecture gate, subject to
the separate TPM and Delivery continuation decisions.

## Independent evidence reviewed

- Approved design: `docs/superpowers/specs/2026-08-01-vd207-settings-information-architecture-design.md`
- Task brief and full implementation plan, including Task 1 and Task 2
  contracts
- Task-1 implementation report, independent code review, and independent QA
  verification
- The six named methods only:
  - `RekonPursuitUITests/RekonPursuitUITests.swift:2629-2796`
  - `RekonPursuitTests/WorkspaceViewModelTests.swift:660-690`
- Retained `/private/tmp/rekon-vd207-task-1-red.xcresult` directly:
  **33 executed; 28 passed; 5 failed; 0 skipped; 0 expected failures**.
  Each new UI method ran once and the unit regression passed once. The five
  failures are the absent `settings-*` selector/panel boundary, not a build,
  signing, fixture, rail, or lower-layer failure. `git diff --check` is clean.

| Approved architecture contract | Task-1 contract evidence | Assessment |
| --- | --- | --- |
| Global rail is retained; Settings selection is local only | The first UI contract holds `sidebar-settings` selected while changing all three non-default Settings sections; the compact contract uses semantic focus/Space only. | Compatible; neither test creates or depends on a global Settings sub-route. |
| Recovery & archives defaults and resets on relaunch | The default/relaunch contracts require `Recovery & archives` after route entry and after terminating/relaunching the same UUID-qualified fixture session, while the aggregate document truth remains unchanged. | Compatible; this is evidence for ephemeral local state, not persistence. |
| `ContentView` remains root owner of recovery actions and cancellation | The archive contract enters existing archive/export/purge presentations through existing identifiers, cancels without entering a key or selecting an export destination, and rechecks durable archive truth. The unit regression proves cancelling a reviewed export clears review/error without writing or changing active-workspace facts. | Compatible; the contracts preserve existing root flow ownership and prohibit new action paths. |
| Display-safe document and AI sections | The document/AI contract requires aggregate-only counts, forbids document metadata and actionable child controls, and requires the unconfigured AI/Gmail/Calendar wording with no controls. | Compatible; no document/store/configuration interface is needed. |
| No persistence, model, store, or security-boundary deviation | The only uniquely named Task-1 additions are five UI methods and one unit method in the two permitted test files. The recovery key is generated in unit-test memory only and is not logged, attached, or fixture-transported. | Compatible; Task 1 adds no production code. |

## ADR and constraints

**ADR required:** No. The test contracts exercise the approved local-selector
and `ContentView`-owned-flow design without changing its ownership, routing,
data, persistence, or security boundaries.

**Open constraints for Task 2:** Keep the six Task-1 tests unchanged except
for their expected transition from RED to GREEN. `SettingsView` must keep its
selection as local non-persisted presentation state; `ContentView` must retain
all model, global-route, file-panel, sheet, alert, recovery-key, cancellation,
and action ownership. Do not widen the document or AI input surfaces or alter
the lower-layer recovery/export/archive contracts.

The RED result bundle contains XCTest-generated failure diagnostics for the
absent-selector failures; the six test methods do not create attachments and
do not enter a recovery key. These runner diagnostics are not an architecture
deviation. The mandated later security/privacy evidence review must still
inspect retained Task-2 artifacts for secret or document-metadata disclosure.

## Continuation recommendation

**Architecture gate: release-eligible for Task 2.** Task 2 may start only
after the independent TPM and Delivery continuation gates record their own
acceptance. This decision does not approve Task-2 implementation details that
deviate from the controlling design; any such ownership, routing, persistence,
or data-boundary change requires an ADR first.
