# RP-R1b — Reactive application shell

**State:** Released for implementation  
**Depends on:** `RP-R1a` accepted  
**Blocks:** `RP-R2`, `RP-R4`, `RP-R6`, `RP-R7a`, and `RP-R8`

## Outcome

Replace the segmented root control with a native macOS `NavigationSplitView` so
Rekon Pursuit has the approved desktop hierarchy: branded persistent sidebar,
toolbar, scrollable page detail, and a visible workspace-state control. It
must remain usable at a compact desktop window of **no more than** 900 × 640
points.

## Scope and boundaries

- Preserve the accepted R1a workspace gate exactly: create/retry/recheck
  controls stay visible and retain their existing non-destructive behavior.
- Surface only the app's already-persistent local workflows; this task adds no
  fields, migrations, import mapping/update behavior, reconciliation request,
  document capability, lifecycle capability, AI, network, or integration.
- Reorganize existing page content only. Do not claim blocked functionality as
  complete or alter its underlying commands, storage, audit events, or copy to
  imply a new capability.
- The sidebar destinations are **Needs attention**, **Pipeline**, **Add
  opportunity**, **Import CSV**, **Contacts**, **Activity & AI**, and
  **Settings**. Use the Rekon Pursuit identity already in the app/mockups;
  never make a logo asset a launch dependency.

## Implementation brief

1. Add `RekonPursuit/AppShellView.swift` containing the typed sidebar
   destination and shell view. Use `NavigationSplitView` with a sidebar list,
   a compact Rekon Pursuit wordmark/title, and toolbar navigation/title. Keep
   selection in the shell; inject the existing `WorkspaceViewModel` rather
   than duplicating state.
2. Refactor `RekonPursuit/ContentView.swift` so it owns the existing
   `@StateObject`, modal/file-import/export bindings, alerts, and `start()`;
   render the new shell and move each existing page body into scrollable detail
   content. The workspace gate is a persistent detail/header state, not a
   hidden destination. Pass explicit intent callbacks/bindings from
   `ContentView` to `AppShellView` for CSV choosing, backup restore, document
   attach, export, and alert presentation. `AppShellView` must not own or
   duplicate a picker, `NSOpenPanel`, persistence, or modal state. The
   existing native CSV `NSOpenPanel` path remains unchanged.
3. Update `RekonPursuit/BootstrapApp.swift` only as necessary to set a useful
   desktop default size and a minimum content size no larger than 900 × 640.
   Update
   `RekonPursuit.xcodeproj/project.pbxproj` only to compile the new source
   file. Do not add dependencies.
4. Update `RekonPursuitUITests/RekonPursuitUITests.swift` before the refactor:
   replace segmented-control assertions with accessibility-identified sidebar
   navigation and assert the workspace gate/default Needs attention destination
   on launch. UI tests are non-mutating navigation/workspace-gate checks only;
   they must not introduce a launch argument, preference, environment value,
   or any production storage/Keychain configuration seam. They do not create a
   workspace or drive the native chooser.
5. Use the existing R1a generated temporary-app harness
   (`scripts/remediation/run_r1a_isolated_smoke.sh`) for the mutating manual
   smoke. A minimal harness extension is allowed only to keep its compiled
   temporary bundle, app-data container, and Keychain namespace isolated and
   cleaned up; it must not change production storage or Keychain configuration.
   The manual smoke owns workspace creation, create/edit/Pipeline refresh, and
   native panel/fixture preview verification.
6. R1a's existing focused non-UI recovery tests remain authoritative for the
   database/key-state recovery matrix. R1b verifies only the visible default
   fresh-create workspace gate; do not add a recovery fixture, harness launch,
   test injection, or production configuration seam.

## Acceptance criteria

- At 900 × 640, sidebar selection, toolbar, primary content, and recovery
  controls are reachable; long page content scrolls rather than clipping.
- A fresh default launch shows Needs attention plus the R1a workspace-create
  state. R1a's accepted focused recovery tests remain authoritative for
  recovery-required behavior.
- The isolated R1a temporary-app smoke creates a workspace, creates a unique
  synthetic opportunity, edits/saves that same record, and navigates to
  Pipeline where the edited record visibly refreshes without relaunch. R1a's
  accepted focused recovery tests remain the evidence that recovery never
  exposes replacement/overwrite behavior.
- The CSV chooser button is enabled only after workspace-ready. In the manual
  isolated smoke, activating it opens the native single-file dialog and the
  R1a synthetic fixture previews successfully; UI tests assert button
  availability only.
- The implementation remains local-only and creates no new persistence,
  external request, entitlement, or activity-event type.
- Before/after screenshots at 900 × 640 show the approved sidebar/detail
  hierarchy; evidence identifies only synthetic data and no local paths.

## Focused verification and evidence

1. Run the updated focused UI tests and existing workspace/view-model tests;
   run a Debug macOS build. No coverage target or hosted test expansion.
2. Run the existing R1a generated isolated temporary-app harness at 900 × 640,
   then manually verify: first launch → create workspace → create a unique
   synthetic opportunity → edit/save that same record → select Pipeline and
   Activity & AI → select Import CSV → activate the enabled CSV chooser button
   → choose the R1a synthetic fixture
   (`RekonPursuitTests/Fixtures/r1a-smoke-import.csv`) → confirm preview.
   Verify visible immediate refresh and no clipped primary action. Recovery
   behavior is verified by R1a's existing focused non-UI recovery tests.
3. Record redacted screenshots and the build/test commands/results in
   `docs/delivery/evidence/remediation/RP-R1b/RP-R1b-shell-smoke.md`.

## Risks

- The current single root view is large; move presentation only, preserving
  command ownership in `WorkspaceViewModel` to avoid domain regressions.
- Some existing views represent blocked later work. R1b may make their current
  local screens navigable, but cannot extend, relabel, or accept those scopes.
- `NSOpenPanel` is deliberately retained because the accepted R1a user smoke
  proved it works where the SwiftUI importer did not.

## Required gates

Fresh Implementer → separate Code Reviewer and QA verifier → Architect review
for shell/state-boundary effects → TPM/Delivery acceptance. Security/Privacy
review is required only if the implementation changes file scope, persistence,
entitlements, or data leaving the Mac; none is planned.
