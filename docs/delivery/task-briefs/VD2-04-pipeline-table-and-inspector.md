# VD2-04 — Pipeline table and inspector

## Outcome

Replace the current compact Pipeline list with the approved Visual Design v2
table and a read-only, ephemeral inspector while continuing to render only the
active local workspace. The table is the default Pipeline view. It supports
case-insensitive multi-token search, stage and closed-record filtering, and a
compact usable layout. Selecting a table row changes only the local
presentation selection; **Open details** is the sole table/inspector control
that enters the existing canonical opportunity route.

This card is presentation and navigation work. It does not introduce a new
opportunity editor, mutate a stage, alter a task, change the store schema, or
alter local recovery, document, reconciliation, or audit semantics.

## Controlling inputs and release position

- Approved product direction:
  `docs/superpowers/specs/2026-07-28-visual-design-v2-design.md`.
- Program plan: `docs/superpowers/plans/2026-07-28-visual-design-v2.md`, Task
  4.
- VD2-03 is accepted. `VD2-04` is the sole Next-up child and must be completed
  before `VD2-05`; no concurrent edit may be made to `ContentView.swift`,
  `WorkspaceViewModel.swift`, or the Pipeline presentation seam.
- The existing baseline is the private `PipelineView` in
  `RekonPursuit/ContentView.swift`, the canonical route owner in `ContentView`,
  and `WorkspaceViewModel.filteredOpportunities`.

## Approved scope decision — local Closed visibility

**Decision (product owner, 2026-07-30):** VD2-04 may remove the obsolete
global **Show closed opportunities** Settings control and its
`UserDefaults`-backed model state. The Pipeline Closed control becomes the
sole session-local visibility decision for this behavior. This is a narrow
consistency correction, not a Settings redesign.

**Architectural rationale:** keeping the persisted global control after
Pipeline moves to a local filter would leave a visible Settings value with no
effect, while retaining it in the Pipeline path would violate the approved
ephemeral presentation-state boundary. Removing the obsolete preference avoids
both split sources of truth and hidden cross-destination state.

**VD2-07 boundary:** this authorization covers only the named control, its
backing preference/state, and direct tests or copy necessary to retire it. It
does not authorize information-architecture, grouping, other Settings
controls, connectivity/privacy settings, or any broader Settings visual work;
those remain exclusively in VD2-07.

Durable record: `docs/delivery/evidence/visual-design-v2/VD2-04-closed-filter-scope-decision-2026-07-30.md`.

## Architecture and state contract

1. `ContentView` remains the only owner of `WorkspaceViewModel`,
   `DailyNavigationState`, `OpportunityRoute`, document dialogs, destructive
   confirmations, `pipelineAnchorID`, and the return-to-Pipeline route
   behavior. Extraction may make `PipelineView` and focused table/inspector
   components non-private, but they receive callbacks/bindings only; they must
   not create a model, navigation state, route, dialog, or anchor owner.
2. The Pipeline table owns a local `@State private var selectedTableID:
   String?`. That ID is ephemeral, never persisted, and must be cleared if its
   record no longer exists or is filtered out. It must not bind to
   `WorkspaceViewModel.selectedOpportunityID`.
3. Selecting a row to show the inspector must not call `model.select(_)`,
   `selectRouteOpportunity(id:)`, or `navigateToRouteOpportunity(id:)`; it must
   not load a canonical draft, append an activity event, change a route, or
   change `selectedOpportunityID`. It is derived from the current filtered
   snapshot and clears on filter change, delete, and relaunch.
4. The inspector receives the selected `Opportunity` value from the currently
   filtered, refreshed snapshot. It is a read-only summary. Its only
   record-opening control calls the existing `open(opportunity)` callback,
   which ultimately calls `ContentView.openOpportunity(_:)` and establishes
   `.overview(opportunity.id)` through the canonical route boundary.
5. Existing field truth rules apply. Render title, company, stage, location,
   work arrangement, next action, due date, and derived urgency only when the
   persisted value exists; omit absent optional data and use a clear no-action
   state rather than invented metadata. Status requires text/icon as well as
   color.
