# VD2-05 Core-suite evidence repair Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Repair the eight failed `WorkspaceStoreTests` methods (nine recorded failures) so their assertions and historical fixtures prove the unchanged Core contracts against signed Debug builds.

**Architecture:** This is a test-only evidence repair under existing VD2-05 Task 2. Slice A makes the two stage-projection assertions identify the moved row, makes the stale update request supply the required effective date, and aligns one full-value expected `Opportunity` with the accepted legacy-action canonicalization contract. Slice B replaces partial/current-schema rewind fixtures with one declarative, test-only exact-historical-schema builder; its literals describe historical database states, while behavioral expected values remain hand-derived in the individual tests.

**Tech Stack:** Swift, XCTest, SQLCipher `EncryptedDatabase`, SQLite DDL, Xcode signed Debug test bundles, `codesign`.

## Global Constraints

- Preserve `/tmp/rekon-vd205-schema-impl-core-019fb/Logs/Test/Test-RekonPursuit-2026.07.31_01-07-59--0400.xcresult` as valid RED evidence: 108 tests, 100 passed, eight failed methods, nine failure records. Do not rewrite, delete, or reinterpret it as GREEN.
- The only implementation source permitted to change is `RekonPursuitCoreTests/WorkspaceStoreTests.swift`; do not change production, schema, migration, UI, Board, project, signing, dashboard, roadmap, ledger, or delivery evidence records, and do not commit.
- The accepted Architecture and QA diagnoses authorize exactly one additional Slice A expectation repair: in `testUpdateOpportunityReplacesItsNextActionAndWritesOneActivityEvent`, add only `actionType: .other` and `actionCustomText: "Prepare recruiter call"` to the expected `Opportunity`. Preserve `nextAction: "Prepare recruiter call"` and every other request argument, expected field, and assertion.
- Do not add idempotency guards to migrations or patch individual missing tables. Each repaired fixture must be the exact cumulative schema declared by `schema_migrations.version`.
- Do not derive expected migration behavior by replaying/copying production migration code. Fixture DDL may be declarative historical state; test assertions use literals for retained data behavior.
- Run signed Debug tests without `CODE_SIGNING_ALLOWED=NO`, with a unique `-derivedDataPath` and `-resultBundlePath` for every command.
- Before implementation, independent Architecture, TPM, QA, Delivery, **and Security/privacy** review and release this migration/recovery-fixture repair. Security/privacy independently verifies fixture isolation, encrypted recovery-snapshot coverage, no persisted bookmark bytes in the v22 seed, and no signing/entitlement change. The same independent Security/privacy review is required again after implementation.
- This plan repairs evidence only. It neither accepts VD2-05 Task 2 nor releases Task 3/Board work.

## File Structure and Interfaces

- Modify only `RekonPursuitCoreTests/WorkspaceStoreTests.swift`.
  - `testStageMoveCommitsStageAuditHistoryAndProjectionTogether()` locates the subject by `opportunity.id`, and explicitly proves the unrelated record remains `.saved` in both the projection and reopened store.
  - `testUpdateOpportunityReplacesItsNextActionAndWritesOneActivityEvent()` supplies `stageChangedAt: now` and expects the canonical legacy-action fields `.other` / `"Prepare recruiter call"` while retaining the legacy `nextAction`; `testUpdateRejectsMissingEffectiveDatesWithoutWriting()` remains the nil-date rejection contract.
  - Replace `makeVersionEighteenDatabase(at:)`, `makeVersionNineteenDatabase(at:)`, and `makeVersionTwentyDatabase(at:)`; replace the v11/v16/v22 inline partial/current-rewind setup with calls to the fixture architecture below.
  - Add test-only helpers with these exact signatures:

```swift
private enum HistoricalWorkspaceSchemaVersion: Int, CaseIterable {
    case eleven = 11, sixteen = 16, eighteen = 18, nineteen = 19, twenty = 20, twentyTwo = 22
}

private func makeHistoricalWorkspaceDatabase(
    at url: URL,
    version: HistoricalWorkspaceSchemaVersion
) throws -> EncryptedDatabase

private func installHistoricalWorkspaceSchema(
    on database: EncryptedDatabase,
    through version: HistoricalWorkspaceSchemaVersion
) throws

private func insertHistoricalMigrationHistory(
    into database: EncryptedDatabase,
    through version: HistoricalWorkspaceSchemaVersion
) throws

private func assertExactHistoricalSchema(
    _ database: EncryptedDatabase,
    version: HistoricalWorkspaceSchemaVersion
) throws

private struct HistoricalWorkspaceExpectation {
    let schemaVersion: Int
    let tables: Set<String>
    let namedIndexes: Set<String>
    let columnNamesByTable: [String: Set<String>]
    let migrationHistoryRows: [[DatabaseValue]]
}

private func expectedHistoricalWorkspace(
    version: HistoricalWorkspaceSchemaVersion
) -> HistoricalWorkspaceExpectation
```

`assertExactHistoricalSchema` is a fixture-integrity precondition, not an expectation mirror. It queries the real encrypted database and compares it with `expectedHistoricalWorkspace(version:)`. The installer DDL arrays and installer `(version, WorkspaceMigrations.*Checksum)` rows are one literal declaration; `expectedHistoricalWorkspace` is a separate hand-written literal declaration of expected tables, indexes, columns, and checksum strings. Neither declaration imports, maps, iterates over, parses, or otherwise derives values from the other. The integrity oracle must not call `WorkspaceMigrations.apply`, initialize `WorkspaceStore`, use a production migration SQL helper, or assert source text.

## Historical Fixture Contract

Every builder opens a fresh encrypted database, creates `schema_migrations(version INTEGER NOT NULL)`, writes exactly one selected version, creates `migration_history(version INTEGER PRIMARY KEY NOT NULL, checksum TEXT NOT NULL)`, and inserts contiguous rows 4...N with the matching `WorkspaceMigrations` checksum constants. There are no rows above N. It creates each table/index that existed at N with the following cumulative shapes, then inserts exactly one common historically required metadata row:

```sql
INSERT INTO workspace_metadata (key, value)
VALUES ('workspace_id', '00000000000040008000000000000001');
```

That deterministic 32-character lowercase hexadecimal value is non-secret test data. Every v11+ integrity test asserts the exact row `workspace_id`/`00000000000040008000000000000001`. Other than that common invariant and rows explicitly seeded by an individual behavior test, no fixture data is permitted.

