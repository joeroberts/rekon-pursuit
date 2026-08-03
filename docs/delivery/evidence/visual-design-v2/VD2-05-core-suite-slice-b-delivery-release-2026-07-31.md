# VD2-05 — Core-suite evidence-repair Slice B delivery release

**Date:** 2026-07-31  
**Role:** Fresh independent Delivery Manager  
**Decision:** **COMPLETE — Slice B accepted after implementation; repair-plan
Task 3 whole-suite proof is released separately.**

## Dependency decision

Slice A is complete. Fresh independent Code Review, QA, Architecture,
Security/privacy, and TPM post-gates each ACCEPT the same source hash,
baseline-relative delta, exact signed six-selector 6/6 evidence, signature
identities, artifact hashes, and clean whitespace check with no findings.

The accepted Slice A source SHA-256
`c482870a0648a1129f9fceecc325e126c0f412b35b96d7a1acc2476483ae88d0`
is the Slice B dirty-worktree baseline. Preserve the original 108-test signed
RED, the accepted Slice A follow-up RED, and both accepted Slice A 6/6 signed
GREEN bundles.

## Sole released implementation boundary

Modify only `RekonPursuitCoreTests/WorkspaceStoreTests.swift` under Task 2 of
`docs/superpowers/plans/2026-07-31-vd205-core-suite-evidence-repair.md` and
`docs/delivery/task-briefs/VD2-05-core-suite-evidence-repair.md`.

Implement exact declarative historical test databases for versions 11, 16, 18,
19, 20, and 22:

- Define the accepted `HistoricalWorkspaceSchemaVersion` cases and test-private
  builder, installer, migration-history, expected-manifest, and
  exact-schema-assertion helpers.
- Install literal cumulative `CREATE TABLE`, `CREATE INDEX`, and
  `ALTER TABLE ADD COLUMN` declarations only through the requested checkpoint.
  Compose v19 from exact v18, v20 from exact v19, and v22 from exact v20.
- Keep installer DDL/checksum declarations and expected table, named-index,
  per-table column, migration-history, and checksum manifests as independent
  hand-written literals. The oracle must query the encrypted database and use
  exact set/row equality; it must not derive one side from the other.
- Every fixture must have exact `schema_migrations`, contiguous literal
  migration-history rows 4...N with no later row, and exactly
  `workspace_metadata('workspace_id',
  '00000000000040008000000000000001')`.
- Do not initialize current schema, call `WorkspaceStore` or
  `WorkspaceMigrations.apply` from the fixture oracle/builder, replay
  production migrations, build current then rewind, add idempotency guards, or
  patch individual missing tables.

## Historical behavior and seed requirements

- Convert all six failed migration tests and both retained rollback regressions
  to the exact builder.
- Insert every parent opportunity before `posting_checks`,
  `reconciliation_results`, or `document_references` children. Both v19 tests
  must seed exact `result-v19` only after `legacy-opportunity`.
- The v22 seed uses the exact pre-v23 column list and contains no bookmark
  bytes or availability field.
- Preserve every hand-derived retained-row, mapping, foreign-key,
  absent-fact, snapshot retention/removal, empty-operation, compatibility, and
  current-version assertion.
- Replace only the four accepted stale terminal version literals with
  `WorkspaceMigrations.currentVersion`.
- Remove the three obsolete
  `makeVersionEighteen/Nineteen/TwentyDatabase` helpers and every reference.

## Required test-first and signed evidence

1. Retain the six recorded behavioral RED failures and use the missing-builder
   compiler result only as the narrow API RED for the six new integrity tests.
2. Run all six exact temporary mutation commands in the accepted plan,
   separately and signed:
   omit v11 `task_reminders`; omit v16 `posting_checks`; add v19
   `reconciliation_results` to v18; add v20
   `reconciliation_check_operations` to v19; add v21
   `compensation_minimum` to v20; add v23 `bookmark_data` to v22.
   Each must reach its named integrity assertion, include result
   summary/details and app/host/test-bundle signature identities, and be
   reverted before the next mutation.
3. After all mutations are gone, require the obsolete-helper scan to return no
   matches and prove the baseline-relative permanent implementation delta is
   confined to the authorized Slice A/B changes in
   `WorkspaceStoreTests.swift`.
4. Run the plan's exact signed 14-selector Slice B GREEN matrix: all six
   integrity tests, six repaired migration tests, and two retained rollback
   regressions. Require 14 passed, zero failed/skipped, exact selector
   enumeration, strict app/host/test-bundle signing and identity evidence,
   prescribed hashes, and clean `git diff --check`.

## Slice B completion gate

Slice B is complete. The accepted final
`RekonPursuitCoreTests/WorkspaceStoreTests.swift` SHA-256 is
`83d61ea4769da4c44c8466b5af76415f7e9ecebf974295ba036a424921dc2162`.
The missing-builder RED, all six reverted signed mutation proofs, and both
implementer and independent QA signed 14/14 GREEN results are accepted.
Signature identities, artifact hashes, obsolete-helper removal,
baseline-relative one-file scope, and `git diff --check` all verify.

| Post-gate | Evidence | Decision |
| --- | --- | --- |
| Final Core Code Review | `.superpowers/sdd/2026-07-31-vd205-core-suite-evidence-repair/task-2-slice-b-final-core-code-review.md` | ACCEPT; no findings. |
| QA | `.superpowers/sdd/2026-07-31-vd205-core-suite-evidence-repair/task-2-slice-b-post-implementation-qa.md` | ACCEPT; independently reproduced signed 14/14 and mutation evidence. |
| Architecture | `.superpowers/sdd/2026-07-31-vd205-core-suite-evidence-repair/task-2-slice-b-post-implementation-architecture.md` | ACCEPT; exact historical architecture and no ADR/production impact. |
| Security/privacy | `.superpowers/sdd/2026-07-31-vd205-core-suite-evidence-repair/task-2-slice-b-post-implementation-security.md` | ACCEPT; encrypted fixture/recovery/privacy and no-production-change boundaries verified. |
| TPM | `.superpowers/sdd/2026-07-31-vd205-core-suite-evidence-repair/task-2-slice-b-post-implementation-tpm-gate.md` | ACCEPT; Slice B may close and repair-plan Task 3 is the sole eligible successor. |

Delivery releases only the evidence-only successor in
[the whole-suite proof release](VD2-05-core-suite-task-3-whole-suite-proof-delivery-release-2026-07-31.md).

## Current non-authorizations and holds

No production, schema, migration, persistence, recovery, UI, Board, project,
scheme, signing, entitlement, dashboard, roadmap, ledger, delivery-evidence,
unrelated-test, or commit change belongs to Slice B implementation.

Parent VD2-05 Task 2 acceptance remains blocked pending the complete signed
Core/ViewModel proof and all repair-plan Task 3 post-gates. The original
VD2-05 Board/Task 3, card relocation, owner handoff, status advancement, and
VD2-06–08 remain withheld.
