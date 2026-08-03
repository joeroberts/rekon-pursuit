# VD2-07x protected-export dialog unification — Delivery release

**Date:** 2026-08-02
**Role:** Fresh independent Delivery Manager
**Decision:** **NEEDS CHANGE — do not release an implementer yet.**

## Release decision

The fresh Planner brief and the Architecture, QA, Security/privacy, and TPM
pre-implementation gates approve one narrowly bounded, test-first visual
slice. `VD2-07` remains **In progress** and the TPM gate releases no
successor or adjacent work.

This worktree is not yet safe to dispatch. The specified current unstaged
`git diff --numstat` reports `317 insertions / 507 deletions` in
`RekonPursuit/ContentView.swift` and `776 insertions / 15 deletions` in
`RekonPursuitUITests/RekonPursuitUITests.swift`; no unstaged stat is reported
for `RekonPursuit/SettingsView.swift`. Those already-modified shared files
cannot be attributed to the proposed small dialog/test hunk from this release
check alone. Delivery therefore cannot establish the TPM-required reviewed
baseline or protect unrelated owner work from staging/overwrite.

## Required correction before one fresh implementer may be released

Record an explicit reviewed hunk baseline and integration procedure for the
three shared paths, including confirmation that no concurrent slice owns or
will edit the protected-export dialog/test hunks. The fresh implementer must
then use `git add -p` to stage only the protected-export root-overlay/dialog
and the one new focused UI-test method, and inspect the temporary index with
`git diff --cached --check` before any commit. No unrelated existing hunks may
be staged, amended, reverted, or absorbed.

## Scope if re-released

**Writable production/test files:**

- `RekonPursuit/ContentView.swift` — only the protected-export stock-sheet to
  root-overlay presentation hunk, existing root-owned state/action wiring, and
  associated review-change clearing modifier.
- `RekonPursuit/SettingsView.swift` — only
  `SettingsProtectedExportDialogMode` and the presentation-only
  `SettingsProtectedExportDialog` beside the existing protected-export success
  dialog.
- `RekonPursuitUITests/RekonPursuitUITests.swift` — only
  `testVD207ProtectedExportEntryUsesRootDialogAndRetainsErrorUntilCancel`.
- `docs/delivery/reviews/` and `.superpowers/sdd/` — delivery evidence only.

**Prohibited:** every other production/test/dashboard file and all unrelated
hunks in the writable files; in particular no ViewModel, worker, store,
native Save-panel, entitlement/security-scope, persistence, activity/audit,
fixture, launch-path, success-content/timing, recovery-key handling,
accessibility, global-theme/navigation, `VD2-08`, roadmap, or dashboard
change.

## Required TDD and verification evidence after re-release

1. Add and execute the focused invalid-key UI method as an executable RED that
   fails only on the current stock sheet (`app.sheets.count == 1`), without a
   recovery-key fixture or native panel interaction.
2. Implement only the approved root-owned custom dialog and execute the same
   selector as GREEN; inspect summary and detailed result output showing one
   execution, zero skips, and zero expected failures.
3. Run the nine named protected-export model protections, inspect their
   summaries and detailed results, build the Debug scheme, and run
   `git diff --check`.
4. Preserve hunk isolation during staging with `git add -p`, then confirm the
   index contains only this slice before any commit.

## Stop condition

Stop immediately and return to Delivery for a fresh release if the hunk
baseline is not recorded, another implementer is editing any of the same
source/test hunks, the RED is not the single stock-sheet presentation failure,
the narrow diff expands beyond the files/hunks above, a required verification
fails/skips, or any successor (`VD2-08` or otherwise) is proposed for release.
No implementation, dashboard transition, or successor release is authorized
by this decision.