| Cumulative fact | Exact historical shape |
| --- | --- |
| v11 base | `opportunities(id TEXT PRIMARY KEY NOT NULL,title TEXT NOT NULL,company TEXT NOT NULL,created_at REAL NOT NULL,stage TEXT NOT NULL DEFAULT 'Saved',next_action TEXT NOT NULL DEFAULT '',due_at REAL,deleted_at REAL)`; `task_reminders(id TEXT PRIMARY KEY NOT NULL,opportunity_id TEXT NOT NULL REFERENCES opportunities(id),title TEXT NOT NULL,due_at REAL,is_complete INTEGER NOT NULL DEFAULT 0)`; `activity_events(id TEXT PRIMARY KEY NOT NULL,kind TEXT NOT NULL,opportunity_id TEXT REFERENCES opportunities(id),contact_id TEXT,actor_id TEXT NOT NULL,correlation_id TEXT NOT NULL,occurred_at REAL NOT NULL)`; `contacts(id TEXT PRIMARY KEY NOT NULL,name TEXT NOT NULL,employer TEXT NOT NULL,title TEXT NOT NULL DEFAULT '',email TEXT NOT NULL DEFAULT '',profile_url TEXT NOT NULL DEFAULT '',relationship_context TEXT NOT NULL DEFAULT '',notes TEXT NOT NULL DEFAULT '',deleted_at REAL)`; `contact_opportunities(contact_id TEXT NOT NULL REFERENCES contacts(id),opportunity_id TEXT NOT NULL REFERENCES opportunities(id),PRIMARY KEY(contact_id,opportunity_id))`; `interactions(id TEXT PRIMARY KEY NOT NULL,opportunity_id TEXT NOT NULL REFERENCES opportunities(id),summary TEXT NOT NULL,occurred_at REAL NOT NULL)`; `workspace_metadata(key TEXT PRIMARY KEY NOT NULL,value TEXT NOT NULL)`; `deletion_tombstones(subject_id TEXT PRIMARY KEY NOT NULL,subject_type TEXT NOT NULL,deleted_at REAL NOT NULL,display_value TEXT NOT NULL)`; `import_reports(id TEXT PRIMARY KEY NOT NULL,imported_count INTEGER NOT NULL,skipped_count INTEGER NOT NULL,duplicate_kept_count INTEGER NOT NULL,invalid_count INTEGER NOT NULL,created_at REAL NOT NULL)`; `opportunity_stage_history(id TEXT PRIMARY KEY NOT NULL,opportunity_id TEXT NOT NULL REFERENCES opportunities(id),from_stage TEXT,to_stage TEXT NOT NULL,occurred_at REAL NOT NULL)`. There are no v11 secondary indexes. |
| v12-v16 additions | v12 replaces `interactions` with `id TEXT PRIMARY KEY NOT NULL,contact_id TEXT REFERENCES contacts(id),opportunity_id TEXT REFERENCES opportunities(id),kind TEXT NOT NULL,summary TEXT NOT NULL,occurred_at REAL NOT NULL,next_touch_at REAL`, index `interactions_contact_occurred_at(contact_id,occurred_at,id)`; v13 adds `opportunities.job_url TEXT NOT NULL DEFAULT ''`, `posting_checks(id TEXT PRIMARY KEY NOT NULL,opportunity_id TEXT NOT NULL REFERENCES opportunities(id),url TEXT NOT NULL,status TEXT NOT NULL,evidence TEXT NOT NULL,checked_at REAL NOT NULL)`, index `posting_checks_opportunity_checked_at(opportunity_id,checked_at,id)`; v14 adds `document_references(id TEXT PRIMARY KEY NOT NULL,opportunity_id TEXT NOT NULL REFERENCES opportunities(id),kind TEXT NOT NULL,filename TEXT NOT NULL,content_type TEXT NOT NULL,source_hash TEXT NOT NULL,byte_count INTEGER NOT NULL,attached_at REAL NOT NULL,final_sent_at REAL)`, index `document_references_opportunity_attached_at(opportunity_id,attached_at,id)`; v15 adds `opportunities.job_description TEXT NOT NULL DEFAULT ''`, `notes TEXT NOT NULL DEFAULT ''`; v16 adds `compensation TEXT`, `location TEXT`, `work_arrangement TEXT NOT NULL DEFAULT 'Not specified'`, `application_date REAL`, `response_state TEXT NOT NULL DEFAULT 'No response recorded'`, `stage_changed_at REAL`, plus `opportunity_response_history(id TEXT PRIMARY KEY NOT NULL,opportunity_id TEXT NOT NULL REFERENCES opportunities(id),from_state TEXT NOT NULL,to_state TEXT NOT NULL,occurred_at REAL NOT NULL)`, index `opportunity_response_history_opportunity_occurred_at(opportunity_id,occurred_at DESC,id DESC)`. |
| v17-v18 additions | v17 adds `import_reports.updated_count INTEGER NOT NULL DEFAULT 0`, `source_basename TEXT NOT NULL DEFAULT ''`, `mapping_summary TEXT NOT NULL DEFAULT ''`, `import_report_rows(id TEXT PRIMARY KEY NOT NULL,report_id TEXT NOT NULL REFERENCES import_reports(id),source_row INTEGER NOT NULL,outcome TEXT NOT NULL,reason TEXT NOT NULL,duplicate_rationale TEXT NOT NULL,opportunity_id TEXT)`, index `import_report_rows_report_row(report_id,source_row)`; v18 adds `import_reports.failed_count INTEGER NOT NULL DEFAULT 0`. |
| v19 additions | `reconciliation_reviews(opportunity_id TEXT PRIMARY KEY NOT NULL REFERENCES opportunities(id),task_reminder_id TEXT NOT NULL UNIQUE REFERENCES task_reminders(id),created_at REAL NOT NULL,closure_confirmed_at REAL)`, index `reconciliation_reviews_task_reminder_id(task_reminder_id)`; `reconciliation_results(id TEXT PRIMARY KEY NOT NULL,opportunity_id TEXT NOT NULL REFERENCES opportunities(id),url TEXT NOT NULL,recorded_at REAL NOT NULL,outcome TEXT NOT NULL,classification TEXT NOT NULL,reason TEXT NOT NULL,confidence TEXT,evidence TEXT NOT NULL,error TEXT NOT NULL,review_task_reminder_id TEXT REFERENCES task_reminders(id),closure_confirmed_at REAL,legacy_posting_check_id TEXT UNIQUE,legacy_status TEXT)`, index `reconciliation_results_opportunity_recorded_at(opportunity_id,recorded_at DESC,id DESC)`. |
| v20 additions | `reconciliation_check_operations(id TEXT PRIMARY KEY NOT NULL,opportunity_id TEXT NOT NULL REFERENCES opportunities(id),correlation_id TEXT NOT NULL UNIQUE,url_snapshot TEXT NOT NULL,state TEXT NOT NULL,started_at REAL NOT NULL,terminal_at REAL)`, index `reconciliation_check_operations_opportunity_state(opportunity_id,state)`; add nullable `reconciliation_results.check_operation_id TEXT REFERENCES reconciliation_check_operations(id)`, `method TEXT`, `checker_version TEXT`, `http_status INTEGER`, `mime_type TEXT`, `declared_bytes INTEGER`, `received_bytes INTEGER`, `content_sha256 TEXT`, `response_date TEXT`, `last_modified TEXT`, `etag TEXT`, `retry_after TEXT`, `redirect_target_redacted TEXT`, `evidence_excerpt TEXT`, `redacted_error_code TEXT`. |
| v21-v22 additions (only v22) | v21 adds `opportunities.compensation_minimum REAL`, `compensation_maximum REAL`, `compensation_pay_period TEXT`, `action_type TEXT NOT NULL DEFAULT 'No action'`, `action_custom_text TEXT`; v22 adds `import_report_rows.display_title TEXT NOT NULL DEFAULT ''`, `display_company TEXT NOT NULL DEFAULT ''`. `document_references.bookmark_data` and `availability`, `recovery_enrollment`, all v25+ tables, and all v26 triggers are absent. |

The builder installs v11 through v16 cumulatively from literal DDL arrays, v18 by adding v17/v18 to exact v16, v19 by composing exact v18 plus only the v19 tables/indexes/history row, v20 by composing exact v19 plus only v20, and v22 by composing exact v20 plus only v21/v22. This composition is required: `makeHistoricalWorkspaceDatabase(at:version:.nineteen)` must call the same internal v18 installation path before adding v19, never create current schema then drop facts.

### Exact table and index manifest

