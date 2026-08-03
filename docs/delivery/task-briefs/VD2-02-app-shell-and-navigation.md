# VD2-02 — App shell and navigation

## Authority, dependency state, and boundary

This brief implements only Task 2 of the approved
[Visual Design v2 plan](../../superpowers/plans/2026-07-28-visual-design-v2.md)
and its [design specification](../../superpowers/specs/2026-07-28-visual-design-v2-design.md).
It is dependency-safe only after VD2-01 is Accepted and the independent
Architecture, TPM, QA, and Delivery Manager gates release this task.

The deterministic, non-personal UI fixture-host isolation work already present
in the worktree is prerequisite testing infrastructure. It is not a VD2-02
delivery-state transition and must not be folded into this task's product claim.
The current delivery dashboard and SDD state remain unchanged by this planning
brief.

`ContentView` remains the sole owner of the active `WorkspaceViewModel`, route
state, document importers, destructive confirmations, recovery sheets, and
other workspace-mutating dialogs. `AppShellView` is presentation/navigation
infrastructure only: it receives a selected daily destination and forwards an
intent through its existing closure. It must not create a second route model,
mutate persistence, or own recovery state.

## Deliverable

- A responsive native macOS shell using the VD2-01 visual system: deep-navy
  canvas, correct existing Rekon logo treatment, left navigation rail, title
  region, selected-destination treatment, and decorative geometry that is
  noninteractive and accessibility hidden.
- Navigation for Home, Pipeline, Contacts, Activity & AI, and Settings that
  continues to use the canonical daily-route state and preserves current
  destination content.
- A compact-width navigation mode using the existing split-view column
  behavior, without hiding the macOS window controls or relying on OS
  foreground/background colors for readable rail labels, icons, or collapse
  control.
- Keyboard-operable rail navigation, explicit VoiceOver labels/values, visible
  focus, non-color selected-state cues, and reduced-motion-safe transitions.
- Safe departure from opportunity overview/history/reconciliation routes: an
  action through the rail returns through the existing route controller and
  retains its existing unsaved/deleted/recovery safeguards.

## Explicit non-scope

- No redesign of Home, Pipeline table/inspector, Pipeline board, Contacts, or
  Settings content; those are VD2-03 through VD2-07.
- No new opportunity stages, drag/drop, workflow commands, workspace schema,
  persistence, migration, activity-event semantics, recovery/export/archive
  behavior, documents behavior, AI behavior, connected services, or mock data.
- No raster illustrations, fictional company logos, avatars, web frontend,
  cloud service, or changes to the existing approved Rekon logo asset.
- No attempt to resolve unrelated stale whole-suite migration/schema failures
  as part of this slice. They remain a recorded verification risk for milestone
  QA; a focused shell result cannot be used to erase them.

## Files and ownership boundaries

Expected implementation files are limited to:

- `RekonPursuit/AppShellView.swift` — shell presentation, rail semantics,
  sizing, and focused accessibility treatment.
- `RekonPursuit/ContentView.swift` — only the minimal canonical-route bridge
  required to wire shell intent to the existing controller.
- `RekonPursuitUITests/RekonPursuitUITests.swift` — deterministic UI coverage.
- A focused unit-test file only if a small, pure shell layout/accessibility
  policy is extracted for deterministic testing.

The fixture host and fixture-host tests may be amended only if a missing
deterministic fixture state prevents a focused test. Any such edit must remain
compile-time isolated from the production target and independently re-reviewed.
Do not change `WorkspaceViewModel`, stores, database/schema migration code, or
recovery/export implementations for this task.

## Test-first contract

The implementer must add the following focused red tests before changing shell
production code, run them to capture the expected failure, then make the
smallest change that turns them green.

| Contract | Required deterministic proof |
| --- | --- |
| Route ownership | In a populated fixture, activating each visible rail destination changes the displayed daily route without creating, deleting, editing, or selecting a new workspace record. |
| Selected rail state | Each active destination exposes a stable identifier, explicit accessibility label/value, visible focus, text/icon contrast, and an active cue that is not color alone. Only the current destination is selected. |
| Keyboard access | Tab/keyboard focus reaches every rail destination and the collapse/restore control; Space/Return activates the focused destination. |
| Responsive shell | At supported compact, default, and wide window sizes, the rail remains operable; collapse/restore retains access to all five destinations and does not obscure the standard macOS window controls. |
| Opportunity departure | From overview, history, and reconciliation subroutes, choosing a rail destination follows the canonical safe-departure path; the selected opportunity UI does not leak into the destination and existing block/confirmation behavior is preserved. |
| Recovery containment | In the recovery fixture, only recovery-safe controls are exposed. Recheck/return actions do not create a workspace or expose normal-destination content. |
| Fixture privacy | All UI tests launch the isolated fixture host with an explicit fixture ID. No test reads a personal workspace, keychain namespace, or live application support database. |

Test names may differ, but the suite must contain distinct evidence equivalent
to `testShellDestinationsActivateCanonicalRoutes`,
`testSelectedRailStateAndKeyboardActivation`,
`testShellIsUsableAtCompactDefaultAndWideWidths`,
`testSidebarDepartureFromOpportunitySubroutesIsSafe`, and
`testRecoveryFixtureContainsNormalNavigation`.

