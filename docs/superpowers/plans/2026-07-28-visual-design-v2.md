# Visual Design v2 Implementation Plan

> **Execution model:** Required sub-skill: `superpowers:subagent-driven-development`.
> Every implementation task is delivered by a fresh implementer, then independently
> code-reviewed, QA-verified, and security/privacy-verified. The security/privacy
> verification is proportional for presentation-only slices and deep for VD2-05
> and VD2-07, but is never omitted.

**Goal:** Rework the native macOS SwiftUI application to the approved Rekon
Pursuit design system while preserving live local data, local-first recovery,
auditing, and existing workflow semantics.

**Architecture:** Expand the existing `RekonTheme`/`AppShellView` seam into a
semantic visual system. Keep `ContentView` as the sole `WorkspaceViewModel`
owner and route owner; extract presentation views/components around it. Keep
the existing `WorkspaceViewModel.changeStage(_:to:)` command as the only board
stage mutation boundary. The dashboard remains static, local-file-compatible
delivery tracking; it is not part of the app UI.

**Tech stack:** SwiftUI/AppKit, existing SQLCipher local store and models,
XCTest/XCUITest, existing Python delivery-dashboard renderer.

## Governing references

- `docs/superpowers/specs/2026-07-28-visual-design-v2-design.md`
- `docs/delivery/dashboard-status.json`
- `docs/delivery/roadmap.md`
- `AGENTS.md`
- Product-owner supplied reference images listed in the Visual Design v2 spec.

## Global constraints

- Native macOS SwiftUI only; no web frontend, browser storage, cloud service,
  plugin, external asset, or new dependency.
- Use the existing Rekon logo/emblem. Build decoration from SwiftUI gradient and
  geometry; do not fabricate company logos, avatars, recruiters, dates, or data.
- `ContentView` remains sole view-model and route owner. New visual selection,
  hover, and drag state is ephemeral.
- Preserve route safety, local persistence, activity/audit behavior,
  reconciliation closure guard, recovery/export/archive/document behavior, and
  privacy claims.
- A stage move is never client-only: it must use the existing persisted
  transactional command, then render from the refreshed source of truth.
- Preserve or deliberately compatibility-test accessibility identifiers.
- All owner handoffs use the existing signed Debug workflow. No task becomes
  Accepted from a test/commit alone.
- Current shared SwiftUI seams require serial release in the card order below.
- At each real state transition update JSON, roadmap, dashboard operational
  record, generated HTML, and SDD evidence together. The authoritative
  non-remediation delivery record for this program is the **Visual Design v2**
  section in `docs/delivery/roadmap.md`; do not record VD2 acceptance evidence
  in `docs/delivery/remediation-ledger.md`.

## Prerequisite release record

Before VD2-01 implementation, create the program roll-up and child cards in
the active `post_mvp_refinement` dashboard phase:

- `DESIGN-V2` remains Backlog but is retitled **Visual Design v2 program** and
  marked `workType: Program`.
- `VD2-01` is Next up only after this plan receives all five independent gate
  approvals; `VD2-02` through `VD2-08` are Backlog.
- `activeTaskId` stays null until the Delivery Manager formally starts VD2-01.
- Each child starts with `evidence` pointing at its governed task brief (or this
  plan until the brief exists) and `needsUserAction: false`. At a completed
  owner-smoke handoff only, its card sets `needsUserAction: true`; it resets to
  `false` when the owner accepts the card and review evidence replaces the
  planning evidence. This is the only VD2 attention-queue condition.
- `activePhaseId` stays `post_mvp_refinement`; `UX-D10`–`UX-D12` and Phase 2+
  remain untouched Backlog work.

Create `.superpowers/sdd/2026-07-28-visual-design-v2/progress.md` with the
program/card map, gate records, review evidence, risks, and each transition.

## Task 1 — VD2-01: Visual foundation and tokens

**Files:**
- Modify: `RekonPursuit/AppShellView.swift`
- Create: `RekonPursuit/RekonVisualTheme.swift` (or an equally focused theme
  component file if extraction is necessary)
- Modify: `RekonPursuitTests/RekonPursuitTests.swift`
- Modify: `RekonPursuitUITests/RekonPursuitUITests.swift`

**Test first:**
1. Add deterministic theme/component checks for semantic colors, selected,
   pressed, disabled, focused states, and the exact known `RekonEmblem` asset.
2. Define and add a stable, non-personal app launch-fixture contract: an
   explicit launch argument and fixture ID, an isolated temporary store/keychain
   namespace, a fixed clock/time-zone, deterministic empty/populated/recovery/
   error/archive/document-relink fixtures, and UI-test teardown. The normal
   launch path must remain untouched and fixture mode must never read a personal
   workspace. Add accessibility identifier assertions for shell/focus targets.
3. Run the focused tests and confirm failure before implementation.

