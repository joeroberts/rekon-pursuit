# VD2-05 — schema-expectation repair delivery release

**Date:** 2026-07-31  
**Role:** Fresh independent Delivery Manager  
**Decision:** **APPROVED — release one test-only schema-expectation repair.**

## Independently verified diagnosis

A fresh signed-Debug focused run of
`-only-testing:RekonPursuitTests/WorkspaceStoreTests` passed 69 tests before
stopping at `RekonPursuitCoreTests/WorkspaceStoreTests.swift:176`: the test
expects schema version `25`, but the unchanged authoritative production value
is `WorkspaceMigrations.currentVersion == 33`.

`WorkspaceMigrations` already contains versions 26–33 and their checksum
constants. Those migrations predate the Visual Design v2 branch, and neither
committed nor uncommitted VD2-05 work changes `Migrations.swift`. Four
terminal schema assertions in `WorkspaceStoreTests.swift` still use `25`; the
v4 migration-history fixture likewise ends at v25. This is stale test
expectation evidence, not a VD2-05 persistence, migration, signing, or Board
failure.

## Authorized repair scope

Only `RekonPursuitCoreTests/WorkspaceStoreTests.swift` may change, and only to:

1. Replace semantically terminal schema-version assertions with the existing
   authoritative `WorkspaceMigrations.currentVersion`.
2. Extend the exact v4 migration-history expected rows through versions 26–33,
   using the existing `WorkspaceMigrations.versionTwentySixChecksum` through
   `WorkspaceMigrations.versionThirtyThreeChecksum` constants/values.
3. Preserve the existing migration setup, ordering, checksums, and all
   behavioral assertions. No assertion may be deleted, generalized to a lower
   bound, or otherwise weakened.

## Required return evidence

Before this repair can be considered complete, provide fresh, isolated,
signed-Debug result bundles for both selectors:

```text
-only-testing:RekonPursuitTests/WorkspaceStoreTests
-only-testing:RekonPursuitTests/WorkspaceViewModelTests
```

Record successful signature checks and focused test summaries in a new
verification record. Run the repository dashboard renderer/test as applicable
and `git diff --check`. Fresh independent QA and code-review verdicts are
required before Architecture, TPM, Security/privacy, and Delivery reconsider
the full Core/VM slice.

## Explicit non-authorizations

This release does **not** authorize production, schema, migration, project,
signing, fixture, or test-host source changes; weakened behavioral assertions;
Board/UI work; drag/drop; keyboard movement; card relocation; dashboard
advancement beyond VD2-05 in progress; owner handoff; or release of VD2-06,
VD2-07, or VD2-08.

## Delivery state

- `VD2-05`: **In progress — schema-expectation/evidence repair only.**
- Core/VM acceptance and Board interaction: **withheld.**
- Owner handoff and `VD2-06`–`VD2-08`: **not released.**
