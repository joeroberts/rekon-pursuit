# VD2-07x Dialog Unification — Delivery Preimage Release

**Date:** 2026-08-02
**Decision:** **ACCEPT — release one fresh implementer.**

Implementation is limited to working-tree-only V2-07x dialog unification. The private preimage at `/private/tmp/rekon-vd207x-dialog-baseline.NMoUHM`, created after the required baseline record, contains three source snapshots and a tracked preimage patch.

## Permitted scope

- The protected-export overlay/sheet hunk in `ContentView`.
- `SettingsProtectedExportDialogMode` and `SettingsProtectedExportDialog`, appended after the success dialog.
- One new focused UI-test method.

## Prohibited scope

All other source changes. Do not stage or commit `SettingsView`; do not modify ViewModel, worker, save panel, accessibility, dashboard, or VD2-08 work.

## Required verification and stop conditions

Run the specified RED UI test, then GREEN UI test, nine model tests, Debug build, and diff check. Before and after implementation, `diff -U0` for each source against the preimage must show only its permitted hunk. Stop and escalate on any unexpected test, diff, or command result.

No dashboard or successor task is released. Post-implementation requires fresh code review, QA, architecture, and security verification, plus completion of the owner native checklist.
