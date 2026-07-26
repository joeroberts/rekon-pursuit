# UX-R1 — Shell and opportunity navigation

**State:** Next up — planning/release gate required  
**Depends on:** `RP-R5` accepted  
**Blocks:** `UX-R2`; `RP-R6` remains unreleased until `UX-R2` is accepted  
**Implementation release requires:** Planning, Architect, TPM, QA, and Delivery
approval of this brief.

## Outcome

Make the daily Rekon Pursuit shell feel like a native, focused tracker rather
than a diagnostic form: a real macOS app icon, restrained Rekon visual token
layer, and compact brand treatment,
first-run-only workspace setup, a scrollable Pipeline that leads to a dedicated
opportunity overview, and focused secondary views for history and
reconciliation. Existing document metadata remains available in a compact
overview section, without claiming durable file access before `RP-R6`.

## Fixed product decisions

- Use the approved Rekon target/arrow emblem, derived from the source artwork
  in `design/assets/`, as the square macOS app icon. It must be recognizable in
  Dock/Finder at small sizes; do not squeeze the horizontal wordmark into an
  icon or introduce a different letter-mark.
- The expanded sidebar header uses a restrained compact emblem with the
  Rekon Pursuit name. Do not center a decorative full wordmark/pill in every
  toolbar. When the sidebar is compact, the emblem alone is acceptable.
- Establish shared Rekon visual tokens for deep navy/near-black backgrounds,
  dark navy surfaces, fine navy borders, bright primary text, blue-gray
  secondary text, and blue-to-violet accents for primary actions and active
  selection. Keep the productivity interface calm and readable: do not copy
  marketing-page glow, decorative charts, or pervasive gradients into daily
  tracking surfaces.
- A first launch with no workspace shows a dedicated onboarding/setup view.
  Once ready, daily destinations show no workspace-ready card, global status
  message, opportunity count, attention count, activity count, or local-data
  footer. Workspace health/recovery/privacy remains Settings information,
  outside this task's Settings-polish scope.
- The existing safe workspace-state contract is unchanged: only
  `createAvailable` may offer Create; recovery-required/corrupt/unavailable
  states must offer the existing safe recheck/retry guidance and never create
  over existing local material.
- Pipeline is a scrollable list or board. Selecting an opportunity opens a
  dedicated **Opportunity overview** route. Back restores the originating
  Pipeline query, stage filter, view selection, and visible list position; it
  does not return to a permanent below-list editor or a floating detail modal.
- The overview contains the primary editable record and a compact Documents
  section. **Activity & history** and **Reconcile posting** are separate
  opportunity sub-routes reached from the overview and return to that same
  selected opportunity.
- Activity & history contains opportunity activity, stage history, response
  history, linked contacts, and relationship interactions. It is not the
  global Activity & AI destination.
- Reconcile posting contains the existing R4/R5 URL check, manual review,
  evidence, retry/action state, and explicit closure confirmation. It preserves
  the R4/R5 safety contract, including no automatic stage close.

## Scope and boundaries

- Refactor presentation/navigation only around existing `WorkspaceViewModel`
  commands and persistent records. Do not add a database migration, schema
  version, data model field, importer behavior, network behavior, entitlement,
  AI feature, Gmail/Calendar integration, or Settings redesign.
- Preserve the existing document-reference metadata workflow (attach record,
  list metadata, and mark-final-sent) behind a compact overview section. Do
  not add security-scoped bookmarks, open, verify, relink, file copying,
  parsing, editing, upload, or any new file capability. Those are `RP-R6`.
- Preserve current Add Opportunity, Contacts, and CSV form semantics. Their
  layout, validation, employer association, and completion-report redesign are
  `UX-R2`, not incidental work in this task.
- URL detail extraction is a later connected capability. This task must not
  fetch or parse a posting merely because an opportunity overview exists.
- Keep the existing global **Activity & AI** and **Settings** destinations
  functional; do not polish or redefine their contents in UX-R1.

## Implementation brief