`assertExactHistoricalSchema` must compare `sqlite_master` table/index names to these exact version ceilings (SQLite implicit primary-key indexes are excluded from the named-index comparison):

| Version | Required user tables | Required named indexes | Required absent facts |
| --- | --- | --- | --- |
| 11 | `schema_migrations`, `migration_history`, `opportunities`, `task_reminders`, `activity_events`, `contacts`, `contact_opportunities`, `interactions`, `workspace_metadata`, `deletion_tombstones`, `import_reports`, `opportunity_stage_history` | none | `interactions_contact_occurred_at`, `posting_checks`, `document_references`, `opportunity_response_history`, `import_report_rows`, every reconciliation table. |
| 16 | v11 tables plus `posting_checks`, `document_references`, `opportunity_response_history` | `interactions_contact_occurred_at`, `posting_checks_opportunity_checked_at`, `document_references_opportunity_attached_at`, `opportunity_response_history_opportunity_occurred_at` | `import_report_rows`, reconciliation tables, `opportunities.compensation_minimum`, `import_report_rows.display_title`, `document_references.bookmark_data`, `recovery_enrollment`. |
| 18 | v16 tables plus `import_report_rows` | v16 indexes plus `import_report_rows_report_row` | all v19 reconciliation tables/indexes; all v20 evidence columns; all v21/v22 columns; all v23+ tables/indexes/triggers. |
| 19 | v18 tables plus `reconciliation_reviews`, `reconciliation_results` | v18 indexes plus `reconciliation_reviews_task_reminder_id`, `reconciliation_results_opportunity_recorded_at` | `reconciliation_check_operations` and its index; all v20 added columns; all v21+ facts. |
| 20 | v19 tables plus `reconciliation_check_operations` | v19 indexes plus `reconciliation_check_operations_opportunity_state` | all five v21 `opportunities` columns, both v22 `import_report_rows` columns, every v23+ table/index/trigger. |
| 22 | v20 tables | v20 named indexes exactly | `document_references.bookmark_data`, `document_references.availability`, `recovery_enrollment`, `portable_archive_catalogue`, `tracker_export_revision`, `protected_export_events`, every v26 trigger, and every v27-v33 table/column/index. |

The column manifests are cumulative and exact: v11 columns are the v11 base row above; v16 adds exactly the v12-v16 row; v18 adds exactly the v17-v18 row; v19 adds exactly the v19 row; v20 adds exactly the v20 row; and v22 adds exactly the v21-v22 row. For every table in the declared table set—including `schema_migrations` and `migration_history`—`assertExactHistoricalSchema` executes `PRAGMA table_info(<table>)`, extracts column names, and requires exact `Set<String>` equality with the independent `columnNamesByTable[table]`. Required-column containment is insufficient. This exact equality rejects stray v23 `document_references.bookmark_data` or `availability` columns at v18 and v20 as well as v22; v22 additionally retains named assertions that both columns are absent.

### Independent literal checksum oracle

The installer writes checksum values through its own explicit `WorkspaceMigrations` constant switch. The integrity expectation must independently contain these literal SHA-256 strings and slice the hand-written list at the requested version; it must not reuse the installer switch or recompute hashes from production manifests:

| Version | Expected literal checksum |
| ---: | --- |
| 4 | `363c516ac302e21fedd5407bb547daa516b957f592ee7a0505f7e3d8f88ce6e9` |
| 5 | `5fa294b9f447a4acebdd8961a43f4214788bf67fab3b0165c327f4a032e4e36b` |
| 6 | `ca983bac7d74e8f3c4107bc4c893c30a244467a27f301b4dbe929580673841b8` |
| 7 | `8e651b7b00affb52940b0d3873439a64f9cec7448cef601e0553e636fe8159f9` |
| 8 | `ad8da3456b86cc4a74c5438126ca448261760e29c1adda72cde837ed297c195e` |
| 9 | `c155d40c9ad76659e9e26660e4802ee1a324cd81f3dd6b2950ed48e7730df7dd` |
| 10 | `5dea6b590574cf8aba5cc0e26c1a91c24bfd517dcfe04a586b341432f4478cff` |
| 11 | `2787c3a077d6038cdbc0e04192469c586a376752293e35e37273cfb4591d90bd` |
| 12 | `d6ac5e4b99e8f6d9eabd3c9bb14ac186b22a7c2995b56aa230bc399f29a45c67` |
| 13 | `fc1a67cc69bc1e1753627154ffe426d45dcd8c40c1c6bbfe8e9af283b571fc5a` |
| 14 | `a5124dad9f2faccedbf6a89289263372fea732fdbe5f21c1c25c9f7f15086333` |
| 15 | `9ee95b90bd209947f260e9c8aca9b13be63a6ebb5baa9a8af45abf69afbe858e` |
| 16 | `ded7964daa1d739c95b9368b423c916c74610ee05cfb3b311bca8b3f665fb558` |
| 17 | `ee5d2ea234ba5dcb8a31fbe1b77adeb68ab211074f17f9c875934f0f07379c95` |
| 18 | `ede096d54d80a8add35b640127686b3e5d7415fc72f3dd97832add02812e7c85` |
| 19 | `b77fca7a7d83a9ceee85e48862beadd303016e1cd5c4aded14b67f110dfa03d5` |
| 20 | `f8479d3ccd283df05793c7680af5131a9ec03c5265fc53add03b03dc0f70dc44` |
| 21 | `ee3b09829091f7dacd090d6c368a0875cd0e3b4f037ddc653a0696ee7063b63a` |
| 22 | `c24963911d57d3e250de2fb101041f2f4a13e2780ec0009a8a59d8923ce915c9` |

## Task 1: Slice A — identity, effective-date, and action-expectation contract repairs

**Files:**

- Modify: `RekonPursuitCoreTests/WorkspaceStoreTests.swift:872-914,1082-1110`

**Consumes:** Recorded RED failures 1-3 and existing active stage/date contracts.
**Produces:** Identity-based stage projection/reopen evidence and an update test that obeys the explicit effective-date API and expects the existing legacy-action canonicalization contract.

- [ ] **Step 1: Establish Slice A RED evidence and mutation targets**

Record the existing signed result bundle's two `.first` assertions failing `.saved != .screening` and its `invalidOpportunity` failure. The production mutations that these repaired assertions must catch are: returning/moving the wrong opportunity in the committed projection or after reopen, mutating the unrelated row, and removing the explicit-date rejection guard. Do not manufacture a second RED by changing production code.

Run the focused selector only to confirm it reaches the recorded failures in a fresh signed Debug bundle:

```bash
xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:RekonPursuitTests/WorkspaceStoreTests/testStageMoveCommitsStageAuditHistoryAndProjectionTogether \
  -only-testing:RekonPursuitTests/WorkspaceStoreTests/testUpdateOpportunityReplacesItsNextActionAndWritesOneActivityEvent \
  -derivedDataPath /tmp/rekon-vd205-core-suite-slice-a-red-dd \
  -resultBundlePath /tmp/rekon-vd205-core-suite-slice-a-red.xcresult
```

Expected: the named assertion/`invalidOpportunity` failures, not a compile, cache, fixture, or signing error.

- [ ] **Step 2: Repair the two stage assertions by identity**

Immediately after the persisted projection is unwrapped, select the moved record and the unrelated record by their immutable IDs, then assert their exact stages. Replace the positional/reopen reads with this concrete shape:

```swift
let projectedMoved = try XCTUnwrap(commit.projection.opportunities.first { $0.id == opportunity.id })
let projectedOther = try XCTUnwrap(commit.projection.opportunities.first { $0.id != opportunity.id })
XCTAssertEqual(projectedMoved.stage, .screening)
XCTAssertEqual(projectedOther.stage, .saved)

try store.close()
let reopened = try makeStore()
let reopenedMoved = try XCTUnwrap(try reopened.opportunities().first { $0.id == opportunity.id })
let reopenedOther = try XCTUnwrap(try reopened.opportunities().first { $0.id == projectedOther.id })
XCTAssertEqual(reopenedMoved.stage, .screening)
XCTAssertEqual(reopenedOther.stage, .saved)
```

Retain the existing exact activity, history, attention, from/to, and count assertions. Do not reorder fixtures, change production order, or replace the unrelated-row assertion with a count-only check.

- [ ] **Step 3: Repair the stale update request and preserve rejection behavior**

In `testUpdateOpportunityReplacesItsNextActionAndWritesOneActivityEvent`, add only the existing fixed clock value to the intentional Saved-to-Screening request. Preserve every existing argument and every existing assertion:

```swift
try store.updateOpportunity(
    id: opportunity.id,
    title: "Senior Product Manager",
    company: "Rekon Labs",
    stage: .screening,
    nextAction: "Prepare recruiter call",
    dueAt: rescheduled,
    stageChangedAt: now
)
```

Keep `testUpdateRejectsMissingEffectiveDatesWithoutWriting` unchanged and run it with the repaired test and deterministic-tie test; it remains the nil-date RED/guard proof.

- [ ] **Step 4: Preserve the accepted follow-up action-contract RED**

Treat `/private/tmp/rekon-vd205-core-suite-slice-a-green-20260731-019fb19c.xcresult` as follow-up RED evidence, not GREEN. Record its inspected result as four executed, three passed, and one failed: `testUpdateOpportunityReplacesItsNextActionAndWritesOneActivityEvent` differs only because the full-value expected `Opportunity` still says `.noAction` / `nil` while the persisted legacy action is correctly canonicalized to `.other` / `"Prepare recruiter call"`. This diagnosis is accepted by:

- `.superpowers/sdd/2026-07-31-vd205-core-suite-evidence-repair/task-1-action-contract-architecture.md`
- `.superpowers/sdd/2026-07-31-vd205-core-suite-evidence-repair/task-1-action-contract-qa.md`

Do not reinterpret that four-selector bundle as satisfying the Slice A gate.

- [ ] **Step 5: Apply only the accepted action expectation repair**

Before editing, record `shasum -a 256 RekonPursuitCoreTests/WorkspaceStoreTests.swift` and the current test-file diff as the follow-up baseline. In the expected `Opportunity` inside `testUpdateOpportunityReplacesItsNextActionAndWritesOneActivityEvent`, add exactly these two fields after the retained `stageChangedAt: now`:

```swift
actionType: .other,
actionCustomText: "Prepare recruiter call"
```

Preserve `nextAction: "Prepare recruiter call"` and every other expected field. Preserve the full `updateOpportunity` call, including the existing default `typedActionEdited: false`, and preserve all separate attention-title, due-date, and exact activity-kind assertions. Do not add structured-action request arguments or change production, model defaults, schema, migrations, UI, Board, project, signing, or any other test.

After editing, record the source-file SHA-256 again and compare the new diff with the follow-up baseline. The only newly introduced delta must be those two expected-value lines; the already-authorized ID-selection and `stageChangedAt: now` repairs remain intact.

- [ ] **Step 6: Prove the fresh six-selector signed Slice A GREEN**

```bash
xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:RekonPursuitTests/WorkspaceStoreTests/testStageMoveCommitsStageAuditHistoryAndProjectionTogether \
  -only-testing:RekonPursuitTests/WorkspaceStoreTests/testUpdateOpportunityReplacesItsNextActionAndWritesOneActivityEvent \
  -only-testing:RekonPursuitTests/WorkspaceStoreTests/testUpdateRejectsMissingEffectiveDatesWithoutWriting \
  -only-testing:RekonPursuitTests/WorkspaceStoreTests/testHistoriesUseExplicitDateThenIdentifierForDeterministicTies \
  -only-testing:RekonPursuitTests/WorkspaceStoreTests/testLegacyCompensationAndActionTextRemainAvailableAsCompatibilityValues \
  -only-testing:RekonPursuitTests/WorkspaceStoreTests/testStructuredCompensationAndOtherActionPersistWithoutChangingStageHistory \
  -derivedDataPath /private/tmp/rekon-vd205-core-suite-slice-a-action-green-20260731-dd \
  -resultBundlePath /private/tmp/rekon-vd205-core-suite-slice-a-action-green-20260731.xcresult
```

Use these exact evidence checks:

```bash
xcrun xcresulttool get test-results summary \
  --path /private/tmp/rekon-vd205-core-suite-slice-a-action-green-20260731.xcresult
xcrun xcresulttool get test-results tests \
  --path /private/tmp/rekon-vd205-core-suite-slice-a-action-green-20260731.xcresult

codesign --verify --deep --strict --verbose=2 \
  /private/tmp/rekon-vd205-core-suite-slice-a-action-green-20260731-dd/Build/Products/Debug/RekonPursuit.app
codesign -dvv \
  /private/tmp/rekon-vd205-core-suite-slice-a-action-green-20260731-dd/Build/Products/Debug/RekonPursuit.app
codesign --verify --deep --strict --verbose=2 \
  /private/tmp/rekon-vd205-core-suite-slice-a-action-green-20260731-dd/Build/Products/Debug/RekonPursuit.app/Contents/MacOS/RekonPursuit
codesign -dvv \
  /private/tmp/rekon-vd205-core-suite-slice-a-action-green-20260731-dd/Build/Products/Debug/RekonPursuit.app/Contents/MacOS/RekonPursuit
codesign --verify --deep --strict --verbose=2 \
  /private/tmp/rekon-vd205-core-suite-slice-a-action-green-20260731-dd/Build/Products/Debug/RekonPursuit.app/Contents/PlugIns/RekonPursuitTests.xctest
codesign -dvv \
  /private/tmp/rekon-vd205-core-suite-slice-a-action-green-20260731-dd/Build/Products/Debug/RekonPursuit.app/Contents/PlugIns/RekonPursuitTests.xctest

shasum -a 256 \
  RekonPursuitCoreTests/WorkspaceStoreTests.swift \
  /private/tmp/rekon-vd205-core-suite-slice-a-action-green-20260731-dd/Build/Products/Debug/RekonPursuit.app/Contents/MacOS/RekonPursuit \
  /private/tmp/rekon-vd205-core-suite-slice-a-action-green-20260731-dd/Build/Products/Debug/RekonPursuit.app/Contents/PlugIns/RekonPursuitTests.xctest/Contents/MacOS/RekonPursuitTests \
  /private/tmp/rekon-vd205-core-suite-slice-a-action-green-20260731.xcresult/Info.plist

git diff -- RekonPursuitCoreTests/WorkspaceStoreTests.swift
git diff --check
```

Expected: the result summary reports exactly six tests passed, zero failed, and zero skipped; test details enumerate all six requested selectors once as passed. All three strict signature verifications succeed, all three `codesign -dvv` inspections record identity/details, all four regular-file SHA-256 values are recorded, the test-file diff preserves the prior authorized repairs and adds only the two expected fields, and `git diff --check` exits zero.

