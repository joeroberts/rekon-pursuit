# VD2-07 Settings information architecture — Task 1 Delivery release

**Date:** 2026-08-01
**Role:** Independent Delivery Manager
**Verdict:** **ACCEPT — release Task 1 only.**

## Delivery decision

VD2-07 Task 1 is the next dependency-safe slice. A fresh Implementer may add
only the focused, fixture-driven test contract required to establish the
Settings presentation RED and its unchanged lower-layer baseline. This is an
authorization to create and classify that evidence; it is **not** evidence
that the RED already exists, and it does not release Settings production code.

The release is limited to these two test files and six test methods:

| File | Released addition |
| --- | --- |
| `RekonPursuitUITests/RekonPursuitUITests.swift` | `testVD207SettingsSecondaryNavigationDefaultsToRecoveryAndKeepsGlobalRail`, `testVD207SettingsSecondaryNavigationIsKeyboardOperableAtCompactWidth`, `testVD207SettingsRecoveryRetainsArchiveTruthAndRootOwnedCancellation`, `testVD207SettingsDocumentAndAISectionsStayAggregateAndUnavailable`, and `testVD207SettingsRelaunchKeepsFixtureTruthAndResetsLocalSelection` |
| `RekonPursuitTests/WorkspaceViewModelTests.swift` | `testCancellingReviewedProtectedExportClearsReviewWithoutWritingOrChangingActiveWorkspace` |

The five UI methods must use the current UUID-qualified deterministic fixtures
and fixed clock. The unit test may create a recovery key only in process memory
and must not print, attach, log, screenshot, fixture-transport, or otherwise
persist a recovery-key value.

No production source, project file, test-host source, fixture identity or
launch parsing, route, persistence, lifecycle, recovery, archive, protected
export, purge, restore, document, AI, signing, entitlement, provider, or
network behavior is released. In particular, this release does **not**
authorize `SettingsView.swift`, a `ContentView` extraction, root-modal binding
work, or source-phase registration.

## Gate audit

| Required gate | Evidence reviewed | Delivery result |
| --- | --- | --- |
| Approved Settings design | Commit `efe1de6` adds only the approved VD2-07 design; `git diff --check efe1de6^..efe1de6` is clean. | Satisfied |
| Final test-first brief and plan | Commit `5544c03` amends only the VD2-07 task brief and implementation plan; `git diff --check 5544c03^..5544c03` is clean. | Satisfied |
| Architecture | `docs/delivery/reviews/VD2-07-preimplementation-architecture-final-2026-08-01.md` records **ACCEPT** and retains local-only Settings selection plus `ContentView` ownership. | Satisfied |
| QA/test plan gate | `docs/delivery/reviews/VD2-07-preimplementation-qa-final-2026-08-01.md` records **ACCEPT** for plan coverage only. | Satisfied for Task 1 release |
| Security/privacy | `docs/delivery/reviews/VD2-07-preimplementation-security-privacy-final-2026-08-01.md` records **ACCEPT** for planning only. | Satisfied |
| TPM | `docs/delivery/reviews/VD2-07-preimplementation-tpm-review-2026-08-01.md` records **ACCEPT** and recommends **Task 1 only**. | Satisfied |
| Upstream dependency | The current dashboard and roadmap identify VD2-02 and VD2-06 as accepted, with VD2-07 next in the delivery queue. | Satisfied |

The older preimplementation TPM gate remains a historical planning-blocked
record. Its stated missing artifacts and review decisions are now supplied by
the final records above; this release relies on the final independent TPM
decision, not on a reinterpretation of the earlier record.

## Baseline and runner evidence

The QA final record and the retained result bundle
`/private/tmp/rekon-vd207-qa-preimpl-baseline.xcresult` show the current
lower-layer and fixture-host baseline at **26 passed / 0 skipped**. That
invocation also contains one non-qualifying UI-runner infrastructure failure
(`Timed out while enabling automation mode`) before the recovery-only UI
selector ran. It is neither a Settings failure nor allowed Task 1 RED evidence.