1. Create a native `Assets.xcassets/AppIcon.appiconset` from one approved
   1024px square emblem master plus the macOS renditions required by Xcode.
   Configure the existing app target to use `AppIcon`; verify the built app
   no longer uses the generic macOS placeholder. Add only target resources and
   asset-catalog build settings necessary for this result.
2. Define and apply one shared, semantic Rekon color/token layer to the shell,
   sidebar selection, controls, surfaces, borders, and typography. Do not
   replace native interaction affordances or use color as the sole status cue.
3. Refactor `AppShellView` into a shell that owns only route presentation and
   sidebar selection. Add an explicit opportunity route state such as
   `pipeline`, `overview(opportunityID)`, `history(opportunityID)`, and
   `reconcile(opportunityID)`. Route state must be ephemeral UI state, not
   stored in SQLite or activity records.
4. Split the oversized `ContentView` presentation into focused SwiftUI views
   (for example shell/onboarding, pipeline, opportunity overview, history,
   reconciliation, and compact document section) while keeping
   `ContentView` as the owner of the one `WorkspaceViewModel`, existing native
   panel/sheet bindings, alerts, and callback ownership. New views receive
   explicit bindings/intents; they do not create another model, store, picker,
   persistence session, or network client.
5. Replace the persistent `workspaceGate` header with a full-content
   first-run/onboarding/recovery presentation shown only while no workspace is
   ready. When workspace-ready, render the selected daily destination directly
   without the workspace card or global footer/count/status text. Preserve the
   exact R1a create/retry/recheck accessibility controls and their
   non-destructive conditions.
6. Make Pipeline's list and board independently scrollable. A list/board card
   selects the record and navigates to the overview. Keep search text, stage
   filter, table/board choice, and stable row identity in the Pipeline owner;
   use a `ScrollViewReader` (or equivalent native SwiftUI mechanism) to restore
   the previously visible selected/anchor row on Back. If the selected record
   was deleted while away, return to the filtered Pipeline without an invalid
   selection or crash.
7. Put only the editable opportunity fields, primary stage/action controls,
   and compact documents summary on the overview. Use clear toolbar/header
   actions for **Activity & history** and **Reconcile posting**. Do not leave
   their content rendered below the overview form.
8. Move the existing R4/R5 reconciliation controls and history verbatim into
   Reconcile posting. Existing Check public URL, Cancel, manual review,
   offline record, evidence display, and closure-confirmation sheet must keep
   their current commands and safety copy. A sub-route transition itself must
   not create an activity event, reconciliation result, task, or stage change.
9. Move stage/response history, opportunity activity, contacts, and
   relationship interactions into Activity & history. It is read-only except
   for already-approved navigation/link actions; it must not manufacture audit
   events just because a user views it.

## Data, activity, and migration invariants

- **No migration:** UX-R1 changes no SQLite schema, migration version, stored
  data representation, or existing encrypted-workspace/key lifecycle.
- Navigation, filtering, scrolling, opening/closing sub-routes, and rendering
  the icon/brand create no activity event, task, reconciliation operation, or
  network request.
- Existing records, task ordering, stage/response history, contacts,
  interactions, reconciliation evidence, and document-reference metadata
  survive relaunch unchanged.
- Only existing explicit actions may mutate: save/create/delete opportunity,
  task actions, current R4/R5 reconciliation actions, existing document
  metadata attach/final-sent actions, and existing workspace actions.
- In every workspace state, an existing workspace is never replaced or
  destroyed by the onboarding UI. Recovery-required remains recovery-required
  until the existing accepted recovery flow resolves it.

## Acceptance criteria

1. A Finder/Dock build displays the Rekon emblem AppIcon rather than the
   generic placeholder. The sidebar has a compact recognizable Rekon identity;
   the toolbar remains functional without a centered logo pill. The shell uses
   the restrained Rekon visual language without making productivity surfaces
   glow-heavy, hard to read, or dependent on color-only cues.