6. Search, stage, and Closed controls are Pipeline presentation/session state,
   not global preferences: specifically, Closed visibility is a local
   `@State` binding initialized for each Pipeline session and must not read or
   write `UserDefaults`. The query is case-insensitive whitespace-token AND
   matching across title and company. A distinct Closed toggle controls whether
   Closed records are eligible after the stage filter; it is not a hidden
   side-effect of an unrelated application-wide setting.
7. Keep the current Table/Board segmented control and `showsBoard` binding as
   a view boundary. VD2-04 does not redesign board cards or add drag/drop,
   keyboard stage moves, typed results, or a client-side stage mutation. Those
   belong exclusively to VD2-05.

## Bounded implementation slices (one serial card)

### Slice A — deterministic pipeline projection and filter contract

**Files expected:**

- Modify narrowly: `RekonPursuit/WorkspaceViewModel.swift`
- Modify: `RekonPursuitTests/WorkspaceViewModelTests.swift`

**Test-first work:**

1. Add a model test with persisted records such as `Senior Product Manager /`
   `Northstar Labs`, `Designer / Northstar Labs`, and a Closed record. Set
   the pure projection query input to `"northstar senior"` and prove matching is
   case-insensitive and each whitespace-delimited term must occur across the
   persisted title/company search surface. Reverse the terms and prove the
   result is identical; use a nonmatching second token to prove it is excluded.
2. Add a test for stage filtering and session-scoped Closed visibility:
   Saved + Screening + Closed fixture records, a specific stage filter, and
   an explicit `includesClosed` false/true filter input. The Closed toggle must
   be the only visibility control for Closed rows; no test may consult or
   mutate the global `showClosedOpportunities` UserDefaults-backed preference.
3. Add a test that filtering is a read-only projection: retain
   `opportunities`, `selectedOpportunityID`, activity-event IDs, stage-history
   IDs, and store rows before and after repeated search/filter reads. They must
   be unchanged.
4. Run only the new focused tests first and record their expected RED state.

**Minimal implementation:**

- Provide a pure/read-only filtered projection that accepts query, stage, and
  `includesClosed` inputs (or an equivalently testable projection seam), rather
  than binding the table to global filter preferences. Change matching from
  whole-field substring to whitespace-token AND matching across the truthful
  title/company search surface. Keep a blank query as all records allowed by
  the stage/Closed inputs; do not add a persistence write or network call.
- Retire `showClosedOpportunities` from the Pipeline filtering path and remove
  its `UserDefaults` side effect only after confirming no other destination
  consumes it. VD2-04 must not replace it with a new global preference.
- Preserve stable source ordering unless an existing documented ordering is
  already used. Do not invent ranking, score, activity, or urgency persistence.

**Pass condition:** focused model tests pass and an existing Pipeline filter
test (if present) remains green.

### Slice B — responsive table and read-only local inspector

**Files expected:**

- Create: `RekonPursuit/PipelineView.swift` (or a comparably focused Pipeline
  presentation file)
- Modify narrowly: `RekonPursuit/ContentView.swift`
- Modify: `RekonPursuitUITests/RekonPursuitUITests.swift`

**Test-first work:**

1. Add fixture-driven UI coverage for the deterministic `pipeline` fixture that asserts the
   Pipeline destination exposes stable identifiers for the table, its search
   field, stage filter, closed-record control, table row, inspector, selection
   summary, and Open details. Identifiers must include the real opportunity ID
   only where the record-specific control needs it, e.g.
   `pipeline-table-row-<id>`, `pipeline-inspector-<id>`, and
   `pipeline-open-details-<id>`.
2. Add a UI test that selects one row and asserts (a) its inspector shows the
   same title/company/stage, (b) a second row replaces the inspector, and (c)
   no canonical overview fields or route-only Back control appear merely from
   selection. Pair it with a model test using the same fixture data that proves
   `selectedOpportunityID`, persisted record values, and activity IDs did not
   change.
3. Add a UI test that filters two terms, changes the stage, and clears each;
   it must see only real fixture records and an explicit truthful no-results
   surface. Verify empty workspace separately from no-results: empty data says
   there are no opportunities and exposes the existing Add opportunity route;
   no-results says no opportunities match and retains a clear-filter action.
