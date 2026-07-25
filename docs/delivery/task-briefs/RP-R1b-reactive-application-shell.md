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
   on launch. The UI-test harness must use a deterministic, isolated temporary
   workspace and compiled Keychain namespace, then clean both up; it must not
   read or write real app-data or the production Keychain namespace. Add the
   smallest UI smoke that creates a workspace, creates one uniquely named
   synthetic opportunity, edits and saves that same record, selects Pipeline,
   and observes the edited record without relaunch. The UI test asserts only
   that the CSV chooser is available after workspace-ready; it does not drive
   the native chooser.

## Acceptance criteria

- At 900 × 640, sidebar selection, toolbar, primary content, and recovery
  controls are reachable; long page content scrolls rather than clipping.
- First launch shows Needs attention plus the R1a workspace-create or recovery
  state. Recovery-required never exposes replacement/overwrite behavior.
- Creating a workspace, creating a unique synthetic opportunity, editing and
  saving that same record, and navigating to Pipeline visibly refreshes the
  edited record without relaunch. The recovery-required gate is separately
  observed and never exposes replacement/overwrite behavior.
- Existing native CSV selection remains available only after workspace-ready
  and still opens the native single-file dialog.
- The implementation remains local-only and creates no new persistence,
  external request, entitlement, or activity-event type.
- Before/after screenshots at 900 × 640 show the approved sidebar/detail
  hierarchy; evidence identifies only synthetic data and no local paths.

## Focused verification and evidence

1. Run the updated focused UI tests and existing workspace/view-model tests;
   run a Debug macOS build. No coverage target or hosted test expansion.
2. Perform one isolated manual smoke at 900 × 640: first launch → create
   workspace → create a unique synthetic opportunity → edit/save that same
   record → select Pipeline and Activity & AI → select Import CSV → choose the
   R1a synthetic CSV fixture (`RekonPursuitTests/Fixtures/r1a-smoke-import.csv`)
   → confirm preview. Separately observe the
   recovery-required gate. Verify visible immediate refresh and no clipped
   primary action.
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