Slice B remains blocked until this exact 6/6 signed GREEN evidence and hashes are accepted by a fresh separate Code Reviewer and QA verifier, then by Architecture, TPM, Security/privacy, and Delivery. A failed/skipped/missing selector, signature or identity problem, missing hash, unauthorized diff, or failed whitespace check keeps Slice B blocked.

## Task 2: Slice B — exact historical-schema fixture repair

**Files:**

- Modify: `RekonPursuitCoreTests/WorkspaceStoreTests.swift:241-418,1887-1918,2003-2039`

**Consumes:** Recorded RED failures 4-9, both passing rollback regressions that call the obsolete rewind helpers, accepted six-selector Slice A signed GREEN plus all post-Slice-A gates, and the historical fixture contract above.
**Produces:** Six authentic declared-version databases, eight migrated behavior tests, six integrity tests, and no `makeVersionEighteenDatabase`, `makeVersionNineteenDatabase`, or `makeVersionTwentyDatabase` wrapper.

- [ ] **Step 1: Establish Slice B RED evidence and write fixture-integrity tests first**

The existing full signed result bundle is the behavioral RED for all six migration methods. Add one focused fixture-integrity test per version before defining the new builder, using real `EncryptedDatabase` queries and hand-written manifests:

```swift
func testVersionElevenFixtureHasOnlyVersionElevenFacts() throws
func testVersionSixteenFixtureHasOnlyVersionSixteenFacts() throws
func testVersionEighteenFixtureHasOnlyVersionEighteenFacts() throws
func testVersionNineteenFixtureComposesExactVersionEighteenPlusNineteen() throws
func testVersionTwentyFixtureHasOnlyVersionTwentyFacts() throws
func testVersionTwentyTwoFixtureHasOnlyVersionTwentyTwoFacts() throws
```

The initial compiler error for the missing `makeHistoricalWorkspaceDatabase(at:version:)` is accepted as the narrow test-first API RED for these six new integrity tests. It is not substituted for the six behavioral RED records already preserved in the signed full bundle. After the minimal builder exists, validate the integrity tests behaviorally by making one temporary test-only DDL mutation at a time, running its selector, observing the named failure, then reverting the mutation before proceeding: omit v11 `task_reminders`; omit v16 `posting_checks`; add v19 `reconciliation_results` to v18; add v20 `reconciliation_check_operations` to v19; add v21 `compensation_minimum` to v20; add v23 `bookmark_data` to v22.

Each final integrity test calls `makeHistoricalWorkspaceDatabase(at:version:)`, checks `schema_migrations`, the exact `workspace_metadata` row, independent literal contiguous checksum rows, exact `sqlite_master` table/index set equality, and exact `PRAGMA table_info` column-name set equality for every declared table. No integrity test calls `WorkspaceMigrations.apply`; the eight behavior tests remain the real migration-chain tests.

- [ ] **Step 2: Implement the declarative fixture builder, no migration replay**

Install literal `CREATE TABLE`, `CREATE INDEX`, and `ALTER TABLE ADD COLUMN` statements in test-only DDL arrays grouped by historical checkpoint. Use `HistoricalWorkspaceSchemaVersion` switches to install only checkpoint groups at or below `through.rawValue`, then insert history rows using an explicit `(version, checksum)` switch covering 4...22 and insert the deterministic `workspace_metadata` row. Keep all table names, columns, nullability, defaults, foreign-key references, primary keys, index names, and metadata values exactly as listed in the Historical Fixture Contract. Do not call `WorkspaceMigrations.apply`, initialize a `WorkspaceStore`, build v33, or drop/alter later facts.

Keep construction and expectation independent:

```swift
// Installer-side declarations; never consumed by expectedHistoricalWorkspace.
private let versionElevenDDL: [String]
private let versionTwelveThroughSixteenDDL: [String]
private let versionSeventeenThroughEighteenDDL: [String]
private let versionNineteenDDL: [String]
private let versionTwentyDDL: [String]
private let versionTwentyOneThroughTwentyTwoDDL: [String]

// Assertion-side declaration; never generated from the installer arrays/switch.
private func expectedHistoricalWorkspace(
    version: HistoricalWorkspaceSchemaVersion
) -> HistoricalWorkspaceExpectation
```

The expectation function contains separate literal table sets, named-index sets, per-table column-name sets, the exact metadata row, and the literal checksum hashes above. A shared builder array or installer switch must never be the asserted oracle.

The required composition is:

```swift
case .nineteen:
    try installHistoricalWorkspaceSchema(on: database, through: .eighteen)
    try installVersionNineteenSchema(on: database)
case .twenty:
    try installHistoricalWorkspaceSchema(on: database, through: .nineteen)
    try installVersionTwentySchema(on: database)
case .twentyTwo:
    try installHistoricalWorkspaceSchema(on: database, through: .twenty)
    try installVersionTwentyOneAndTwentyTwoSchema(on: database)
```

The helper's fixture precondition asserts absence of all later facts before returning. Do not use it to calculate expected migrated rows.

- [ ] **Step 3: Seed each historical test directly and retain its behavior contract**

Use the shared builder for the v11, v16, v18, v19, v20, and v22 tests. Convert both retained rollback tests as well as the six failed migration tests. Insert parent rows before all foreign-key-dependent child rows:

Use this exact parent opportunity seed in every v18/v19 test before inserting `posting_checks` or `reconciliation_results`:

```swift
try database.execute(
    """
    INSERT INTO opportunities (
        id, title, company, created_at, stage, next_action, due_at,
        job_url, job_description, notes, compensation, location,
        work_arrangement, application_date, response_state,
        stage_changed_at, deleted_at
    ) VALUES (
        'legacy-opportunity', 'Legacy role', 'Rekon Labs', ?,
        'Saved', '', NULL, '', '', '', NULL, NULL, 'Not specified',
        NULL, 'No response recorded', ?, NULL
    )
    """,
    values: [.real(now.timeIntervalSince1970), .real(now.timeIntervalSince1970)]
)
```

Use this exact child seed only after that parent in both v19 tests:

```swift
try database.execute(
    """
    INSERT INTO reconciliation_results (
        id, opportunity_id, url, recorded_at, outcome, classification,
        reason, confidence, evidence, error, review_task_reminder_id,
        closure_confirmed_at, legacy_posting_check_id, legacy_status
    ) VALUES (
        'result-v19', 'legacy-opportunity', 'https://jobs.example.com/role',
        ?, 'Needs manual review', 'Ambiguous', 'manual review', 'Medium',
        'Existing R4 evidence', '', NULL, NULL, NULL, NULL
    )
    """,
    values: [.real(now.timeIntervalSince1970)]
)
```

For the v22 document test, seed the same parent opportunity first, then insert the exact pre-v23 row directly:

```swift
try database.execute(
    """
    INSERT INTO document_references (
        id, opportunity_id, kind, filename, content_type, source_hash,
        byte_count, attached_at, final_sent_at
    ) VALUES (
        'document-v22', 'legacy-opportunity', 'Résumé', 'resume.pdf',
        'application/pdf', ?, 2048, ?, NULL
    )
    """,
    values: [
        .text(String(repeating: "c", count: 64)),
        .real(now.timeIntervalSince1970)
    ]
)
```

The row has no place to carry bookmark bytes or availability because exact v22 `document_references` has neither column.

