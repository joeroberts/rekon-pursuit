# VD2-05 — Core-suite evidence repair task brief

**Status:** Plan amended; Planning authorizes one narrowly bounded Slice A expected-value repair described below. Slice B remains blocked until the fresh six-selector signed Slice A run is 6/6 GREEN and all post-Slice-A reviews accept its evidence. Security/privacy must approve fixture isolation, encrypted recovery-snapshot coverage, v22 no-bookmark seed behavior, and no signing/entitlement change before and after Slice B implementation.

**Parent work:** Existing VD2-05 Task 2, transactional Core + view-model evidence. This brief repairs failed Core-suite evidence only; it does not accept Task 2 or release Task 3/Board interaction.

## Authorized scope

- Modify only `RekonPursuitCoreTests/WorkspaceStoreTests.swift`.
- Preserve the existing signed RED bundle at `/tmp/rekon-vd205-schema-impl-core-019fb/Logs/Test/Test-RekonPursuit-2026.07.31_01-07-59--0400.xcresult` (eight failed methods/nine records) as RED evidence.
- Produce test-only exact v11, v16, v18, v19, v20, and v22 fixtures; v19 must compose from v18.
- Insert and assert the deterministic non-secret common row `workspace_metadata('workspace_id', '00000000000040008000000000000001')` in every historical fixture.
- In `testUpdateOpportunityReplacesItsNextActionAndWritesOneActivityEvent`, add exactly `actionType: .other` and `actionCustomText: "Prepare recruiter call"` to the expected `Opportunity`. Retain `nextAction: "Prepare recruiter call"` and every other request argument, expected field, and assertion.

## Explicit non-authorizations

No production, migration, schema, UI, Board, project, signing, dashboard, roadmap, delivery ledger, or commit changes. Do not add production idempotency guards, `IF NOT EXISTS` masking, a one-table missing-table patch, current-schema rewind, migration replay, or copied migration behavior in expectation helpers.

## Test-first task decomposition

### A. Identity, explicit-date, and action-expectation repairs

1. Use the recorded result plus a fresh targeted signed Debug invocation as RED for the two stage `.first` failures and stale `invalidOpportunity` call.
2. In `testStageMoveCommitsStageAuditHistoryAndProjectionTogether`, use `first { $0.id == opportunity.id }` for the moved record and retain a second identity lookup that proves the unrelated record is `.saved`, both in the commit projection and after encrypted reopen.
3. Add only `stageChangedAt: now` to `testUpdateOpportunityReplacesItsNextActionAndWritesOneActivityEvent`; retain `title: "Senior Product Manager"`, `company: "Rekon Labs"`, `stage: .screening`, `nextAction: "Prepare recruiter call"`, `dueAt: rescheduled`, and every existing assertion.
4. Retain, execute, and require GREEN for `testUpdateRejectsMissingEffectiveDatesWithoutWriting` and `testHistoriesUseExplicitDateThenIdentifierForDeterministicTies`; the former proves nil remains rejected without writes.
5. Preserve `/private/tmp/rekon-vd205-core-suite-slice-a-green-20260731-019fb19c.xcresult` as accepted follow-up RED: four executed, three passed, and only `testUpdateOpportunityReplacesItsNextActionAndWritesOneActivityEvent` failed because its full-value expected `Opportunity` retained `.noAction` / `nil`. The accepted Architecture and QA diagnoses establish that production correctly canonicalizes the unchanged legacy text to `.other` / `"Prepare recruiter call"`.
6. Record the test file's pre-edit SHA-256 and diff. Add only `actionType: .other` and `actionCustomText: "Prepare recruiter call"` to that expected `Opportunity`; preserve the legacy `nextAction`, default `typedActionEdited: false`, every other field, and the separate attention-title, due-date, and exact activity-kind assertions. Record the post-edit SHA-256 and require the follow-up delta to contain only those two lines.
7. Run and require 6/6 GREEN for these exact selectors in one fresh signed Debug bundle: `testStageMoveCommitsStageAuditHistoryAndProjectionTogether`, `testUpdateOpportunityReplacesItsNextActionAndWritesOneActivityEvent`, `testUpdateRejectsMissingEffectiveDatesWithoutWriting`, `testHistoriesUseExplicitDateThenIdentifierForDeterministicTies`, `testLegacyCompensationAndActionTextRemainAvailableAsCompatibilityValues`, and `testStructuredCompensationAndOtherActionPersistWithoutChangingStageHistory`.

### B. Exact historical fixture architecture

