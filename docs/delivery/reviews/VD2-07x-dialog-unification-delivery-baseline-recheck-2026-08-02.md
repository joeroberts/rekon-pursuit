# VD2-07x protected-export dialog unification — Delivery baseline recheck

**Date:** 2026-08-02
**Role:** Fresh independent Delivery Manager
**Decision:** **NEEDS CHANGE — do not release an implementer yet.**

## Decision

The approved dialog-unification plan and the Architecture, QA, Security/privacy,
and TPM rechecks accept one test-first, presentation-only slice. The prior
Delivery record correctly required a reviewed hunk baseline; the subsequent
hunk-baseline record identifies the allowed `ContentView` and UI-test hunks,
the append-only `SettingsView` location, and records that no active agent owns
them.

That record does **not** safely protect the untracked, user-owned
`RekonPursuit/SettingsView.swift` during a working-tree-only implementation:
a before/after SHA-256 necessarily changes when the approved dialog is added,
so it cannot establish that every other existing line is unchanged. Its
required `git diff -U0` check also omits the untracked file. A fresh implementer
is therefore not yet released.

## One required correction

Before editing, create a private temporary preimage of all three writable
files outside the repository, record the stated baseline commands, and retain
that preimage until independent post-implementation review. After editing,
compare each working-tree file to its corresponding preimage with zero context.
For `SettingsView.swift`, the comparison must show only the two approved new
symbols inserted immediately after `SettingsProtectedExportSuccessDialog`; no
other addition, deletion, or modification is permitted. This is the missing
procedure required to make the untracked user-owned file safely editable
without staging or committing it.

## Authorized scope after the correction only

**Writable source/test paths and hunks**

- `RekonPursuit/ContentView.swift`: only the protected-export stock-sheet to
  mutually exclusive root-overlay replacement, its existing root-owned
  state/action wiring, and the associated review-change clearing modifier.
- `RekonPursuit/SettingsView.swift`: only
  `SettingsProtectedExportDialogMode` and the presentation-only
  `SettingsProtectedExportDialog`, inserted directly after
  `SettingsProtectedExportSuccessDialog`.
- `RekonPursuitUITests/RekonPursuitUITests.swift`: only
  `testVD207ProtectedExportEntryUsesRootDialogAndRetainsErrorUntilCancel`
  beside the existing VD2-07x tests.

`SettingsView.swift` remains user-owned, untracked, and uncommitted throughout
this working-tree release. Do not run `git add`, `git commit`, `git checkout`,
`git reset`, or any broad formatter against that file.

**Prohibited paths and changes**

Every other production, test, dashboard, roadmap, and delivery-status path is
prohibited, as are unrelated hunks in the three writable files. In particular,
do not alter any ViewModel, worker, store, persistence/activity/audit behavior,
native Save-panel or sandbox/security-scope behavior, entitlement, fixture,
launch path, recovery-key handling, success content/timing, global
theme/navigation, or VD2-08 accessibility work.

## Mandatory integrity procedure

Run and preserve the output of these commands before editing (with
`$vd207x_baseline` set to a newly created private directory under
`/private/tmp`):

```bash
git status --short -- RekonPursuit/ContentView.swift RekonPursuit/SettingsView.swift RekonPursuitUITests/RekonPursuitUITests.swift
git diff -U0 -- RekonPursuit/ContentView.swift RekonPursuitUITests/RekonPursuitUITests.swift
shasum -a 256 RekonPursuit/SettingsView.swift
cp RekonPursuit/ContentView.swift "$vd207x_baseline/ContentView.swift"
cp RekonPursuit/SettingsView.swift "$vd207x_baseline/SettingsView.swift"
cp RekonPursuitUITests/RekonPursuitUITests.swift "$vd207x_baseline/RekonPursuitUITests.swift"
rg -n "SettingsProtectedExportSuccessDialog|SettingsProtectedExportDialogMode|SettingsProtectedExportDialog" RekonPursuit/SettingsView.swift
```

Run and preserve the output below after editing, before any staging action.
Each zero-context comparison is an intentional manual hunk inspection: it
must contain only the approved delta stated above. The `SettingsView` output
must be insertion-only at the recorded success-dialog anchor.

```bash
diff -U0 "$vd207x_baseline/ContentView.swift" RekonPursuit/ContentView.swift
diff -U0 "$vd207x_baseline/SettingsView.swift" RekonPursuit/SettingsView.swift
diff -U0 "$vd207x_baseline/RekonPursuitUITests.swift" RekonPursuitUITests/RekonPursuitUITests.swift
shasum -a 256 RekonPursuit/SettingsView.swift
git diff -U0 -- RekonPursuit/ContentView.swift RekonPursuitUITests/RekonPursuitUITests.swift
git diff --check
git status --short -- RekonPursuit/ContentView.swift RekonPursuit/SettingsView.swift RekonPursuitUITests/RekonPursuitUITests.swift
```

If any comparison includes an unrelated hunk, the implementer must stop and
return to Delivery; do not repair, revert, stage, or absorb the user-owned
content. The private preimage may be removed only after the independent review
and QA/security verification have accepted the exact diff.

## Test release condition

After the one missing preimage-comparison procedure is recorded and accepted,
release exactly one fresh implementer for the bounded working-tree slice. That
implementer must first add and execute the specified focused invalid-key UI
test as RED; it must execute once and fail only because the current entry form
is a stock sheet. GREEN requires that same test to execute once with zero skips
and zero expected failures, all nine named protected-export model protections
to execute with inspectable summary and detailed results, a successful macOS
Debug build, and `git diff --check` passing. Any failure, skip, unexpected RED,
scope expansion, or overlapping hunk ownership returns the task to Delivery.

No dashboard update, VD2-07 acceptance/status transition, successor release,
or VD2-08 release is authorized by this record. Post-implementation acceptance
still requires independent code review, QA, architecture-deviation review,
security/privacy verification, and the restricted owner-native checklist.
