# VD2-07x Task 2 visual QA release

**Decision: NEEDS CHANGE — do not release Task 2.**

## Scope inspected

- Approved reference design: `docs/superpowers/specs/2026-08-01-vd207-reference-faithful-recovery-screen-design.md`.
- Controlling Task 2 matrix/evidence requirements: `docs/delivery/task-briefs/VD2-07x-reference-faithful-settings.md`.
- Product-owner VD2-08 accessibility deferral: `docs/delivery/task-briefs/VD2-07x-vd208-accessibility-deferral-addendum.md`.
- Current `SettingsView`, `ContentView`, protected-export model contracts, UI/host/Core tests, and prior Task 1/baseline reports.

## What remains sound

1. The fixed fixture timestamp is presently `2025-05-06T12:00:00Z` in `RekonPursuit/RekonVisualTheme.swift:1349`; the required May 6/June 5 archive facts remain a V2-07x gate.
2. The Task 1 event seam remains narrow in source: `ProtectedExportSuccess` contains only `displayFilename`, the model invalidates its token for review/cancel/error/workspace transitions, and completion checks both the token and store identity before publishing. The existing Task 1 report records focused real-write/root-dismissal evidence. This is not, however, Task 2 dialog-rendering evidence.
3. The deferred tests and their identifiers still exist. The only deferred categories permitted by the addendum are (a) the local section controls' Tab/Space/focus value handoff and (b) the AI unavailable text's accessibility role/label/value. They must continue to run and be reported, not skipped or weakened.
4. `git diff --check` exits successfully in the current worktree. No source or test change was made by this review.

## Blocking Task 2 gaps

### 1. The approved Settings surfaces are not rendered

`RekonPursuit/SettingsView.swift` is still the generic implementation:

- `SettingsView.body` at lines 205–231 renders plain text buttons, a `ScrollView`, and a simple `VStack`; it does not render the reference tab strip or card composition.
- `WorkspaceSettingsSection` at lines 282–300 is a single `GroupBox`, not the local-workspace hero, recovery card, and truthful disabled/available return card.
- `RecoveryArchivesSettingsSection` at lines 302–387 is a generic button list and summary text. It has none of the required overview, safe archive-detail, or three action-card selectors.
- `DocumentReferencesSettingsSection` at lines 390–408 has only the aggregate text; it lacks the hero, count cards, and privacy card.
- `AIConnectionsSettingsSection` at lines 411–419 is one unavailable-copy `GroupBox`; it lacks the offline hero, three status cards, and privacy card.

The 24 reference visual/card identifiers remain absent. The retained Task 1 tests still call `recordUnrenderedVisualSelectors` for them at `RekonPursuitUITests/RekonPursuitUITests.swift:2744`, `2812`, and `2854`; that is RED-contract coverage, not a Task 2 visual pass.

### 2. No root-owned protected-export success dialog is rendered

`ContentView` projects `model.protectedExportSuccess` into `SettingsRootModalPresentation` (lines 523–535), but its body contains no presentation bound to `isProtectedExportSuccessPresented`, no `settings-protected-export-success-dialog`, no `Protected copy exported` visual, and no visible root-owned `Done` action. The current UI test only asserts the dialog is absent before export (line 2773); no post-real-write dialog test or screenshot exists.

This means Task 2 does not yet prove the required end-to-end invariant: a dialog appears only after an actual protected-export write, shows the safe filename and `Selected local folder`, and `Done` changes neither the active workspace nor export/recovery state.

### 3. Required pointer-selection coverage is absent

The addendum requires focused pointer-selection tests for all four compact local tabs plus a focused AI visual/content-boundary test, without changing the deferred keyboard/AI tests. Current UI tests have no such focused pointer test. Their compact reference test invokes `tabToKeyboardFocus` (lines 2788–2810), so it is VD2-08 handoff evidence rather than the required independent V2-07x pointer proof.

No focused test currently proves, at compact width, pointer selection of Workspace, Recovery & archives, Document references, and AI & connections while retaining the global Settings rail and showing each corresponding panel.

### 4. Required visual evidence and Task 2 matrix evidence are absent

There are no eight named Task 2 screenshot attachments (`VD2-07x-wide-*` and `VD2-07x-compact-*`) and no real-export-success dialog capture. No completed parseable Task 2 result bundle/log is present for the literal 43-selector matrix.

The prior Task 1 and baseline-repair reports show that the runner could leave an incomplete bundle. That is not a reason to classify Task 2 green: it must be reported as an infrastructure evidence limitation, and the release report must identify the exact carried VD2-08 test failures with their actual role/label/value and matching VD2-08 requirement.

## Required QA acceptance gates

Before QA can accept Task 2:

1. Render the four approved reference-faithful Settings surfaces, preserving the global rail, local non-persisted section selection, truthful state, aggregate/privacy/no-control boundaries, and existing recovery action/error/cancel behavior.
2. Add the root-owned success dialog only from the existing safe event. Add end-to-end coverage for absent-before-export, present-after-real-success, safe content only, and Done dismissing without workspace mutation.
3. Add focused compact pointer-selection and AI visual/content-boundary coverage. Keep the three deferred accessibility tests intact; record their exact outcomes separately as VD2-08 evidence rather than reclassifying them as green.
4. Run the literal Task 2 matrix. All non-deferred failures are blocking. A carried failure is acceptable only when it is exactly the documented focus/Tab/Space semantic handoff or AI text role/label/value failure; list the exact failure and platform evidence in the release record.
5. Capture and independently inspect all eight wide/compact screenshots plus the ordinary, real successful-export dialog image. Verify no recovery key, path, document name, hash, bookmark, MIME type, checksum, or other forbidden metadata appears.

Until these gates are met, there is no reference-faithful visual implementation to release, regardless of the VD2-08 accessibility deferral.