1. Add `HistoricalWorkspaceSchemaVersion` cases 11, 16, 18, 19, 20, and 22 plus test-private helpers `makeHistoricalWorkspaceDatabase(at:version:)`, `installHistoricalWorkspaceSchema(on:through:)`, `insertHistoricalMigrationHistory(into:through:)`, `expectedHistoricalWorkspace(version:)`, and `assertExactHistoricalSchema(_:version:)`.
2. Build the schema from literal historical DDL, including all cumulative tables/indexes/columns, the deterministic workspace identity, and contiguous 4...N history/checksum records. It must never initialize current schema, call `WorkspaceStore`, call `WorkspaceMigrations.apply`, or drop later facts.
3. Compose v19 from exact v18 plus only `reconciliation_reviews`/index and pre-public-evidence `reconciliation_results`/index; compose v20 from exact v19 plus check-operation table/index and 15 public-evidence columns; compose v22 from exact v20 plus v21 structured compensation/action columns and v22 import display columns.
4. Keep the installer DDL/checksum declarations and the integrity expected table/index/column/checksum manifests as independent hand-written literals. Integrity code queries the encrypted database but does not derive expectations from installer arrays/switches, call production migrations/store code, or assert source text. For every declared table at every checkpoint, compare the exact `PRAGMA table_info` column-name set; this rejects post-v22 document columns in v18/v20 and retains explicit v22 no-`bookmark_data`/no-`availability`.
5. Write fixture-integrity tests first. Their initial missing-builder compiler result is the narrow API RED; retain the completed signed full bundle as the six behavioral migration RED records. After the builder compiles, validate each integrity test by a temporary one-fact test-only DDL mutation (missing v11 `task_reminders`, missing v16 `posting_checks`, or one forbidden next-version fact at v18/v19/v20/v22), observe its named failure, then restore the manifest before GREEN.
6. Convert all six failing behavior tests and both passing rollback regressions to the exact builder. In every v18/v19 test, seed `legacy-opportunity` before the foreign-key-dependent posting/result row. In both v19 tests, seed exact `result-v19` only after the parent. Preserve the rollback markers, rows, absent table/column facts, and verified snapshots. Remove all three `makeVersionEighteen/Nineteen/TwentyDatabase` rewind helpers and references.
7. Replace only the stale terminal version values in the v16, v18, v19, and v20 success tests (current lines 326/346/367/391) with `WorkspaceMigrations.currentVersion`; preserve every row/value assertion.

## Failure and regression matrix

| Required evidence | Selector |
| --- | --- |
| Failure records 1-2 | `testStageMoveCommitsStageAuditHistoryAndProjectionTogether` |
| Failure record 3 | `testUpdateOpportunityReplacesItsNextActionAndWritesOneActivityEvent`, plus retained nil-date and deterministic-tie tests |
| Failure record 4 | `testVersionEighteenPostingChecksMigrateLosslesslyToReadOnlyReconciliationHistory` |
| Failure record 5 | `testVersionElevenInteractionRowsAreRetainedAsLegacyRowsDuringContactInteractionMigration` |
| Failure record 6 | `testVersionNineteenMigratesToTwentyWithoutChangingExistingReconciliationRows` |
| Failure record 7 | `testVersionSixteenToSeventeenMigrationAndFailureKeepSnapshot` |
| Failure record 8 | `testVersionTwentyMigrationRetainsLegacyCompensationAndActionText` |
| Failure record 9 | `testVersionTwentyTwoDocumentReferenceMigrationRequiresRelinkWithoutRetainingBookmarkData` |
| Passing rollback regression 1 | `testFailedVersionNineteenMigrationRetainsVersionEighteenPostingChecksAndSnapshot` |
| Passing rollback regression 2 | `testFailedVersionTwentyMigrationKeepsVersionNineteenRowsAndVerifiedSnapshot` |

## Required signed checks

Run without `CODE_SIGNING_ALLOWED=NO`, each with unique isolated derived data and result bundle paths:

```text
Slice A: the six exact selectors listed in A.7, using /private/tmp/rekon-vd205-core-suite-slice-a-action-green-20260731-dd and /private/tmp/rekon-vd205-core-suite-slice-a-action-green-20260731.xcresult.
Slice B: accepted missing-builder API RED plus six preserved behavioral migration RED records; the six exact mutation commands and named assertion failures in Plan Task 2 Step 4; then all six integrity tests, six repaired failing migration selectors, and both retained rollback selectors.
Full: RekonPursuitTests/WorkspaceStoreTests.
Full: RekonPursuitTests/WorkspaceViewModelTests.
```

For Slice A, inspect both `xcresulttool get test-results summary` and `tests`; require exactly six passed, zero failed, zero skipped, and all six requested selectors enumerated once. Strictly verify and inspect identity for the generated Debug `RekonPursuit.app`, `Contents/MacOS/RekonPursuit`, and nested `Contents/PlugIns/RekonPursuitTests.xctest` using `codesign --verify --deep --strict --verbose=2` plus `codesign -dvv`. Record SHA-256 hashes for the pre- and post-edit `WorkspaceStoreTests.swift`, the generated app executable, the generated test-bundle executable, and the result bundle's `Info.plist`. Inspect the test-file diff against the captured follow-up baseline and run `git diff --check`.

For each Slice B mutation use its unique `-derivedDataPath`/`-resultBundlePath`, inspect `xcresulttool` summary and test details, require the exact named integrity assertion failure, and perform the same strict signature and identity checks. Revert each mutation before the next. Before final GREEN, require the obsolete helper-name scan to return no matches, inspect the permanent test-file diff against the pre-task dirty baseline, and run `git diff --check`; reject any new implementation-source diff outside `RekonPursuitCoreTests/WorkspaceStoreTests.swift`.

## Acceptance gates

After the expectation repair, a fresh separate Code Reviewer and independent QA verifier must accept the exact two-line delta and 6/6 signed evidence. Architecture must confirm no contract/ADR deviation; TPM must confirm scope/dependency readiness; Security/privacy must confirm no signing, entitlement, production, schema, migration, recovery, or persistence-scope change; Delivery must accept the evidence and explicitly release the next work. Slice B and Board remain blocked until every one of those post-Slice-A gates passes. No delivery evidence/status record is authorized by this brief.
