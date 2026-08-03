# VD2-07x — Pre-implementation TPM release

**Date:** 2026-08-01  
**Role:** Independent TPM reviewer  
**Verdict:** **ACCEPT — release Task 1 only.**

## Release decision

VD2-06 is accepted, and the amended VD2-07x design, plan, and Task 1 brief
now form a dependency-safe, bounded first slice. This approval authorizes only
**Task 1: test-first event lifecycle, root projection, and visual RED**. It is
not implementation acceptance and does not advance VD2-07x beyond Task 1.

The original Architecture, QA, and Security/privacy blockers are superseded by
their recorded rechecks: Architecture **ACCEPT**, Security/privacy **ACCEPT**,
and QA final command recheck **ACCEPT**. The final QA recheck confirms that the
two signed matrices have 43 identical, unique selectors; route all selectors
to existing test bundles; differ only in their isolated output paths; and are
syntactically executable. It also confirms the required classification: zero
skips and zero expected failures, with only the three named visual-reference
methods permitted to be RED through the exact declared selector message.

## Authorized scope

Task 1 may do only the following on its six-file allowlist:

- Add the four deterministic reference UI contracts and the four protected-
  export event/token/workspace-transition contracts, plus the bounded existing
  pure presentation-state test extension.
- Add the filename-only, non-persisted `ProtectedExportSuccess` event; the
  private operation-token invalidation lifecycle; the test-only local creation
  closure; and the root-safe presentation value/dismissal binding.
- Run the exact signed Task 1 matrix and retain evidence that all baseline,
  operation, event, fixture, route, accessibility, archive, purge, restore,
  and workspace-transition selectors are green. The only permitted failures
  are the planned unrendered visual selectors in the three designated methods.

Task 1 must **not** compose the reference dashboard, tabs, cards, responsive
layout, or success dialog, and it must not close an export sheet. The current
source inventory supports that boundary: the reference panel/dialog selectors,
the success event/token types, and all eight new Task-1 methods are absent;
the current Settings view remains the pre-composition section/panel form. The
VD2-07x commits through `776f7b1` change only the amended brief and plan, not
application, test, project, fixture, or dashboard source.

## Dependencies and release holds

- Delivery must record its separate approval before work starts, as required by
  the amended brief. This TPM decision does not substitute for that gate.
- The implementation must first record the current dirty baseline. The
  worktree has 50 pre-existing modified/untracked entries, including the six
  Task-1 paths; no whole-file staging, reset, reformat, or attribution of those
  baseline changes to VD2-07x is permitted.
- Task 2 remains blocked pending Task 1's isolated-diff review and exact
  signed-matrix evidence: 43 selectors each run once, all nonvisual selectors
  green, and only the declared RED activities. Task 3 remains blocked pending
  Task 2's full green matrix, visual evidence, signing checks, and independent
  gates.
- VD2-08 remains **Backlog and blocked** until VD2-07 is accepted in full; its
  existing accessibility/recovery automation debts are not absorbed by this
  release.

## Risks and controls

The primary delivery risk is contamination from the dirty shared worktree.
Mitigate it with the Task-1 baseline commands, file-scoped diff inspection,
and an explicit comparison against the captured pre-work baseline before any
review. The functional/security risk is stale or sensitive export success.
The required opaque token, store-identity guard, deterministic in-flight
cancel test, exhaustive non-success cases, and filename-only root boundary
remain mandatory and green; they are not RED-eligible. Any source dashboard
composition, fixture/host/launch/project/Core/signing/entitlement/network
hunk, non-filename data transport, or matrix deviation is out of scope and
requires a new release decision.