| Starting version/test | Seed and retained post-apply assertions |
| --- | --- |
| v11 interaction | `opportunity-1` and `interaction-1`; v12 result keeps ID/opportunity/summary/time, maps `contact_id` and `next_touch_at` to NULL and `kind` to `Note`; reaches `currentVersion`; snapshot is removed. |
| v16 v17 rollback/success | `import_reports('prior', 1,0,0,0, now)`; injected v17 leaves marker 16, prior row, and snapshot; ordinary apply reaches `currentVersion` and retains `updated_count == 0`, `source_basename == ""`. |
| v18 posting success | Seed `legacy-opportunity` first with the exact parent SQL above, then the four literal posting statuses/evidence rows; hand-derived mapping remains Still open/Confirmed, Possibly closed/Ambiguous, Closed suggested/Confirmed, Needs manual review/Ambiguous; exactly one review for non-open rows; reaches `currentVersion`; snapshot removed. |
| retained v18→v19 rollback | In `testFailedVersionNineteenMigrationRetainsVersionEighteenPostingChecksAndSnapshot`, use `.eighteen`, seed parent `legacy-opportunity` first, then `legacy-closed`; injected failure retains marker 18 and exact posting ID/status/evidence, leaves `reconciliation_results` absent, and keeps the verified snapshot. |
| v19 existing reconciliation success | Use `.nineteen`, seed parent `legacy-opportunity` first, then exact `result-v19`; v20 adds all fifteen public-evidence columns as NULL; the row's pre-v20 values remain byte-for-value; `reconciliation_check_operations` is empty; reaches `currentVersion`; snapshot removed. |
| retained v19→v20 rollback | In `testFailedVersionTwentyMigrationKeepsVersionNineteenRowsAndVerifiedSnapshot`, use `.nineteen`, seed parent `legacy-opportunity` first, then exact `result-v19`; injected failure retains marker 19 and result ID/evidence, leaves `reconciliation_check_operations` absent and `check_operation_id` absent, and keeps the verified snapshot. |
| v20 compensation/action | seed `legacy-opportunity` with `compensation = "150k base"` and `next_action = "  Ask Morgan for a referral  "`; migration leaves compensation text, nil structured compensation, exact whitespace action, `.other` and exact custom text; `PRAGMA foreign_key_check` empty; existing contact-link assertion remains. |
| v22 document reference | seed `legacy-opportunity` and a v22-shaped `document_references` row directly, with no bookmark bytes because the columns do not exist; v23+ result has `bookmarkData == nil`, `.relinkRequired`, and `currentVersion`. |

Replace the v22 current-store/reverse-column setup entirely. Remove all three obsolete rewind helper definitions and require `rg -n "makeVersion(Eighteen|Nineteen|Twenty)Database" RekonPursuitCoreTests/WorkspaceStoreTests.swift` to return no matches.

Replace these four stale terminal assertions, and only their expected version value, with the authoritative current version:

```swift
XCTAssertEqual(
    try database.rows("SELECT version FROM schema_migrations"),
    [[.integer(Int64(WorkspaceMigrations.currentVersion))]]
)
```

Apply that exact replacement in:

- `testVersionSixteenToSeventeenMigrationAndFailureKeepSnapshot` (current line 326);
- `testVersionEighteenPostingChecksMigrateLosslesslyToReadOnlyReconciliationHistory` (current line 346);
- `testVersionNineteenMigratesToTwentyWithoutChangingExistingReconciliationRows` (current line 367); and
- `testVersionTwentyMigrationRetainsLegacyCompensationAndActionText` (current line 391).

Preserve every neighboring hand-derived row/value, foreign-key, snapshot, and empty-operation assertion.

### Slice B failure and retained-regression mapping

| Evidence record/test | Repair and required retained proof |
| --- | --- |
| Failure records 1-2: `testStageMoveCommitsStageAuditHistoryAndProjectionTogether` | Slice A moved-ID and unrelated-ID assertions in projection and reopen. |
| Failure record 3: `testUpdateOpportunityReplacesItsNextActionAndWritesOneActivityEvent` | Slice A retains `stageChangedAt: now` and adds only `.other` / `"Prepare recruiter call"` to the expected structured-action fields; legacy `nextAction`, missing-date rejection, deterministic-tie behavior, and both compatibility selectors remain. |
| Failure record 4: `testVersionEighteenPostingChecksMigrateLosslesslyToReadOnlyReconciliationHistory` | Exact v18 fixture, parent opportunity before four postings, four literal mappings, one review, current version, snapshot removal. |
| Failure record 5: `testVersionElevenInteractionRowsAreRetainedAsLegacyRowsDuringContactInteractionMigration` | Exact v11 fixture/metadata; retained interaction mapping; current version; snapshot removal. |
| Failure record 6: `testVersionNineteenMigratesToTwentyWithoutChangingExistingReconciliationRows` | Exact v19-from-v18 fixture, parent opportunity before `result-v19`, byte-for-value row/NULL additions, empty operation table, current version, snapshot removal. |
| Failure record 7: `testVersionSixteenToSeventeenMigrationAndFailureKeepSnapshot` | Exact v16 fixture/metadata; retained v17 failure marker/row/snapshot; ordinary apply reaches current version with literal defaults. |
| Failure record 8: `testVersionTwentyMigrationRetainsLegacyCompensationAndActionText` | Exact v20-from-v19 fixture/metadata; retained compensation/action/foreign-key/contact-link assertions; current version. |
| Failure record 9: `testVersionTwentyTwoDocumentReferenceMigrationRequiresRelinkWithoutRetainingBookmarkData` | Exact v22 fixture/metadata; direct no-bookmark seed; exact no-bookmark/no-availability precondition; nil bookmark/relink-required/current-version result. |
| Passing retained rollback: `testFailedVersionNineteenMigrationRetainsVersionEighteenPostingChecksAndSnapshot` | Exact v18 fixture; parent before child; retain marker 18, posting row, absent reconciliation table, verified snapshot. |
| Passing retained rollback: `testFailedVersionTwentyMigrationKeepsVersionNineteenRowsAndVerifiedSnapshot` | Exact v19 fixture; parent before child; retain marker 19, result row, absent v20 table/column, verified snapshot. |

- [ ] **Step 4: Run six concrete signed mutation validations**

For every mutation below: make only the named temporary edit in the test-only installer declaration; run its one selector; require the named integrity assertion failure (not a compile, SQLite setup, cache, or signing error); inspect both the finalized result summary and detailed test record; verify the produced Debug app/test-host bundle, test-host executable, and test bundle with strict codesign and identity display; then revert that exact temporary mutation before starting the next mutation.

**Mutation 1 — omit v11 `task_reminders`.** Expected failure message: `v11 table set mismatch: task_reminders is required`.

```bash
xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:RekonPursuitTests/WorkspaceStoreTests/testVersionElevenFixtureHasOnlyVersionElevenFacts \
  -derivedDataPath /tmp/rekon-vd205-core-suite-mutation-v11-task-reminders-dd \
  -resultBundlePath /tmp/rekon-vd205-core-suite-mutation-v11-task-reminders.xcresult
xcrun xcresulttool get test-results summary --path /tmp/rekon-vd205-core-suite-mutation-v11-task-reminders.xcresult
xcrun xcresulttool get test-results tests --path /tmp/rekon-vd205-core-suite-mutation-v11-task-reminders.xcresult
for artifact in \
  /tmp/rekon-vd205-core-suite-mutation-v11-task-reminders-dd/Build/Products/Debug/RekonPursuit.app \
  /tmp/rekon-vd205-core-suite-mutation-v11-task-reminders-dd/Build/Products/Debug/RekonPursuit.app/Contents/MacOS/RekonPursuit \
  /tmp/rekon-vd205-core-suite-mutation-v11-task-reminders-dd/Build/Products/Debug/RekonPursuitTests.xctest
do
  codesign --verify --deep --strict --verbose=2 "$artifact"
  codesign -dvv "$artifact"
done
```

