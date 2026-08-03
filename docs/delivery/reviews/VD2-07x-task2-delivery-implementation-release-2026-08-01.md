# VD2-07x Task 2 — Delivery implementation release

**Date:** 2026-08-01
**Role:** Independent Delivery Manager
**Verdict:** **ACCEPT — RELEASED: Task 2 reference-faithful Settings visual slice only.**

## Delivery decision

The current source is the pre-implementation baseline for this decision. The
absence of the approved reference panels, compact pointer proof, and export
success dialog is the work Task 2 is released to deliver; it is not a
pre-implementation blocker. The approved design, controlling brief and plan,
accepted Task 1 event/root seam, V2-08 accessibility deferral, and current
delivery dashboard together support release of one fresh implementer for this
bounded visual slice.

This is not Task 2 acceptance, a claim that its matrix is green, or a release
of V2-08. VD2-07 is correctly shown as **In progress** in
`docs/delivery/dashboard-status.json`; VD2-08 remains Backlog and blocked
until VD2-07 is accepted.

## Gate audit

| Required gate | Evidence reviewed | Delivery result |
| --- | --- | --- |
| Approved product direction | `docs/superpowers/specs/2026-08-01-vd207-reference-faithful-recovery-screen-design.md` and the product-owner-approved reference images define the four local Settings surfaces and success dialog. | ACCEPT |
| Bounded, test-first brief and plan | `docs/delivery/task-briefs/VD2-07x-reference-faithful-settings.md` and `docs/superpowers/plans/2026-08-01-vd207-reference-faithful-recovery-screen.md` define the visual selectors, root dialog contract, test matrix, and outside-repository evidence. | ACCEPT |
| Task 1 dependency | The durable ledger records the Task 1 real-write-only filename event/root seam as passed for the focused Core/ViewModel and host contracts. The pre-existing Settings rendering is unaccepted baseline, not evidence attributed to Task 1. | ACCEPT for Task 2 start |
| Architecture release | `docs/delivery/reviews/VD2-07x-visual-architecture-release-2026-08-01.md` accepts the local-state, root-ownership, token/store-lifetime, and global-rail boundary. | ACCEPT |
| Security/privacy release | `docs/delivery/reviews/VD2-07x-visual-security-privacy-release-2026-08-01.md` accepts the filename-only, real-write-only dialog boundary and aggregate/no-control panels. | ACCEPT |
| QA strategy | The brief and the V2-08 addendum require the literal matrix, the retained original accessibility assertions, focused compact pointer selection, focused AI visual/content-boundary coverage, and eight fixture images. The current lack of those Task 2 artifacts is expected before implementation and is a post-implementation acceptance gate. | ACCEPT for implementation start |
| Upstream/downstream sequencing | VD2-06 is accepted. `docs/delivery/dashboard-status.json` now places VD2-07 In progress; VD2-08 remains unavailable until VD2-07 acceptance. | ACCEPT |

The existing QA inventory in
`docs/delivery/reviews/VD2-07x-visual-qa-release-2026-08-01.md` correctly
identifies absent current-source visuals and evidence. Those are mandatory
post-implementation checks, not a reason to require implementation before
releasing the implementation task. Delivery does not reclassify any test
result as passing.

## Implementation allowlist

The fresh implementer may author only these Task 2 hunks:

| Path | Authorized change |
| --- | --- |
| `RekonPursuit/SettingsView.swift` | Render the four specified local Settings sections, reference tab strip/compact stack, safe cards, existing action closures and predicates, and the string-only success-dialog view. Local section selection/focus remains non-persisted. |
| `RekonPursuit/ContentView.swift` | Root-only presentation of the existing safe export-success projection; on real success close the existing export sheet and clear its re-entry text, retain the event until `Done`, and have `Done` call only the existing dismissal binding. |
| `RekonPursuitUITests/RekonPursuitUITests.swift` | Turn the retained reference selectors green; add focused compact pointer-selection and AI visual/content-boundary coverage; retain every existing deferred keyboard/AI accessibility assertion unchanged; attach only the required safe wide/compact fixture images. |
| `RekonPursuitUITestHostTests/RekonPursuitUITestHostTests.swift` | Add only the display-safe Task 2 presentation assertions required by the brief, if needed. |
| `RekonPursuitTests/WorkspaceViewModelTests.swift` | Add only a narrowly necessary root-modal/active-workspace regression, if needed; do not alter export behavior. |
| `RekonPursuit.xcodeproj/project.pbxproj` | Only if `SettingsView.swift` is not already registered exactly once in both existing app targets; source-reference/build-file/two target-membership hunks only. |

No other path is released. In particular, Task 2 must not change
`WorkspaceViewModel` semantics, Core/store/schema/migrations, fixture launch
or time, app-shell/global navigation, pipeline/Kanban behavior, signing,
entitlements, network capability, recovery/archive/export/purge/restore
semantics, document metadata policy, or AI/cloud/Gmail/Calendar capability.
The existing dirty worktree remains user-owned: stage nothing wholesale,
preserve unrelated hunks, and do not reset, reformat, or attribute an existing
untracked file in its entirety to Task 2.

## Non-negotiable acceptance evidence after implementation

1. The four Settings surfaces match the approved reference at wide and compact
   widths while the five-item global rail remains selected on Settings. Local
   selection is not a route and does not persist.
2. Recovery uses `SettingsArchiveSummary` and existing callbacks/predicates;
   Workspace remains truthful; Document stays aggregate-only/no-control; AI
   stays informational/offline/no-control. No recovery key, path, document
   name, hash, bookmark, checksum, MIME type, or other metadata appears in UI,
   tests, logs, or retained imagery.
3. The success dialog appears only after the existing real protected-export
   write event, displays only safe filename, `Selected local folder`, reminder,
   and `Done`; errors, cancellations, stale work, transitions, defaults, and
   fixtures never present it. `Done` leaves active workspace state unchanged.
4. The two original compact keyboard-focus tests and the original Document/AI
   semantic test run unchanged. Only their exact existing focus/Tab/Space or
   AI role/label/value findings may be reported as carried VD2-08 evidence;
   they may not be skipped, expected-failed, guarded, weakened, or represented
   as green. All other non-deferred matrix failures block acceptance.
5. Add and pass focused compact pointer-selection coverage for all four local
   tabs, retaining the Settings rail and matching panel, plus the focused AI
   visual/content-boundary coverage required by the addendum.
6. Retain a parseable signed literal Task 2 result bundle and separately record
   every carried V2-08 result with its exact test, assertion, actual
   role/label/value, platform evidence, and mapped V2-08 requirement.
7. Capture and inspect the eight named fixture attachments and the signed
   normal-Debug real-export dialog image outside the repository. No image may
   disclose prohibited content. Independent Code Review, QA, Architecture,
   Security/privacy, TPM, and Delivery acceptance remain required before the
   product-owner handoff.

## Downstream status

Task 3 and VD2-08 are not released by this decision. V2-07x remains **In
progress** until all visual, export, privacy, signed-verification, independent
review, and product-owner acceptance evidence is complete.
