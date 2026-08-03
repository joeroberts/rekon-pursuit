# VD2-05 — Core/VM baseline assertion repair delivery release

**Date:** 2026-07-31  
**Role:** Fresh independent Delivery Manager  
**Decision:** **Release one test-only actor-isolated baseline assertion repair.
Board interaction remains withheld.**

## Diagnosis

`WorkspaceViewModelTests` is `@MainActor`, as are the opportunity, activity,
attention, and history model conformances captured by the rollback baseline.
The synthesized `Equatable` witness for `StageMoveModelBaseline` must satisfy a
nonisolated XCTest generic boundary, so an `XCTAssertEqual` comparison of the
whole baseline cannot carry that actor isolation.

This is a test-infrastructure contradiction, not a production stage-move,
database, signing, or Board defect.

## Authorized amendment

Only `RekonPursuitTests/WorkspaceViewModelTests.swift` may change:

1. Remove `Equatable` from the `@MainActor` `StageMoveModelBaseline` value
   struct.
2. Add an `@MainActor` fieldwise assertion helper in the existing
   `@MainActor` test case.
3. Replace the four whole-baseline `XCTAssertEqual` calls with that helper.

The helper must retain every original baseline assertion: opportunities,
activity events, needs-attention array, all three counts, selected ID, selected
detail, and selected stage history. It must not weaken or remove any rollback,
no-op, unavailable, blocked, or failed outcome assertion.

The current corrected test selectors and signed-evidence requirements remain
unchanged:

```text
-only-testing:RekonPursuitTests/WorkspaceStoreTests
-only-testing:RekonPursuitTests/WorkspaceViewModelTests
```

## Explicit non-authorizations

No production source, project or signing configuration, test-host routing,
database schema, fixture data, Board/Pipeline/UI source, drag/drop, keyboard
control, activity copy, dashboard renderer, or successor VD2 work may change.
This release neither accepts the Core/VM slice nor releases Board interaction,
owner handoff, VD2-06, VD2-07, or VD2-08.

## Return gate

The repair must return fresh isolated signed-Debug focused result bundles for
both selectors, a verification record with successful signature checks, clean
`git diff --check`, and fresh independent QA and code-review verdicts. Then
Architecture, TPM, Security/privacy, and Delivery must re-evaluate the full
Core/VM slice before any Board interaction is eligible.

## Delivery state

- `VD2-05`: **In progress — baseline assertion/evidence repair only.**
- Board interaction and card relocation: **withheld.**
- `VD2-06`, `VD2-07`, `VD2-08`: **Backlog.**