The first run must record which assertions are red and why. A pre-existing
passing test is not red evidence; add or tighten the assertion until it proves
the missing behavior. Do not use screenshot pixel matching as the primary
contract; assert semantic identifiers, route content, accessibility properties,
and interaction behavior, then use visual smoke for presentation quality.

## Implementation sequence

1. **Freeze the boundary.** Rebase the focused task on the reviewed VD2-01
   token layer and fixture-host prerequisite. Record the exact baseline working
   tree and do not mix unrelated fixture or user changes with shell edits.
2. **Write and run the focused red tests.** Cover the route, accessibility,
   compact/wide, recovery, and safe-departure contracts above using only named
   fixtures. Capture the red result in task evidence.
3. **Build the shell presentation.** Apply VD2-01 semantic tokens to the
   navigation split view, rail, title region, button/focus treatment, and
   native geometry. Use fixed semantic colors for the app-owned rail text,
   icons, and collapse control so system appearance changes cannot make them
   disappear.
4. **Wire intent, not state.** If a bridge adjustment is necessary, keep
   `ContentView` as the single canonical route/dialog owner and forward rail
   intent through the current daily-navigation controller. Verify route
   departure before adding any presentation animation.
5. **Make compact behavior explicit.** Use the split-view visibility model and
   accessible collapse/restore control. Do not simulate or replace macOS
   traffic lights, force a custom title-bar behavior, or introduce fixed window
   sizes.
6. **Green focused suite and visual pass.** Run the focused unit/UI tests,
   compile Debug, inspect the actual signed Debug app at compact/default/wide,
   keyboard-only, VoiceOver, light/dark system appearance, and Reduce Motion.
   Correct only findings within this task boundary.
7. **Independent gates.** A fresh code reviewer, QA verifier, Architect, and
   proportional security/privacy verifier review the implementation and
   evidence. Material findings return the task to the implementer, followed by
   re-review and re-verification. The Delivery Manager records completion only
   after all gates and hands-on product-owner acceptance.

## Verification evidence

Run the repository's documented macOS Debug build and focused XCTest/XCUITest
commands. At minimum, retain output for:

```sh
xcodebuild -project RekonPursuit.xcodeproj -scheme RekonPursuit \
  -configuration Debug -destination 'platform=macOS' \
  -only-testing:RekonPursuitUITests test

xcodebuild -project RekonPursuit.xcodeproj -scheme RekonPursuit \
  -configuration Debug -destination 'platform=macOS' build

git diff --check
```

If the fixture host uses a dedicated test target, run its documented focused
command in addition to—not instead of—the shell UI suite. Report any whole
suite failure separately with a cause and scope; do not silently omit it.

## Hands-on acceptance path

The product owner receives a signed Debug handoff and performs this short
path against a test workspace, not a personal production workspace:

1. Launch at default width, then resize to compact and wide widths; confirm
   consistent deep-navy app-owned chrome, readable rail labels/icons, visible
   macOS controls, and a usable collapse/restore control.
2. Visit Home, Pipeline, Contacts, Activity & AI, and Settings by mouse and
   keyboard. Confirm the selected rail item has its left indicator, focus, and
   non-color selected cue, and that the destination title/content matches.
3. Open an opportunity, visit its overview/history/reconciliation route as
   available, then use a rail item to leave. Confirm normal content returns and
   no stale detail state or unsafe discard occurs.
4. Launch the recovery scenario and confirm normal content is not exposed;
   use only its existing safe recovery actions and confirm no workspace data is
   created or changed.
5. Enable Reduce Motion and switch system appearance; confirm there is no
   excessive shell animation and no unreadable app-owned navigation text or
   iconography.

Acceptance requires the owner's explicit approval after this path. Passing
tests, review, or a commit alone does not make VD2-02 Accepted.

## Risks and release conditions

- `AppShellView` and `ContentView` are shared integration points. No parallel
  implementation work may edit these files without an explicit integration
  owner and serialized merge plan.
- Customizing app-owned chrome can conflict with macOS title-bar/full-screen
  behavior. The task must preserve native controls rather than drawing fake
  traffic lights or depending on an opaque host background.
- Route and recovery regressions are higher risk than visual polish because
  they can expose or mutate local workspace state. The fixture-host boundary
  and recovery containment proofs are release conditions.
- Broad migration/schema failures observed outside this scope must stay visible
  in the QA ledger. They require separate triage before overall VD2-08
  completion if they still reproduce.

## Gate checklist

- [ ] VD2-01 acceptance and reviewed fixture-host prerequisite confirmed.
- [ ] Planning, Architect, TPM, QA, and Delivery Manager approve this brief and
      release VD2-02.
- [ ] Focused red evidence recorded before production implementation.
- [ ] Implementer completes bounded change and focused green evidence.
- [ ] Independent code review, QA, Architect, and security/privacy verification
      complete with material findings resolved and re-reviewed.
- [ ] Product-owner hands-on path accepted.
- [ ] Delivery Manager updates the SDD, dashboard JSON, detailed delivery
      ledger, and generated dashboard HTML together for the real transition.
