# VD2-07x — Reference-faithful Settings Task 1 brief

**Status:** Planning complete. No implementation is released by this brief. A
Delivery Manager may release Task 1 only after independent Architecture, QA,
Security/privacy, TPM, and Delivery approval is recorded.

## Controlling artifacts

- `docs/superpowers/specs/2026-08-01-vd207-reference-faithful-recovery-screen-design.md`
- `docs/superpowers/plans/2026-08-01-vd207-reference-faithful-recovery-screen.md`
- `.superpowers/sdd/2026-08-01-vd207-reference-faithful-recovery-screen/task-1-brief.md`
- `docs/delivery/task-briefs/VD2-07-settings-information-architecture.md`

## Task 1 objective and boundary

Define the signed, deterministic RED contract for the approved four-section
Settings reference, then add only the minimal transient model event needed to
prove that a protected-export success can occur after a real verified write.
Task 1 does **not** render the reference tabs, Recovery dashboard, Workspace,
Document references, AI & connections, or the success dialog. Those are the
single presentation release of Task 2.

The eventual target comprises all four local, non-persisted sections:

| Section | Eventual reference contract covered by Task 1 tests |
| --- | --- |
| Workspace | cyan local-workspace hero, recovery explanation, and truthful disabled-or-existing return card |
| Recovery & archives | selected cyan icon tab, recovery overview, safe archive facts, action cards, and real-export-only success dialog |
| Document references | aggregate-only hero/count/privacy cards with no document metadata or actionable controls |
| AI & connections | truthful unavailable status cards with no setup, cloud, Gmail, Calendar, or network control |

The global five-destination rail, root route, and existing sheet/alert/file-panel
ownership remain unchanged. Settings-local selection remains Recovery by
default, keyboard-operable, local to the view, and non-persisted.

## Task 1 allowlist

Only these paths may receive newly authored Task 1 hunks after the dirty
baseline is recorded:

| Path | Narrow permitted purpose |
| --- | --- |
| `RekonPursuit/WorkspaceViewModel.swift` | Introduce the transient, filename-only post-write success event and its clearing/dismissal behavior. |
| `RekonPursuit/ContentView.swift` | Pass the event into the existing root modal presentation seam and expose a root-only dismissal callback; do not add an overlay or alter current sheets. |
| `RekonPursuit/SettingsView.swift` | Extend display-only `SettingsRootModalPresentation`/bindings and, if required by the host test, pure recovery display-state helpers. Do not alter a `View` body, selectors, cards, or dialog. |
| `RekonPursuitTests/WorkspaceViewModelTests.swift` | Add the real-write, safe-event/no-workspace-mutation contract. |
| `RekonPursuitUITests/RekonPursuitUITests.swift` | Add the four deterministic reference UI contracts. |
| `RekonPursuitUITestHostTests/RekonPursuitUITestHostTests.swift` | Extend the existing pure recovery-presentation state test only. |

## Explicitly not allowed in Task 1

- No change to `RekonPursuit.xcodeproj/project.pbxproj`, app-shell/global-route
  code, theme values, fixture construction/identities, launch parsing, test
  host routing, signing, entitlements, or product-test switch.
- No `RekonPursuitCore/**`, store, schema, migration, workspace, recovery-key,
  archive, export-review/write, purge, restore, expiry, document-reference,
  AI/cloud, Gmail, Calendar, network, or persistence behavior change.
- No rendering or source release for the reference tabs, any of the four card
  sections, responsive layout, action-card styling, or the protected-export
  success dialog. No Settings-owned model, URL, key, bookmark, route, sheet,
  persistent preference, or invented success state.
- No modification of dashboard, roadmap, progress, delivery evidence, or
  unrelated dirty hunks. No fixture key, absolute path, document name, hash,
  bookmark, MIME type, checksum, fingerprint, receipt, or recovery-key value
  may be placed in source, process arguments, logs, screenshots, attachments,
  or reports.

## Test-first RED contract

### 1. Add the four reference UI selectors before visual implementation

Add these `@MainActor` methods to `RekonPursuitUITests/RekonPursuitUITests.swift`:

```swift
func testVD207ReferenceRecoveryDashboardKeepsRailAndUsesCardComposition()
func testVD207ReferenceRecoveryDoesNotInventExportSuccess()
func testVD207ReferenceTabsKeepKeyboardSelectionAtCompactWidth()
func testVD207ReferenceOtherSettingsSectionsUseTruthfulInformationalCards()
```

The archive-fixture Recovery test enters through `sidebar-settings`, confirms
the global Settings rail remains selected, and requires all of these eventual
reference identifiers:

```text
settings-reference-tab-strip
settings-reference-tab-recovery-archives
settings-recovery-overview-card
settings-recovery-status-enrollment
settings-recovery-status-state
settings-recovery-archive-detail-card
settings-recovery-action-create
settings-recovery-action-purge
settings-recovery-action-restore
settings-recovery-protected-export
```