4. Add UI/preview or deterministic view-level coverage for a compact width
   (860×600) showing an accessible inspector disclosure/sheet rather than
   squeezing table columns unreadably. At default/wide widths, selected row and
   inspector may be side-by-side. Large text must scroll, wrap, or truncate
   secondary metadata without clipping title, selection, or Open details.
5. Run the named new tests first and retain the failure output before writing
   production code.

**Minimal implementation:**

- Extract the Pipeline presentation from `ContentView` without moving its
  state ownership. Use existing `RekonTheme` semantic surfaces, spacing,
  focus treatment, and status colors; no new raster artwork or dependency.
- Build a native SwiftUI table/list with columns appropriate to actual values:
  opportunity title/company, stage, location/arrangement when present, and
  next action/due state when present. Give the selected row a non-color cue and
  visible focus.
- Add a stage picker plus a local, session-scoped explicit Closed visibility
  toggle. Its labels and values must be exposed to VoiceOver; it must be
  keyboard-operable, retain the existing `opportunity-search` identifier or a
  documented compatible replacement, and neither read nor write `UserDefaults`.
- Add the local inspector with read-only fields and a clearly identified Open
  details action. Do not place `TextField`, `DatePicker`, stage mutation,
  delete, task action, reconciliation, document, export, or recovery controls
  in the inspector.
- Keep existing Add opportunity and Import CSV callbacks and their stable IDs.
  Keep table/board toggle semantics. The board may retain its pre-VD2-04
  presentation, but must receive only the existing filtered projection.

**Pass condition:** all named UI tests pass on the dedicated signed-Debug UI
test host; no selection-only test causes a store write, canonical selection,
route change, or activity event.

### Slice C — canonical open/back, saved-edit/relaunch, and removal safety

**Files expected:**

- Modify narrowly: `RekonPursuit/ContentView.swift`,
  `RekonPursuit/PipelineView.swift` (if created)
- Modify: `RekonPursuitTests/WorkspaceViewModelTests.swift`,
  `RekonPursuitUITests/RekonPursuitUITests.swift`

**Test-first work:**

1. Add UI coverage for Open details from an inspector: it must use the
   canonical `.overview(id)` flow, expose `selected-opportunity-title`, and
   preserve the opportunity ID as the existing Pipeline anchor when Back to
   Pipeline returns. Repeat after searching/filtering to ensure no stale
   selection leaks into another record.
2. Add a fixture/relaunch UI test that changes an opportunity through the
   canonical overview's existing Save changes locally action, returns to the
   table, relaunches the same fixture session, and sees the saved persisted
   title/company/stage in the matching table and inspector. Assert the
   expected existing update activity evidence in the local store/model; do not
   add a decorative table-specific event.
3. Add model/UI coverage for two unhappy paths: (a) a selected row disappears
   after a local delete or no longer matches the filter, clearing only the
   ephemeral inspector selection; (b) opening a deleted/unavailable record
   safely stays/returns to Pipeline and uses the existing truthful unavailable
   route behavior rather than showing stale inspector data.
4. Run tests RED, implement only the route/selection cleanup required, then
   run them GREEN.

**Pass condition:** inspector opening is canonical, canonical editing remains
the only edit path, save/relaunch evidence is real, and deleted/filter-hidden
records cannot leave a stale local selection or unsafe route.

## Fixture and QA data contract

- Add the test-host-only deterministic `VisualFixtureID.pipeline` fixture;
  do not overload `populated` or make production launch parse it. It uses the
  fixture host's fixed UTC clock/calendar and includes stable-ID records for:
  (a) at least three open stages, (b) one Closed record, (c) a title/company
  pair requiring cross-field multi-token AND search, (d) a deliberately
  nonmatching term, (e) absent location, arrangement, next action, and due
  date fields, and (f) one canonical-overview record safe for saved-edit and
  process-relaunch verification. Seed only truthful local record values.
- The fixture is opt-in through the existing UI-test-only launch argument and
  session environment key. It must use the existing isolated temporary session
  root, fixture-only key namespace/key files, fixed clock, no-network checker,
  cleanup process, and `.live-store-access-disabled` proof. It must never read
  a personal workspace, live Keychain namespace, live support DB, wall clock,
  or global user preference. Relaunching the same named fixture session opens
  the existing encrypted fixture store; a new session reseeds it.