**Mutation 2 — omit v16 `posting_checks`.** Expected failure message: `v16 table set mismatch: posting_checks is required`.

```bash
xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:RekonPursuitTests/WorkspaceStoreTests/testVersionSixteenFixtureHasOnlyVersionSixteenFacts \
  -derivedDataPath /tmp/rekon-vd205-core-suite-mutation-v16-posting-checks-dd \
  -resultBundlePath /tmp/rekon-vd205-core-suite-mutation-v16-posting-checks.xcresult
xcrun xcresulttool get test-results summary --path /tmp/rekon-vd205-core-suite-mutation-v16-posting-checks.xcresult
xcrun xcresulttool get test-results tests --path /tmp/rekon-vd205-core-suite-mutation-v16-posting-checks.xcresult
for artifact in \
  /tmp/rekon-vd205-core-suite-mutation-v16-posting-checks-dd/Build/Products/Debug/RekonPursuit.app \
  /tmp/rekon-vd205-core-suite-mutation-v16-posting-checks-dd/Build/Products/Debug/RekonPursuit.app/Contents/MacOS/RekonPursuit \
  /tmp/rekon-vd205-core-suite-mutation-v16-posting-checks-dd/Build/Products/Debug/RekonPursuitTests.xctest
do
  codesign --verify --deep --strict --verbose=2 "$artifact"
  codesign -dvv "$artifact"
done
```

**Mutation 3 — add v19 `reconciliation_results` to v18.** Expected failure message: `v18 table set mismatch: reconciliation_results must be absent`.

```bash
xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:RekonPursuitTests/WorkspaceStoreTests/testVersionEighteenFixtureHasOnlyVersionEighteenFacts \
  -derivedDataPath /tmp/rekon-vd205-core-suite-mutation-v18-reconciliation-results-dd \
  -resultBundlePath /tmp/rekon-vd205-core-suite-mutation-v18-reconciliation-results.xcresult
xcrun xcresulttool get test-results summary --path /tmp/rekon-vd205-core-suite-mutation-v18-reconciliation-results.xcresult
xcrun xcresulttool get test-results tests --path /tmp/rekon-vd205-core-suite-mutation-v18-reconciliation-results.xcresult
for artifact in \
  /tmp/rekon-vd205-core-suite-mutation-v18-reconciliation-results-dd/Build/Products/Debug/RekonPursuit.app \
  /tmp/rekon-vd205-core-suite-mutation-v18-reconciliation-results-dd/Build/Products/Debug/RekonPursuit.app/Contents/MacOS/RekonPursuit \
  /tmp/rekon-vd205-core-suite-mutation-v18-reconciliation-results-dd/Build/Products/Debug/RekonPursuitTests.xctest
do
  codesign --verify --deep --strict --verbose=2 "$artifact"
  codesign -dvv "$artifact"
done
```

**Mutation 4 — add v20 `reconciliation_check_operations` to v19.** Expected failure message: `v19 table set mismatch: reconciliation_check_operations must be absent`.

```bash
xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:RekonPursuitTests/WorkspaceStoreTests/testVersionNineteenFixtureComposesExactVersionEighteenPlusNineteen \
  -derivedDataPath /tmp/rekon-vd205-core-suite-mutation-v19-check-operations-dd \
  -resultBundlePath /tmp/rekon-vd205-core-suite-mutation-v19-check-operations.xcresult
xcrun xcresulttool get test-results summary --path /tmp/rekon-vd205-core-suite-mutation-v19-check-operations.xcresult
xcrun xcresulttool get test-results tests --path /tmp/rekon-vd205-core-suite-mutation-v19-check-operations.xcresult
for artifact in \
  /tmp/rekon-vd205-core-suite-mutation-v19-check-operations-dd/Build/Products/Debug/RekonPursuit.app \
  /tmp/rekon-vd205-core-suite-mutation-v19-check-operations-dd/Build/Products/Debug/RekonPursuit.app/Contents/MacOS/RekonPursuit \
  /tmp/rekon-vd205-core-suite-mutation-v19-check-operations-dd/Build/Products/Debug/RekonPursuitTests.xctest
do
  codesign --verify --deep --strict --verbose=2 "$artifact"
  codesign -dvv "$artifact"
done
```

**Mutation 5 — add v21 `opportunities.compensation_minimum` to v20.** Expected failure message: `v20 opportunities column-name set mismatch: compensation_minimum must be absent`.

```bash
xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:RekonPursuitTests/WorkspaceStoreTests/testVersionTwentyFixtureHasOnlyVersionTwentyFacts \
  -derivedDataPath /tmp/rekon-vd205-core-suite-mutation-v20-compensation-minimum-dd \
  -resultBundlePath /tmp/rekon-vd205-core-suite-mutation-v20-compensation-minimum.xcresult
xcrun xcresulttool get test-results summary --path /tmp/rekon-vd205-core-suite-mutation-v20-compensation-minimum.xcresult
xcrun xcresulttool get test-results tests --path /tmp/rekon-vd205-core-suite-mutation-v20-compensation-minimum.xcresult
for artifact in \
  /tmp/rekon-vd205-core-suite-mutation-v20-compensation-minimum-dd/Build/Products/Debug/RekonPursuit.app \
  /tmp/rekon-vd205-core-suite-mutation-v20-compensation-minimum-dd/Build/Products/Debug/RekonPursuit.app/Contents/MacOS/RekonPursuit \
  /tmp/rekon-vd205-core-suite-mutation-v20-compensation-minimum-dd/Build/Products/Debug/RekonPursuitTests.xctest
do
  codesign --verify --deep --strict --verbose=2 "$artifact"
  codesign -dvv "$artifact"
done
```

**Mutation 6 — add v23 `document_references.bookmark_data` to v22.** Expected failure message: `v22 document_references column-name set mismatch: bookmark_data and availability must be absent`.

```bash
xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:RekonPursuitTests/WorkspaceStoreTests/testVersionTwentyTwoFixtureHasOnlyVersionTwentyTwoFacts \
  -derivedDataPath /tmp/rekon-vd205-core-suite-mutation-v22-bookmark-data-dd \
  -resultBundlePath /tmp/rekon-vd205-core-suite-mutation-v22-bookmark-data.xcresult
xcrun xcresulttool get test-results summary --path /tmp/rekon-vd205-core-suite-mutation-v22-bookmark-data.xcresult
xcrun xcresulttool get test-results tests --path /tmp/rekon-vd205-core-suite-mutation-v22-bookmark-data.xcresult
for artifact in \
  /tmp/rekon-vd205-core-suite-mutation-v22-bookmark-data-dd/Build/Products/Debug/RekonPursuit.app \
  /tmp/rekon-vd205-core-suite-mutation-v22-bookmark-data-dd/Build/Products/Debug/RekonPursuit.app/Contents/MacOS/RekonPursuit \
  /tmp/rekon-vd205-core-suite-mutation-v22-bookmark-data-dd/Build/Products/Debug/RekonPursuitTests.xctest
do
  codesign --verify --deep --strict --verbose=2 "$artifact"
  codesign -dvv "$artifact"
done
```

After reverting Mutation 6, inspect the test-file diff to prove all six temporary mutations are gone, require the three obsolete helper names to be absent, compare the changed implementation-source paths with the implementer's recorded pre-task dirty-worktree baseline, and run:

```bash
rg -n "makeVersion(Eighteen|Nineteen|Twenty)Database" RekonPursuitCoreTests/WorkspaceStoreTests.swift
git diff -- RekonPursuitCoreTests/WorkspaceStoreTests.swift
git diff --check
```

Expected: `rg` has no matches; the test-file diff contains only the authorized permanent Slice A/B repair; no new implementation-source path outside `RekonPursuitCoreTests/WorkspaceStoreTests.swift` appears relative to the recorded baseline; `git diff --check` exits zero.

- [ ] **Step 5: Run the Slice B signed GREEN matrix**

Run all six integrity tests, all six repaired failures, and both retained rollback tests together:

```bash
xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:RekonPursuitTests/WorkspaceStoreTests/testVersionElevenFixtureHasOnlyVersionElevenFacts \
  -only-testing:RekonPursuitTests/WorkspaceStoreTests/testVersionSixteenFixtureHasOnlyVersionSixteenFacts \
  -only-testing:RekonPursuitTests/WorkspaceStoreTests/testVersionEighteenFixtureHasOnlyVersionEighteenFacts \
  -only-testing:RekonPursuitTests/WorkspaceStoreTests/testVersionNineteenFixtureComposesExactVersionEighteenPlusNineteen \
  -only-testing:RekonPursuitTests/WorkspaceStoreTests/testVersionTwentyFixtureHasOnlyVersionTwentyFacts \
  -only-testing:RekonPursuitTests/WorkspaceStoreTests/testVersionTwentyTwoFixtureHasOnlyVersionTwentyTwoFacts \
  -only-testing:RekonPursuitTests/WorkspaceStoreTests/testVersionElevenInteractionRowsAreRetainedAsLegacyRowsDuringContactInteractionMigration \
  -only-testing:RekonPursuitTests/WorkspaceStoreTests/testVersionSixteenToSeventeenMigrationAndFailureKeepSnapshot \
  -only-testing:RekonPursuitTests/WorkspaceStoreTests/testVersionEighteenPostingChecksMigrateLosslesslyToReadOnlyReconciliationHistory \
  -only-testing:RekonPursuitTests/WorkspaceStoreTests/testFailedVersionNineteenMigrationRetainsVersionEighteenPostingChecksAndSnapshot \
  -only-testing:RekonPursuitTests/WorkspaceStoreTests/testVersionNineteenMigratesToTwentyWithoutChangingExistingReconciliationRows \
  -only-testing:RekonPursuitTests/WorkspaceStoreTests/testVersionTwentyMigrationRetainsLegacyCompensationAndActionText \
  -only-testing:RekonPursuitTests/WorkspaceStoreTests/testFailedVersionTwentyMigrationKeepsVersionNineteenRowsAndVerifiedSnapshot \
  -only-testing:RekonPursuitTests/WorkspaceStoreTests/testVersionTwentyTwoDocumentReferenceMigrationRequiresRelinkWithoutRetainingBookmarkData \
  -derivedDataPath /tmp/rekon-vd205-core-suite-slice-b-green-dd \
  -resultBundlePath /tmp/rekon-vd205-core-suite-slice-b-green.xcresult
```

Expected: 14 selected tests pass. The six successful migration tests reach `WorkspaceMigrations.currentVersion`; both rollback tests remain at their injected versions with exact retained-row/absent-fact/snapshot evidence. Inspect the finalized summary and detailed results, then run strict deep codesign verification and identity display against the app/test-host bundle, host executable, and test bundle under `/tmp/rekon-vd205-core-suite-slice-b-green-dd/Build/Products/Debug`.

## Task 3: Whole-suite proof and release hold

**Files:** no implementation files beyond the single permitted test source. Delivery evidence records may be created later only by authorized governance roles.

**Consumes:** Slice A and Slice B signed GREEN result bundles.
**Produces:** Review-ready evidence only; no Task 2 acceptance or Board release.

- [ ] **Step 1: Run the complete signed Core and ViewModel regressions**

```bash
xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:RekonPursuitTests/WorkspaceStoreTests \
  -derivedDataPath /tmp/rekon-vd205-core-suite-full-core-dd \
  -resultBundlePath /tmp/rekon-vd205-core-suite-full-core.xcresult

xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:RekonPursuitTests/WorkspaceViewModelTests \
  -derivedDataPath /tmp/rekon-vd205-core-suite-full-vm-dd \
  -resultBundlePath /tmp/rekon-vd205-core-suite-full-vm.xcresult
```

Expected: both selectors pass in isolated signed Debug bundles. Run `codesign --verify --deep --strict --verbose=2` and `codesign -dvv` against every generated app, test host, and XCTest bundle used by these runs; record only identity/bundle verification output, never credentials.

- [ ] **Step 2: Perform implementation-boundary and plan self-review**

Run `git diff --check`; inspect the diff to ensure only `RekonPursuitCoreTests/WorkspaceStoreTests.swift` implementation source changed and no migration, schema, Board, project, signing, UI, dashboard, roadmap, or ledger file changed. Confirm each helper is test-private; the expected outcomes are literal; and the following mutations would fail at least one test: target-ID mismatch, unrelated-row mutation, nil effective date accepted, missing v11 protected table, missing v16 posting checks, v21 column preexisting in v18/v19, v22 columns preexisting in v20, or v24 table preexisting in v22.

- [ ] **Step 3: Keep the Board release hold**

Submit the results to fresh independent code review and QA verification, then Architecture, TPM, Security/privacy, and Delivery review. The pre-implementation Security/privacy release and this post-implementation Security/privacy verification are both mandatory because the fixtures exercise encrypted migration snapshots and document-reference recovery semantics. Delivery alone may create evidence/ledger/dashboard records and decides whether Task 2 is accepted. Until every listed gate passes, Board Task 3, owner handoff, and VD2-06–VD2-08 remain withheld.

## Plan Self-Review

- **Spec coverage:** Slice A addresses failure records 1-3, preserves the accepted four-selector follow-up RED, authorizes only the two expected structured-action fields, and requires the exact six-selector 6/6 signed GREEN with identities, regular-file hashes, and diff hygiene before every post-Slice-A gate. Slice B maps failure records 4-9 plus both passing rollback regressions, inserts/asserts the required workspace identity, uses exact per-table column-set equality and independent literal checksum/schema oracles, replaces four terminal `22` assertions, removes every rewind helper, and supplies six executable signed mutation checks. Task 3 requires both full selectors, signatures, diff hygiene, pre- and post-implementation Security/privacy review, independent review, and release hold.
- **Placeholder scan:** No prohibited placeholder phrasing is used; each change has a path, helper contract, historical schema boundary, concrete seed, and command.
- **Type consistency:** The Slice A expectation uses existing `Opportunity.ActionType.other` inference and a non-optional string literal for `actionCustomText`, with legacy `nextAction` retained. All six integrity tests and eight migration behavior tests use `HistoricalWorkspaceSchemaVersion`; all builder APIs return `EncryptedDatabase`; expected history rows use the existing `DatabaseValue`; v19 composes v18, v20 composes v19, and v22 composes v20. Production migration APIs are not part of the fixture construction interface.
- **Constraint consistency:** The only implementation file remains `RekonPursuitCoreTests/WorkspaceStoreTests.swift`; the expectation follow-up adds exactly two lines and preserves every other field/assertion. Production, schema, migration, UI, Board, project, signing, dashboard, roadmap, ledger, delivery evidence, and commits remain unauthorized. Slice B cannot start until the fresh six-selector run is 6/6 GREEN and Code Review, QA, Architecture, TPM, Security/privacy, and Delivery all accept it.