It must assert the current archive accessibility value exactly equals
`created=2025-05-06T12:00:00Z;expires=2025-06-05T12:00:00Z;lifecycle=Verified`.
Panel-scoped labels and values must not contain `fixture-document-hash`,
`application/pdf`, `/private/`, or `recovery key` (case-insensitive where the
query supports it).

The default-success test uses a ready fixture without starting export and
asserts `settings-protected-export-success-dialog` does not exist. It must not
use a launch argument, fixture field, or demo control to simulate success.

The compact-width test uses `populated`, requires
`settings-reference-tab-strip`, focuses
`settings-section-document-references`, observes the exact value `Not
selected; Keyboard focus`, presses Space, then observes `Selected; Keyboard
focus`, the document panel, and a still-selected `sidebar-settings` rail.

The other-sections test uses `document-relink` and, after local selection,
requires these exact eventual card identifiers:

```text
settings-workspace-overview-card
settings-workspace-recovery-card
settings-workspace-return-card

settings-document-overview-card
settings-document-available-card
settings-document-relink-card
settings-document-privacy-card

settings-ai-overview-card
settings-ai-assistant-card
settings-ai-email-calendar-card
settings-ai-cloud-card
settings-ai-privacy-card
```

`settings-document-reference-summary` must remain aggregate-only. The document
and AI panels must each have no descendant button, link, menu button, text
field, switch, or checkbox. The document panel must disclose no fixture
filename, path, hash, or MIME sentinel. The AI panel must include the truthful
unavailable words `No cloud services`, `Not configured`, `Not connected`, and
`Offline`, without implying a capability or setup action.

### 2. Add the real-export unit contract before its implementation

Add async
`testVerifiedProtectedExportPublishesSafeSuccessOnlyAfterWritingAndDismissesWithoutWorkspaceMutation()`
to `WorkspaceViewModelTests`. It generates a `RecoveryKey` only in process
memory, injects one exact non-existent temporary `.rekonexport` destination,
creates an active opportunity, reviews and confirms the export, and waits only
while `isCreatingProtectedExport` is true.

The assertions are normative:

```swift
XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path))
XCTAssertEqual(model.protectedExportSuccess?.displayFilename, destination.lastPathComponent)
XCTAssertFalse(model.protectedExportSuccess!.displayFilename.contains("/"))
model.dismissProtectedExportSuccess()
XCTAssertNil(model.protectedExportSuccess)
XCTAssertEqual(model.opportunities.map(\.id), activeIDsBefore)
```

Before review, after destination cancellation, and after review/write error,
the event must be `nil`. Deferred cleanup removes only that generated
destination. The test must neither log nor attach a recovery key.

### 3. Extend the pure display-state test

Extend
`testVD207SettingsRecoveryPresentationPreservesBusyDisabledAndInactiveCandidateContracts`
using only constructed `SettingsArchiveSummary` display values. It must cover
truthful Recovery overview wording and existing action states for not enrolled,
enrolled with no archive, verified archive, exporting, and restoring. Fixture
construction, launch parsing, and host routing are read-only.

## Minimal safe transient success event

After the unit contract exists, add a `ProtectedExportSuccess: Equatable`
value adjacent to current protected-export state. It has exactly one datum:
`displayFilename`. `WorkspaceViewModel` publishes it as an optional,
private-set transient event and provides a dismissal method that only clears the
event.

The model assigns the event only after the existing
`createProtectedExport(review:recoveryKey:)` call returns successfully and its
existing store-identity guard still holds. Its value derives from
`ProtectedExportReview.displayFilename`, never from the destination URL. A
fresh export review and `cancelProtectedExport()` clear any prior success;
cancel, invalid re-entry, review failure, stale review, and write failure never
publish it.

The event must never retain, publish, derive, or log a destination URL/parent
identity, bookmark, receipt, recovery key, key-derived material, checksum,
fingerprint, document metadata, or workspace mutation. It does not change the
review-before-write flow, no-overwrite behavior, archive/purge/restore state,
or active workspace.

`ContentView` remains the only root owner: it may project this event through
`SettingsRootModalPresentation` and offer a root-only dismissal helper. Task 1
must not present a success view, close the existing export sheet, or change
error/cancellation presentation. Task 2 alone consumes the event to show the
dialog after a real success.

## Exact signed Task 1 matrix and classification

First, the just-added unit test may be run alone to demonstrate the narrowly
expected compile-time RED for the absent event symbol. That is test-first
evidence only; it is not a signed-matrix result and cannot be used to classify
a build failure as acceptable.

After the minimal event is present, run this exact signed Debug matrix:

```bash
xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit -configuration Debug -destination 'platform=macOS,arch=arm64' -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207ReferenceRecoveryDashboardKeepsRailAndUsesCardComposition -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207ReferenceRecoveryDoesNotInventExportSuccess -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207ReferenceTabsKeepKeyboardSelectionAtCompactWidth -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207ReferenceOtherSettingsSectionsUseTruthfulInformationalCards -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207SettingsRecoveryRetainsArchiveTruthAndRootOwnedCancellation -only-testing:RekonPursuitUITests/RekonPursuitUITests/testVD207SettingsSecondaryNavigationDefaultsToRecoveryAndKeepsGlobalRail -only-testing:RekonPursuitUITestHostTests/RekonPursuitUITestHostTests/testVD207SettingsRecoveryPresentationPreservesBusyDisabledAndInactiveCandidateContracts -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testVerifiedProtectedExportPublishesSafeSuccessOnlyAfterWritingAndDismissesWithoutWorkspaceMutation -only-testing:RekonPursuitTests/WorkspaceViewModelTests/testCancellingReviewedProtectedExportClearsReviewWithoutWritingOrChangingActiveWorkspace -only-testing:RekonPursuitTests/ProtectedExportTests/testReviewBindsDestinationParentIdentity -only-testing:RekonPursuitTests/ProtectedExportTests/testSourceRevisionChangeRejectsReviewedExportWithoutCreatingAFile -only-testing:RekonPursuitTests/ProtectedExportTests/testExistingTargetIsRejectedWithoutOverwritingIt -derivedDataPath /private/tmp/rekon-vd207x-task-1-red-dd -resultBundlePath /private/tmp/rekon-vd207x-task-1-red.xcresult
```

The only allowed final REDs are selector/panel absences in these three
not-yet-rendered reference tests:

1. `testVD207ReferenceRecoveryDashboardKeepsRailAndUsesCardComposition`
2. `testVD207ReferenceTabsKeepKeyboardSelectionAtCompactWidth`
3. `testVD207ReferenceOtherSettingsSectionsUseTruthfulInformationalCards`

`testVD207ReferenceRecoveryDoesNotInventExportSuccess` must pass because
success is not a fixture/default state. The real-export unit test, pure host
display-state test, both existing Settings UI safety tests, reviewed-export
cancellation test, and all three lower-layer protected-export safety tests must
pass once with no skip or expected-failure marker. A compile, signing, fixture,
host, route, global-rail, accessibility-query, baseline-safety, or unrelated
test failure blocks Task 1; it is never valid RED evidence.

## Dirty-baseline and hunk-isolated checkpoint rules

1. Before editing, record `git status --short`, the unstaged diffs for every
   allowlisted source/test path, and
   `git hash-object RekonPursuit.xcodeproj/project.pbxproj`. Do not stage
   anything while recording the baseline.
2. Treat the existing `SettingsView.swift`, `ContentView.swift`, and test-path
   changes as unaccepted work. Do not reformat, move, amend, stage, or cite
   those hunks as Task 1 evidence. If the untracked Settings file must be made
   patch-selectable, use `git add -N RekonPursuit/SettingsView.swift` only;
   then stage just authored hunks with `git add -p`.
3. A Task 1 checkpoint may contain only the allowlisted Task 1 hunks. It must
   not include a whole dirty file merely because that file also contains the
   new hunk. Do not stage project registration, UI rendering, fixture changes,
   dashboard/roadmap/progress updates, result bundles, or temporary artifacts.
4. Before a checkpoint, inspect `git diff --cached --name-only` and the full
   `git diff --cached` against this allowlist; then run
   `git diff --cached --check`. Any extra path, pre-existing hunk, whitespace
   error, generated output, or unreconciled baseline difference rejects the
   checkpoint.
5. Preserve the unique `.xcresult` outside the repository and record its
   per-selector result. Do not commit test artifacts. A later reviewer must be
   able to distinguish the three named visual REDs from every required green
   safety result without relying on a working-tree diff.

## Task 2 release prerequisite

Task 2 remains blocked until all of the following are recorded:

1. Task 1 has a hunk-isolated checkpoint containing only the safe transient
   event and its allowlisted contracts, plus the cached-diff inspection and
   `git diff --cached --check` evidence.
2. Independent QA confirms the exact signed matrix: every named safety test
   ran once and passed without skip, and only the three declared unrendered
   selector/panel absences are RED.
3. Architecture confirms root-owned presentation and filename-only event
   boundaries; Security/privacy confirms no key, path, bookmark, fingerprint,
   checksum, receipt, or document metadata crosses into Settings or evidence.
4. TPM and Delivery record the dirty-baseline risk, exact RED classification,
   artifact locations, and dependency-safe approval to release the one
   presentation task.

Only then may a fresh Task 2 implementer render the approved four-section
reference design and root-owned dialog. VD2-08 remains out of scope.