**Implementation:**
1. Introduce semantic background/surface/border/text/status/action tokens,
   type/spacing/radius/elevation scales, card/field/button styles, and focus
   ring. Use restrained cyan/violet gradients only for action/selected accents.
2. Add a noninteractive, accessibility-hidden geometry/gradient background
   treatment and correct existing logo/emblem usage; no raster art additions.
3. Honor `accessibilityReduceMotion` for all decorative effects and guarantee
   non-color state cues.

**Verify:**
- focused XCTest/XCUITest suite, Debug build, compact/default/wide visual
  sampler, Dynamic Type and Reduce Motion smoke, manual contrast/focus review,
  and proportional independent security/privacy verification that confirms no
  data collection, network, persistence, entitlement, or local-data exposure
  change.
- Independent reviewer and QA confirm no model/store/activity behavior change.

**Hands-on path:** Open the signed Debug handoff; navigate between existing
screens and confirm the shared visual foundation, keyboard focus, reduced
motion, and unchanged workspace behavior.

## Task 2 — VD2-02: App shell and navigation

**Files:**
- Modify: `RekonPursuit/AppShellView.swift`
- Modify: `RekonPursuit/ContentView.swift`
- Modify: `RekonPursuitUITests/RekonPursuitUITests.swift`

**Test first:** Add UI tests for every sidebar destination, selected state,
keyboard traversal, VoiceOver labels, compact/default/wide layout, onboarding
recovery navigation, and safe departure from opportunity routes.

**Implementation:**
1. Build the rail/header/background/split layout from VD2-01 components.
2. Preserve `DailyRoute`, `OpportunityRoute`, recovery dialogs, document
importer, destructive confirmations, and file dialogs; do not move route state
into the shell.
3. Support compact window behavior with an accessible usable navigation
alternative instead of unreadable shrinking.

**Verify:** Focused UI suite, all existing route tests, Debug build, independent
code review/QA, proportional security/privacy verification, and architectural
route-boundary review.

**Hands-on path:** Resize the signed Debug build at 860×600, normal, and wide;
use keyboard only to visit every destination; open and return from an
opportunity and recovery state.

## Task 3 — VD2-03: Home redesign

**Files:**
- Extract/create: `RekonPursuit/HomeView.swift`
- Modify narrowly: `RekonPursuit/ContentView.swift`, `WorkspaceViewModel.swift`
- Modify: `RekonPursuitTests/WorkspaceViewModelTests.swift`
- Modify: `RekonPursuitUITests/RekonPursuitUITests.swift`

**Test first:** Fixture-driven view-model tests for attention ordering, empty
state, active opportunities, applied-this-week (local calendar-week rule),
interviews, next actions, recovery/error state, and zero mutation on read.
UI tests cover Open/Snooze/Reschedule/Complete and relaunch persistence.

**Implementation:** Render Needs Attention first, real pipeline snapshot
metrics, and real upcoming tasks using the approved hierarchy. Decorative
surfaces must not conceal missing data; unsupported metrics are omitted.

**Verify:** Focused tests, app manual at supported window sizes, independent
review/QA, proportional security/privacy verification, and owner test of task
action persistence.

## Task 4 — VD2-04: Pipeline table and inspector

**Files:**
- Extract/create: `RekonPursuit/PipelineView.swift`, table/inspector components
- Modify narrowly: `ContentView.swift`, `WorkspaceViewModel.swift`
- Modify: `WorkspaceViewModelTests.swift`, `RekonPursuitUITests.swift`

**Test first:** Case-insensitive multi-token search; stage and closed filters;
selection/route/back behavior; empty state; inspector matching its selected
record; saved edits and relaunch persistence. Explicitly prove table selection
is ephemeral: selecting a row to populate the inspector does not call
`model.select(_)`, mutate `selectedOpportunityID`, reload a canonical draft, or
change the current route. Only **Open details** may select and route to the
canonical overview.

**Implementation:** Build reference-inspired toolbar, table/list presentation,
read-only inspector, board toggle boundary, responsive compact layout, and
Open details action. Inspector selection is local ephemeral view state. The
inspector is not a second editor; canonical editing stays in
`OpportunityRoute.overview`.

**Verify:** Existing import/reconcile/history routes plus focused table tests,
independent code review/QA, proportional security/privacy verification, and
architecture selection-boundary review.

**Hands-on path:** Search multiple terms, filter stage, select several records,
open details/save, return, and relaunch to confirm no stale selection/data.

## Task 5 — VD2-05: Pipeline board and persisted stage movement

**Files:**
- Create: `RekonPursuit/PipelineBoardView.swift`
- Modify narrowly: `PipelineView.swift`, `WorkspaceViewModel.swift`
- Modify: `WorkspaceViewModelTests.swift`, `RekonPursuitTests.swift`,
  `RekonPursuitUITests.swift`