2. A fresh no-workspace launch displays a dedicated onboarding/create state,
   and a recovery-required launch displays safe recovery/recheck state. A
   ready workspace displays neither a workspace card nor global counts,
   activity/status messages, or local-data footer across Needs Attention,
   Pipeline, Add Opportunity, Import CSV, Contacts, opportunity overview,
   history, or reconciliation.
3. Pipeline list and board scroll with more records than fit in the window.
   Selecting a record navigates to the dedicated overview; Back returns to the
   same search/filter/view context and restores the list anchor where the
   selected record still exists.
4. Opportunity overview no longer renders permanent below-form history or
   reconciliation content. Its Activity & history action shows all listed
   historical/relationship data for the selected opportunity and returns to
   that exact overview.
5. Reconcile posting exposes the current R4/R5 workflow for that exact
   selected opportunity. It neither fetches automatically on navigation nor
   changes the opportunity stage without the existing explicit closure
   confirmation.
6. The overview Documents section is compact, shows existing metadata and
   existing permitted actions on demand, and introduces no open/relink/bookmark
   behavior or new persistence.
7. Existing first-run safety, CSV import, selected-opportunity save, task
   action, reconciliation, and document-metadata focused tests continue to
   pass without new CI/coverage requirements.

## Focused fixture and verification plan

Use existing deterministic local stores/fixtures; do not add live network
tests, a new general UI harness, coverage gates, or hosted test work.

1. Extend the existing UI tests with a ready-workspace fixture only if the
   current project already has a safe isolated UI-test launch mechanism. If it
   does not, keep UI tests non-mutating and use the existing isolated smoke
   harness for workspace-ready navigation. Cover: first-run onboarding visible;
   ready shell has no workspace/status clutter; Pipeline selection → overview
   → history/reconcile → overview → Back; and sidebar destination reachability.
2. Add or update the lowest practical `WorkspaceViewModelTests` for state that
   can be proven without UI: selecting/opening an opportunity retains the
   correct ID, an absent/deleted selected ID clears safely, and navigation-only
   paths do not mutate event/task/reconciliation counts. Do not test SwiftUI
   layout through the store.
3. Re-run existing focused R1a workspace-state tests, R3 CSV tests, R4/R5
   reconciliation tests, document-reference metadata tests, and the targeted
   navigation UI tests. Run a Debug macOS build. No live URL is an acceptance
   test.
4. In the existing isolated temporary-app smoke at a compact desktop size,
   verify: fresh onboarding → create workspace → create/import synthetic
   records → scroll/filter Pipeline → open an overview → visit Activity &
   history → return → open Reconcile posting without dispatching a request →
   return → inspect compact Documents → Back to the same Pipeline context.
   Capture redacted screenshots with synthetic records only.

## Risks and implementation notes

- `ContentView` currently owns all page bodies, presentation bindings, and
  alerts. Splitting views must preserve that single ownership; duplicating the
  model would desynchronize selected record state and create regressions.
- SwiftUI list-position restoration is sensitive to identity. Use stable
  opportunity IDs, and treat restoration as best effort when filtering removes
  the prior anchor; the invariant is preserved context and no wrong record.
- The former persistent workspace gate was part of accepted R1a recovery
  safety. Its removal from ready daily pages must not hide its non-ready
  create/recheck/retry states.
- The R5 check path is security-sensitive. Moving its view must not modify
  `PublicURLChecker`, entitlement configuration, request behavior, retained
  evidence, or closure semantics.

## Required gates and release rule

Planning → Architect (shell/state and no-migration review) → TPM (sequence and
scope) → QA (focused fixture plan) → Delivery release. After implementation, a
fresh Implementer is reviewed by separate Code Reviewer and QA verifier, then
Architect reviews any architectural deviation before TPM/Delivery acceptance.
Security/Privacy review is required only if implementation changes document
scope, persistence, entitlements, or network behavior; none is planned.

UX-R1 remains **Next up** until the independent plan/release gate approves this
brief. The dashboard must move `UX-R1: Next up → In progress` only at Delivery
release. `UX-R2` and `RP-R6` remain unreleased.
