# VD2-07 Settings information architecture — pre-implementation TPM review

**Date:** 2026-08-01
**Role:** Independent Technical Program Manager
**Reviewed commits:** `efe1de6` (approved design) and `5544c03` (final brief and test-first plan)
**Verdict:** **ACCEPT** — recommend that Delivery release **Task 1 only** as the next dependency-safe, test-only RED slice. This is not a release of Task 2, Task 3, or VD2-07 acceptance.

## Decision

The controlling queue has `activeTaskId: null` and `nextEligibleTaskId: VD2-07`.
`VD2-02` and `VD2-06` are accepted, while `VD2-08` remains blocked until
VD2-07 is accepted. The final design, task brief, and implementation plan now
exist, and the final independent Architecture, QA/test, and Security/privacy
reviews each return **ACCEPT** for pre-implementation planning. This record
supplies the independent TPM decision required by the brief's serial-release
table.

The only execution concern in the final QA record was not a product or plan
defect: its otherwise signed baseline could not start its one UI selector
because macOS timed out while enabling XCTest automation. The record correctly
did not classify that infrastructure failure as Task 1 RED evidence. Fresh
post-review diagnostics now resolve that *runner-availability* concern:

| Fresh signed diagnostic | DerivedData / result bundle | Result | Selector duration |
| --- | --- | --- | --- |
| Probe | `/private/tmp/rekon-vd207-ui-probe-528107EA-52FF-45C4-9B8F-B8B854BA02AD-dd` / `/private/tmp/rekon-vd207-ui-probe-528107EA-52FF-45C4-9B8F-B8B854BA02AD.xcresult` | `xcodebuild test` selected exactly `RekonPursuitUITests/testRecoveryFixtureShowsOnlyRecoveryActionsAndDoesNotOpenAWorkspace`; 1 passed, 0 failed, 0 skipped | 7.58424699306488 s |
| Repeat | `/private/tmp/rekon-vd207-ui-repeat-8A24B025-7154-4E63-AE85-F9B5C5F95893-dd` / `/private/tmp/rekon-vd207-ui-repeat-8A24B025-7154-4E63-AE85-F9B5C5F95893.xcresult` | The same single selector passed again; 1 passed, 0 failed, 0 skipped | 7.592511057853699 s |

I independently read both result summaries and test trees with
`xcresulttool`: each names the required recovery-only UI selector once and
reports `Passed`. The paths are distinct, so the second result is not a reused
DerivedData or result bundle. Both resulting Debug apps also pass
`codesign --verify --deep --strict` and report the configured Apple
Development signing chain. The existing XCTest runtime warning attached under
the test node did not fail either run; it is a watch item, not a release
blocker.

These diagnostic runs are deliberately **not** presented as Task 1 evidence:
they do not contain the five future VD2-07 test methods and therefore cannot
establish the required absent-selector/panel RED classification. They do prove
that the previously unavailable signed UI automation path is presently capable
of launching the existing recovery fixture. Task 1 is the correct next slice
to add those tests and produce the exact classified result.

## Dependency and gate status

| Requirement | Authority and current evidence | Status |
| --- | --- | --- |
| Upstream visual dependencies | Dashboard and roadmap record `VD2-02` and `VD2-06` as accepted. | Satisfied |
| Approved Settings design | `efe1de6` adds the approved VD2-07 design only; its diff is clean. | Satisfied |
| Complete test-first brief and plan | `5544c03` supplies the final corrected brief/plan only; its diff is clean. The brief makes Task 1 test-only. | Satisfied |
| Architecture plan gate | `VD2-07-preimplementation-architecture-final-2026-08-01.md` is **ACCEPT**. | Satisfied |
| QA/test plan gate | `VD2-07-preimplementation-qa-final-2026-08-01.md` is **ACCEPT**; the earlier UI automation initialization limitation is superseded as runner-capacity evidence by the two fresh signed diagnostics above. | Satisfied for Task 1 release; Task 1 execution evidence remains pending |
| Security/privacy plan gate | `VD2-07-preimplementation-security-privacy-final-2026-08-01.md` is **ACCEPT**. | Satisfied |
| TPM plan gate | This independent review. | Satisfied |
| Delivery release | The dashboard remains `next_up`; no Delivery Manager release is recorded yet. | Pending — Delivery-owned action |

## Release recommendation and constraints

**Delivery may release Task 1 now.** Its scope is strictly the six named,
test-only additions: five `testVD207...` UI RED methods and the protected
export cancellation/no-write unit regression. It must not create
`SettingsView.swift`, move a `ContentView` modifier, change the project graph,
or alter recovery, archive, export, purge, restore, document, AI, persistence,
fixture, signing, routing, or network behavior.

The Task 1 signed command must still produce the exact evidence defined by the
brief and plan: every named current lower-layer, fixture-host, and
recovery-only selector executes once as passed without skip; each of the five
new UI tests reaches a ready fixture and fails only because the named
`settings-*` selector/panel is absent. A build, signing, fixture launch,
global-rail, accessibility-query, unrelated baseline, or UI-runner failure is
blocking—not allowed RED. Preserve the result bundle and use the mandated
hunk-isolated checkpoint because this shared worktree is intentionally dirty.

## Milestone risks and downstream gates

- The current diagnostic proves only one existing UI selector; it reduces the
  automation-startup risk but does not replace the exact Task 1 matrix.
- The prior runtime warning remains non-failing but should be recorded if it
  recurs in Task 1 evidence or begins to affect timing/stability.
- Task 2 remains **blocked** until a fresh independent QA verifier accepts the
  classified Task 1 signed RED and its fixture/lower-layer baseline. It is then
  subject to Architecture, TPM, and Delivery continuation approval.
- Task 3 remains blocked until Task 2 GREEN plus separate Code Review, QA,
  Architecture, Security/privacy, TPM, and Delivery decisions. Product-owner
  hands-on acceptance remains after that evidence.
- `VD2-08` stays Backlog and blocked. Its three owner-approved VD2-06
  accessibility/recovery automation debts are neither absorbed nor resolved by
  this release.

No dashboard, roadmap, progress ledger, plan, brief, specification, source,
project, index, or commit was changed by this review.
