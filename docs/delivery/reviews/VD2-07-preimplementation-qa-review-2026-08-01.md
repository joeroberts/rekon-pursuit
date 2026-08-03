# VD2-07 pre-implementation QA/test review

**Date:** 2026-08-01  
**Role:** Independent QA/test owner  
**Reviewed artifacts:** `efe1de6` (approved design), `ec0b5ce` (brief and plan), the live fixture host, UI-test harness, current Settings implementation, test targets, and selected lower-layer tests.  
**Verdict:** **NEEDS CHANGE**

## Decision

The design has a sound deterministic-fixture foundation: UI launches create a UUID-qualified fixture session (`RekonPursuitUITests/RekonPursuitUITests.swift:4-33`), the fixture configuration uses a fixed clock and UTC (`RekonPursuit/RekonVisualTheme.swift:1345-1408`), and the archive and document fixtures have focused host coverage (`RekonPursuitUITestHostTests/RekonPursuitUITestHostTests.swift:573-625`). The proposed four UI tests also cover the default local section, global-rail retention, compact keyboard activation, aggregate document output, and the unavailable AI surface.

However, the exact RED/GREEN runner is narrower than the accepted brief, and the planned UI assertions do not prove several presentation-level safety invariants. The following changes are required before QA can approve Task 1.

## Required changes

### P1 — Run every lower-layer contract that the brief makes mandatory

The brief names archive-expiry, successful retained-data purge, inactive restore, separate-workspace relaunch, and return-to-preserved-recovery as required before-and-after regression evidence (`docs/delivery/task-briefs/VD2-07-settings-information-architecture.md:82-88`). Neither focused command contains these five selectors; it includes only the wrong-key purge selector (`docs/superpowers/plans/2026-08-01-vd207-settings-information-architecture.md:212-227`, `:417-432`). The live selectors exist at `RekonPursuitCoreTests/PortableArchiveTests.swift:53,1215,1959` and `RekonPursuitTests/WorkspaceViewModelTests.swift:1101,1177`.

Add all five selectors to both the Task 1 RED baseline and Task 2 GREEN command, then require the result bundle to show every selected test executed once with no failure or skip. This closes the missing expiry, successful-purge, inactive-current-workspace, relaunch, and recovery-return evidence.

### P1 — Make recovery UI coverage prove retained behavior, not only control presence

The brief requires the extracted surface to retain each action's disabled predicate, busy copy, cancellation/error behavior, destructive confirmation, and inactive-candidate result (`docs/delivery/task-briefs/VD2-07-settings-information-architecture.md:67`). The archive UI test only checks that four controls exist and that three are enabled; it does not assert the purge enabled state, fixed rendered created/expiry values, any disabled/busy state, retained purge status, cancel, protected-export error/cancel/no-write, restore cancellation/failure, or the inactive candidate message (`docs/superpowers/plans/2026-08-01-vd207-settings-information-architecture.md:163-180`).

Add deterministic presentation tests (or a clearly specified, testable presentation seam that does not alter product behavior) for all retained controls. At minimum, assert archive created and expiry text from the fixed clock; the enrolled purge predicate; the existing busy labels and disabled controls; each moved sheet/alert's cancel/error path; protected-export no-write and unchanged-current-workspace evidence; and restore cancellation plus its inactive-candidate result. The test artifact must continue to omit all recovery-key values.

### P1 — Include fixture-isolation and Settings relaunch evidence in the executed suite

The plan directs the final QA verifier to "check" fixture isolation, fixed-clock truth, and relaunch truth but tells it only to rerun the Task 2 focused command (`docs/superpowers/plans/2026-08-01-vd207-settings-information-architecture.md:495-503`). That command selects no fixture-host tests and performs no Settings UI relaunch. The existing host test proves a populated fixture can reopen persistently (`RekonPursuitUITestHostTests/RekonPursuitUITestHostTests.swift:402-423`), but it does not prove that the extracted Settings surface reads the selected active local workspace truth after relaunch.

Add named fixture-host selectors covering isolation, fixed time, archive catalogue construction, and document-relink setup to both runner commands. Also add a fixture-driven Settings relaunch test using one UUID-qualified session: establish the relevant active/local workspace fact, terminate and relaunch, reopen Settings, and assert the same truthful aggregate/recovery surface while the local selected section resets to its non-persisted default. Preserve the existing recovery-only fixture assertion that normal navigation is not exposed.

## Runner and signing assessment

`xcodebuild -list -project RekonPursuit.xcodeproj` was run during this review; the `RekonPursuit` scheme exposes the expected app, unit-test, UI-test, UI-test-host, and UI-test-host-test targets. The plan's Debug commands retain signing and use unique derived-data/result-bundle paths, and its later signature checks are directionally appropriate. They are not acceptance evidence yet because implementation and the Task 1 RED tests have not been created or executed.

## Scope and limitation

No implementation, test, fixture, plan, brief, specification, delivery-status, or project configuration file was changed by this review. VD2-07 implementation remains unreleased and Task 1 must not be released on this verdict alone. A fresh QA review is required after the plan incorporates the three changes above and before any implementation task proceeds.
