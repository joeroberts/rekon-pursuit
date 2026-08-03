# VD2-07x Save-panel leaf authority — TPM release re-gate 3

**Date:** 2026-08-01  
**Role:** Fresh independent TPM  
**Verdict:** **ACCEPT — dependency-safe for Delivery Manager implementation release.**

## Decision

This is the next eligible, bounded repair within the already **In progress**
VD2-07 Settings task. It corrects the signed-app failure that prevents a valid
native `NSSavePanel` protected-export choice from reaching review. The product
owner has already authorized the protected-export repair and did not select a
new interaction, permission, or product capability; therefore no additional
owner approval is needed to release this implementation slice.

This decision does **not** complete VD2-07, authorize a dashboard transition,
or substitute for the mandatory signed owner-native smoke.

## Evidence reviewed

- `docs/architecture/adr/ADR-005-save-panel-leaf-export-authority.md`.
- `docs/superpowers/plans/2026-08-01-vd207x-save-panel-leaf-authority.md` and
  `docs/delivery/task-briefs/VD2-07x-save-panel-leaf-authority.md`.
- Accepted independent gates:
  - Architecture re-gate 3;
  - QA/test re-gate 2; and
  - Security/privacy re-gate 3.
- The unrepaired worker, which still opens, identifies, and writes through the
  selected leaf's parent directory; this matches the recorded signed sandbox
  root cause.
- Current delivery state in `docs/delivery/dashboard-status.json` and
  `docs/delivery/roadmap.md`: VD2-07 remains **In progress** and VD2-08 owns
  the deferred accessibility closure.
- The working-tree isolation check: the authorized protected-export feedback
  island in `RekonPursuitTests/WorkspaceViewModelTests.swift:706-860` has no
  current dirty hunk; unrelated dirty hunks remain elsewhere in that file and
  throughout the V2 worktree.

No production or test source was changed by this review.

## Released sequence

1. A fresh Delivery Manager may release exactly one fresh implementer for the
   atomic three-path TDD slice:
   - `RekonPursuitCore/Workspace/ProtectedExportWorker.swift`;
   - `RekonPursuitCoreTests/ProtectedExportTests.swift`; and
   - only the clean protected-export feedback island and adjacent helpers in
     `RekonPursuitTests/WorkspaceViewModelTests.swift:706-860`.
2. The implementer must first record the executable canonical-leaf RED, then
   the separately inspected GREEN and regression result bundles. Before
   editing the model test file, it must rerun the zero-context diff check and
   stop for a new integration plan if another edit enters the allowed island.
3. Fresh, separate Code Review, QA/test, Architect, and Security/privacy
   verifiers must inspect the implementation and the three result bundles.
   The implementer cannot perform any of those roles.
4. Only after those technical gates, build the configured signed Debug app and
   perform the actual one-step `NSSavePanel` owner smoke in a new local
   Documents child folder. The smoke must reach review without the false folder
   rejection and create one nonempty export at confirmation. It records only
   filename-safe, redacted evidence.
5. Delivery records the outcome. VD2-07 and its dashboard card remain **In
   progress** until that signed owner-native confirmation is recorded.

## Scope and dependency controls

- Retain the one-step Save panel, current `.rekonexport` filter/default name,
  folder-creation capability, existing sandbox entitlement, and leaf-only
  security-scope usage. The repair must not introduce a two-step folder
  chooser, a bookmark, an entitlement/signing change, or persistent selected
  path material.
- Do not change Settings visuals, subnavigation, dialogs, accessibility, the
  ViewModel source, Store/schema/activity schema, project files, dashboard
  presentation, or general Pipeline/Kanban work. VD2-08 remains the owner of
  the deferred accessibility issues.
- ADR-005 deliberately does not promise parent device/inode continuity between
  review and confirmation. A changed or unusable selected leaf must fail
  truthfully; restoring parent traversal would be a different scope requiring
  a new decision.
- The selected URL/path, recovery key, export contents, raw entitlement dump,
  and database remain out of retained evidence. Previously exposed recovery
  keys must not be used in the owner smoke.

## Residual risks and release condition

The only remaining functional proof is macOS-issued Save-panel authority in a
signed process; unit tests cannot mint it. The isolated dirty worktree is a
second delivery risk, controlled by the pre-edit hunk check and selective
staging of only the three allowlisted paths. Any scope expansion, source
boundary overlap, failed RED explanation, missing result-bundle inspection,
or failure to complete the signed owner smoke returns this work to Delivery
Manager triage.

**TPM release condition:** Delivery Manager may now issue the one-slice
implementation release, provided it records the hunk-isolation check and
preserves every condition above. No user action is pending before that release.