**Test first:** Define a typed `StageMoveResult` at the view-model boundary,
then add store/view-model regression tests for `.persisted`, `.noOp`,
`.reconciliationBlocked`, `.unavailable`, and `.failed` outcomes. Cover valid
moves, same-stage no-op, rejected missing/closed-unconfirmed moves, store or
refresh failure rollback, activity event, stage history, refreshed lane counts,
and relaunch persistence. UI/manual tests cover drag, drop outside/cancel, a
stable identified **Move to stage** keyboard/VoiceOver menu with every valid
target label, matching disabled/blocked outcome copy, and Reduce Motion.

**Implementation:** Build truthful context-rich stage cards with SF-symbol or
initial fallbacks only. Introduce a structured stage-move result returned only
after refresh; it distinguishes persisted move, same-stage no-op,
reconciliation-blocked close, unavailable/deleted record, and store/refresh
failure. Use a payload containing opportunity ID, validate target, and invoke
only `WorkspaceViewModel.changeStage(_:to:)`. Animate drag lift and drop hover
only; commit the lane change only after `.persisted`. All other outcomes retain
source placement and expose their matching accessible error. The identified
**Move to stage** menu/action is the complete keyboard and VoiceOver
alternative; native drag/drop is never the only stage-move path.

**Verify:** Focused persistence/audit tests, full stage-move regression,
independent code review, QA, and security/privacy verification.

**Hands-on path:** Move a non-closed record between stages, relaunch to verify
persistence/activity; attempt a reconciliation-blocked Close move; use the
keyboard alternative and Reduce Motion.

## Task 6 — VD2-06: Contacts master/detail redesign

**Files:**
- Extract/create: `RekonPursuit/ContactsView.swift`, contact detail components
- Modify narrowly: `ContentView.swift`, `WorkspaceViewModel.swift`
- Modify: `WorkspaceViewModelTests.swift`, `RekonPursuitUITests.swift`

**Test first:** Contact search/filter/selection, validation, employer
association, scrolling/compact behavior, on-demand related-opportunity
disclosure, delete/open route, and relaunch/persistence checks.

**Implementation:** Build scrollable master/detail Contacts view using real
contacts. Keep employer/linked opportunity lists collapsed until explicit
disclosure; preserve current email/profile validation and activity behavior.

**Verify:** Focused tests, keyboard/VoiceOver/resize smoke, independent review,
QA, and proportional security/privacy verification.

**Hands-on path:** Filter contacts, select a record, expand/collapse related
opportunities, open one canonical opportunity, then edit/save/relaunch.

## Task 7 — VD2-07: Settings information architecture

**Files:**
- Extract/create: `RekonPursuit/SettingsView.swift`, focused setting cards
- Modify narrowly: `ContentView.swift`
- Modify: existing recovery/export/document tests and UI tests

**Test first:** Re-run and extend regression coverage for recovery/archive
create/verify/expiry/purge using an injected fixed clock, protected export
destination binding/confirm/error/cancel with no recovery-key value in UI,
logs, or test artifacts, inactive restore, separate workspace recovery, and
document reference/relink. UI tests must use fixture state and verify accessible
alerts and busy/disabled controls.

**Implementation:** Recompose existing Workspace, Recovery & archives,
Document references, and AI & connections content into truthful cards. No
lifecycle semantic or security behavior may change.

**Verify:** Existing suite + focused Settings UI suite + signed Debug smoke;
independent code review, QA, and mandatory security/privacy verification.

**Hands-on path:** In the signed Debug app exercise an archive/export
confirmation/cancel or restore flow without changing the current workspace;
verify disabled/error/cancel states remain clear.

## Task 8 — VD2-08: Visual QA and accessibility acceptance

**Files:**
- Modify only as test/evidence findings require: test suites, delivery evidence,
  roadmap/dashboard/ledger/SDD records.

**Test first / execution:**
1. Run all unit/UI tests with deterministic fixture launch states.
2. Debug and Release build; `git diff --check`; existing entitlement/security
checks; dashboard renderer/test/check.
3. Produce an auditable visual/accessibility evidence matrix for Home, Pipeline
table/board, Contacts, Activity & AI, Settings, onboarding/recovery, and
opportunity routes. For each screen/state record stable screenshot or manual
check artifact at 860×600, 1100×760, default, and wide layouts; large text;
Reduce Motion; and supported macOS appearance.
4. Record keyboard-only and VoiceOver/Accessibility Inspector pass evidence,
contrast and visible-focus review, and relaunch persistence checks for
stage/contact/document/recovery flows.

**Acceptance:** A separate reviewer, QA, and security/privacy verifier approve.
Product owner receives a concise signed Debug verification checklist and
explicitly accepts VD2-08. Every earlier child has already been accepted
individually through its own
`Backlog → Next up → In progress → review/QA/security → owner smoke → Accepted`
transition before its successor released. Only then does the Delivery Manager
marks `DESIGN-V2` Accepted and updates the static dashboard/ledger/roadmap
together.
