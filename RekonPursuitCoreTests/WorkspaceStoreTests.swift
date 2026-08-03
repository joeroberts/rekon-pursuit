import Foundation
import XCTest
@testable import RekonPursuit

@MainActor
final class WorkspaceStoreTests: XCTestCase {
    private enum HistoricalWorkspaceSchemaVersion: Int, CaseIterable {
        case eleven = 11
        case sixteen = 16
        case eighteen = 18
        case nineteen = 19
        case twenty = 20
        case twentyTwo = 22
    }

    private struct HistoricalWorkspaceExpectation {
        let schemaVersion: Int
        let tables: Set<String>
        let namedIndexes: Set<String>
        let columnNamesByTable: [String: Set<String>]
        let migrationHistoryRows: [[DatabaseValue]]
    }

    private let versionElevenDDL = [
        "CREATE TABLE opportunities (id TEXT PRIMARY KEY NOT NULL, title TEXT NOT NULL, company TEXT NOT NULL, created_at REAL NOT NULL, stage TEXT NOT NULL DEFAULT 'Saved', next_action TEXT NOT NULL DEFAULT '', due_at REAL, deleted_at REAL)",
        "CREATE TABLE task_reminders (id TEXT PRIMARY KEY NOT NULL, opportunity_id TEXT NOT NULL REFERENCES opportunities(id), title TEXT NOT NULL, due_at REAL, is_complete INTEGER NOT NULL DEFAULT 0)",
        "CREATE TABLE activity_events (id TEXT PRIMARY KEY NOT NULL, kind TEXT NOT NULL, opportunity_id TEXT REFERENCES opportunities(id), contact_id TEXT, actor_id TEXT NOT NULL, correlation_id TEXT NOT NULL, occurred_at REAL NOT NULL)",
        "CREATE TABLE contacts (id TEXT PRIMARY KEY NOT NULL, name TEXT NOT NULL, employer TEXT NOT NULL, title TEXT NOT NULL DEFAULT '', email TEXT NOT NULL DEFAULT '', profile_url TEXT NOT NULL DEFAULT '', relationship_context TEXT NOT NULL DEFAULT '', notes TEXT NOT NULL DEFAULT '', deleted_at REAL)",
        "CREATE TABLE contact_opportunities (contact_id TEXT NOT NULL REFERENCES contacts(id), opportunity_id TEXT NOT NULL REFERENCES opportunities(id), PRIMARY KEY(contact_id, opportunity_id))",
        "CREATE TABLE interactions (id TEXT PRIMARY KEY NOT NULL, opportunity_id TEXT NOT NULL REFERENCES opportunities(id), summary TEXT NOT NULL, occurred_at REAL NOT NULL)",
        "CREATE TABLE workspace_metadata (key TEXT PRIMARY KEY NOT NULL, value TEXT NOT NULL)",
        "CREATE TABLE deletion_tombstones (subject_id TEXT PRIMARY KEY NOT NULL, subject_type TEXT NOT NULL, deleted_at REAL NOT NULL, display_value TEXT NOT NULL)",
        "CREATE TABLE import_reports (id TEXT PRIMARY KEY NOT NULL, imported_count INTEGER NOT NULL, skipped_count INTEGER NOT NULL, duplicate_kept_count INTEGER NOT NULL, invalid_count INTEGER NOT NULL, created_at REAL NOT NULL)",
        "CREATE TABLE opportunity_stage_history (id TEXT PRIMARY KEY NOT NULL, opportunity_id TEXT NOT NULL REFERENCES opportunities(id), from_stage TEXT, to_stage TEXT NOT NULL, occurred_at REAL NOT NULL)"
    ]

    private let versionTwelveThroughSixteenDDL = [
        "DROP TABLE interactions",
        "CREATE TABLE interactions (id TEXT PRIMARY KEY NOT NULL, contact_id TEXT REFERENCES contacts(id), opportunity_id TEXT REFERENCES opportunities(id), kind TEXT NOT NULL, summary TEXT NOT NULL, occurred_at REAL NOT NULL, next_touch_at REAL)",
        "CREATE INDEX interactions_contact_occurred_at ON interactions(contact_id, occurred_at, id)",
        "ALTER TABLE opportunities ADD COLUMN job_url TEXT NOT NULL DEFAULT ''",
        "CREATE TABLE posting_checks (id TEXT PRIMARY KEY NOT NULL, opportunity_id TEXT NOT NULL REFERENCES opportunities(id), url TEXT NOT NULL, status TEXT NOT NULL, evidence TEXT NOT NULL, checked_at REAL NOT NULL)",
        "CREATE INDEX posting_checks_opportunity_checked_at ON posting_checks(opportunity_id, checked_at, id)",
        "CREATE TABLE document_references (id TEXT PRIMARY KEY NOT NULL, opportunity_id TEXT NOT NULL REFERENCES opportunities(id), kind TEXT NOT NULL, filename TEXT NOT NULL, content_type TEXT NOT NULL, source_hash TEXT NOT NULL, byte_count INTEGER NOT NULL, attached_at REAL NOT NULL, final_sent_at REAL)",
        "CREATE INDEX document_references_opportunity_attached_at ON document_references(opportunity_id, attached_at, id)",
        "ALTER TABLE opportunities ADD COLUMN job_description TEXT NOT NULL DEFAULT ''",
        "ALTER TABLE opportunities ADD COLUMN notes TEXT NOT NULL DEFAULT ''",
        "ALTER TABLE opportunities ADD COLUMN compensation TEXT",
        "ALTER TABLE opportunities ADD COLUMN location TEXT",
        "ALTER TABLE opportunities ADD COLUMN work_arrangement TEXT NOT NULL DEFAULT 'Not specified'",
        "ALTER TABLE opportunities ADD COLUMN application_date REAL",
        "ALTER TABLE opportunities ADD COLUMN response_state TEXT NOT NULL DEFAULT 'No response recorded'",
        "ALTER TABLE opportunities ADD COLUMN stage_changed_at REAL",
        "CREATE TABLE opportunity_response_history (id TEXT PRIMARY KEY NOT NULL, opportunity_id TEXT NOT NULL REFERENCES opportunities(id), from_state TEXT NOT NULL, to_state TEXT NOT NULL, occurred_at REAL NOT NULL)",
        "CREATE INDEX opportunity_response_history_opportunity_occurred_at ON opportunity_response_history(opportunity_id, occurred_at DESC, id DESC)"
    ]

    private let versionSeventeenThroughEighteenDDL = [
        "ALTER TABLE import_reports ADD COLUMN updated_count INTEGER NOT NULL DEFAULT 0",
        "ALTER TABLE import_reports ADD COLUMN source_basename TEXT NOT NULL DEFAULT ''",
        "ALTER TABLE import_reports ADD COLUMN mapping_summary TEXT NOT NULL DEFAULT ''",
        "CREATE TABLE import_report_rows (id TEXT PRIMARY KEY NOT NULL, report_id TEXT NOT NULL REFERENCES import_reports(id), source_row INTEGER NOT NULL, outcome TEXT NOT NULL, reason TEXT NOT NULL, duplicate_rationale TEXT NOT NULL, opportunity_id TEXT)",
        "CREATE INDEX import_report_rows_report_row ON import_report_rows(report_id, source_row)",
        "ALTER TABLE import_reports ADD COLUMN failed_count INTEGER NOT NULL DEFAULT 0"
    ]

    private let versionNineteenDDL = [
        "CREATE TABLE reconciliation_reviews (opportunity_id TEXT PRIMARY KEY NOT NULL REFERENCES opportunities(id), task_reminder_id TEXT NOT NULL UNIQUE REFERENCES task_reminders(id), created_at REAL NOT NULL, closure_confirmed_at REAL)",
        "CREATE INDEX reconciliation_reviews_task_reminder_id ON reconciliation_reviews(task_reminder_id)",
        "CREATE TABLE reconciliation_results (id TEXT PRIMARY KEY NOT NULL, opportunity_id TEXT NOT NULL REFERENCES opportunities(id), url TEXT NOT NULL, recorded_at REAL NOT NULL, outcome TEXT NOT NULL, classification TEXT NOT NULL, reason TEXT NOT NULL, confidence TEXT, evidence TEXT NOT NULL, error TEXT NOT NULL, review_task_reminder_id TEXT REFERENCES task_reminders(id), closure_confirmed_at REAL, legacy_posting_check_id TEXT UNIQUE, legacy_status TEXT)",
        "CREATE INDEX reconciliation_results_opportunity_recorded_at ON reconciliation_results(opportunity_id, recorded_at DESC, id DESC)"
    ]

    private let versionTwentyDDL = [
        "CREATE TABLE reconciliation_check_operations (id TEXT PRIMARY KEY NOT NULL, opportunity_id TEXT NOT NULL REFERENCES opportunities(id), correlation_id TEXT NOT NULL UNIQUE, url_snapshot TEXT NOT NULL, state TEXT NOT NULL, started_at REAL NOT NULL, terminal_at REAL)",
        "CREATE INDEX reconciliation_check_operations_opportunity_state ON reconciliation_check_operations(opportunity_id, state)",
        "ALTER TABLE reconciliation_results ADD COLUMN check_operation_id TEXT REFERENCES reconciliation_check_operations(id)",
        "ALTER TABLE reconciliation_results ADD COLUMN method TEXT",
        "ALTER TABLE reconciliation_results ADD COLUMN checker_version TEXT",
        "ALTER TABLE reconciliation_results ADD COLUMN http_status INTEGER",
        "ALTER TABLE reconciliation_results ADD COLUMN mime_type TEXT",
        "ALTER TABLE reconciliation_results ADD COLUMN declared_bytes INTEGER",
        "ALTER TABLE reconciliation_results ADD COLUMN received_bytes INTEGER",
        "ALTER TABLE reconciliation_results ADD COLUMN content_sha256 TEXT",
        "ALTER TABLE reconciliation_results ADD COLUMN response_date TEXT",
        "ALTER TABLE reconciliation_results ADD COLUMN last_modified TEXT",
        "ALTER TABLE reconciliation_results ADD COLUMN etag TEXT",
        "ALTER TABLE reconciliation_results ADD COLUMN retry_after TEXT",
        "ALTER TABLE reconciliation_results ADD COLUMN redirect_target_redacted TEXT",
        "ALTER TABLE reconciliation_results ADD COLUMN evidence_excerpt TEXT",
        "ALTER TABLE reconciliation_results ADD COLUMN redacted_error_code TEXT"
    ]

    private let versionTwentyOneThroughTwentyTwoDDL = [
        "ALTER TABLE opportunities ADD COLUMN compensation_minimum REAL",
        "ALTER TABLE opportunities ADD COLUMN compensation_maximum REAL",
        "ALTER TABLE opportunities ADD COLUMN compensation_pay_period TEXT",
        "ALTER TABLE opportunities ADD COLUMN action_type TEXT NOT NULL DEFAULT 'No action'",
        "ALTER TABLE opportunities ADD COLUMN action_custom_text TEXT",
        "ALTER TABLE import_report_rows ADD COLUMN display_title TEXT NOT NULL DEFAULT ''",
        "ALTER TABLE import_report_rows ADD COLUMN display_company TEXT NOT NULL DEFAULT ''"
    ]

    private let key = Data(repeating: 7, count: 32)
    private let now = Date(timeIntervalSince1970: 1_704_067_200)
    private var databaseURL: URL!

    func testRecoveryEnrollmentRequiresACompleteChecksummedReentryAndPersistsOnlyAFingerprint() throws {
        let generated = try RecoveryKey.generate()
        XCTAssertEqual(RecoveryKey.parse(generated.displayValue), generated)
        XCTAssertNil(RecoveryKey.parse(String(generated.displayValue.dropLast())))
        let wrongChecksum = String(generated.displayValue.dropLast()) + (generated.displayValue.last == "A" ? "B" : "A")
        XCTAssertNil(RecoveryKey.parse(wrongChecksum))

        let store = try makeStore()
        try store.enroll(recoveryKey: generated)

        XCTAssertTrue(try store.recoveryEnrollmentState().isEnabled)
        let record = try XCTUnwrap(try store.recoveryEnrollmentRecordForTesting())
        XCTAssertTrue(record.fingerprint.hasPrefix("v1:"))
        XCTAssertFalse(record.fingerprint.contains(generated.displayValue))
        XCTAssertEqual(try store.activityEvents().last?.kind, "recovery_enrollment_enabled")
        try store.close()
        let reopenedDatabase = try EncryptedDatabase.open(url: databaseURL, key: key, createIfMissing: false)
        let reopened = try WorkspaceStore(database: reopenedDatabase, actorID: "test", correlationID: "test")
        XCTAssertTrue(try reopened.recoveryEnrollmentState().isEnabled)
    }

    func testRecoveryEnrollmentPersistenceFailureDoesNotReplaceExistingEnrollment() throws {
        let store = try makeStore()
        try store.enroll(recoveryKey: try RecoveryKey.generate())
        let original = try XCTUnwrap(try store.recoveryEnrollmentRecordForTesting())
        let database = try EncryptedDatabase.open(url: databaseURL, key: key, createIfMissing: false)
        let failing = try WorkspaceStore(database: database, actorID: "test", correlationID: "test", failBeforeActivityInsert: true)

        XCTAssertThrowsError(try failing.enroll(recoveryKey: try RecoveryKey.generate()))
        XCTAssertEqual(try failing.recoveryEnrollmentRecordForTesting(), original)
    }

    func testInitialRecoveryEnrollmentPersistenceFailureLeavesWorkspaceDisabled() throws {
        let database = try EncryptedDatabase.open(url: databaseURL, key: key)
        let failing = try WorkspaceStore(database: database, actorID: "test", correlationID: "test", failBeforeActivityInsert: true)

        XCTAssertThrowsError(try failing.enroll(recoveryKey: try RecoveryKey.generate()))

        XCTAssertFalse(try failing.recoveryEnrollmentState().isEnabled)
        XCTAssertNil(try failing.recoveryEnrollmentRecordForTesting())
    }

    func testSecondSuccessfulEnrollmentAttemptCannotReplaceExistingEnrollment() throws {
        let store = try makeStore()
        try store.enroll(recoveryKey: try RecoveryKey.generate())
        let original = try XCTUnwrap(try store.recoveryEnrollmentRecordForTesting())

        XCTAssertThrowsError(try store.enroll(recoveryKey: try RecoveryKey.generate()))

        XCTAssertEqual(try store.recoveryEnrollmentRecordForTesting(), original)
    }