- QA must verify all fixture data displayed comes from the seeded store. No
  fictional employer mark, person, date, count, location, action, urgency, or
  status may be introduced for decoration.
- Capture manual evidence at 860×600, 1100×760, default, and wide windows;
  default and increased text sizes; Reduce Motion; and supported system
  appearances. Exercise keyboard-only selection/open/filter and VoiceOver
  labels/values/actions.

## Acceptance criteria

1. Pipeline opens in Table mode with a native, readable responsive table of
   real persisted records and an explicit Board switch preserved for VD2-05.
2. Search is case-insensitive multi-token AND search across title/company;
   stage and the session-scoped Closed toggle have clear labels, values, and
   deterministic behavior without `UserDefaults` reads/writes.
3. Inspector content matches exactly the selected currently visible record and
   never fabricates absent data. It is read-only and is completely ephemeral.
4. A selection-only interaction performs no store write, no audit/event
   append, no canonical draft load, no `selectedOpportunityID` mutation, and
   no route mutation. Open details is the sole inspector/table action that
   selects and opens the canonical opportunity overview.
5. Canonical edit/save, activity evidence, relaunch persistence, return anchor,
   reconciliation departure protections, Import CSV, Add opportunity, and
   destructive confirmation behavior remain intact.
6. Empty, no-results, deleted/unavailable, and compact/large-text states are
   explicit, truthful, and recoverable.
7. Controls provide labels, values, visible keyboard focus, non-color selected
   state, and stable test identifiers. Reduce Motion affects only decoration;
   it changes no data or navigation behavior.
8. `git diff --check`, focused unit/UI tests, relevant existing route/import/
   reconciliation regressions, and the signed Debug build pass. Pre-existing
   warnings must be documented rather than relabeled as new passing evidence.

## Explicit non-goals

- No drag/drop, keyboard stage movement, typed `StageMoveResult`, stage-change
  behavior, stage-history or activity changes beyond existing canonical edits;
  VD2-05 owns all of those.
- No new editor or mutable inspector; no replacement of
  `OpportunityRoute.overview` or `WorkspaceViewModel` selection contracts.
- No changes to contacts, recovery/archive/export, document references, public
  URL checking, AI, Gmail, Calendar, cloud services, browser storage, plugins,
  data schema, or migrations. Settings changes are limited to the approved
  retirement of the obsolete global **Show closed opportunities** control and
  its backing preference; all other Settings work remains VD2-07.
- No global table-selection persistence, new user defaults, mock data,
  decorative counters, new dependency, external asset, or network request.

## Required independent gates and evidence

Before implementation, Architect, TPM, QA, and Delivery Manager must each
review this brief and record a release decision. A fresh implementer then owns
this card only. A separate code reviewer and QA verifier independently review
the resulting work; Architect reviews the selection/route effect. A
proportional security/privacy verifier confirms that this presentation-only
slice did not weaken local-data, fixture isolation, route, document, recovery,
or network boundaries.

The Delivery Manager may transition `VD2-04` to In progress only after all
pre-implementation gates approve. It may mark the card ready for owner smoke
only after all implementation gates, named evidence, and hands-on path pass.
At every real transition, update together the dashboard JSON, Visual Design v2
roadmap section, generated dashboard HTML, and SDD progress/review evidence.
`VD2-05` remains Backlog until explicit product-owner acceptance of VD2-04.

## Product-owner hands-on verification

In the signed Debug handoff, use a seeded local fixture to:

1. Open Pipeline at default and compact widths; search two terms across title
   and company, set/clear a stage, and show/hide Closed records.
2. Select two different rows and confirm the inspector follows the selection
   without opening an editor or changing the route.
3. Use Open details, edit and save through the canonical overview, return to
   Pipeline, relaunch, and confirm the real edited value plus existing activity
   history persists.
4. Keyboard-navigate search, filters, table, inspector, and Open details;
   verify visible focus and VoiceOver labels. Verify a no-results state and a
   deleted/filter-hidden selection recover without stale content.

Product-owner acceptance is required before releasing VD2-05.