Runner availability was subsequently recovered by two separate signed Debug
diagnostics, each executing the existing recovery-only selector once with no
failure or skip:

| Diagnostic | Result bundle | Result |
| --- | --- | --- |
| Probe | `/private/tmp/rekon-vd207-ui-probe-528107EA-52FF-45C4-9B8F-B8B854BA02AD.xcresult` | `testRecoveryFixtureShowsOnlyRecoveryActionsAndDoesNotOpenAWorkspace`: 1 passed / 0 failed / 0 skipped |
| Repeat | `/private/tmp/rekon-vd207-ui-repeat-8A24B025-7154-4E63-AE85-F9B5C5F95893.xcresult` | The same selector: 1 passed / 0 failed / 0 skipped |

Both result bundles remain present. Delivery independently re-ran
`codesign --verify --deep --strict` on each corresponding Debug app and it
succeeded. These are runner-capacity diagnostics only; they do not substitute
for the Task 1 matrix.

## Task 1 evidence that must be produced

Run the exact Task 1 command in
`docs/superpowers/plans/2026-08-01-vd207-settings-information-architecture.md`
with fresh unique DerivedData and result-bundle paths. A valid result must show:

- every named pre-existing lower-layer, fixture-host, and recovery-only selector
  exactly once as passed, with no skip; and
- each of the five newly released UI tests reaches its ready named fixture and
  fails only because its named `settings-*` selector or panel is absent.

A compile, signing, test-host, fixture-launch, global-rail, accessibility-query,
unrelated baseline, or UI-runner failure blocks the task and is not RED
evidence. Preserve the `.xcresult`, result summary, full test list, fixture
sessions, and the pre-task project-file SHA-256. The worktree is intentionally
dirty, including the two released test paths: stage only the six released
hunks, verify the staged diff and whitespace, and make the plan-mandated
isolated test checkpoint. Do not stage the shared worktree as a whole.

## Current non-completion evidence

There is no Task 1 RED result at the planned
`/private/tmp/rekon-vd207-task-1-red.xcresult` path. The current source tree
contains neither the five `testVD207...` UI methods nor the Task 1 protected
export cancellation regression. The current private `SettingsView` remains
inside `ContentView.swift`; no extracted `RekonPursuit/SettingsView.swift`
exists. Consequently, Task 1 evidence has not been pre-created or
misclassified, and Task 2 has no basis to start.

## Controlling-ledger decision

**No dashboard, roadmap, or SDD progress record was modified.** All three
controlling records were already dirty before this release:

- `docs/delivery/dashboard-status.json` has uncommitted changes to both the
  global active/next task fields and the VD2-07 card that would have to change
  for a Task 1 transition.
- `docs/delivery/roadmap.md` has uncommitted changes to both the active-queue
  summary and the VD2-07 table row that would have to change for the same
  transition.
- `.superpowers/sdd/2026-07-28-visual-design-v2/progress.md` is already
  modified and still describes VD2-07 as unreleased.

There is no narrow, non-overlapping patch that can change all controlling
records consistently without editing pre-existing user changes. Updating only
the progress record would make it contradict the unchanged dashboard and
roadmap. Delivery therefore leaves those files untouched and makes this
independent release record the authoritative Task 1 release until an owner can
reconcile the dirty controlling files without staging or overwriting unrelated
work.

## Downstream release state

- **Task 1:** Released only on the terms above.
- **Task 2:** Blocked pending a fresh independent QA acceptance of the exact
  signed Task 1 RED classification and baseline, followed by Architecture, TPM,
  and Delivery continuation decisions.
- **Task 3:** Blocked pending Task 2 GREEN and its independent Code Review, QA,
  Architecture, Security/privacy, TPM, and Delivery decisions.
- **Task 4 and product-owner acceptance:** Blocked pending Task 3 evidence and
  independent gates.
- **VD2-08:** Remains Backlog and blocked pending VD2-03 through VD2-07
  acceptance. Its three owner-approved VD2-06 accessibility/recovery automation
  debts remain open and are outside this release.