    func testPortableArchiveCreatesOneVerifiedCatalogueRowWithFixedThirtyDayExpiry() async throws {
        let database = try EncryptedDatabase.open(url: databaseURL, key: key)
        let store = try WorkspaceStore(database: database, now: now, actorID: "test", correlationID: "test", archiveSigningKeyStore: InMemoryArchiveSigningKeyStore())
        let recoveryKey = try RecoveryKey.generate()
        try store.enroll(recoveryKey: recoveryKey)
        _ = try store.create(CreateOpportunity(title: "Archive fixture", company: "Rekon Labs"))
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent("archive-\(UUID().uuidString).rekonarchive")
        defer { try? FileManager.default.removeItem(at: destination) }

        let archive = try await store.createPortableArchive(recoveryKey: recoveryKey, at: destination)

        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path))
        XCTAssertEqual(archive.verificationState, "Verified")
        XCTAssertEqual(archive.expiresAt, now.addingTimeInterval(30 * 24 * 60 * 60))
        XCTAssertEqual(try store.portableArchiveCatalogue(), [archive])
        XCTAssertEqual(try store.activityEvents().last?.kind, "portable_backup_created")
    }

    func testPortableArchiveWithoutEnrollmentOrWithWrongKeyLeavesNoFileOrCatalogueRow() async throws {
        let database = try EncryptedDatabase.open(url: databaseURL, key: key)
        let store = try WorkspaceStore(database: database, now: now, actorID: "test", correlationID: "test", archiveSigningKeyStore: InMemoryArchiveSigningKeyStore())
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent("archive-\(UUID().uuidString).rekonarchive")
        defer { try? FileManager.default.removeItem(at: destination) }

        await assertPortableArchiveThrows {
            try await store.createPortableArchive(recoveryKey: try RecoveryKey.generate(), at: destination)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
        XCTAssertEqual(try store.portableArchiveCatalogue(), [])

        let enrolled = try RecoveryKey.generate()
        try store.enroll(recoveryKey: enrolled)
        await assertPortableArchiveThrows {
            try await store.createPortableArchive(recoveryKey: try RecoveryKey.generate(), at: destination)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
        XCTAssertEqual(try store.portableArchiveCatalogue(), [])
    }

    func testPortableArchiveRejectsExistingDestinationWithoutChangingCatalogue() async throws {
        let store = try makeStore()
        let enrolled = try RecoveryKey.generate()
        try store.enroll(recoveryKey: enrolled)
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent("archive-\(UUID().uuidString).rekonarchive")
        try Data("existing".utf8).write(to: destination)
        defer { try? FileManager.default.removeItem(at: destination) }

        await assertPortableArchiveThrows {
            try await store.createPortableArchive(recoveryKey: enrolled, at: destination)
        }
        XCTAssertEqual(try Data(contentsOf: destination), Data("existing".utf8))
        XCTAssertEqual(try store.portableArchiveCatalogue(), [])
    }

    func testPortableArchiveRejectsTamperedCiphertextBeforeCataloguePromotion() async throws {
        let database = try EncryptedDatabase.open(url: databaseURL, key: key)
        let store = try WorkspaceStore(database: database, now: now, actorID: "test", correlationID: "test", archiveSigningKeyStore: InMemoryArchiveSigningKeyStore())
        let recoveryKey = try RecoveryKey.generate()
        try store.enroll(recoveryKey: recoveryKey)
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent("archive-\(UUID().uuidString).rekonarchive")
        defer { try? FileManager.default.removeItem(at: destination) }
        _ = try await store.createPortableArchive(recoveryKey: recoveryKey, at: destination)
        var tampered = try Data(contentsOf: destination)
        tampered[tampered.index(before: tampered.endIndex)] ^= 0x01

        XCTAssertThrowsError(try PortableArchiveService.verify(data: tampered, recoveryKey: recoveryKey))
    }

    func testPortableArchiveReadableMetadataDoesNotContainOpportunityContentOrRecoveryKey() async throws {
        let database = try EncryptedDatabase.open(url: databaseURL, key: key)
        let store = try WorkspaceStore(database: database, now: now, actorID: "test", correlationID: "test", archiveSigningKeyStore: InMemoryArchiveSigningKeyStore())
        let recoveryKey = try RecoveryKey.generate()
        let secretTitle = "PRIVATE-ARCHIVE-CONTENT"
        try store.enroll(recoveryKey: recoveryKey)
        _ = try store.create(CreateOpportunity(title: secretTitle, company: "Rekon Labs"))
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent("archive-\(UUID().uuidString).rekonarchive")
        defer { try? FileManager.default.removeItem(at: destination) }

        let archive = try await store.createPortableArchive(recoveryKey: recoveryKey, at: destination)

        XCTAssertNil(try Data(contentsOf: destination).range(of: Data(secretTitle.utf8)))
        XCTAssertNil(archive.displayFilename.range(of: secretTitle))
        XCTAssertFalse(try store.activityEvents().contains { $0.kind.contains(recoveryKey.displayValue) || $0.kind.contains(secretTitle) })
    }

    private func assertPortableArchiveThrows(
        _ operation: () async throws -> PortableArchiveCatalogueRow,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            _ = try await operation()
            XCTFail("Expected portable archive creation to fail.", file: file, line: line)
        } catch {
            // Expected.
        }
    }

    override func setUpWithError() throws {
        databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("rekon-workspace-\(UUID().uuidString)")
            .appendingPathExtension("sqlite")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: databaseURL)
        try? FileManager.default.removeItem(at: databaseURL.appendingPathExtension("sqlite-wal"))
        try? FileManager.default.removeItem(at: databaseURL.appendingPathExtension("sqlite-shm"))
    }

    func testNewWorkspaceRecordsSchemaVersion() throws {
        let store = try makeStore()

        XCTAssertEqual(try store.schemaVersion(), WorkspaceMigrations.currentVersion)
        XCTAssertEqual(try store.opportunities(), [])
        XCTAssertEqual(try store.activityEvents(), [])
    }

    func testVersionFourWorkspaceMigratesWithImmutableHistory() throws {
        let database = try EncryptedDatabase.open(url: databaseURL, key: key)
        try database.execute("CREATE TABLE schema_migrations (version INTEGER NOT NULL)")
        try database.execute("INSERT INTO schema_migrations (version) VALUES (4)")
        try database.execute("CREATE TABLE opportunities (id TEXT PRIMARY KEY NOT NULL, title TEXT NOT NULL, company TEXT NOT NULL, created_at REAL NOT NULL, stage TEXT NOT NULL DEFAULT 'Saved', next_action TEXT NOT NULL DEFAULT '', due_at REAL)")
        try database.execute("CREATE TABLE activity_events (id TEXT PRIMARY KEY NOT NULL, kind TEXT NOT NULL, opportunity_id TEXT NOT NULL, actor_id TEXT NOT NULL, correlation_id TEXT NOT NULL, occurred_at REAL NOT NULL)")
        try database.execute("CREATE TABLE task_reminders (id TEXT PRIMARY KEY NOT NULL, opportunity_id TEXT NOT NULL, title TEXT NOT NULL, due_at REAL NOT NULL, is_complete INTEGER NOT NULL DEFAULT 0)")
        try database.execute("INSERT INTO opportunities (id, title, company, created_at, stage, next_action) VALUES ('opportunity-1', 'Product Manager', 'Rekon Labs', 1704067200, 'Saved', '')")

        let store = try WorkspaceStore(database: database, actorID: "test", correlationID: "test")

        XCTAssertEqual(try store.schemaVersion(), WorkspaceMigrations.currentVersion)
        XCTAssertEqual(
            try database.rows("SELECT version, checksum FROM migration_history ORDER BY version"),
            [
                [.integer(4), .text(WorkspaceMigrations.baselineChecksum)],
                [.integer(5), .text(WorkspaceMigrations.versionFiveChecksum)],
                [.integer(6), .text(WorkspaceMigrations.versionSixChecksum)],
                [.integer(7), .text(WorkspaceMigrations.versionSevenChecksum)],
                [.integer(8), .text(WorkspaceMigrations.versionEightChecksum)],
                [.integer(9), .text(WorkspaceMigrations.versionNineChecksum)],
                [.integer(10), .text(WorkspaceMigrations.versionTenChecksum)],
                [.integer(11), .text(WorkspaceMigrations.versionElevenChecksum)],
                [.integer(12), .text(WorkspaceMigrations.versionTwelveChecksum)],
                [.integer(13), .text(WorkspaceMigrations.versionThirteenChecksum)],
                [.integer(14), .text(WorkspaceMigrations.versionFourteenChecksum)],
                [.integer(15), .text(WorkspaceMigrations.versionFifteenChecksum)]
                , [.integer(16), .text(WorkspaceMigrations.versionSixteenChecksum)]
                , [.integer(17), .text(WorkspaceMigrations.versionSeventeenChecksum)]
                , [.integer(18), .text(WorkspaceMigrations.versionEighteenChecksum)]
                , [.integer(19), .text(WorkspaceMigrations.versionNineteenChecksum)]
                , [.integer(20), .text(WorkspaceMigrations.versionTwentyChecksum)]
                , [.integer(21), .text(WorkspaceMigrations.versionTwentyOneChecksum)]
                , [.integer(22), .text(WorkspaceMigrations.versionTwentyTwoChecksum)]
                , [.integer(23), .text(WorkspaceMigrations.versionTwentyThreeChecksum)]
                , [.integer(24), .text(WorkspaceMigrations.versionTwentyFourChecksum)]
                , [.integer(25), .text(WorkspaceMigrations.versionTwentyFiveChecksum)]
                , [.integer(26), .text(WorkspaceMigrations.versionTwentySixChecksum)]
                , [.integer(27), .text(WorkspaceMigrations.versionTwentySevenChecksum)]
                , [.integer(28), .text(WorkspaceMigrations.versionTwentyEightChecksum)]
                , [.integer(29), .text(WorkspaceMigrations.versionTwentyNineChecksum)]
                , [.integer(30), .text(WorkspaceMigrations.versionThirtyChecksum)]
                , [.integer(31), .text(WorkspaceMigrations.versionThirtyOneChecksum)]
                , [.integer(32), .text(WorkspaceMigrations.versionThirtyTwoChecksum)]
                , [.integer(33), .text(WorkspaceMigrations.versionThirtyThreeChecksum)]
                , [.integer(34), .text(WorkspaceMigrations.versionThirtyFourChecksum)]
            ]
        )
        XCTAssertEqual(try database.rows("SELECT id, title, company FROM opportunities"), [[.text("opportunity-1"), .text("Product Manager"), .text("Rekon Labs")]])
        let migrated = try store.opportunities().first
        XCTAssertEqual(migrated?.compensation, nil)
        XCTAssertEqual(migrated?.location, nil)
        XCTAssertEqual(migrated?.workArrangement, .notSpecified)
        XCTAssertEqual(migrated?.responseState, .noResponseRecorded)
        XCTAssertEqual(migrated?.stageChangedAt, Date(timeIntervalSince1970: 1_704_067_200))
        XCTAssertEqual(try store.responseHistory(forOpportunityID: "opportunity-1"), [])
        XCTAssertFalse(FileManager.default.fileExists(atPath: database.migrationSnapshotURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: database.migrationSnapshotArtifactURLs[1].path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: database.migrationSnapshotArtifactURLs[2].path))
    }

    func testVersionThirtyThreeContactMigrationPreservesLegacyChannelsAndDefaultsNewChannels() throws {
        // This catches migration 34 losing legacy email/profile_url data or
        // failing to provide safe defaults for every newly added column.
        let seededStore = try makeStore()
        try seededStore.close()
        let database = try EncryptedDatabase.open(url: databaseURL, key: key, createIfMissing: false)
        try database.transaction {
            try database.execute("ALTER TABLE contacts RENAME TO contacts_v34")
            try database.execute("CREATE TABLE contacts (id TEXT PRIMARY KEY NOT NULL, name TEXT NOT NULL, employer TEXT NOT NULL, title TEXT NOT NULL DEFAULT '', email TEXT NOT NULL DEFAULT '', profile_url TEXT NOT NULL DEFAULT '', relationship_context TEXT NOT NULL DEFAULT '', notes TEXT NOT NULL DEFAULT '', deleted_at REAL)")
            try database.execute("INSERT INTO contacts (id, name, employer, title, email, profile_url, relationship_context, notes) VALUES ('legacy-contact', 'Legacy Alex', 'Rekon Labs', 'Recruiter', 'legacy.work@example.test', 'https://linkedin.example.test/in/legacy', 'Warm introduction', 'Legacy note')")
            try database.execute("DROP TABLE contacts_v34")
            try database.execute("DELETE FROM migration_history WHERE version = 34")
            try database.execute("UPDATE schema_migrations SET version = 33")
        }

        let migratedStore = try WorkspaceStore(database: database, now: now, actorID: "local-user", correlationID: "fixture-correlation")
        let contact = try XCTUnwrap(migratedStore.contacts().first)
        XCTAssertEqual(try migratedStore.schemaVersion(), WorkspaceMigrations.currentVersion)
        XCTAssertEqual(contact.workEmail, "legacy.work@example.test")
        XCTAssertEqual(contact.linkedInURL, "https://linkedin.example.test/in/legacy")
        XCTAssertEqual([contact.personalEmail, contact.mobilePhone, contact.officePhone, contact.instagramURL, contact.facebookURL], ["", "", "", "", ""])
    }

    func testVersionElevenFixtureHasOnlyVersionElevenFacts() throws {
        let database = try makeHistoricalWorkspaceDatabase(at: databaseURL, version: .eleven)

        try assertExactHistoricalSchema(database, version: .eleven)
    }

    func testVersionSixteenFixtureHasOnlyVersionSixteenFacts() throws {
        let database = try makeHistoricalWorkspaceDatabase(at: databaseURL, version: .sixteen)

        try assertExactHistoricalSchema(database, version: .sixteen)
    }

    func testVersionEighteenFixtureHasOnlyVersionEighteenFacts() throws {
        let database = try makeHistoricalWorkspaceDatabase(at: databaseURL, version: .eighteen)

        try assertExactHistoricalSchema(database, version: .eighteen)
    }

    func testVersionNineteenFixtureComposesExactVersionEighteenPlusNineteen() throws {
        let database = try makeHistoricalWorkspaceDatabase(at: databaseURL, version: .nineteen)

        try assertExactHistoricalSchema(database, version: .nineteen)
    }

    func testVersionTwentyFixtureHasOnlyVersionTwentyFacts() throws {
        let database = try makeHistoricalWorkspaceDatabase(at: databaseURL, version: .twenty)

        try assertExactHistoricalSchema(database, version: .twenty)
    }

    func testVersionTwentyTwoFixtureHasOnlyVersionTwentyTwoFacts() throws {
        let database = try makeHistoricalWorkspaceDatabase(at: databaseURL, version: .twentyTwo)

        try assertExactHistoricalSchema(database, version: .twentyTwo)
    }

    func testVersionElevenInteractionRowsAreRetainedAsLegacyRowsDuringContactInteractionMigration() throws {
        let database = try makeHistoricalWorkspaceDatabase(at: databaseURL, version: .eleven)
        try database.execute("INSERT INTO opportunities (id, title, company, created_at) VALUES ('opportunity-1', 'Product Manager', 'Rekon Labs', 1704067200)")
        try database.execute("INSERT INTO interactions (id, opportunity_id, summary, occurred_at) VALUES ('interaction-1', 'opportunity-1', 'Legacy note', 1704067200)")

        let store = try WorkspaceStore(database: database, actorID: "test", correlationID: "test")

        XCTAssertEqual(try store.schemaVersion(), WorkspaceMigrations.currentVersion)
        XCTAssertEqual(try database.rows("SELECT id, contact_id, opportunity_id, kind, summary, occurred_at, next_touch_at FROM interactions"), [[.text("interaction-1"), .null, .text("opportunity-1"), .text("Note"), .text("Legacy note"), .real(1_704_067_200), .null]])
        XCTAssertFalse(FileManager.default.fileExists(atPath: database.migrationSnapshotURL.path))
    }

    func testFailedVersionFiveMigrationKeepsVerifiedRecoverySnapshot() throws {
        let database = try EncryptedDatabase.open(url: databaseURL, key: key)
        try database.execute("CREATE TABLE schema_migrations (version INTEGER NOT NULL)")
        try database.execute("INSERT INTO schema_migrations (version) VALUES (4)")
        try database.execute("CREATE TABLE opportunities (id TEXT PRIMARY KEY NOT NULL, title TEXT NOT NULL, company TEXT NOT NULL, created_at REAL NOT NULL, stage TEXT NOT NULL DEFAULT 'Saved', next_action TEXT NOT NULL DEFAULT '', due_at REAL)")
        try database.execute("CREATE TABLE activity_events (id TEXT PRIMARY KEY NOT NULL, kind TEXT NOT NULL, opportunity_id TEXT NOT NULL, actor_id TEXT NOT NULL, correlation_id TEXT NOT NULL, occurred_at REAL NOT NULL)")

        XCTAssertThrowsError(try WorkspaceMigrations.apply(to: database, failVersionFive: true))

        XCTAssertEqual(try database.rows("SELECT version FROM schema_migrations"), [[.integer(4)]])
        XCTAssertTrue(FileManager.default.fileExists(atPath: databaseURL.appendingPathExtension("migration-snapshot").path))
    }

    func testFailedVersionSixMigrationKeepsVersionFiveWorkspaceAndSnapshot() throws {
        let database = try EncryptedDatabase.open(url: databaseURL, key: key)
        try database.execute("CREATE TABLE schema_migrations (version INTEGER NOT NULL)")
        try database.execute("INSERT INTO schema_migrations (version) VALUES (5)")
        try database.execute("CREATE TABLE opportunities (id TEXT PRIMARY KEY NOT NULL, title TEXT NOT NULL, company TEXT NOT NULL, created_at REAL NOT NULL, stage TEXT NOT NULL DEFAULT 'Saved', next_action TEXT NOT NULL DEFAULT '', due_at REAL, deleted_at REAL)")
        try database.execute("CREATE TABLE activity_events (id TEXT PRIMARY KEY NOT NULL, kind TEXT NOT NULL, opportunity_id TEXT NOT NULL, actor_id TEXT NOT NULL, correlation_id TEXT NOT NULL, occurred_at REAL NOT NULL)")
        try database.execute("CREATE TABLE migration_history (version INTEGER PRIMARY KEY NOT NULL, checksum TEXT NOT NULL)")
        try database.execute("INSERT INTO migration_history (version, checksum) VALUES (4, ?)", values: [.text(WorkspaceMigrations.baselineChecksum)])
        try database.execute("INSERT INTO migration_history (version, checksum) VALUES (5, ?)", values: [.text(WorkspaceMigrations.versionFiveChecksum)])

        XCTAssertThrowsError(try WorkspaceMigrations.apply(to: database, failVersionSix: true))

        XCTAssertEqual(try database.rows("SELECT version FROM schema_migrations"), [[.integer(5)]])
        XCTAssertTrue(FileManager.default.fileExists(atPath: database.migrationSnapshotURL.path))
        XCTAssertEqual(try database.rows("SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'workspace_metadata'"), [])
    }

    func testFailedVersionSixteenMigrationKeepsVerifiedSnapshot() throws {
        let database = try EncryptedDatabase.open(url: databaseURL, key: key)
        try database.execute("CREATE TABLE schema_migrations (version INTEGER NOT NULL)")
        try database.execute("INSERT INTO schema_migrations (version) VALUES (15)")
        try database.execute("CREATE TABLE migration_history (version INTEGER PRIMARY KEY NOT NULL, checksum TEXT NOT NULL)")
        for version in 4...15 {
            let checksum = [
                4: WorkspaceMigrations.baselineChecksum, 5: WorkspaceMigrations.versionFiveChecksum,
                6: WorkspaceMigrations.versionSixChecksum, 7: WorkspaceMigrations.versionSevenChecksum,
                8: WorkspaceMigrations.versionEightChecksum, 9: WorkspaceMigrations.versionNineChecksum,
                10: WorkspaceMigrations.versionTenChecksum, 11: WorkspaceMigrations.versionElevenChecksum,
                12: WorkspaceMigrations.versionTwelveChecksum, 13: WorkspaceMigrations.versionThirteenChecksum,
                14: WorkspaceMigrations.versionFourteenChecksum, 15: WorkspaceMigrations.versionFifteenChecksum
            ][version]!
            try database.execute("INSERT INTO migration_history (version, checksum) VALUES (?, ?)", values: [.integer(Int64(version)), .text(checksum)])
        }
        try database.execute("CREATE TABLE opportunities (id TEXT PRIMARY KEY NOT NULL, title TEXT NOT NULL, company TEXT NOT NULL, created_at REAL NOT NULL, stage TEXT NOT NULL DEFAULT 'Saved', next_action TEXT NOT NULL DEFAULT '', due_at REAL, deleted_at REAL, job_url TEXT NOT NULL DEFAULT '', job_description TEXT NOT NULL DEFAULT '', notes TEXT NOT NULL DEFAULT '')")
        try database.execute("INSERT INTO opportunities (id, title, company, created_at, stage, next_action, job_url, job_description, notes) VALUES ('legacy-r2', 'Legacy role', 'Legacy employer', ?, 'Applied', '', '', 'Legacy description', 'Legacy notes')", values: [.real(now.timeIntervalSince1970)])

        XCTAssertThrowsError(try WorkspaceMigrations.apply(to: database, failVersionSixteen: true))

        XCTAssertEqual(try database.rows("SELECT version FROM schema_migrations"), [[.integer(15)]])
        XCTAssertEqual(try database.rows("SELECT title, company, job_description, notes FROM opportunities WHERE id = 'legacy-r2'"), [[.text("Legacy role"), .text("Legacy employer"), .text("Legacy description"), .text("Legacy notes")]])
        XCTAssertTrue(FileManager.default.fileExists(atPath: database.migrationSnapshotURL.path))
    }

    func testVersionSixteenToSeventeenMigrationAndFailureKeepSnapshot() throws {
        let database = try makeHistoricalWorkspaceDatabase(at: databaseURL, version: .sixteen)
        try database.execute(
            "INSERT INTO import_reports (id, imported_count, skipped_count, duplicate_kept_count, invalid_count, created_at) VALUES ('prior', 1, 0, 0, 0, ?)",
            values: [.real(now.timeIntervalSince1970)]
        )
        XCTAssertThrowsError(try WorkspaceMigrations.apply(to: database, failVersionSeventeen: true))
        XCTAssertEqual(try database.rows("SELECT version FROM schema_migrations"), [[.integer(16)]])
        XCTAssertEqual(try database.rows("SELECT id FROM import_reports"), [[.text("prior")]])
        XCTAssertTrue(FileManager.default.fileExists(atPath: database.migrationSnapshotURL.path))
        try WorkspaceMigrations.apply(to: database)
        XCTAssertEqual(
            try database.rows("SELECT version FROM schema_migrations"),
            [[.integer(Int64(WorkspaceMigrations.currentVersion))]]
        )
        XCTAssertEqual(try database.rows("SELECT updated_count, source_basename FROM import_reports"), [[.integer(0), .text("")]])
    }

    func testVersionEighteenPostingChecksMigrateLosslesslyToReadOnlyReconciliationHistory() throws {
        let database = try makeHistoricalWorkspaceDatabase(at: databaseURL, version: .eighteen)
        try insertLegacyHistoricalOpportunity(into: database)
        try database.execute("INSERT INTO posting_checks (id, opportunity_id, url, status, evidence, checked_at) VALUES ('legacy-open', 'legacy-opportunity', 'https://jobs.example.com/open', 'Still open', 'Open evidence', 1704067200)")
        try database.execute("INSERT INTO posting_checks (id, opportunity_id, url, status, evidence, checked_at) VALUES ('legacy-possible', 'legacy-opportunity', 'https://jobs.example.com/possible', 'Possibly closed', 'Possible evidence', 1704067201)")
        try database.execute("INSERT INTO posting_checks (id, opportunity_id, url, status, evidence, checked_at) VALUES ('legacy-closed', 'legacy-opportunity', 'https://jobs.example.com/closed', 'Closed', 'Closed evidence', 1704067202)")
        try database.execute("INSERT INTO posting_checks (id, opportunity_id, url, status, evidence, checked_at) VALUES ('legacy-review', 'legacy-opportunity', 'https://jobs.example.com/review', 'Needs manual review', 'Review evidence', 1704067203)")

        try WorkspaceMigrations.apply(to: database)

        XCTAssertEqual(try database.rows("SELECT legacy_posting_check_id, legacy_status, outcome, classification, closure_confirmed_at FROM reconciliation_results ORDER BY legacy_posting_check_id"), [
            [.text("legacy-closed"), .text("Closed"), .text("Closed suggested"), .text("Confirmed"), .null],
            [.text("legacy-open"), .text("Still open"), .text("Still open"), .text("Confirmed"), .null],
            [.text("legacy-possible"), .text("Possibly closed"), .text("Possibly closed"), .text("Ambiguous"), .null],
            [.text("legacy-review"), .text("Needs manual review"), .text("Needs manual review"), .text("Ambiguous"), .null]
        ])
        XCTAssertEqual(try database.rows("SELECT count(*) FROM reconciliation_reviews"), [[.integer(1)]])
        XCTAssertEqual(
            try database.rows("SELECT version FROM schema_migrations"),
            [[.integer(Int64(WorkspaceMigrations.currentVersion))]]
        )
        XCTAssertFalse(FileManager.default.fileExists(atPath: database.migrationSnapshotURL.path))
    }

    func testFailedVersionNineteenMigrationRetainsVersionEighteenPostingChecksAndSnapshot() throws {
        let database = try makeHistoricalWorkspaceDatabase(at: databaseURL, version: .eighteen)
        try insertLegacyHistoricalOpportunity(into: database)
        try database.execute("INSERT INTO posting_checks (id, opportunity_id, url, status, evidence, checked_at) VALUES ('legacy-closed', 'legacy-opportunity', 'https://jobs.example.com/closed', 'Closed', 'Closed evidence', 1704067202)")

        XCTAssertThrowsError(try WorkspaceMigrations.apply(to: database, failVersionNineteen: true))

        XCTAssertEqual(try database.rows("SELECT version FROM schema_migrations"), [[.integer(18)]])
        XCTAssertEqual(try database.rows("SELECT id, status, evidence FROM posting_checks"), [[.text("legacy-closed"), .text("Closed"), .text("Closed evidence")]])
        XCTAssertEqual(try database.rows("SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'reconciliation_results'"), [])
        XCTAssertTrue(FileManager.default.fileExists(atPath: database.migrationSnapshotURL.path))
    }

    func testVersionNineteenMigratesToTwentyWithoutChangingExistingReconciliationRows() throws {
        let database = try makeHistoricalWorkspaceDatabase(at: databaseURL, version: .nineteen)
        try insertLegacyHistoricalOpportunity(into: database)
        try insertVersionNineteenReconciliationResult(into: database)

        try WorkspaceMigrations.apply(to: database)

        XCTAssertEqual(
            try database.rows("SELECT version FROM schema_migrations"),
            [[.integer(Int64(WorkspaceMigrations.currentVersion))]]
        )
        XCTAssertEqual(
            try database.rows("SELECT id, opportunity_id, url, outcome, classification, reason, confidence, evidence, error, review_task_reminder_id, closure_confirmed_at, legacy_posting_check_id, legacy_status, check_operation_id, method, checker_version, http_status, mime_type, declared_bytes, received_bytes, content_sha256, response_date, last_modified, etag, retry_after, redirect_target_redacted, evidence_excerpt, redacted_error_code FROM reconciliation_results"),
            [[
                .text("result-v19"), .text("legacy-opportunity"), .text("https://jobs.example.com/role"),
                .text("Needs manual review"), .text("Ambiguous"), .text("manual review"), .text("Medium"),
                .text("Existing R4 evidence"), .text(""), .null, .null, .null, .null,
                .null, .null, .null, .null, .null, .null, .null, .null, .null, .null, .null, .null, .null, .null, .null
            ]]
        )
        XCTAssertEqual(try database.rows("SELECT count(*) FROM reconciliation_check_operations"), [[.integer(0)]])
        XCTAssertFalse(FileManager.default.fileExists(atPath: database.migrationSnapshotURL.path))
    }

    func testVersionTwentyMigrationRetainsLegacyCompensationAndActionText() throws {
        let database = try makeHistoricalWorkspaceDatabase(at: databaseURL, version: .twenty)
        let legacyAction = "  Ask Morgan for a referral  "
        try database.execute(
            "INSERT INTO opportunities (id, title, company, created_at, stage, next_action, due_at, job_url, job_description, notes, compensation, location, work_arrangement, application_date, response_state, stage_changed_at, deleted_at) VALUES ('legacy-opportunity', 'Legacy role', 'Rekon Labs', ?, 'Saved', ?, NULL, '', '', '', '150k base', NULL, 'Not specified', NULL, 'No response recorded', ?, NULL)",
            values: [.real(now.timeIntervalSince1970), .text(legacyAction), .real(now.timeIntervalSince1970)]
        )

        try WorkspaceMigrations.apply(to: database)

        XCTAssertEqual(
            try database.rows("SELECT version FROM schema_migrations"),
            [[.integer(Int64(WorkspaceMigrations.currentVersion))]]
        )
        XCTAssertEqual(try database.rows("PRAGMA foreign_key_check"), [])
        let store = try WorkspaceStore(database: database, now: now, actorID: "test", correlationID: "test")
        let migrated = try XCTUnwrap(try store.opportunities().first)
        XCTAssertEqual(migrated.compensation, "150k base")
        XCTAssertNil(migrated.compensationMinimum)
        XCTAssertNil(migrated.compensationMaximum)
        XCTAssertNil(migrated.compensationPayPeriod)
        XCTAssertEqual(migrated.nextAction, legacyAction)
        XCTAssertEqual(migrated.actionType, .other)
        XCTAssertEqual(migrated.actionCustomText, legacyAction)
        let contact = try store.createContact(CreateContact(name: "Alex Morgan", employer: "Rekon Labs"))
        try store.linkContact(contactID: contact.id, toOpportunityID: migrated.id)
        XCTAssertEqual(try store.opportunities(forContactID: contact.id), [migrated])
    }

    func testFailedVersionTwentyMigrationKeepsVersionNineteenRowsAndVerifiedSnapshot() throws {
        let database = try makeHistoricalWorkspaceDatabase(at: databaseURL, version: .nineteen)
        try insertLegacyHistoricalOpportunity(into: database)
        try insertVersionNineteenReconciliationResult(into: database)

        XCTAssertThrowsError(try WorkspaceMigrations.apply(to: database, failVersionTwenty: true))

        XCTAssertEqual(try database.rows("SELECT version FROM schema_migrations"), [[.integer(19)]])
        XCTAssertEqual(try database.rows("SELECT id, evidence FROM reconciliation_results"), [[.text("result-v19"), .text("Existing R4 evidence")]])
        XCTAssertEqual(try database.rows("SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'reconciliation_check_operations'"), [])
        XCTAssertFalse(try database.rows("PRAGMA table_info(reconciliation_results)").contains { row in
            row.count > 1 && row[1] == .text("check_operation_id")
        })
        XCTAssertTrue(FileManager.default.fileExists(atPath: database.migrationSnapshotURL.path))
    }

    func testMixedImportFailureLeavesPriorReportAndOpportunityAfterReopen() throws {
        let store = try makeStore()
        let prior = try store.create(CreateOpportunity(title: "Prior", company: "Rekon"))
        let seed = try CSVOpportunityImporter.preview(data: Data("title,company\nSeed,Rekon\n".utf8))
        let seedReport = try store.importCSV(try store.csvImportPlan(for: seed), invalidCount: 0)
        try store.close()
        let failingDatabase = try EncryptedDatabase.open(url: databaseURL, key: key, createIfMissing: false)
        let failing = try WorkspaceStore(database: failingDatabase, now: now, actorID: "local-user", correlationID: "rollback", failBeforeActivityInsert: true)
        let next = try CSVOpportunityImporter.preview(data: Data("title,company\nNew,Rekon\n".utf8))
        XCTAssertThrowsError(try failing.importCSV(try failing.csvImportPlan(for: next), invalidCount: 0))
        try failing.close()
        let reopened = try makeStore()
        XCTAssertEqual(try reopened.opportunities().map(\.id).contains(prior.id), true)
        XCTAssertEqual(try reopened.importReports().map(\.id), [seedReport.id])
        XCTAssertFalse(try reopened.opportunities().contains { $0.title == "New" })
    }

    func testCreateOpportunityAddsOneMatchingActivityEvent() throws {
        let store = try makeStore()

        let opportunity = try store.create(CreateOpportunity(title: "Product Manager", company: "Rekon Labs"))

        XCTAssertEqual(try store.opportunities(), [opportunity])
        XCTAssertEqual(try store.activityEvents(), [
            ActivityEvent(
                id: "fixture-id-1",
                kind: "opportunity_created",
                opportunityID: opportunity.id,
                actorID: "local-user",
                correlationID: "fixture-correlation",
                occurredAt: now
            )
        ])
    }

    func testCommandsUseTheInjectedCurrentClockRatherThanStoreConstructionTime() throws {
        let database = try EncryptedDatabase.open(url: databaseURL, key: key)
        var current = now
        var identifier = 0
        let store = try WorkspaceStore(
            database: database,
            clock: { current },
            nextIdentifier: { defer { identifier += 1 }; return "clock-id-\(identifier)" },
            actorID: "local-user",
            correlationID: "clock-test"
        )

        current = now.addingTimeInterval(60)
        let opportunity = try store.create(CreateOpportunity(title: "Product Manager", company: "Rekon Labs", nextAction: "Follow up", dueAt: current))
        XCTAssertEqual(opportunity.createdAt, current)

        current = now.addingTimeInterval(120)
        try store.changeStage(opportunityID: opportunity.id, to: .screening)
        XCTAssertEqual(try store.opportunities().first?.stageChangedAt, current)
        XCTAssertEqual(try store.stageHistory(forOpportunityID: opportunity.id).last?.occurredAt, current)
        XCTAssertEqual(try store.activityEvents().last?.occurredAt, current)

        current = now.addingTimeInterval(180)
        try store.snoozeTask(id: "clock-id-2")
        XCTAssertEqual(try store.needsAttention().first?.dueAt, current.addingTimeInterval(86_400))
        XCTAssertEqual(try store.activityEvents().last?.occurredAt, current)
    }

    func testCreateRejectsNonDefaultResponseWithoutExplicitDateAtomically() throws {
        let store = try makeStore()

        XCTAssertThrowsError(try store.create(CreateOpportunity(
            title: "Product Manager", company: "Rekon Labs", responseState: .responseReceived
        )))
        XCTAssertTrue(try store.opportunities().isEmpty)
        XCTAssertTrue(try store.activityEvents().isEmpty)
    }

    func testHistoriesUseExplicitDateThenIdentifierForDeterministicTies() throws {
        let store = try makeStore()
        let opportunity = try store.create(CreateOpportunity(title: "Product Manager", company: "Rekon Labs"))

        try store.updateOpportunity(id: opportunity.id, title: opportunity.title, company: opportunity.company, stage: .applied, nextAction: "", dueAt: nil, responseState: .awaitingResponse, responseEffectiveDate: now, stageChangedAt: now)
        try store.updateOpportunity(id: opportunity.id, title: opportunity.title, company: opportunity.company, stage: .screening, nextAction: "", dueAt: nil, responseState: .responseReceived, responseEffectiveDate: now, stageChangedAt: now)

        XCTAssertEqual(try store.stageHistory(forOpportunityID: opportunity.id).map(\.id), ["fixture-id-2", "fixture-id-4", "fixture-id-8"])
        XCTAssertEqual(try store.responseHistory(forOpportunityID: opportunity.id).map(\.id), ["fixture-id-9", "fixture-id-5"])
    }

    func testUpdateRejectsMissingEffectiveDatesWithoutWriting() throws {
        let store = try makeStore()
        let opportunity = try store.create(CreateOpportunity(title: "Product Manager", company: "Rekon Labs", nextAction: "Follow up", dueAt: now))
        let baseline = try store.activityEvents()

        XCTAssertThrowsError(try store.updateOpportunity(
            id: opportunity.id, title: opportunity.title, company: opportunity.company,
            stage: .screening, nextAction: "Changed action", dueAt: now,
            responseState: .responseReceived, responseEffectiveDate: nil, stageChangedAt: nil
        ))

        XCTAssertEqual(try store.opportunities(), [opportunity])
        XCTAssertEqual(try store.stageHistory(forOpportunityID: opportunity.id).count, 1)
        XCTAssertEqual(try store.responseHistory(forOpportunityID: opportunity.id), [])
        XCTAssertEqual(try store.activityEvents(), baseline)
        XCTAssertEqual(try store.latestTask(forOpportunityID: opportunity.id)?.title, "Follow up")
    }

    func testFailedUpdateRollsBackOpportunityTaskHistoriesAndActivity() throws {
        let database = try EncryptedDatabase.open(url: databaseURL, key: key)
        var identifier = 0
        let store = try WorkspaceStore(
            database: database,
            now: now,
            nextIdentifier: { defer { identifier += 1 }; return "rollback-id-\(identifier)" },
            actorID: "local-user",
            correlationID: "rollback-test"
        )
        let opportunity = try store.create(CreateOpportunity(
            title: "Product Manager", company: "Rekon Labs", nextAction: "Send follow-up", dueAt: now
        ))
        let baselineOpportunity = try XCTUnwrap(store.opportunities().first)
        let baselineTask = try store.latestTask(forOpportunityID: opportunity.id)
        let baselineStages = try store.stageHistory(forOpportunityID: opportunity.id)
        let baselineResponses = try store.responseHistory(forOpportunityID: opportunity.id)
        let baselineActivity = try store.activityEvents()
        try store.close()

        let failingDatabase = try EncryptedDatabase.open(url: databaseURL, key: key, createIfMissing: false)
        let failingStore = try WorkspaceStore(
            database: failingDatabase,
            now: now,
            nextIdentifier: { defer { identifier += 1 }; return "rollback-id-\(identifier)" },
            actorID: "local-user",
            correlationID: "rollback-test",
            failBeforeActivityInsert: true
        )

        XCTAssertThrowsError(try failingStore.updateOpportunity(
            id: opportunity.id,
            title: "Senior Product Manager",
            company: "Rekon Labs",
            stage: .screening,
            nextAction: "Prepare recruiter call",
            dueAt: now.addingTimeInterval(3_600),
            responseState: .responseReceived,
            responseEffectiveDate: now,
            stageChangedAt: now
        ))

        XCTAssertEqual(try failingStore.opportunities(), [baselineOpportunity])
        XCTAssertEqual(try failingStore.latestTask(forOpportunityID: opportunity.id), baselineTask)
        XCTAssertEqual(try failingStore.stageHistory(forOpportunityID: opportunity.id), baselineStages)
        XCTAssertEqual(try failingStore.responseHistory(forOpportunityID: opportunity.id), baselineResponses)
        XCTAssertEqual(try failingStore.activityEvents(), baselineActivity)
    }

    func testMultiRowCSVImportUsesOneCurrentCommandTimestamp() throws {
        let database = try EncryptedDatabase.open(url: databaseURL, key: key)
        var current = now
        var identifier = 0
        let store = try WorkspaceStore(
            database: database,
            clock: { current },
            nextIdentifier: { defer { identifier += 1 }; return "csv-clock-\(identifier)" },
            actorID: "local-user", correlationID: "csv-clock"
        )
        let preview = try CSVOpportunityImporter.preview(data: Data("title,company\nFirst,Rekon Labs\nSecond,Rekon Labs\n".utf8))
        let plan = try store.csvImportPlan(for: preview)
        current = now.addingTimeInterval(3600)

        let report = try store.importCSV(plan, invalidCount: 0)

        XCTAssertEqual(report.createdAt, current)
        XCTAssertTrue(try store.opportunities().allSatisfy { $0.createdAt == current && $0.stageChangedAt == current })
        let importedIDs = Set(try store.opportunities().map(\.id))
        XCTAssertTrue(try importedIDs.allSatisfy { try store.stageHistory(forOpportunityID: $0).allSatisfy { $0.occurredAt == current } })
        XCTAssertTrue(try store.activityEvents().allSatisfy { $0.occurredAt == current })
    }

    func testNeedsAttentionSamplesTheClockAtReadTime() throws {
        let database = try EncryptedDatabase.open(url: databaseURL, key: key)
        var current = now
        var identifier = 0
        let store = try WorkspaceStore(
            database: database,
            clock: { current },
            nextIdentifier: { defer { identifier += 1 }; return "attention-clock-\(identifier)" },
            actorID: "local-user", correlationID: "attention-clock"
        )
        let dueAt = now.addingTimeInterval(3600)
        _ = try store.create(CreateOpportunity(title: "Product Manager", company: "Rekon Labs", nextAction: "Follow up", dueAt: dueAt))

        current = now.addingTimeInterval(7200)
        XCTAssertEqual(try store.needsAttention().map(\.title), ["Follow up"])
    }

    func testOpportunityDetailsAndExplicitResponseTransitionPersist() throws {
        let store = try makeStore()
        let responseDate = now.addingTimeInterval(-86_400)
        let stageDate = now.addingTimeInterval(-172_800)

        let opportunity = try store.create(CreateOpportunity(
            title: "Product Manager", company: "Rekon Labs",
            compensation: "150k base", location: "New York", workArrangement: .hybrid,
            applicationDate: responseDate, responseState: .awaitingResponse,
            responseEffectiveDate: responseDate, stageChangedAt: stageDate
        ))

        XCTAssertEqual(try store.opportunities().first?.compensation, "150k base")
        XCTAssertEqual(try store.opportunities().first?.workArrangement, .hybrid)
        XCTAssertEqual(try store.responseHistory(forOpportunityID: opportunity.id).map(\.toState), [.awaitingResponse])
        XCTAssertEqual(try store.responseHistory(forOpportunityID: opportunity.id).first?.occurredAt, responseDate)
        XCTAssertEqual(try store.activityEvents().map(\.kind), ["opportunity_created", "opportunity_response_changed"])
    }

    func testCreateRejectsMalformedOrHostlessJobURLsWithoutWriting() throws {
        let store = try makeStore()

        for url in ["jobs.example.com/role", "https://", "https:///role", "mailto:jobs@example.com"] {
            XCTAssertThrowsError(try store.create(CreateOpportunity(
                title: "Product Manager", company: "Rekon Labs", jobURL: url
            )))
        }

        XCTAssertEqual(try store.opportunities(), [])
        XCTAssertEqual(try store.activityEvents(), [])
    }

    func testUpdateRejectsPersistedMalformedOrHostlessJobURLsWithoutWriting() throws {
        let database = try EncryptedDatabase.open(url: databaseURL, key: key)
        let store = try WorkspaceStore(database: database, now: now, actorID: "test", correlationID: "test")

        for (index, url) in ["https://", "https:///role"].enumerated() {
            let opportunity = try store.create(CreateOpportunity(title: "Product Manager \(index)", company: "Rekon Labs"))
            try database.execute("UPDATE opportunities SET job_url = ? WHERE id = ?", values: [.text(url), .text(opportunity.id)])
            let baselineActivity = try store.activityEvents()

            XCTAssertThrowsError(try store.updateOpportunity(
                id: opportunity.id, title: "Renamed \(index)", company: opportunity.company,
                stage: opportunity.stage, nextAction: opportunity.nextAction, dueAt: opportunity.dueAt,
                jobURL: url, jobDescription: opportunity.jobDescription, notes: opportunity.notes,
                compensation: opportunity.compensation, location: opportunity.location,
                workArrangement: opportunity.workArrangement, applicationDate: opportunity.applicationDate,
                responseState: opportunity.responseState, stageChangedAt: opportunity.stageChangedAt
            ))

            let saved = try XCTUnwrap(store.opportunities().first(where: { $0.id == opportunity.id }))
            XCTAssertEqual(saved.title, opportunity.title)
            XCTAssertEqual(saved.jobURL, url)
            XCTAssertEqual(try store.activityEvents(), baselineActivity)
        }
    }

    func testUpdateRetainsUnchangedHostfulAbsoluteLegacyJobURL() throws {
        let database = try EncryptedDatabase.open(url: databaseURL, key: key)
        let store = try WorkspaceStore(database: database, now: now, actorID: "test", correlationID: "test")
        let opportunity = try store.create(CreateOpportunity(title: "Product Manager", company: "Rekon Labs"))
        let legacyURL = "ftp://jobs.example.com/archive/role"
        try database.execute("UPDATE opportunities SET job_url = ? WHERE id = ?", values: [.text(legacyURL), .text(opportunity.id)])

        try store.updateOpportunity(
            id: opportunity.id, title: opportunity.title, company: opportunity.company,
            stage: opportunity.stage, nextAction: opportunity.nextAction, dueAt: opportunity.dueAt,
            jobURL: legacyURL, jobDescription: opportunity.jobDescription, notes: "Met the recruiter.",
            compensation: opportunity.compensation, location: opportunity.location,
            workArrangement: opportunity.workArrangement, applicationDate: opportunity.applicationDate,
            responseState: opportunity.responseState, stageChangedAt: opportunity.stageChangedAt
        )

        let saved = try XCTUnwrap(store.opportunities().first)
        XCTAssertEqual(saved.notes, "Met the recruiter.")
        XCTAssertEqual(saved.jobURL, legacyURL)
    }

    func testUpdatePreservesUneditedLegacyCompensationByteForByte() throws {
        let database = try EncryptedDatabase.open(url: databaseURL, key: key)
        let store = try WorkspaceStore(database: database, now: now, actorID: "test", correlationID: "test")
        let opportunity = try store.create(CreateOpportunity(title: "Product Manager", company: "Rekon Labs"))
        let legacyCompensation = "  150k base \n"
        try database.execute("UPDATE opportunities SET compensation = ? WHERE id = ?", values: [.text(legacyCompensation), .text(opportunity.id)])

        try store.updateOpportunity(
            id: opportunity.id, title: opportunity.title, company: opportunity.company,
            stage: opportunity.stage, nextAction: opportunity.nextAction, dueAt: opportunity.dueAt,
            jobURL: opportunity.jobURL, jobDescription: opportunity.jobDescription, notes: "Met the recruiter.",
            compensation: legacyCompensation, location: opportunity.location,
            workArrangement: opportunity.workArrangement, applicationDate: opportunity.applicationDate,
            responseState: opportunity.responseState, stageChangedAt: opportunity.stageChangedAt
        )

        let saved = try XCTUnwrap(store.opportunities().first)
        XCTAssertEqual(saved.notes, "Met the recruiter.")
        XCTAssertEqual(saved.compensation, legacyCompensation)
    }

    func testCreateDefaultsApplicationDateToItsCreationDate() throws {
        let store = try makeStore()

        let opportunity = try store.create(CreateOpportunity(title: "Product Manager", company: "Rekon Labs"))

        XCTAssertEqual(opportunity.applicationDate, now)
        XCTAssertEqual(try store.opportunities().first?.applicationDate, now)
    }

    func testStructuredCompensationAndOtherActionPersistWithoutChangingStageHistory() throws {
        let store = try makeStore()
        let opportunity = try store.create(CreateOpportunity(
            title: "Product Manager", company: "Rekon Labs", dueAt: now,
            compensationMinimum: 125_000, compensationMaximum: 150_000, compensationPayPeriod: .year,
            actionType: .other, actionCustomText: "Ask Morgan for a referral"
        ))

        XCTAssertEqual(opportunity.compensation, nil)
        XCTAssertEqual(opportunity.compensationMinimum, 125_000)
        XCTAssertEqual(opportunity.compensationMaximum, 150_000)
        XCTAssertEqual(opportunity.compensationPayPeriod, .year)
        XCTAssertEqual(opportunity.actionType, .other)
        XCTAssertEqual(opportunity.actionCustomText, "Ask Morgan for a referral")
        XCTAssertEqual(opportunity.nextAction, "Ask Morgan for a referral")
        XCTAssertEqual(try store.latestTask(forOpportunityID: opportunity.id)?.title, "Ask Morgan for a referral")

        try store.updateOpportunity(
            id: opportunity.id, title: opportunity.title, company: opportunity.company,
            stage: .saved, nextAction: "", dueAt: nil,
            compensationMinimum: 130_000, compensationMaximum: nil, compensationPayPeriod: .year,
            structuredCompensationEdited: true, actionType: .followUp, actionCustomText: nil, typedActionEdited: true
        )

        let updated = try XCTUnwrap(store.opportunities().first)
        XCTAssertEqual(updated.compensation, nil)
        XCTAssertEqual(updated.compensationMinimum, 130_000)
        XCTAssertNil(updated.compensationMaximum)
        XCTAssertEqual(updated.compensationPayPeriod, .year)
        XCTAssertEqual(updated.actionType, .followUp)
        XCTAssertNil(updated.actionCustomText)
        XCTAssertEqual(updated.nextAction, "Follow up")
        XCTAssertEqual(try store.stageHistory(forOpportunityID: opportunity.id).count, 1)
    }

    func testLegacyCompensationAndActionTextRemainAvailableAsCompatibilityValues() throws {
        let store = try makeStore()

        let opportunity = try store.create(CreateOpportunity(
            title: "Product Manager", company: "Rekon Labs", nextAction: "Ask Morgan for a referral", compensation: "150k base"
        ))

        XCTAssertEqual(opportunity.compensation, "150k base")
        XCTAssertNil(opportunity.compensationMinimum)
        XCTAssertEqual(opportunity.actionType, OpportunityActionType.other)
        XCTAssertEqual(opportunity.actionCustomText, "Ask Morgan for a referral")
        XCTAssertEqual(try store.latestTask(forOpportunityID: opportunity.id)?.title, "Ask Morgan for a referral")
    }

    func testInvalidStructuredCompensationRejectsUpdateWithoutWriting() throws {
        let store = try makeStore()
        let opportunity = try store.create(CreateOpportunity(title: "Product Manager", company: "Rekon Labs"))
        let baselineActivity = try store.activityEvents()

        XCTAssertThrowsError(try store.updateOpportunity(
            id: opportunity.id, title: opportunity.title, company: opportunity.company,
            stage: opportunity.stage, nextAction: opportunity.nextAction, dueAt: opportunity.dueAt,
            compensationMinimum: -1, compensationMaximum: 10, compensationPayPeriod: .year, structuredCompensationEdited: true
        ))

        XCTAssertEqual(try store.opportunities().first, opportunity)
        XCTAssertEqual(try store.activityEvents(), baselineActivity)
    }

    func testFailureBetweenOpportunityAndEventRollsBackBothRecords() throws {
        let store = try makeStore(failBeforeActivityInsert: true)

        XCTAssertThrowsError(try store.create(CreateOpportunity(title: "Product Manager", company: "Rekon Labs")))
        XCTAssertEqual(try store.opportunities(), [])
        XCTAssertEqual(try store.activityEvents(), [])
    }

    func testCreateOpportunityWithNextActionAppearsInNeedsAttention() throws {
        let store = try makeStore()
        let due = now.addingTimeInterval(-3_600)

        let opportunity = try store.create(CreateOpportunity(
            title: "Product Manager", company: "Rekon Labs", stage: .applied,
            nextAction: "Send follow-up", dueAt: due
        ))

        XCTAssertEqual(opportunity.stage, .applied)
        XCTAssertEqual(try store.needsAttention(), [
            TaskReminder(
                id: "fixture-id-2", opportunityID: opportunity.id, title: "Send follow-up",
                dueAt: due, isComplete: false
            )
        ])
    }

    func testCompleteTaskRemovesItFromQueueAndWritesActivity() throws {
        let store = try makeStore()
        _ = try store.create(CreateOpportunity(title: "Product Manager", company: "Rekon Labs", nextAction: "Send follow-up", dueAt: now))

        try store.completeTask(id: "fixture-id-2")

        XCTAssertEqual(try store.needsAttention(), [])
        XCTAssertEqual(try store.activityEvents().last?.kind, "task_completed")
    }

    func testOpenTaskKeepsItInQueueAndWritesActivity() throws {
        let store = try makeStore()
        _ = try store.create(CreateOpportunity(title: "Product Manager", company: "Rekon Labs", nextAction: "Send follow-up", dueAt: now))

        try store.openTask(id: "fixture-id-2")

        XCTAssertEqual(try store.needsAttention().map(\.title), ["Send follow-up"])
        XCTAssertEqual(try store.activityEvents().last?.kind, "task_opened")
    }

    func testRescheduleTaskUpdatesDueDateAndWritesActivity() throws {
        let store = try makeStore()
        _ = try store.create(CreateOpportunity(title: "Product Manager", company: "Rekon Labs", nextAction: "Send follow-up", dueAt: now))
        let rescheduled = now.addingTimeInterval(86_400)

        try store.rescheduleTask(id: "fixture-id-2", dueAt: rescheduled)

        XCTAssertEqual(try store.needsAttention().first?.dueAt, rescheduled)
        XCTAssertEqual(try store.activityEvents().last?.kind, "task_rescheduled")
    }

    func testSnoozeTaskMovesOnlyItsDueDateAndWritesDistinctActivity() throws {
        let store = try makeStore()
        _ = try store.create(CreateOpportunity(title: "Product Manager", company: "Rekon Labs", nextAction: "Send follow-up", dueAt: now))
        let snoozedDueAt = now.addingTimeInterval(86_400)

        try store.snoozeTask(id: "fixture-id-2")

        XCTAssertEqual(try store.needsAttention().first?.dueAt, snoozedDueAt)
        XCTAssertEqual(try store.activityEvents().last?.kind, "task_snoozed")
    }

    func testNeedsAttentionOrdersOverdueTodayFutureThenUndatedActions() throws {
        let store = try makeStore()
        _ = try store.create(CreateOpportunity(title: "Undated", company: "Rekon Labs", nextAction: "Research"))
        _ = try store.create(CreateOpportunity(title: "Future", company: "Rekon Labs", nextAction: "Follow up", dueAt: now.addingTimeInterval(86_400)))
        _ = try store.create(CreateOpportunity(title: "Today", company: "Rekon Labs", nextAction: "Apply", dueAt: now.addingTimeInterval(3_600)))
        _ = try store.create(CreateOpportunity(title: "Overdue", company: "Rekon Labs", nextAction: "Reply", dueAt: now.addingTimeInterval(-3_600)))

        XCTAssertEqual(try store.needsAttention().map(\.title), ["Reply", "Apply", "Follow up", "Research"])
    }

    func testStageChangePersistsAndWritesActivity() throws {
        let store = try makeStore()
        let opportunity = try store.create(CreateOpportunity(title: "Product Manager", company: "Rekon Labs"))

        try store.changeStage(opportunityID: opportunity.id, to: .screening)

        XCTAssertEqual(try store.opportunities().first?.stage, .screening)
        XCTAssertEqual(try store.activityEvents().last?.kind, "opportunity_stage_changed")
    }

    func testStageMoveCommitsStageAuditHistoryAndProjectionTogether() throws {
        let store = try makeStore()
        _ = try store.create(CreateOpportunity(title: "Other opportunity", company: "Rekon Labs"))
        let opportunity = try store.create(CreateOpportunity(title: "Product Manager", company: "Rekon Labs", nextAction: "Follow up", dueAt: now))
        let activitiesBefore = try store.activityEvents()
        let historyBefore = try store.stageHistory(forOpportunityID: opportunity.id)

        let outcome = try store.moveStage(opportunityID: opportunity.id, to: .screening)

        guard case let .persisted(commit) = outcome else {
            return XCTFail("Expected a committed stage-move projection")
        }
        XCTAssertEqual(commit.opportunityID, opportunity.id)
        XCTAssertEqual(commit.from, .saved)
        XCTAssertEqual(commit.to, .screening)
        let projectedMoved = try XCTUnwrap(commit.projection.opportunities.first { $0.id == opportunity.id })
        let projectedOther = try XCTUnwrap(commit.projection.opportunities.first { $0.id != opportunity.id })
        XCTAssertEqual(projectedMoved.stage, .screening)
        XCTAssertEqual(projectedOther.stage, .saved)
        XCTAssertEqual(commit.projection.activityEvents.count, activitiesBefore.count + 1)
        XCTAssertEqual(commit.projection.stageHistoryForTransition.count, historyBefore.count + 1)
        XCTAssertEqual(commit.projection.stageHistoryForTransition.last?.toStage, .screening)
        XCTAssertEqual(commit.projection.needsAttention, try store.needsAttention())

        let newlyAddedActivities = try store.activityEvents().filter { event in
            !activitiesBefore.contains(event)
        }
        XCTAssertEqual(newlyAddedActivities.count, 1)
        XCTAssertEqual(newlyAddedActivities.first?.kind, "opportunity_stage_changed")
        XCTAssertEqual(newlyAddedActivities.first?.opportunityID, opportunity.id)
        let newlyAddedHistory = try store.stageHistory(forOpportunityID: opportunity.id).filter { entry in
            !historyBefore.contains(entry)
        }
        XCTAssertEqual(newlyAddedHistory.count, 1)
        XCTAssertEqual(newlyAddedHistory.first?.opportunityID, opportunity.id)
        XCTAssertEqual(newlyAddedHistory.first?.fromStage, .saved)
        XCTAssertEqual(newlyAddedHistory.first?.toStage, .screening)

        try store.close()
        let reopened = try makeStore()
        let reopenedMoved = try XCTUnwrap(try reopened.opportunities().first { $0.id == opportunity.id })
        let reopenedOther = try XCTUnwrap(try reopened.opportunities().first { $0.id == projectedOther.id })
        XCTAssertEqual(reopenedMoved.stage, .screening)
        XCTAssertEqual(reopenedOther.stage, .saved)
        XCTAssertEqual(try reopened.activityEvents().count, activitiesBefore.count + 1)
        XCTAssertEqual(try reopened.stageHistory(forOpportunityID: opportunity.id).count, historyBefore.count + 1)
    }

    func testStageMoveSameStageClosedRetainsFullEncryptedReopenBaseline() throws {
        let store = try makeStore()
        let closed = try store.create(CreateOpportunity(title: "Closed role", company: "Rekon Labs", stage: .closed))
        let opportunitiesBefore = try store.opportunities()
        let activitiesBefore = try store.activityEvents()
        let historyBefore = try store.stageHistory(forOpportunityID: closed.id)
        let attentionBefore = try store.needsAttention()

        XCTAssertEqual(try store.moveStage(opportunityID: closed.id, to: .closed), .noOp(opportunityID: closed.id, stage: .closed))
        try store.close()
        let reopened = try makeStore()

        XCTAssertEqual(try reopened.opportunities(), opportunitiesBefore)
        XCTAssertEqual(try reopened.activityEvents(), activitiesBefore)
        XCTAssertEqual(try reopened.stageHistory(forOpportunityID: closed.id), historyBefore)
        XCTAssertEqual(try reopened.needsAttention(), attentionBefore)
    }

    func testStageMoveDeletedOpportunityRetainsFullEncryptedReopenBaseline() throws {
        let store = try makeStore()
        let deleted = try store.create(CreateOpportunity(title: "Deleted role", company: "Rekon Labs", nextAction: "Follow up", dueAt: now))
        try store.deleteOpportunity(id: deleted.id)
        let opportunitiesBefore = try store.opportunities()
        let activitiesBefore = try store.activityEvents()
        let historyBefore = try store.stageHistory(forOpportunityID: deleted.id)
        let attentionBefore = try store.needsAttention()

        XCTAssertEqual(try store.moveStage(opportunityID: deleted.id, to: .screening), .unavailable(opportunityID: deleted.id))
        try store.close()
        let reopened = try makeStore()

        XCTAssertEqual(try reopened.opportunities(), opportunitiesBefore)
        XCTAssertEqual(try reopened.activityEvents(), activitiesBefore)
        XCTAssertEqual(try reopened.stageHistory(forOpportunityID: deleted.id), historyBefore)
        XCTAssertEqual(try reopened.needsAttention(), attentionBefore)
    }

    func testStageMoveReconciliationBlockedCloseRetainsFullEncryptedReopenBaseline() throws {
        let store = try makeStore()
        let opportunity = try store.create(CreateOpportunity(
            title: "Blocked role",
            company: "Rekon Labs",
            nextAction: "Confirm review",
            dueAt: now,
            jobURL: "https://jobs.example.com/blocked"
        ))
        _ = try store.recordReconciliationResult(RecordReconciliationResult(
            opportunityID: opportunity.id,
            url: opportunity.jobURL,
            outcome: .needsManualReview,
            classification: .offlineUnchecked,
            reason: .offlineUnchecked,
            evidence: "Offline — check not run"
        ))
        let opportunitiesBefore = try store.opportunities()
        let activitiesBefore = try store.activityEvents()
        let historyBefore = try store.stageHistory(forOpportunityID: opportunity.id)
        let attentionBefore = try store.needsAttention()

        XCTAssertEqual(
            try store.moveStage(opportunityID: opportunity.id, to: .closed),
            .reconciliationBlocked(opportunityID: opportunity.id, target: .closed)
        )
        try store.close()
        let reopened = try makeStore()

        XCTAssertEqual(try reopened.opportunities(), opportunitiesBefore)
        XCTAssertEqual(try reopened.activityEvents(), activitiesBefore)
        XCTAssertEqual(try reopened.stageHistory(forOpportunityID: opportunity.id), historyBefore)
        XCTAssertEqual(try reopened.needsAttention(), attentionBefore)
    }

    func testStageMoveSameStageIncludingClosedIsNoOpWithoutAuditOrHistory() throws {
        let store = try makeStore()
        let opportunity = try store.create(CreateOpportunity(title: "Product Manager", company: "Rekon Labs", stage: .closed))
        let activitiesBefore = try store.activityEvents()
        let historyBefore = try store.stageHistory(forOpportunityID: opportunity.id)

        let outcome = try store.moveStage(opportunityID: opportunity.id, to: .closed)

        XCTAssertEqual(outcome, .noOp(opportunityID: opportunity.id, stage: .closed))
        XCTAssertEqual(try store.activityEvents(), activitiesBefore)
        XCTAssertEqual(try store.stageHistory(forOpportunityID: opportunity.id), historyBefore)
    }

    func testStageMoveUnavailableAndBlockedCloseDoNotWriteAuditOrHistory() throws {
        let store = try makeStore()
        let opportunity = try store.create(CreateOpportunity(
            title: "Product Manager",
            company: "Rekon Labs",
            jobURL: "https://jobs.example.com/product-manager"
        ))
        _ = try store.recordReconciliationResult(RecordReconciliationResult(
            opportunityID: opportunity.id,
            url: opportunity.jobURL,
            outcome: .needsManualReview,
            classification: .offlineUnchecked,
            reason: .offlineUnchecked,
            evidence: "Offline — check not run"
        ))
        let opportunitiesBefore = try store.opportunities()
        let activitiesBefore = try store.activityEvents()
        let historyBefore = try store.stageHistory(forOpportunityID: opportunity.id)
        let tasksBefore = try store.needsAttention()

        XCTAssertEqual(
            try store.moveStage(opportunityID: opportunity.id, to: .closed),
            .reconciliationBlocked(opportunityID: opportunity.id, target: .closed)
        )
        XCTAssertEqual(
            try store.moveStage(opportunityID: "missing", to: .screening),
            .unavailable(opportunityID: "missing")
        )
        XCTAssertEqual(try store.opportunities(), opportunitiesBefore)
        XCTAssertEqual(try store.activityEvents(), activitiesBefore)
        XCTAssertEqual(try store.stageHistory(forOpportunityID: opportunity.id), historyBefore)
        XCTAssertEqual(try store.needsAttention(), tasksBefore)
    }

    func testStageMoveWriteFailureRollsBackStageAuditHistoryAndProjectionAfterReopen() throws {
        let normal = try makeStore()
        let opportunity = try normal.create(CreateOpportunity(title: "Product Manager", company: "Rekon Labs", nextAction: "Follow up", dueAt: now))
        let opportunitiesBefore = try normal.opportunities()
        let eventsBefore = try normal.activityEvents()
        let historyBefore = try normal.stageHistory(forOpportunityID: opportunity.id)
        let tasksBefore = try normal.needsAttention()
        try normal.close()
        let failing = try makeStore(stageMoveFailurePoint: .beforeWrite)

        XCTAssertThrowsError(try failing.moveStage(opportunityID: opportunity.id, to: .screening))
        try failing.close()
        let reopened = try makeStore()
        XCTAssertEqual(try reopened.opportunities(), opportunitiesBefore)
        XCTAssertEqual(try reopened.activityEvents(), eventsBefore)
        XCTAssertEqual(try reopened.stageHistory(forOpportunityID: opportunity.id), historyBefore)
        XCTAssertEqual(try reopened.needsAttention(), tasksBefore)
    }

    func testStageMoveProjectionFailureRollsBackStageAuditHistoryAndProjectionAfterReopen() throws {
        let normal = try makeStore()
        let opportunity = try normal.create(CreateOpportunity(title: "Product Manager", company: "Rekon Labs", nextAction: "Follow up", dueAt: now))
        let opportunitiesBefore = try normal.opportunities()
        let eventsBefore = try normal.activityEvents()
        let historyBefore = try normal.stageHistory(forOpportunityID: opportunity.id)
        let tasksBefore = try normal.needsAttention()
        try normal.close()
        let failing = try makeStore(stageMoveFailurePoint: .beforeProjectionRead)

        XCTAssertThrowsError(try failing.moveStage(opportunityID: opportunity.id, to: .screening))
        try failing.close()
        let reopened = try makeStore()
        XCTAssertEqual(try reopened.opportunities(), opportunitiesBefore)
        XCTAssertEqual(try reopened.activityEvents(), eventsBefore)
        XCTAssertEqual(try reopened.stageHistory(forOpportunityID: opportunity.id), historyBefore)
        XCTAssertEqual(try reopened.needsAttention(), tasksBefore)
    }

    func testStageHistoryRecordsCreationAndRealStageChanges() throws {
        let store = try makeStore()
        let opportunity = try store.create(CreateOpportunity(title: "Product Manager", company: "Rekon Labs"))

        try store.changeStage(opportunityID: opportunity.id, to: .screening)
        try store.changeStage(opportunityID: opportunity.id, to: .screening)

        XCTAssertEqual(try store.stageHistory(forOpportunityID: opportunity.id).map { "\($0.fromStage?.rawValue ?? "Created") → \($0.toStage.rawValue)" }, ["Created → Saved", "Saved → Screening"])
        XCTAssertEqual(try store.activityEvents().map(\.kind), ["opportunity_created", "opportunity_stage_changed"])
    }

    func testUpdateOpportunityReplacesItsNextActionAndWritesOneActivityEvent() throws {
        let store = try makeStore()
        let opportunity = try store.create(CreateOpportunity(
            title: "Product Manager", company: "Rekon Labs", nextAction: "Send follow-up", dueAt: now
        ))
        let rescheduled = now.addingTimeInterval(86_400)

        try store.updateOpportunity(
            id: opportunity.id,
            title: "Senior Product Manager",
            company: "Rekon Labs",
            stage: .screening,
            nextAction: "Prepare recruiter call",
            dueAt: rescheduled,
            stageChangedAt: now
        )

        XCTAssertEqual(try store.opportunities(), [
            Opportunity(
                id: opportunity.id,
                title: "Senior Product Manager",
                company: "Rekon Labs",
                createdAt: now,
                stage: .screening,
                nextAction: "Prepare recruiter call",
                dueAt: rescheduled,
                stageChangedAt: now,
                actionType: .other,
                actionCustomText: "Prepare recruiter call"
            )
        ])
        XCTAssertEqual(try store.needsAttention().map(\.title), ["Prepare recruiter call"])
        XCTAssertEqual(try store.needsAttention().first?.dueAt, rescheduled)
        XCTAssertEqual(try store.activityEvents().map(\.kind), ["opportunity_created", "opportunity_stage_changed"])
    }

    func testClosedOpportunityIsRemovedFromQueueAndCannotBeActioned() throws {
        let store = try makeStore()
        let opportunity = try store.create(CreateOpportunity(title: "Product Manager", company: "Rekon Labs", nextAction: "Follow up", dueAt: now))

        try store.changeStage(opportunityID: opportunity.id, to: .closed)

        XCTAssertEqual(try store.needsAttention(), [])
        XCTAssertThrowsError(try store.completeTask(id: "fixture-id-2"))
    }

    func testContactCanLinkToMultipleOpportunities() throws {
        let store = try makeStore()
        let first = try store.create(CreateOpportunity(title: "Product Manager", company: "Rekon Labs"))
        let second = try store.create(CreateOpportunity(title: "Director", company: "Rekon Labs"))
        let contact = try store.createContact(CreateContact(name: "Alex Morgan", employer: "Rekon Labs"))

        try store.linkContact(contactID: contact.id, toOpportunityID: first.id)
        try store.linkContact(contactID: contact.id, toOpportunityID: second.id)

        XCTAssertEqual(try store.contacts(forOpportunityID: first.id), [contact])
        XCTAssertEqual(try store.contacts(forOpportunityID: second.id), [contact])
        XCTAssertEqual(try store.activityEvents().map(\.kind), ["opportunity_created", "opportunity_created", "contact_created", "contact_linked", "contact_linked"])
        XCTAssertNil(try store.activityEvents().first { $0.kind == "contact_created" }?.opportunityID)
    }

    func testContactFoundationPersistsDetailsAndFindsSameEmployerDiscovery() throws {
        let store = try makeStore()
        let first = try store.create(CreateOpportunity(title: "Product Manager", company: "Rekon Labs"))
        let second = try store.create(CreateOpportunity(title: "Director", company: "Rekon Labs"))

        let contact = try store.createContact(CreateContact(
            name: "Alex Morgan",
            employer: "Rekon Labs",
            title: "Recruiter",
            workEmail: "alex@example.com",
            linkedInURL: "https://example.com/alex",
            relationshipContext: "Met at conference",
            notes: "Prefers email."
        ))
        try store.linkContact(contactID: contact.id, toOpportunityID: first.id)

        XCTAssertEqual(try store.contacts(), [contact])
        XCTAssertEqual(try store.contacts(forOpportunityID: first.id), [contact])
        XCTAssertEqual(try store.sameEmployerContacts(forOpportunityID: second.id), [contact])
        XCTAssertEqual(try store.activityEvents().last?.contactID, contact.id)
    }

    func testContactChannelsPersistAcrossCreateUpdateAndReopenAndRejectMalformedInputWithoutWriting() throws {
        // This catches a channel that is silently omitted from the SQL mapping,
        // a reopen that decodes the wrong column, or rejected input that writes.
        let store = try makeStore()
        let created = try store.createContact(CreateContact(
            name: "Alex Morgan", workEmail: "alex.work@example.test", personalEmail: "alex.personal@example.test",
            mobilePhone: "+1 212 555 0101", officePhone: "+1 212 555 0102",
            linkedInURL: "https://linkedin.example.test/in/alex", instagramURL: "https://instagram.example.test/alex",
            facebookURL: "https://facebook.example.test/alex"
        ))
        XCTAssertEqual(try store.contacts(), [created])

        try store.updateContact(id: created.id, command: CreateContact(
            name: "Alex Morgan", workEmail: "updated.work@example.test", personalEmail: "updated.personal@example.test",
            mobilePhone: "+1 212 555 0191", officePhone: "+1 212 555 0192",
            linkedInURL: "https://linkedin.example.test/in/updated", instagramURL: "https://instagram.example.test/updated",
            facebookURL: "https://facebook.example.test/updated"
        ))
        try store.close()
        let reopened = try WorkspaceStore(database: EncryptedDatabase.open(url: databaseURL, key: key, createIfMissing: false), now: now, actorID: "local-user", correlationID: "fixture-correlation")
        let updated = try XCTUnwrap(reopened.contacts().first)
        XCTAssertEqual([updated.workEmail, updated.personalEmail, updated.mobilePhone, updated.officePhone, updated.linkedInURL, updated.instagramURL, updated.facebookURL], ["updated.work@example.test", "updated.personal@example.test", "+1 212 555 0191", "+1 212 555 0192", "https://linkedin.example.test/in/updated", "https://instagram.example.test/updated", "https://facebook.example.test/updated"])

        let contactsBeforeRejections = try reopened.contacts()
        let activitiesBeforeRejections = try reopened.activityEvents()
        XCTAssertThrowsError(try reopened.createContact(CreateContact(name: "Bad work", workEmail: "alex@")))
        XCTAssertThrowsError(try reopened.createContact(CreateContact(name: "Bad personal", personalEmail: "alex@")))
        for socialURL in ["linkedin.example.test/alex", "https:///alex"] {
            XCTAssertThrowsError(try reopened.createContact(CreateContact(name: "Bad LinkedIn", linkedInURL: socialURL)))
            XCTAssertThrowsError(try reopened.createContact(CreateContact(name: "Bad Instagram", instagramURL: socialURL)))
            XCTAssertThrowsError(try reopened.createContact(CreateContact(name: "Bad Facebook", facebookURL: socialURL)))
        }
        XCTAssertEqual(try reopened.contacts(), contactsBeforeRejections)
        XCTAssertEqual(try reopened.activityEvents(), activitiesBeforeRejections)
    }

    func testContactProfileURLsRejectPrivateAndLocalHostsWithoutWriting() throws {
        // This catches a profile URL validator that treats a dotted private IP
        // address or local DNS alias as a public URL and persists it.
        let store = try makeStore()
        let publicHTTP = try store.createContact(CreateContact(
            name: "Public HTTP",
            linkedInURL: "http://profiles.example.test/alex"
        ))
        let publicHTTPS = try store.createContact(CreateContact(
            name: "Public HTTPS",
            linkedInURL: "https://profiles.example.test/alex"
        ))
        let publicIPAddress = try store.createContact(CreateContact(
            name: "Public IP address",
            linkedInURL: "http://8.8.8.8/profile"
        ))
        XCTAssertEqual(
            try store.contacts().map(\.linkedInURL),
            [publicHTTP.linkedInURL, publicHTTPS.linkedInURL, publicIPAddress.linkedInURL]
        )

        let contactsBeforeRejections = try store.contacts()
        let activitiesBeforeRejections = try store.activityEvents()
        let unsafeURLs = [
            "https://127.0.0.1/profile",
            "https://127.1/profile",
            "https://10.0.0.1/profile",
            "https://172.16.0.1/profile",
            "https://192.168.0.1/profile",
            "https://169.254.169.254/latest/meta-data",
            "https://localhost.localdomain/profile",
            "https://printer.local/profile",
            "https://[::1]/profile",
            "https://[fe80::1]/profile",
            "https://[fd00::1]/profile"
        ]

        for url in unsafeURLs {
            XCTAssertThrowsError(
                try store.createContact(CreateContact(name: "Rejected profile", linkedInURL: url)),
                "accepted unsafe profile URL: \(url)"
            )
            XCTAssertEqual(try store.contacts(), contactsBeforeRejections, "contact state changed for \(url)")
            XCTAssertEqual(try store.activityEvents(), activitiesBeforeRejections, "activity evidence changed for \(url)")
        }
    }

    func testContactEmailHandlerTargetsRejectUnsafeWorkAndPersonalValuesWithoutWriting() throws {
        // This catches either contact-email field accepting URL-handler syntax
        // on create or update and mutating the contact or its activity evidence.
        let store = try makeStore()
        let original = try store.createContact(CreateContact(
            name: "Alex Morgan",
            workEmail: "alex.work@example.test",
            personalEmail: "alex.personal@example.test"
        ))
        let contactsBeforeRejections = try store.contacts()
        let activitiesBeforeRejections = try store.activityEvents()
        let unsafeAddresses = [
            "question": "victim@example.test?cc=attacker.example.test",
            "fragment": "victim#tag@example.test",
            "slash": "victim/name@example.test",
            "ampersand": "victim&other@example.test",
            "additional-at": "victim@example.test@attacker.test"
        ]

        for (label, address) in unsafeAddresses {
            XCTAssertThrowsError(
                try store.createContact(CreateContact(name: "Rejected work \(label)", workEmail: address)),
                "work email accepted \(label)"
            )
            XCTAssertThrowsError(
                try store.createContact(CreateContact(name: "Rejected personal \(label)", personalEmail: address)),
                "personal email accepted \(label)"
            )
            XCTAssertThrowsError(
                try store.updateContact(id: original.id, command: CreateContact(name: "Changed work", workEmail: address)),
                "work email update accepted \(label)"
            )
            XCTAssertThrowsError(
                try store.updateContact(id: original.id, command: CreateContact(name: "Changed personal", personalEmail: address)),
                "personal email update accepted \(label)"
            )
            XCTAssertEqual(try store.contacts(), contactsBeforeRejections, "contact state changed for \(label)")
            XCTAssertEqual(try store.activityEvents(), activitiesBeforeRejections, "activity evidence changed for \(label)")
        }
    }

    func testContactRetainsMultilineRelationshipContextAndNotes() throws {
        let store = try makeStore()
        let relationshipContext = "Met at an industry event.\nAsked for an introduction to the hiring manager."
        let notes = "Prefers email.\nFollow up after the team planning meeting."

        let contact = try store.createContact(CreateContact(
            name: "Alex Morgan",
            employer: "Rekon Labs",
            relationshipContext: relationshipContext,
            notes: notes
        ))

        XCTAssertEqual(try store.contacts(), [contact])
        XCTAssertEqual(try store.contacts().first?.relationshipContext, relationshipContext)
        XCTAssertEqual(try store.contacts().first?.notes, notes)
    }

    func testEmployerOpportunitiesUseNormalizedExactMatchWithoutImplicitLinks() throws {
        let store = try makeStore()
        let matching = try store.create(CreateOpportunity(title: "Product Manager", company: "Rekon Labs"))
        let normalizedMatch = try store.create(CreateOpportunity(title: "Director", company: "rekon labs"))
        _ = try store.create(CreateOpportunity(title: "Recruiter", company: "Rekon Labs International"))
        let contact = try store.createContact(CreateContact(name: "Alex Morgan", employer: " REKON LABS "))

        XCTAssertEqual(Set(try store.opportunities(forEmployer: contact.employer).map(\.id)), Set([matching.id, normalizedMatch.id]))
        XCTAssertEqual(try store.opportunities(forContactID: contact.id), [])

        try store.linkContact(contactID: contact.id, toOpportunityID: matching.id)

        XCTAssertEqual(try store.opportunities(forContactID: contact.id).map(\.id), [matching.id])
    }

    func testOpportunitiesForContactDecodeStructuredOpportunityFields() throws {
        let store = try makeStore()
        let opportunity = try store.create(CreateOpportunity(
            title: "Product Manager", company: "Rekon Labs",
            compensationMinimum: 125_000, compensationMaximum: 150_000, compensationPayPeriod: .year,
            actionType: .other, actionCustomText: "Ask Morgan for a referral"
        ))
        let contact = try store.createContact(CreateContact(name: "Alex Morgan", employer: "Rekon Labs"))
        try store.linkContact(contactID: contact.id, toOpportunityID: opportunity.id)

        XCTAssertEqual(try store.opportunities(forContactID: contact.id), [opportunity])
    }

    func testContactUpdateUnlinkAndDeletionAreSafeAndRedacted() throws {
        let store = try makeStore()
        let first = try store.create(CreateOpportunity(title: "Product Manager", company: "Rekon Labs"))
        let second = try store.create(CreateOpportunity(title: "Director", company: "Rekon Labs"))
        let contact = try store.createContact(CreateContact(name: "Alex Morgan", employer: "Rekon Labs", workEmail: "alex@example.com"))

        try store.linkContact(contactID: contact.id, toOpportunityID: first.id)
        try store.linkContact(contactID: contact.id, toOpportunityID: second.id)
        try store.unlinkContact(contactID: contact.id, fromOpportunityID: first.id)
        try store.unlinkContact(contactID: contact.id, fromOpportunityID: first.id)
        let updated = try store.updateContact(id: contact.id, command: CreateContact(name: "Alex Morgan", employer: "New Co", title: "Director"))
        try store.deleteContact(id: contact.id)

        XCTAssertEqual(updated.title, "Director")
        XCTAssertEqual(try store.contacts(forOpportunityID: first.id), [])
        XCTAssertEqual(try store.contacts(forOpportunityID: second.id), [])
        XCTAssertEqual(try store.contacts(), [])
        XCTAssertEqual(try store.sameEmployerContacts(forOpportunityID: second.id), [])
        XCTAssertTrue(try store.activityEvents().filter { $0.kind.hasPrefix("contact_") }.allSatisfy { $0.contactID == contact.id })
        XCTAssertFalse(try store.tombstones().contains { $0.displayValue.contains("Alex") || $0.displayValue.contains("New Co") })
        XCTAssertThrowsError(try store.linkContact(contactID: contact.id, toOpportunityID: second.id))
        XCTAssertEqual(try store.activityEvents().last?.kind, "contact_deleted")
    }

    func testDeletingContactKeepsItsRelationshipRowsForRecovery() throws {
        let database = try EncryptedDatabase.open(url: databaseURL, key: key)
        var identifier = 0
        let store = try WorkspaceStore(
            database: database,
            now: now,
            nextIdentifier: {
                defer { identifier += 1 }
                return "fixture-id-\(identifier)"
            },
            actorID: "local-user",
            correlationID: "fixture-correlation"
        )
        let opportunity = try store.create(CreateOpportunity(title: "Product Manager", company: "Rekon Labs"))
        let contact = try store.createContact(CreateContact(name: "Alex Morgan", employer: "Rekon Labs"))
        try store.linkContact(contactID: contact.id, toOpportunityID: opportunity.id)

        try store.deleteContact(id: contact.id)

        XCTAssertEqual(try database.rows("SELECT contact_id, opportunity_id FROM contact_opportunities"), [[.text(contact.id), .text(opportunity.id)]])
    }

    func testCSVPreviewMapsTitleAndCompanyAndRejectsIncompleteRows() throws {
        let preview = try CSVOpportunityImporter.preview(data: Data("title,company\nProduct Manager,Rekon Labs\n,Missing Co\n".utf8))

        XCTAssertEqual(preview.rows.filter(\.isValid).map(\.opportunity), [CreateOpportunity(title: "Product Manager", company: "Rekon Labs")])
        XCTAssertEqual(preview.invalidRowCount, 1)
    }

    func testCSVPreviewUsesOnlyTheCRLFHeaderRecordForMappingChoices() throws {
        let csv = "Tier,Company,Title,Location,Resume Variant,Employer Job Board URL,Verification\r\nTier 1,Altana,Senior Director,Boston / Remote,Platform/Cloud Director,https://example.com/jobs/1,Exact employer posting\r\n"

        let preview = try CSVOpportunityImporter.preview(data: Data(csv.utf8))

        XCTAssertEqual(preview.headers, ["Tier", "Company", "Title", "Location", "Resume Variant", "Employer Job Board URL", "Verification"])
        XCTAssertEqual(preview.rawRows.count, 1)
        XCTAssertEqual(preview.rawRows[0], ["Tier 1", "Altana", "Senior Director", "Boston / Remote", "Platform/Cloud Director", "https://example.com/jobs/1", "Exact employer posting"])
        XCTAssertEqual(preview.mapping[.title], 2)
        XCTAssertEqual(preview.mapping[.company], 1)
    }

    func testCSVPreviewSuggestsNonstandardHeadersAndValidatesDueDateCoupling() throws {
        let preview = try CSVOpportunityImporter.preview(data: Data("Role,Employer,Follow up,Due date\n\"Product, Platform\",Rekon Labs,Email recruiter,2026-08-01\nDirector,Rekon Labs,,2026-08-02\n".utf8))
        XCTAssertEqual(preview.mapping[.title], 0)
        XCTAssertEqual(preview.mapping[.company], 1)
        XCTAssertEqual(preview.rows.first?.opportunity?.title, "Product, Platform")
        XCTAssertEqual(preview.rows.last?.reasons, ["Due date requires a Next action."])
    }

    func testCSVDateValidationRejectsNonCanonicalAndImpossibleGregorianDates() throws {
        let preview = try CSVOpportunityImporter.preview(data: Data("title,company,applied date\nA,Rekon,2026-2-1\nB,Rekon,2026-02-30\n".utf8))
        XCTAssertEqual(preview.invalidRowCount, 2)
    }

    func testCSVImportRequiresDuplicateDecisionAndPersistsReport() throws {
        let store = try makeStore()
        _ = try store.create(CreateOpportunity(title: "Product Manager", company: "Rekon Labs"))
        let preview = try CSVOpportunityImporter.preview(data: Data("title,company\nProduct Manager,Rekon Labs\nDirector,Rekon Labs\n".utf8))
        var plan = try store.csvImportPlan(for: preview)

        XCTAssertTrue(plan[0].isDuplicate)
        XCTAssertThrowsError(try store.importCSV(plan, invalidCount: preview.invalidRowCount))
        plan[0].decision = .skip

        let report = try store.importCSV(plan, invalidCount: preview.invalidRowCount)

        XCTAssertEqual(report.importedCount, 1)
        XCTAssertEqual(report.skippedCount, 1)
        XCTAssertEqual(try store.importReports(), [report])
        XCTAssertEqual(try store.opportunities().map(\.title), ["Product Manager", "Director"])
        XCTAssertEqual(try store.activityEvents().suffix(3).map(\.kind), ["csv_import_row_2_skipped", "csv_import_row_3_created", "csv_import_batch_completed"])
    }

    func testCSVSelectedFieldUpdatePreservesUnselectedExistingFields() throws {
        let store = try makeStore()
        let existing = try store.create(CreateOpportunity(title: "Product Manager", company: "Rekon Labs", jobURL: "https://jobs.example.com/old", notes: "Keep this", compensation: "120k"))
        let preview = try CSVOpportunityImporter.preview(data: Data("title,company,compensation,notes\nProduct Manager,Rekon Labs,150k,Do not overwrite\n".utf8))
        var plan = try store.csvImportPlan(for: preview)
        plan[0].decision = .updateSelectedFields
        plan[0].selectedFields = [.compensation]
        let report = try store.importCSV(plan, invalidCount: preview.invalidRowCount, sourceBasename: "jobs.csv", mapping: preview.mapping)
        let updated = try XCTUnwrap(try store.opportunities().first(where: { $0.id == existing.id }))
        XCTAssertEqual(report.updatedCount, 1)
        XCTAssertEqual(updated.compensation, "150k")
        XCTAssertEqual(updated.jobURL, "https://jobs.example.com/old")
        XCTAssertEqual(updated.notes, "Keep this")
        let reportRow = try XCTUnwrap(try store.importReportRows(for: report.id).first)
        XCTAssertEqual(reportRow.outcome, "updated")
        XCTAssertTrue(reportRow.reason.contains("Selected fields: Compensation"))
        XCTAssertEqual(reportRow.title, "Product Manager")
        XCTAssertEqual(reportRow.company, "Rekon Labs")
    }

    func testCSVCandidateCannotBeSilentlyCreatedAndRejectsDateOnlySelection() throws {
        let store = try makeStore()
        _ = try store.create(CreateOpportunity(title: "Product Manager", company: "Rekon Labs"))
        let preview = try CSVOpportunityImporter.preview(data: Data("title,company,stage,stage date\nProduct Manager,Rekon Labs,Screening,2026-08-01\n".utf8))
        var plan = try store.csvImportPlan(for: preview)
        plan[0].decision = .create
        XCTAssertThrowsError(try store.importCSV(plan, invalidCount: 0))
        plan[0].decision = .updateSelectedFields
        plan[0].selectedFields = [.stageDate]
        XCTAssertThrowsError(try store.importCSV(plan, invalidCount: 0))
    }

    func testCSVBlankMappedFieldCannotClearExistingValueOrTaskDueDate() throws {
        let store = try makeStore()
        let existing = try store.create(CreateOpportunity(title: "Role", company: "Rekon", nextAction: "Follow up", dueAt: now, notes: "Keep"))
        let preview = try CSVOpportunityImporter.preview(data: Data("title,company,notes,next action,due date\nRole,Rekon,,,\n".utf8))
        var plan = try store.csvImportPlan(for: preview)
        plan[0].decision = .updateSelectedFields
        plan[0].selectedFields = [.notes, .nextAction]
        XCTAssertThrowsError(try store.importCSV(plan, invalidCount: 0))
        XCTAssertEqual(try store.opportunities().first(where: { $0.id == existing.id })?.notes, "Keep")
        XCTAssertEqual(try store.latestTask(forOpportunityID: existing.id)?.dueAt, now)
    }

    func testCSVUpdateCannotCloseAnOpportunityWithAnUnconfirmedReconciliationReview() throws {
        let store = try makeStore()
        let existing = try store.create(CreateOpportunity(title: "Product Manager", company: "Rekon Labs", stage: .applied, jobURL: "https://jobs.example.com/role"))
        _ = try store.recordReconciliationResult(RecordReconciliationResult(opportunityID: existing.id, url: existing.jobURL, outcome: .closedSuggested, classification: .confirmed, confidence: .high, evidence: "Role filled"))
        let preview = try CSVOpportunityImporter.preview(data: Data("title,company,stage,stage date\nProduct Manager,Rekon Labs,Closed,2026-08-01\n".utf8))
        var plan = try store.csvImportPlan(for: preview)
        plan[0].decision = .updateSelectedFields
        plan[0].selectedFields = [.stage, .stageDate]

        XCTAssertThrowsError(try store.importCSV(plan, invalidCount: 0))
        XCTAssertEqual(try store.opportunities().first(where: { $0.id == existing.id })?.stage, .applied)
    }

    func testCSVUpdateDoesNotRenameTheDedicatedReconciliationReviewTask() throws {
        let store = try makeStore()
        let existing = try store.create(CreateOpportunity(title: "Product Manager", company: "Rekon Labs", jobURL: "https://jobs.example.com/role"))
        let result = try store.recordReconciliationResult(RecordReconciliationResult(opportunityID: existing.id, url: existing.jobURL, outcome: .needsManualReview, classification: .offlineUnchecked, reason: .offlineUnchecked, evidence: "Offline; check not run"))
        let reviewTaskID = try XCTUnwrap(result.reviewTaskID)
        let preview = try CSVOpportunityImporter.preview(data: Data("title,company,next action\nProduct Manager,Rekon Labs,Send follow-up\n".utf8))
        var plan = try store.csvImportPlan(for: preview)
        plan[0].decision = .updateSelectedFields
        plan[0].selectedFields = [.nextAction]

        _ = try store.importCSV(plan, invalidCount: 0)

        XCTAssertEqual(try store.reconciliationReviewTask(forOpportunityID: existing.id)?.id, reviewTaskID)
        XCTAssertEqual(try store.reconciliationReviewTask(forOpportunityID: existing.id)?.title, "Review reconciliation evidence")
        XCTAssertEqual(try store.latestTask(forOpportunityID: existing.id)?.title, "Send follow-up")
    }

    func testCSVURLCandidateUsesTrimmedLowercaseURLBeforeTitleCompanyAndIDTie() throws {
        let store = try makeStore()
        _ = try store.create(CreateOpportunity(title: "Title Match", company: "Rekon", jobURL: "https://other.example"))
        _ = try store.create(CreateOpportunity(title: "Other", company: "Co", jobURL: "https://jobs.example/role"))
        let preview = try CSVOpportunityImporter.preview(data: Data("title,company,url\nTitle Match,Rekon, HTTPS://JOBS.EXAMPLE/ROLE \n".utf8))
        let plan = try store.csvImportPlan(for: preview)
        let candidate = try XCTUnwrap(plan.first)
        XCTAssertEqual(candidate.duplicateRationale, "Exact job URL")
        XCTAssertEqual(candidate.candidateTitle, "Other")
    }

    func testCSVDefaultResponseDateIsOptionalForCreateButRequiredForResetUpdate() throws {
        let preview = try CSVOpportunityImporter.preview(data: Data("title,company,response\nNew,Rekon,No response recorded\n".utf8))
        XCTAssertTrue(preview.rows[0].isValid)
        let store = try makeStore()
        let existing = try store.create(CreateOpportunity(title: "Existing", company: "Rekon", responseState: .responseReceived, responseEffectiveDate: now))
        let update = try CSVOpportunityImporter.preview(data: Data("title,company,response\nExisting,Rekon,No response recorded\n".utf8))
        var plan = try store.csvImportPlan(for: update)
        XCTAssertEqual(plan[0].candidateValues[.responseDate], now.ISO8601Format().prefix(10).description)
        plan[0].decision = .updateSelectedFields
        plan[0].selectedFields = [.responseState]
        XCTAssertThrowsError(try store.importCSV(plan, invalidCount: 0))
        XCTAssertEqual(try store.opportunities().first(where: { $0.id == existing.id })?.responseState, .responseReceived)
    }

    func testContactInteractionIsStoredWithAnExplicitlyLinkedOpportunityAndActivityEvent() throws {
        let store = try makeStore()
        let opportunity = try store.create(CreateOpportunity(title: "Product Manager", company: "Rekon Labs"))
        let contact = try store.createContact(CreateContact(name: "Alex Morgan", employer: "Rekon Labs"))
        try store.linkContact(contactID: contact.id, toOpportunityID: opportunity.id)
        let nextTouch = now.addingTimeInterval(86_400)

        let interaction = try store.recordContactInteraction(CreateContactInteraction(
            contactID: contact.id,
            opportunityID: opportunity.id,
            kind: .call,
            summary: "Spoke with hiring manager.",
            occurredAt: now,
            nextTouchAt: nextTouch
        ))

        XCTAssertEqual(try store.contactInteractions(forContactID: contact.id), [interaction])
        XCTAssertEqual(try store.lastTouch(forContactID: contact.id), now)
        XCTAssertEqual(try store.nextTouch(forContactID: contact.id), nextTouch)
        XCTAssertEqual(try store.activityEvents().last?.kind, "interaction_recorded")
        XCTAssertEqual(try store.activityEvents().last?.contactID, contact.id)
        XCTAssertEqual(try store.activityEvents().last?.opportunityID, opportunity.id)
    }

    func testContactInteractionRejectsAnOpportunityThatIsNotExplicitlyLinked() throws {
        let store = try makeStore()
        let opportunity = try store.create(CreateOpportunity(title: "Product Manager", company: "Rekon Labs"))
        let contact = try store.createContact(CreateContact(name: "Alex Morgan"))
        let activityCount = try store.activityEvents().count

        XCTAssertThrowsError(try store.recordContactInteraction(CreateContactInteraction(
            contactID: contact.id,
            opportunityID: opportunity.id,
            kind: .meeting,
            summary: "Met at an event.",
            occurredAt: now
        )))

        XCTAssertEqual(try store.contactInteractions(forContactID: contact.id), [])
        XCTAssertEqual(try store.opportunityInteractions(forOpportunityID: opportunity.id), [])
        XCTAssertEqual(try store.activityEvents().count, activityCount)
    }

    func testContactInteractionRejectsADeletedOpportunityWithoutWritingDataOrActivity() throws {
        let store = try makeStore()
        let opportunity = try store.create(CreateOpportunity(title: "Product Manager", company: "Rekon Labs"))
        let contact = try store.createContact(CreateContact(name: "Alex Morgan"))
        try store.linkContact(contactID: contact.id, toOpportunityID: opportunity.id)
        try store.deleteOpportunity(id: opportunity.id)
        let activityCount = try store.activityEvents().count

        XCTAssertThrowsError(try store.recordContactInteraction(CreateContactInteraction(
            contactID: contact.id,
            opportunityID: opportunity.id,
            kind: .email,
            summary: "Followed up after closure.",
            occurredAt: now
        )))

        XCTAssertEqual(try store.contactInteractions(forContactID: contact.id), [])
        XCTAssertEqual(try store.activityEvents().count, activityCount)
    }

    func testContactInteractionAndDerivedTouchDatesPersistAfterRelaunch() throws {
        let database = try EncryptedDatabase.open(url: databaseURL, key: key)
        let firstStore = try WorkspaceStore(database: database, now: now, actorID: "local-user", correlationID: "fixture-correlation")
        let contact = try firstStore.createContact(CreateContact(name: "Alex Morgan"))
        let nextTouch = now.addingTimeInterval(86_400)
        _ = try firstStore.recordContactInteraction(CreateContactInteraction(contactID: contact.id, kind: .meeting, summary: "Intro meeting", occurredAt: now, nextTouchAt: nextTouch))
        try firstStore.close()

        let reopenedDatabase = try EncryptedDatabase.open(url: databaseURL, key: key)
        let reopenedStore = try WorkspaceStore(database: reopenedDatabase, actorID: "local-user", correlationID: "fixture-correlation")

        XCTAssertEqual(try reopenedStore.contactInteractions(forContactID: contact.id).map(\.summary), ["Intro meeting"])
        XCTAssertEqual(try reopenedStore.lastTouch(forContactID: contact.id), now)
        XCTAssertEqual(try reopenedStore.nextTouch(forContactID: contact.id), nextTouch)
    }

    func testDeletingContactHidesItsInteractionWithoutDiscardingTheRetainedRow() throws {
        let database = try EncryptedDatabase.open(url: databaseURL, key: key)
        var identifier = 0
        let store = try WorkspaceStore(
            database: database,
            now: now,
            nextIdentifier: { defer { identifier += 1 }; return "fixture-id-\(identifier)" },
            actorID: "local-user",
            correlationID: "fixture-correlation"
        )
        let contact = try store.createContact(CreateContact(name: "Alex Morgan"))
        _ = try store.recordContactInteraction(CreateContactInteraction(contactID: contact.id, kind: .note, summary: "Private note", occurredAt: now))

        try store.deleteContact(id: contact.id)

        XCTAssertEqual(try store.contactInteractions(forContactID: contact.id), [])
        XCTAssertEqual(try database.rows("SELECT contact_id, summary FROM interactions"), [[.text(contact.id), .text("Private note")]])
    }

    func testOpportunityRelationshipHistoryRetainsInteractionAfterCurrentLinkIsRemoved() throws {
        let store = try makeStore()
        let opportunity = try store.create(CreateOpportunity(title: "Product Manager", company: "Rekon Labs"))
        let contact = try store.createContact(CreateContact(name: "Alex Morgan"))
        try store.linkContact(contactID: contact.id, toOpportunityID: opportunity.id)
        _ = try store.recordContactInteraction(CreateContactInteraction(contactID: contact.id, opportunityID: opportunity.id, kind: .call, summary: "Recruiter screen", occurredAt: now))

        try store.unlinkContact(contactID: contact.id, fromOpportunityID: opportunity.id)

        let history = try store.opportunityInteractions(forOpportunityID: opportunity.id)
        XCTAssertEqual(history.map(\.contactID), [contact.id])
        XCTAssertEqual(history.map(\.contactName), [contact.name])
        XCTAssertEqual(history.map(\.kind), [.call])
        XCTAssertEqual(history.map(\.summary), ["Recruiter screen"])
        XCTAssertEqual(try store.contacts(forOpportunityID: opportunity.id), [])
    }

    func testOpportunityRelationshipHistoryKeepsLegacyNoteReadableWithoutInventingAContact() throws {
        let database = try EncryptedDatabase.open(url: databaseURL, key: key)
        let store = try WorkspaceStore(database: database, now: now, actorID: "local-user", correlationID: "fixture-correlation")
        let opportunity = try store.create(CreateOpportunity(title: "Product Manager", company: "Rekon Labs"))
        try database.execute("INSERT INTO interactions (id, contact_id, opportunity_id, kind, summary, occurred_at, next_touch_at) VALUES ('legacy-note', NULL, ?, 'Note', 'Prior note', ?, NULL)", values: [.text(opportunity.id), .real(now.timeIntervalSince1970)])

        let history = try store.opportunityInteractions(forOpportunityID: opportunity.id)
        XCTAssertEqual(history.map(\.contactID), [nil])
        XCTAssertEqual(history.map(\.contactName), [nil])
        XCTAssertEqual(history.map(\.kind), [.note])
        XCTAssertEqual(history.map(\.summary), ["Prior note"])
    }

    func testReconciliationRejectsInvalidURLAndTupleWithoutWriting() throws {
        let store = try makeStore()
        let opportunity = try store.create(CreateOpportunity(title: "Product Manager", company: "Rekon Labs", jobURL: "https://jobs.example.com/123"))
        let before = try store.activityEvents().count

        XCTAssertThrowsError(try store.recordReconciliationResult(RecordReconciliationResult(opportunityID: opportunity.id, url: "http://127.0.0.1/role", outcome: .needsManualReview, classification: .offlineUnchecked, reason: .offlineUnchecked, evidence: "Not run")))
        XCTAssertThrowsError(try store.recordReconciliationResult(RecordReconciliationResult(opportunityID: opportunity.id, url: opportunity.jobURL, outcome: .stillOpen, classification: .ambiguous, confidence: .high, evidence: "Visible")))

        XCTAssertEqual(try store.reconciliationResults(forOpportunityID: opportunity.id), [])
        XCTAssertEqual(try store.activityEvents().count, before)
    }

    func testReconciliationRejectsRestrictedBracketedIPv6HostsWithoutWriting() throws {
        let store = try makeStore()
        let opportunity = try store.create(CreateOpportunity(title: "Product Manager", company: "Rekon Labs", jobURL: "https://jobs.example.com/123"))
        let restrictedURLs = ["http://[::1]/role", "http://[::ffff:127.0.0.1]/role", "http://[fe80::1]/role", "http://[fc00::1]/role", "http://[fd12::1]/role"]

        for url in restrictedURLs {
            XCTAssertThrowsError(try store.recordReconciliationResult(RecordReconciliationResult(opportunityID: opportunity.id, url: url, outcome: .needsManualReview, classification: .offlineUnchecked, reason: .offlineUnchecked, evidence: "Not run")), url)
        }

        XCTAssertEqual(try store.reconciliationResults(forOpportunityID: opportunity.id), [])
    }

    func testManualReviewReusesOneDedicatedReviewTaskAndKeepsOrdinaryTask() throws {
        let store = try makeStore()
        let opportunity = try store.create(CreateOpportunity(title: "Product Manager", company: "Rekon Labs", nextAction: "Send notes", dueAt: now, jobURL: "https://jobs.example.com/123"))
        let ordinaryTask = try XCTUnwrap(store.latestTask(forOpportunityID: opportunity.id))

        let first = try store.recordReconciliationResult(RecordReconciliationResult(opportunityID: opportunity.id, url: opportunity.jobURL, outcome: .needsManualReview, classification: .offlineUnchecked, reason: .offlineUnchecked, evidence: "Offline; check not run"))
        let second = try store.recordReconciliationResult(RecordReconciliationResult(opportunityID: opportunity.id, url: opportunity.jobURL, outcome: .needsManualReview, classification: .ambiguous, reason: .accessBlocked, confidence: .low, evidence: "Blocked page"))

        XCTAssertNotEqual(first.reviewTaskID, ordinaryTask.id)
        XCTAssertEqual(first.reviewTaskID, second.reviewTaskID)
        XCTAssertEqual(try store.taskReminder(id: ordinaryTask.id)?.isComplete, false)
        XCTAssertEqual(try store.reconciliationReviewTask(forOpportunityID: opportunity.id)?.id, first.reviewTaskID)
    }

    func testReconciliationReviewTaskCannotBeCompletedOrDeletedByOrdinaryTaskWorkflow() throws {
        let store = try makeStore()
        let opportunity = try store.create(CreateOpportunity(title: "Product Manager", company: "Rekon Labs", jobURL: "https://jobs.example.com/123"))
        let result = try store.recordReconciliationResult(RecordReconciliationResult(opportunityID: opportunity.id, url: opportunity.jobURL, outcome: .needsManualReview, classification: .offlineUnchecked, reason: .offlineUnchecked, evidence: "Offline; check not run"))
        let reviewTaskID = try XCTUnwrap(result.reviewTaskID)

        XCTAssertThrowsError(try store.completeTask(id: reviewTaskID))
        try store.updateOpportunity(id: opportunity.id, title: opportunity.title, company: opportunity.company, stage: opportunity.stage, nextAction: "", dueAt: nil)

        XCTAssertEqual(try store.reconciliationReviewTask(forOpportunityID: opportunity.id)?.id, reviewTaskID)
        XCTAssertEqual(try store.taskReminder(id: reviewTaskID)?.isComplete, false)
    }

    func testFreshReconciliationReplacesACompletedLegacyReviewTask() throws {
        let database = try EncryptedDatabase.open(url: databaseURL, key: key)
        let store = try WorkspaceStore(database: database, now: now, actorID: "local-user", correlationID: "fixture-correlation")
        let opportunity = try store.create(CreateOpportunity(title: "Product Manager", company: "Rekon Labs", jobURL: "https://jobs.example.com/123"))
        let first = try store.recordReconciliationResult(RecordReconciliationResult(opportunityID: opportunity.id, url: opportunity.jobURL, outcome: .needsManualReview, classification: .offlineUnchecked, reason: .offlineUnchecked, evidence: "Offline; check not run"))
        try database.execute("UPDATE task_reminders SET is_complete = 1 WHERE id = ?", values: [.text(try XCTUnwrap(first.reviewTaskID))])

        let second = try store.recordReconciliationResult(RecordReconciliationResult(opportunityID: opportunity.id, url: opportunity.jobURL, outcome: .needsManualReview, classification: .offlineUnchecked, reason: .offlineUnchecked, evidence: "Still offline"))

        XCTAssertNotEqual(second.reviewTaskID, first.reviewTaskID)
        XCTAssertEqual(try store.reconciliationReviewTask(forOpportunityID: opportunity.id)?.isComplete, false)
    }

    func testClosureSuggestionNeedsExplicitConfirmationToCloseAndCompleteDedicatedTask() throws {
        let store = try makeStore()
        let opportunity = try store.create(CreateOpportunity(title: "Product Manager", company: "Rekon Labs", stage: .applied, nextAction: "Follow up", dueAt: now, jobURL: "https://jobs.example.com/123"))
        let ordinaryTask = try XCTUnwrap(store.latestTask(forOpportunityID: opportunity.id))
        let suggestion = try store.recordReconciliationResult(RecordReconciliationResult(opportunityID: opportunity.id, url: opportunity.jobURL, outcome: .closedSuggested, classification: .confirmed, confidence: .high, evidence: "Employer says role filled"))

        XCTAssertEqual(try store.opportunities().first?.stage, .applied)
        try store.confirmReconciliationClosure(forOpportunityID: opportunity.id)

        XCTAssertEqual(try store.opportunities().first?.stage, .closed)
        XCTAssertEqual(try store.taskReminder(id: suggestion.reviewTaskID!)?.isComplete, true)
        XCTAssertEqual(try store.taskReminder(id: ordinaryTask.id)?.isComplete, false)
        XCTAssertNotNil(try store.reconciliationResults(forOpportunityID: opportunity.id).first?.closureConfirmedAt)
    }

    func testConfirmationUsesAnUnconfirmedClosedSuggestionInsteadOfTheNewestReview() throws {
        let store = try makeStore()
        let opportunity = try store.create(CreateOpportunity(title: "Product Manager", company: "Rekon Labs", stage: .applied, jobURL: "https://jobs.example.com/123"))
        let suggestion = try store.recordReconciliationResult(RecordReconciliationResult(opportunityID: opportunity.id, url: opportunity.jobURL, outcome: .closedSuggested, classification: .confirmed, confidence: .high, evidence: "Role filled"))
        _ = try store.recordReconciliationResult(RecordReconciliationResult(opportunityID: opportunity.id, url: opportunity.jobURL, outcome: .needsManualReview, classification: .offlineUnchecked, reason: .offlineUnchecked, evidence: "Offline; check not run"))

        try store.confirmReconciliationClosure(forOpportunityID: opportunity.id)

        let confirmed = try XCTUnwrap(try store.reconciliationResults(forOpportunityID: opportunity.id).first { $0.id == suggestion.id })
        XCTAssertNotNil(confirmed.closureConfirmedAt)
        XCTAssertEqual(try store.opportunities().first?.stage, .closed)
    }

    func testGenericStageChangeCannotCloseAnOpportunityWithAnActiveReconciliationReview() throws {
        let store = try makeStore()
        let opportunity = try store.create(CreateOpportunity(title: "Product Manager", company: "Rekon Labs", stage: .applied, jobURL: "https://jobs.example.com/123"))
        _ = try store.recordReconciliationResult(RecordReconciliationResult(opportunityID: opportunity.id, url: opportunity.jobURL, outcome: .closedSuggested, classification: .confirmed, confidence: .high, evidence: "Role filled"))

        XCTAssertThrowsError(try store.changeStage(opportunityID: opportunity.id, to: .closed))
        XCTAssertEqual(try store.opportunities().first?.stage, .applied)
    }

    func testBeginningPublicURLCheckPersistsOneStartedOperationPerOpportunityAndHost() throws {
        let store = try makeStore()
        let firstOpportunity = try store.create(CreateOpportunity(title: "Product Manager", company: "Rekon Labs", jobURL: "https://jobs.example.com/role?source=saved"))
        let secondOpportunity = try store.create(CreateOpportunity(title: "Engineering Manager", company: "Rekon Labs", jobURL: "https://jobs.example.com/other"))

        let first = try store.beginPublicURLCheck(opportunityID: firstOpportunity.id, urlSnapshot: firstOpportunity.jobURL)
        let repeatedOpportunity = try store.beginPublicURLCheck(opportunityID: firstOpportunity.id, urlSnapshot: firstOpportunity.jobURL)
        let repeatedHost = try store.beginPublicURLCheck(opportunityID: secondOpportunity.id, urlSnapshot: secondOpportunity.jobURL)

        XCTAssertTrue(first.isNew)
        XCTAssertFalse(repeatedOpportunity.isNew)
        XCTAssertFalse(repeatedHost.isNew)
        XCTAssertEqual(repeatedOpportunity.operation.id, first.operation.id)
        XCTAssertEqual(repeatedHost.operation.id, first.operation.id)
        XCTAssertEqual(first.operation.state, .started)
        XCTAssertEqual(first.operation.urlSnapshot, firstOpportunity.jobURL)
        XCTAssertEqual(try store.publicURLCheckOperations().map(\.id), [first.operation.id])
    }

    func testCompletedStillOpenCheckPersistsAllowlistedEvidenceWithoutChangingStage() throws {
        let store = try makeStore()
        let opportunity = try store.create(CreateOpportunity(title: "Product Manager", company: "Rekon Labs", stage: .applied, jobURL: "https://jobs.example.com/role"))
        let prior = try store.recordReconciliationResult(RecordReconciliationResult(opportunityID: opportunity.id, url: opportunity.jobURL, outcome: .needsManualReview, classification: .offlineUnchecked, reason: .offlineUnchecked, evidence: "Offline — check not run"))
        let operation = try store.beginPublicURLCheck(opportunityID: opportunity.id, urlSnapshot: opportunity.jobURL).operation

        let result = try XCTUnwrap(store.finishPublicURLCheck(
            operationID: operation.id,
            completion: PublicURLCheckCompletion(
                terminalState: .completed,
                outcome: .stillOpen,
                classification: .confirmed,
                confidence: .high,
                evidence: "Exact title and apply marker matched.",
                httpStatus: 200,
                mimeType: "text/html",
                declaredBytes: 1_024,
                receivedBytes: 512,
                contentSHA256: String(repeating: "a", count: 64),
                responseDate: "Mon, 01 Jan 2024 00:00:00 GMT",
                lastModified: "Sun, 31 Dec 2023 00:00:00 GMT",
                etag: "\"fixture\"",
                evidenceExcerpt: "Product Manager apply now"
            )
        ))

        XCTAssertEqual(try store.opportunities().first?.stage, .applied)
        XCTAssertEqual(try store.taskReminder(id: try XCTUnwrap(prior.reviewTaskID))?.isComplete, true)
        XCTAssertEqual(result.checkOperationID, operation.id)
        XCTAssertEqual(result.method, "GET")
        XCTAssertEqual(result.checkerVersion, "1")
        XCTAssertEqual(result.httpStatus, 200)
        XCTAssertEqual(result.mimeType, "text/html")
        XCTAssertEqual(result.receivedBytes, 512)
        XCTAssertEqual(result.contentSHA256, String(repeating: "a", count: 64))
        XCTAssertEqual(result.responseDate, "Mon, 01 Jan 2024 00:00:00 GMT")
        XCTAssertEqual(result.evidenceExcerpt, "Product Manager apply now")
        XCTAssertEqual(try store.publicURLCheckOperations().first?.state, .completed)
    }

    func testFailedPublicURLCheckCreatesOneDeduplicatedManualReviewTask() throws {
        let store = try makeStore()
        let opportunity = try store.create(CreateOpportunity(title: "Product Manager", company: "Rekon Labs", stage: .applied, jobURL: "https://jobs.example.com/role"))
        let firstOperation = try store.beginPublicURLCheck(opportunityID: opportunity.id, urlSnapshot: opportunity.jobURL).operation
        let first = try XCTUnwrap(store.finishPublicURLCheck(
            operationID: firstOperation.id,
            completion: PublicURLCheckCompletion(
                terminalState: .failed,
                outcome: .needsManualReview,
                classification: .failed,
                reason: .sourceFailed,
                evidence: "The public destination could not be proven.",
                redactedErrorCode: "dns_non_public"
            )
        ))
        let secondOperation = try store.beginPublicURLCheck(opportunityID: opportunity.id, urlSnapshot: opportunity.jobURL).operation
        let second = try XCTUnwrap(store.finishPublicURLCheck(
            operationID: secondOperation.id,
            completion: PublicURLCheckCompletion(
                terminalState: .failed,
                outcome: .needsManualReview,
                classification: .failed,
                reason: .sourceFailed,
                evidence: "The public destination could not be proven.",
                redactedErrorCode: "dns_non_public"
            )
        ))

        XCTAssertEqual(first.reviewTaskID, second.reviewTaskID)
        XCTAssertEqual(try store.needsAttention().filter { $0.id == first.reviewTaskID }.count, 1)
        XCTAssertEqual(try store.opportunities().first?.stage, .applied)
        XCTAssertEqual(second.redactedErrorCode, "dns_non_public")
    }

    func testStartupInterruptsAbandonedPublicURLCheckAndCreatesManualReview() throws {
        var store: WorkspaceStore? = try makeStore()
        let opportunity = try store!.create(CreateOpportunity(title: "Product Manager", company: "Rekon Labs", stage: .applied, jobURL: "https://jobs.example.com/role"))
        let operation = try store!.beginPublicURLCheck(opportunityID: opportunity.id, urlSnapshot: opportunity.jobURL).operation
        try store!.close()
        store = nil

        let reopened = try makeStore()

        XCTAssertEqual(try reopened.publicURLCheckOperation(id: operation.id)?.state, .interrupted)
        let result = try XCTUnwrap(try reopened.reconciliationResults(forOpportunityID: opportunity.id).first)
        XCTAssertEqual(result.classification, .failed)
        XCTAssertEqual(result.redactedErrorCode, "interrupted")
        XCTAssertNotNil(result.reviewTaskID)
        XCTAssertEqual(try reopened.opportunities().first?.stage, .applied)
    }

    func testDeletingOpportunityCancelsStartedCheckAndDiscardsLateResult() throws {
        let store = try makeStore()
        let opportunity = try store.create(CreateOpportunity(title: "Product Manager", company: "Rekon Labs", stage: .applied, jobURL: "https://jobs.example.com/role?campaign=private"))
        let operation = try store.beginPublicURLCheck(opportunityID: opportunity.id, urlSnapshot: opportunity.jobURL).operation

        try store.deleteOpportunity(id: opportunity.id)
        _ = try store.finishPublicURLCheck(
            operationID: operation.id,
            completion: PublicURLCheckCompletion(
                terminalState: .completed,
                outcome: .stillOpen,
                classification: .confirmed,
                confidence: .high,
                evidence: "Late response must be ignored."
            )
        )

        let savedOperation = try XCTUnwrap(try store.publicURLCheckOperation(id: operation.id))
        XCTAssertEqual(savedOperation.state, .cancelled)
        XCTAssertEqual(savedOperation.urlSnapshot, "https://jobs.example.com/role")
        XCTAssertEqual(try store.reconciliationResults(forOpportunityID: opportunity.id), [])
        XCTAssertEqual(try store.needsAttention(), [])
    }

    func testMalformedPublicURLCompletionTerminalizesAsRedactedFailure() throws {
        let store = try makeStore()
        let opportunity = try store.create(CreateOpportunity(title: "Product Manager", company: "Rekon Labs", jobURL: "https://jobs.example.com/role"))
        let operation = try store.beginPublicURLCheck(opportunityID: opportunity.id, urlSnapshot: opportunity.jobURL).operation

        let result = try XCTUnwrap(store.finishPublicURLCheck(
            operationID: operation.id,
            completion: PublicURLCheckCompletion(
                terminalState: .completed,
                outcome: .stillOpen,
                classification: .confirmed,
                confidence: .high,
                evidence: "Invalid fixture",
                httpStatus: 999,
                mimeType: "text/html\nunsafe",
                declaredBytes: -1
            )
        ))

        XCTAssertEqual(result.outcome, .needsManualReview)
        XCTAssertEqual(result.classification, .failed)
        XCTAssertEqual(result.redactedErrorCode, "malformed_completion")
        XCTAssertEqual(try store.publicURLCheckOperation(id: operation.id)?.state, .failed)
        XCTAssertNotNil(result.reviewTaskID)
    }

    func testOpportunityExportEscapesDataAndRecordsLocalActivity() throws {
        let store = try makeStore()
        let opportunity = try store.create(CreateOpportunity(title: "Product, Manager", company: "Rekon \"Labs\"", stage: .applied, nextAction: "Send notes", dueAt: now, jobURL: "https://jobs.example.com/123"))

        try store.recordOpportunitiesExport()

        XCTAssertEqual(
            OpportunityCSVExport.render([opportunity]),
            "\"title\",\"company\",\"stage\",\"next_action\",\"due_at\",\"job_url\"\n\"Product, Manager\",\"Rekon \"\"Labs\"\"\",\"Applied\",\"Send notes\",\"2024-01-01T00:00:00Z\",\"https://jobs.example.com/123\"\n"
        )
        XCTAssertEqual(try store.activityEvents().last?.kind, "opportunities_exported")
    }

    func testDocumentReferencePersistsHashAndFinalSentMetadata() throws {
        let store = try makeStore()
        let opportunity = try store.create(CreateOpportunity(title: "Product Manager", company: "Rekon Labs"))
        let reference = try store.recordDocumentReference(RecordDocumentReference(opportunityID: opportunity.id, kind: .resume, filename: "resume.pdf", contentType: "application/pdf", sourceHash: String(repeating: "a", count: 64), byteCount: 1_024))

        try store.markDocumentReferenceFinalSent(id: reference.id)

        let saved = try XCTUnwrap(store.documentReferences(forOpportunityID: opportunity.id).first)
        XCTAssertEqual(saved.filename, "resume.pdf")
        XCTAssertEqual(saved.sourceHash, String(repeating: "a", count: 64))
        XCTAssertEqual(saved.byteCount, 1_024)
        XCTAssertEqual(saved.finalSentAt, now)
        XCTAssertEqual(try store.activityEvents().suffix(2).map(\.kind), ["document_reference_linked", "document_reference_marked_final"])
    }

    func testDocumentReferencePersistsOpaqueBookmarkAndAvailability() throws {
        let store = try makeStore()
        let opportunity = try store.create(CreateOpportunity(title: "Product Manager", company: "Rekon Labs"))
        let reference = try store.recordDocumentReference(RecordDocumentReference(
            opportunityID: opportunity.id,
            kind: .resume,
            filename: "resume.pdf",
            contentType: "application/pdf",
            sourceHash: String(repeating: "b", count: 64),
            byteCount: 2_048,
            bookmarkData: Data([0x01, 0x02])
        ))

        XCTAssertEqual(reference.availability, .available)
        XCTAssertEqual(reference.bookmarkData, Data([0x01, 0x02]))
        XCTAssertEqual(try store.documentReferences(forOpportunityID: opportunity.id).first?.bookmarkData, Data([0x01, 0x02]))
    }

    func testDocumentReferenceSummaryCountsOnlyActiveOpportunityReferences() throws {
        let store = try makeStore()
        let active = try store.create(CreateOpportunity(title: "Active role", company: "Rekon Labs"))
        let deleted = try store.create(CreateOpportunity(title: "Deleted role", company: "Rekon Labs"))
        _ = try store.recordDocumentReference(RecordDocumentReference(
            opportunityID: active.id,
            kind: .resume,
            filename: "available.pdf",
            contentType: "application/pdf",
            sourceHash: String(repeating: "a", count: 64),
            byteCount: 1,
            bookmarkData: Data([0x01])
        ))
        _ = try store.recordDocumentReference(RecordDocumentReference(
            opportunityID: active.id,
            kind: .coverLetter,
            filename: "relink.pdf",
            contentType: "application/pdf",
            sourceHash: String(repeating: "b", count: 64),
            byteCount: 1
        ))
        _ = try store.recordDocumentReference(RecordDocumentReference(
            opportunityID: deleted.id,
            kind: .resume,
            filename: "hidden.pdf",
            contentType: "application/pdf",
            sourceHash: String(repeating: "c", count: 64),
            byteCount: 1,
            bookmarkData: Data([0x02])
        ))
        try store.deleteOpportunity(id: deleted.id)

        XCTAssertEqual(try store.documentReferenceSummary(), .init(availableCount: 1, relinkRequiredCount: 1))
    }

    func testVersionTwentyTwoDocumentReferenceMigrationRequiresRelinkWithoutRetainingBookmarkData() throws {
        let database = try makeHistoricalWorkspaceDatabase(at: databaseURL, version: .twentyTwo)
        try insertLegacyHistoricalOpportunity(into: database)
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
        let versionTwentyTwoDocumentColumns = try database.rows("PRAGMA table_info(document_references)")
        XCTAssertFalse(versionTwentyTwoDocumentColumns.contains { $0.count > 1 && $0[1] == .text("bookmark_data") })
        XCTAssertFalse(versionTwentyTwoDocumentColumns.contains { $0.count > 1 && $0[1] == .text("availability") })

        let migratedStore = try WorkspaceStore(database: database, now: now, actorID: "test", correlationID: "test")
        let reference = try XCTUnwrap(migratedStore.documentReferences(forOpportunityID: "legacy-opportunity").first)

        XCTAssertEqual(try migratedStore.schemaVersion(), WorkspaceMigrations.currentVersion)
        XCTAssertNil(reference.bookmarkData)
        XCTAssertEqual(reference.availability, .relinkRequired)
    }

    func testRemovingDocumentReferenceClearsStoredBookmarkAndRecordsRedactedActivity() throws {
        let store = try makeStore()
        let opportunity = try store.create(CreateOpportunity(title: "Product Manager", company: "Rekon Labs"))
        let reference = try store.recordDocumentReference(RecordDocumentReference(
            opportunityID: opportunity.id,
            kind: .resume,
            filename: "resume.pdf",
            contentType: "application/pdf",
            sourceHash: String(repeating: "b", count: 64),
            byteCount: 2_048,
            bookmarkData: Data([0x01, 0x02])
        ))

        try store.removeDocumentReference(id: reference.id)

        XCTAssertTrue(try store.documentReferences(forOpportunityID: opportunity.id).isEmpty)
        XCTAssertEqual(try store.activityEvents().last?.kind, "document_reference_removed")
    }

    func testEncryptedBackupCreatesReadableWorkspaceAndRecordsActivity() throws {
        let store = try makeStore()
        _ = try store.create(CreateOpportunity(title: "Product Manager", company: "Rekon Labs"))
        let backupURL = FileManager.default.temporaryDirectory.appendingPathComponent("rekon-backup-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: backupURL) }

        try store.createEncryptedBackup(at: backupURL)
        let backup = try EncryptedDatabase.open(url: backupURL, key: key, createIfMissing: false)
        defer { try? backup.close() }

        XCTAssertEqual(try backup.rows("SELECT title, company FROM opportunities"), [[.text("Product Manager"), .text("Rekon Labs")]])
        XCTAssertEqual(try store.activityEvents().last?.kind, "workspace_backed_up")
    }

    func testDeletingOpportunityHidesItAndLeavesOnlyRedactedAuditEvidence() throws {
        let store = try makeStore()
        let opportunity = try store.create(CreateOpportunity(
            title: "Product Manager", company: "Rekon Labs", nextAction: "Send follow-up", dueAt: now
        ))

        try store.deleteOpportunity(id: opportunity.id)

        let reference = try store.deletedOpportunityReference(for: opportunity.id)

        XCTAssertEqual(try store.opportunities(), [])
        XCTAssertEqual(try store.needsAttention(), [])
        XCTAssertEqual(try store.activityEvents().last?.kind, "opportunity_deleted")
        XCTAssertEqual(try store.tombstones(), [
            DeletionTombstone(
                subjectID: opportunity.id,
                subjectType: "opportunity",
                deletedAt: now,
                displayValue: "Deleted opportunity #\(reference)"
            )
        ])
        XCTAssertFalse(try store.tombstones().contains { $0.displayValue.contains(opportunity.title) || $0.displayValue.contains(opportunity.company) })
    }

    func testDeletingOpportunityWithReconciliationHistoryPreservesLinkedReviewEvidence() throws {
        let store = try makeStore()
        let opportunity = try store.create(CreateOpportunity(title: "Product Manager", company: "Rekon Labs", jobURL: "https://jobs.example.com/role"))
        let result = try store.recordReconciliationResult(RecordReconciliationResult(opportunityID: opportunity.id, url: opportunity.jobURL, outcome: .needsManualReview, classification: .offlineUnchecked, reason: .offlineUnchecked, evidence: "Offline; check not run"))
        let reviewTaskID = try XCTUnwrap(result.reviewTaskID)

        try store.deleteOpportunity(id: opportunity.id)

        XCTAssertEqual(try store.opportunities(), [])
        XCTAssertEqual(try store.needsAttention(), [])
        XCTAssertEqual(try store.taskReminder(id: reviewTaskID)?.isComplete, false)
    }

    private func makeStore(
        failBeforeActivityInsert: Bool = false,
        stageMoveFailurePoint: StageMoveFailurePoint? = nil
    ) throws -> WorkspaceStore {
        let database = try EncryptedDatabase.open(url: databaseURL, key: key)
        var identifier = 0
        return try WorkspaceStore(
            database: database,
            now: now,
            nextIdentifier: {
                defer { identifier += 1 }
                return "fixture-id-\(identifier)"
            },
            actorID: "local-user",
            correlationID: "fixture-correlation",
            failBeforeActivityInsert: failBeforeActivityInsert,
            stageMoveFailurePoint: stageMoveFailurePoint
        )
    }

    private func makeHistoricalWorkspaceDatabase(
        at url: URL,
        version: HistoricalWorkspaceSchemaVersion
    ) throws -> EncryptedDatabase {
        let database = try EncryptedDatabase.open(url: url, key: key)
        do {
            try database.execute("CREATE TABLE schema_migrations (version INTEGER NOT NULL)")
            try database.execute(
                "INSERT INTO schema_migrations (version) VALUES (?)",
                values: [.integer(Int64(version.rawValue))]
            )
            try database.execute(
                "CREATE TABLE migration_history (version INTEGER PRIMARY KEY NOT NULL, checksum TEXT NOT NULL)"
            )
            try installHistoricalWorkspaceSchema(on: database, through: version)
            try insertHistoricalMigrationHistory(into: database, through: version)
            try database.execute(
                """
                INSERT INTO workspace_metadata (key, value)
                VALUES ('workspace_id', '00000000000040008000000000000001')
                """
            )
            try assertExactHistoricalSchema(database, version: version)
            return database
        } catch {
            try? database.close()
            throw error
        }
    }

    private func installHistoricalWorkspaceSchema(
        on database: EncryptedDatabase,
        through version: HistoricalWorkspaceSchemaVersion
    ) throws {
        switch version {
        case .eleven:
            try executeHistoricalDDL(versionElevenDDL, on: database)
        case .sixteen:
            try installHistoricalWorkspaceSchema(on: database, through: .eleven)
            try executeHistoricalDDL(versionTwelveThroughSixteenDDL, on: database)
        case .eighteen:
            try installHistoricalWorkspaceSchema(on: database, through: .sixteen)
            try executeHistoricalDDL(versionSeventeenThroughEighteenDDL, on: database)
        case .nineteen:
            try installHistoricalWorkspaceSchema(on: database, through: .eighteen)
            try executeHistoricalDDL(versionNineteenDDL, on: database)
        case .twenty:
            try installHistoricalWorkspaceSchema(on: database, through: .nineteen)
            try executeHistoricalDDL(versionTwentyDDL, on: database)
        case .twentyTwo:
            try installHistoricalWorkspaceSchema(on: database, through: .twenty)
            try executeHistoricalDDL(versionTwentyOneThroughTwentyTwoDDL, on: database)
        }
    }

    private func executeHistoricalDDL(
        _ statements: [String],
        on database: EncryptedDatabase
    ) throws {
        for statement in statements {
            try database.execute(statement)
        }
    }

    private func insertHistoricalMigrationHistory(
        into database: EncryptedDatabase,
        through version: HistoricalWorkspaceSchemaVersion
    ) throws {
        let rows: [(version: Int, checksum: String)] = [
            (4, WorkspaceMigrations.baselineChecksum),
            (5, WorkspaceMigrations.versionFiveChecksum),
            (6, WorkspaceMigrations.versionSixChecksum),
            (7, WorkspaceMigrations.versionSevenChecksum),
            (8, WorkspaceMigrations.versionEightChecksum),
            (9, WorkspaceMigrations.versionNineChecksum),
            (10, WorkspaceMigrations.versionTenChecksum),
            (11, WorkspaceMigrations.versionElevenChecksum),
            (12, WorkspaceMigrations.versionTwelveChecksum),
            (13, WorkspaceMigrations.versionThirteenChecksum),
            (14, WorkspaceMigrations.versionFourteenChecksum),
            (15, WorkspaceMigrations.versionFifteenChecksum),
            (16, WorkspaceMigrations.versionSixteenChecksum),
            (17, WorkspaceMigrations.versionSeventeenChecksum),
            (18, WorkspaceMigrations.versionEighteenChecksum),
            (19, WorkspaceMigrations.versionNineteenChecksum),
            (20, WorkspaceMigrations.versionTwentyChecksum),
            (21, WorkspaceMigrations.versionTwentyOneChecksum),
            (22, WorkspaceMigrations.versionTwentyTwoChecksum)
        ]
        for row in rows where row.version <= version.rawValue {
            try database.execute(
                "INSERT INTO migration_history (version, checksum) VALUES (?, ?)",
                values: [.integer(Int64(row.version)), .text(row.checksum)]
            )
        }
    }

    private func assertExactHistoricalSchema(
        _ database: EncryptedDatabase,
        version: HistoricalWorkspaceSchemaVersion
    ) throws {
        let expectation = expectedHistoricalWorkspace(version: version)
        XCTAssertEqual(
            try database.rows("SELECT version FROM schema_migrations"),
            [[.integer(Int64(expectation.schemaVersion))]],
            "v\(version.rawValue) schema_migrations must contain exactly the selected version"
        )
        XCTAssertEqual(
            try database.rows("SELECT key, value FROM workspace_metadata ORDER BY key"),
            [[.text("workspace_id"), .text("00000000000040008000000000000001")]],
            "v\(version.rawValue) workspace identity mismatch"
        )
        XCTAssertEqual(
            try database.rows("SELECT version, checksum FROM migration_history ORDER BY version"),
            expectation.migrationHistoryRows,
            "v\(version.rawValue) migration history must be contiguous and exact"
        )

        let actualTables = Set<String>(
            try database.rows(
                "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' ORDER BY name"
            ).compactMap { row in
                guard case let .text(name)? = row.first else { return nil }
                return name
            }
        )
        XCTAssertEqual(actualTables, expectation.tables, historicalTableMismatchMessage(for: version))

        let actualIndexes = Set<String>(
            try database.rows(
                "SELECT name FROM sqlite_master WHERE type = 'index' AND name NOT LIKE 'sqlite_%' ORDER BY name"
            ).compactMap { row in
                guard case let .text(name)? = row.first else { return nil }
                return name
            }
        )
        XCTAssertEqual(
            actualIndexes,
            expectation.namedIndexes,
            "v\(version.rawValue) named-index set mismatch"
        )
        XCTAssertEqual(
            Set(expectation.columnNamesByTable.keys),
            expectation.tables,
            "v\(version.rawValue) expected column manifest must cover every table exactly"
        )

        for table in expectation.tables.sorted() {
            let actualColumns = Set<String>(
                try database.rows("PRAGMA table_info('\(table)')").compactMap { row in
                    guard row.count > 1, case let .text(name) = row[1] else { return nil }
                    return name
                }
            )
            XCTAssertEqual(
                actualColumns,
                expectation.columnNamesByTable[table],
                historicalColumnMismatchMessage(for: version, table: table)
            )
        }

        for table in actualTables.subtracting(["schema_migrations", "migration_history", "workspace_metadata"]).sorted() {
            XCTAssertEqual(
                try database.rows("SELECT count(*) FROM '\(table)'"),
                [[.integer(0)]],
                "v\(version.rawValue) \(table) must not contain implicit fixture rows"
            )
        }
    }

    private func historicalTableMismatchMessage(
        for version: HistoricalWorkspaceSchemaVersion
    ) -> String {
        switch version {
        case .eleven:
            return "v11 table set mismatch: task_reminders is required"
        case .sixteen:
            return "v16 table set mismatch: posting_checks is required"
        case .eighteen:
            return "v18 table set mismatch: reconciliation_results must be absent"
        case .nineteen:
            return "v19 table set mismatch: reconciliation_check_operations must be absent"
        case .twenty:
            return "v20 table set mismatch"
        case .twentyTwo:
            return "v22 table set mismatch"
        }
    }

    private func historicalColumnMismatchMessage(
        for version: HistoricalWorkspaceSchemaVersion,
        table: String
    ) -> String {
        if version == .twenty, table == "opportunities" {
            return "v20 opportunities column-name set mismatch: compensation_minimum must be absent"
        }
        if version == .twentyTwo, table == "document_references" {
            return "v22 document_references column-name set mismatch: bookmark_data and availability must be absent"
        }
        return "v\(version.rawValue) \(table) column-name set mismatch"
    }

    private func expectedHistoricalWorkspace(
        version: HistoricalWorkspaceSchemaVersion
    ) -> HistoricalWorkspaceExpectation {
        let tables: Set<String>
        let namedIndexes: Set<String>
        switch version {
        case .eleven:
            tables = [
                "schema_migrations", "migration_history", "opportunities",
                "task_reminders", "activity_events", "contacts",
                "contact_opportunities", "interactions", "workspace_metadata",
                "deletion_tombstones", "import_reports", "opportunity_stage_history"
            ]
            namedIndexes = []
        case .sixteen:
            tables = [
                "schema_migrations", "migration_history", "opportunities",
                "task_reminders", "activity_events", "contacts",
                "contact_opportunities", "interactions", "workspace_metadata",
                "deletion_tombstones", "import_reports", "opportunity_stage_history",
                "posting_checks", "document_references", "opportunity_response_history"
            ]
            namedIndexes = [
                "interactions_contact_occurred_at",
                "posting_checks_opportunity_checked_at",
                "document_references_opportunity_attached_at",
                "opportunity_response_history_opportunity_occurred_at"
            ]
        case .eighteen:
            tables = [
                "schema_migrations", "migration_history", "opportunities",
                "task_reminders", "activity_events", "contacts",
                "contact_opportunities", "interactions", "workspace_metadata",
                "deletion_tombstones", "import_reports", "opportunity_stage_history",
                "posting_checks", "document_references", "opportunity_response_history",
                "import_report_rows"
            ]
            namedIndexes = [
                "interactions_contact_occurred_at",
                "posting_checks_opportunity_checked_at",
                "document_references_opportunity_attached_at",
                "opportunity_response_history_opportunity_occurred_at",
                "import_report_rows_report_row"
            ]
        case .nineteen:
            tables = [
                "schema_migrations", "migration_history", "opportunities",
                "task_reminders", "activity_events", "contacts",
                "contact_opportunities", "interactions", "workspace_metadata",
                "deletion_tombstones", "import_reports", "opportunity_stage_history",
                "posting_checks", "document_references", "opportunity_response_history",
                "import_report_rows", "reconciliation_reviews", "reconciliation_results"
            ]
            namedIndexes = [
                "interactions_contact_occurred_at",
                "posting_checks_opportunity_checked_at",
                "document_references_opportunity_attached_at",
                "opportunity_response_history_opportunity_occurred_at",
                "import_report_rows_report_row",
                "reconciliation_reviews_task_reminder_id",
                "reconciliation_results_opportunity_recorded_at"
            ]
        case .twenty, .twentyTwo:
            tables = [
                "schema_migrations", "migration_history", "opportunities",
                "task_reminders", "activity_events", "contacts",
                "contact_opportunities", "interactions", "workspace_metadata",
                "deletion_tombstones", "import_reports", "opportunity_stage_history",
                "posting_checks", "document_references", "opportunity_response_history",
                "import_report_rows", "reconciliation_reviews", "reconciliation_results",
                "reconciliation_check_operations"
            ]
            namedIndexes = [
                "interactions_contact_occurred_at",
                "posting_checks_opportunity_checked_at",
                "document_references_opportunity_attached_at",
                "opportunity_response_history_opportunity_occurred_at",
                "import_report_rows_report_row",
                "reconciliation_reviews_task_reminder_id",
                "reconciliation_results_opportunity_recorded_at",
                "reconciliation_check_operations_opportunity_state"
            ]
        }

        var columns: [String: Set<String>] = [
            "schema_migrations": ["version"],
            "migration_history": ["version", "checksum"],
            "task_reminders": ["id", "opportunity_id", "title", "due_at", "is_complete"],
            "activity_events": [
                "id", "kind", "opportunity_id", "contact_id", "actor_id",
                "correlation_id", "occurred_at"
            ],
            "contacts": [
                "id", "name", "employer", "title", "email", "profile_url",
                "relationship_context", "notes", "deleted_at"
            ],
            "contact_opportunities": ["contact_id", "opportunity_id"],
            "workspace_metadata": ["key", "value"],
            "deletion_tombstones": ["subject_id", "subject_type", "deleted_at", "display_value"],
            "opportunity_stage_history": [
                "id", "opportunity_id", "from_stage", "to_stage", "occurred_at"
            ]
        ]

        if version == .eleven {
            columns["opportunities"] = [
                "id", "title", "company", "created_at", "stage", "next_action",
                "due_at", "deleted_at"
            ]
            columns["interactions"] = ["id", "opportunity_id", "summary", "occurred_at"]
            columns["import_reports"] = [
                "id", "imported_count", "skipped_count", "duplicate_kept_count",
                "invalid_count", "created_at"
            ]
        } else {
            columns["opportunities"] = [
                "id", "title", "company", "created_at", "stage", "next_action",
                "due_at", "deleted_at", "job_url", "job_description", "notes",
                "compensation", "location", "work_arrangement", "application_date",
                "response_state", "stage_changed_at"
            ]
            columns["interactions"] = [
                "id", "contact_id", "opportunity_id", "kind", "summary",
                "occurred_at", "next_touch_at"
            ]
            columns["posting_checks"] = [
                "id", "opportunity_id", "url", "status", "evidence", "checked_at"
            ]
            columns["document_references"] = [
                "id", "opportunity_id", "kind", "filename", "content_type",
                "source_hash", "byte_count", "attached_at", "final_sent_at"
            ]
            columns["opportunity_response_history"] = [
                "id", "opportunity_id", "from_state", "to_state", "occurred_at"
            ]
            columns["import_reports"] = [
                "id", "imported_count", "skipped_count", "duplicate_kept_count",
                "invalid_count", "created_at"
            ]
        }

        if version.rawValue >= HistoricalWorkspaceSchemaVersion.eighteen.rawValue {
            columns["import_reports"] = [
                "id", "imported_count", "skipped_count", "duplicate_kept_count",
                "invalid_count", "created_at", "updated_count", "source_basename",
                "mapping_summary", "failed_count"
            ]
            columns["import_report_rows"] = [
                "id", "report_id", "source_row", "outcome", "reason",
                "duplicate_rationale", "opportunity_id"
            ]
        }

        if version.rawValue >= HistoricalWorkspaceSchemaVersion.nineteen.rawValue {
            columns["reconciliation_reviews"] = [
                "opportunity_id", "task_reminder_id", "created_at", "closure_confirmed_at"
            ]
            columns["reconciliation_results"] = [
                "id", "opportunity_id", "url", "recorded_at", "outcome",
                "classification", "reason", "confidence", "evidence", "error",
                "review_task_reminder_id", "closure_confirmed_at",
                "legacy_posting_check_id", "legacy_status"
            ]
        }

        if version.rawValue >= HistoricalWorkspaceSchemaVersion.twenty.rawValue {
            columns["reconciliation_check_operations"] = [
                "id", "opportunity_id", "correlation_id", "url_snapshot",
                "state", "started_at", "terminal_at"
            ]
            columns["reconciliation_results"] = [
                "id", "opportunity_id", "url", "recorded_at", "outcome",
                "classification", "reason", "confidence", "evidence", "error",
                "review_task_reminder_id", "closure_confirmed_at",
                "legacy_posting_check_id", "legacy_status", "check_operation_id",
                "method", "checker_version", "http_status", "mime_type",
                "declared_bytes", "received_bytes", "content_sha256",
                "response_date", "last_modified", "etag", "retry_after",
                "redirect_target_redacted", "evidence_excerpt", "redacted_error_code"
            ]
        }

        if version == .twentyTwo {
            columns["opportunities"] = [
                "id", "title", "company", "created_at", "stage", "next_action",
                "due_at", "deleted_at", "job_url", "job_description", "notes",
                "compensation", "location", "work_arrangement", "application_date",
                "response_state", "stage_changed_at", "compensation_minimum",
                "compensation_maximum", "compensation_pay_period", "action_type",
                "action_custom_text"
            ]
            columns["import_report_rows"] = [
                "id", "report_id", "source_row", "outcome", "reason",
                "duplicate_rationale", "opportunity_id", "display_title",
                "display_company"
            ]
        }

        let allMigrationHistoryRows: [[DatabaseValue]] = [
            [.integer(4), .text("363c516ac302e21fedd5407bb547daa516b957f592ee7a0505f7e3d8f88ce6e9")],
            [.integer(5), .text("5fa294b9f447a4acebdd8961a43f4214788bf67fab3b0165c327f4a032e4e36b")],
            [.integer(6), .text("ca983bac7d74e8f3c4107bc4c893c30a244467a27f301b4dbe929580673841b8")],
            [.integer(7), .text("8e651b7b00affb52940b0d3873439a64f9cec7448cef601e0553e636fe8159f9")],
            [.integer(8), .text("ad8da3456b86cc4a74c5438126ca448261760e29c1adda72cde837ed297c195e")],
            [.integer(9), .text("c155d40c9ad76659e9e26660e4802ee1a324cd81f3dd6b2950ed48e7730df7dd")],
            [.integer(10), .text("5dea6b590574cf8aba5cc0e26c1a91c24bfd517dcfe04a586b341432f4478cff")],
            [.integer(11), .text("2787c3a077d6038cdbc0e04192469c586a376752293e35e37273cfb4591d90bd")],
            [.integer(12), .text("d6ac5e4b99e8f6d9eabd3c9bb14ac186b22a7c2995b56aa230bc399f29a45c67")],
            [.integer(13), .text("fc1a67cc69bc1e1753627154ffe426d45dcd8c40c1c6bbfe8e9af283b571fc5a")],
            [.integer(14), .text("a5124dad9f2faccedbf6a89289263372fea732fdbe5f21c1c25c9f7f15086333")],
            [.integer(15), .text("9ee95b90bd209947f260e9c8aca9b13be63a6ebb5baa9a8af45abf69afbe858e")],
            [.integer(16), .text("ded7964daa1d739c95b9368b423c916c74610ee05cfb3b311bca8b3f665fb558")],
            [.integer(17), .text("ee5d2ea234ba5dcb8a31fbe1b77adeb68ab211074f17f9c875934f0f07379c95")],
            [.integer(18), .text("ede096d54d80a8add35b640127686b3e5d7415fc72f3dd97832add02812e7c85")],
            [.integer(19), .text("b77fca7a7d83a9ceee85e48862beadd303016e1cd5c4aded14b67f110dfa03d5")],
            [.integer(20), .text("f8479d3ccd283df05793c7680af5131a9ec03c5265fc53add03b03dc0f70dc44")],
            [.integer(21), .text("ee3b09829091f7dacd090d6c368a0875cd0e3b4f037ddc653a0696ee7063b63a")],
            [.integer(22), .text("c24963911d57d3e250de2fb101041f2f4a13e2780ec0009a8a59d8923ce915c9")]
        ]

        return HistoricalWorkspaceExpectation(
            schemaVersion: version.rawValue,
            tables: tables,
            namedIndexes: namedIndexes,
            columnNamesByTable: columns,
            migrationHistoryRows: Array(allMigrationHistoryRows.prefix(version.rawValue - 3))
        )
    }

    private func insertLegacyHistoricalOpportunity(
        into database: EncryptedDatabase
    ) throws {
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
    }

    private func insertVersionNineteenReconciliationResult(
        into database: EncryptedDatabase
    ) throws {
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
    }
}
