# UX-R1 amendment — Home and Pipeline navigation

**State:** Planned amendment — not released for implementation  
**Depends on:** `UX-R1` implementation at `5a88a00`; approved [Home and Pipeline information architecture](../../superpowers/specs/2026-07-26-home-pipeline-ia-design.md)  
**Blocks:** UX-R1 acceptance; `UX-R2` and `RP-R6` remain unreleased  
**Implementation release requires:** Architect, TPM, QA, and Delivery approval of this amendment.

## Outcome

Make **Home** the default daily destination, with **Needs Attention** as its
first actionable section. Make Pipeline the single owner of Add Opportunity
and Import CSV entry points. Remove legacy gray visual treatment where the
shared Rekon token layer is meant to govern controls and selection, and center
empty states within available content space rather than at fixed coordinates.

## In scope

1. Replace `needsAttention` with `home` in `AppDestination`; Home becomes the
   initial `ContentView.page` and the sidebar shows only Home, Pipeline,
   Contacts, Activity & AI, and Settings.
2. Render the existing Needs Attention task list as Home's first section. Its
   existing open, snooze, reschedule, and complete commands remain unchanged.
   When it is empty, center the existing helpful empty state in Home's usable
   content region and route its Add opportunity action into Pipeline's internal
   add route.
3. Keep `.addOpportunity` and `.importCSV` as internal route/destination
   values only; remove their sidebar rows. Pipeline adds a prominent **Add
   opportunity** action and a secondary **Import CSV** action. Both preserve
   direct navigation so existing native file selection and future UX-R2 cancel/
   back behavior have a stable route boundary.
4. Center Pipeline's no-results empty state responsively after its header and
   filter controls. It must remain usable at the existing compact desktop
   minimum and react to window resize.
5. Apply the existing `RekonTheme` semantic token layer consistently to shell
   selection, primary/secondary buttons, fields, surfaces, borders, and empty
   state containers. Do not add marketing gradients, custom color-only state,
   new preferences, or replace native macOS controls.

## Explicit exclusions

- Add Opportunity field hierarchy, applied-date default, multiline/expanding
  controls, URL/location validation, compensation structure, and next-action
  redesign are `UX-R2`.
- CSV mapping, validation/review/completion layout, cancel/restart/done flow,
  and report language are `UX-R2`. This amendment changes only how Pipeline
  enters the existing import flow.
- Contact form/copy changes, URL extraction, data model/store/migration,
  network behavior, app icon, workspace recovery behavior, Activity & AI, and
  Settings are out of scope.

## Data and behavior invariants

- No model, SQLite, migration, activity, task, reconciliation, file-access,
  or network contract changes.
- Selecting Home, Pipeline, internal add/import, or an empty-state action does
  not write an activity event or mutate an opportunity.
- Existing direct routes continue to work after the sidebar entries are
  removed, including the native CSV picker and Back/cancel ownership retained
  by `ContentView`.
- Home task commands continue to target the same task/opportunity identity and
  preserve the R4/R5 route-safety checks.

## Acceptance criteria

1. A ready launch opens Home. The sidebar contains Home, Pipeline, Contacts,
   Activity & AI, and Settings; it contains neither Needs Attention, Add
   Opportunity, nor Import CSV as destinations.
2. Home's first section is Needs Attention. Existing task actions work; an
   empty state is visually centered in available content and its action opens
   Pipeline's Add Opportunity route.
3. Pipeline exposes clearly differentiated Add opportunity (primary) and
   Import CSV (secondary) actions. Both open the existing flows; removing the
   sidebar rows does not remove CSV selection or opportunity creation.
4. Pipeline's no-results state remains centered below the persistent header
   and filters while resizing the window, without overlapping controls or
   requiring a fixed screen size.
5. Selected navigation and primary/secondary actions visibly follow the
   established Rekon theme. Legacy gray controls do not impersonate a heading
   or primary operation. Accessibility labels continue to describe actions,
   not colors.
6. Existing workspace onboarding/recovery, opportunity overview/history/
   reconciliation routes, selected record behavior, CSV behavior, and local
   persistence work unchanged.

## Focused verification

Use the existing local test target and isolated temporary-app smoke. Do not add
CI, coverage gates, network tests, migrations, or a general UI harness.

1. Update the focused navigation reachability assertion from
   `sidebar-needs-attention` to `sidebar-home`; assert the three removed
   sidebar accessibility identifiers are absent and existing persistent
   destinations remain reachable.
2. Add the lowest-practical route test proving the Home empty-state intent
   selects the internal Add Opportunity route and both Pipeline actions select
   their intended existing internal routes, without a store write.
3. Run existing workspace-state, task-action, selected-opportunity, CSV, and
   R4/R5 focused tests. Run a Debug macOS build.
4. In the isolated app at compact and wide desktop sizes, verify: launch to
   Home; use an actionable task; inspect Home empty state; navigate Pipeline;
   open Add opportunity and return; open Import CSV and return; set a no-match
   filter; resize the window; and confirm no workspace/status/footer clutter
   reappears.

## Risks and implementation notes

- `AppDestination` currently conflates sidebar destinations with internal
  daily routes. Keep the smallest reversible implementation: retain internal
  add/import cases but expose a separate sidebar-case collection rather than
  forcing a new general router during this amendment.
- The add/import screens retain their current titles and forms. UX-R2 owns
  their redesign; this amendment must not hide incompleteness by changing
  their field behavior.
- `ContentUnavailableView` alone will not satisfy responsive vertical
  centering. The implementation should give the content region flexible height
  below the fixed Home/Pipeline header controls while allowing normal scrolling
  for real task/list content.

## Required gates

Planning → Architect (routing/no-data-change review) → TPM (scope/order) → QA
(focused verification) → Delivery release. After implementation: separate Code
Reviewer and QA verification, Architect deviation review if needed, then TPM /
Delivery acceptance and product-owner hands-on review.
