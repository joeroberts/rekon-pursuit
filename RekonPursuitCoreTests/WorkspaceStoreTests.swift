import Foundation
import XCTest
@testable import RekonPursuit

@MainActor
final class WorkspaceStoreTests: XCTestCase {
    private let key = Data(repeating: 7, count: 32)
    private let now = Date(timeIntervalSince1970: 1_704_067_200)
    private var databaseURL: URL!

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

        XCTAssertEqual(try store.schemaVersion(), 15)
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

        XCTAssertEqual(try store.schemaVersion(), 15)
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
            ]
        )
        XCTAssertEqual(try database.rows("SELECT id, title, company FROM opportunities"), [[.text("opportunity-1"), .text("Product Manager"), .text("Rekon Labs")]])
        XCTAssertFalse(FileManager.default.fileExists(atPath: database.migrationSnapshotURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: database.migrationSnapshotArtifactURLs[1].path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: database.migrationSnapshotArtifactURLs[2].path))
    }

    func testVersionElevenInteractionRowsAreRetainedAsLegacyRowsDuringContactInteractionMigration() throws {
        let database = try EncryptedDatabase.open(url: databaseURL, key: key)
        try database.execute("CREATE TABLE schema_migrations (version INTEGER NOT NULL)")
        try database.execute("INSERT INTO schema_migrations (version) VALUES (11)")
        try database.execute("CREATE TABLE contacts (id TEXT PRIMARY KEY NOT NULL, name TEXT NOT NULL, employer TEXT NOT NULL, title TEXT NOT NULL DEFAULT '', email TEXT NOT NULL DEFAULT '', profile_url TEXT NOT NULL DEFAULT '', relationship_context TEXT NOT NULL DEFAULT '', notes TEXT NOT NULL DEFAULT '', deleted_at REAL)")
        try database.execute("CREATE TABLE opportunities (id TEXT PRIMARY KEY NOT NULL, title TEXT NOT NULL, company TEXT NOT NULL, created_at REAL NOT NULL, stage TEXT NOT NULL DEFAULT 'Saved', next_action TEXT NOT NULL DEFAULT '', due_at REAL, deleted_at REAL)")
        try database.execute("CREATE TABLE interactions (id TEXT PRIMARY KEY NOT NULL, opportunity_id TEXT NOT NULL REFERENCES opportunities(id), summary TEXT NOT NULL, occurred_at REAL NOT NULL)")
        try database.execute("INSERT INTO opportunities (id, title, company, created_at) VALUES ('opportunity-1', 'Product Manager', 'Rekon Labs', 1704067200)")
        try database.execute("INSERT INTO interactions (id, opportunity_id, summary, occurred_at) VALUES ('interaction-1', 'opportunity-1', 'Legacy note', 1704067200)")

        let store = try WorkspaceStore(database: database, actorID: "test", correlationID: "test")

        XCTAssertEqual(try store.schemaVersion(), 15)
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
            dueAt: rescheduled
        )

        XCTAssertEqual(try store.opportunities(), [
            Opportunity(
                id: opportunity.id,
                title: "Senior Product Manager",
                company: "Rekon Labs",
                createdAt: now,
                stage: .screening,
                nextAction: "Prepare recruiter call",
                dueAt: rescheduled
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
            email: "alex@example.com",
            profileURL: "https://example.com/alex",
            relationshipContext: "Met at conference",
            notes: "Prefers email."
        ))
        try store.linkContact(contactID: contact.id, toOpportunityID: first.id)

        XCTAssertEqual(try store.contacts(), [contact])
        XCTAssertEqual(try store.contacts(forOpportunityID: first.id), [contact])
        XCTAssertEqual(try store.sameEmployerContacts(forOpportunityID: second.id), [contact])
        XCTAssertEqual(try store.activityEvents().last?.contactID, contact.id)
    }

    func testContactUpdateUnlinkAndDeletionAreSafeAndRedacted() throws {
        let store = try makeStore()
        let first = try store.create(CreateOpportunity(title: "Product Manager", company: "Rekon Labs"))
        let second = try store.create(CreateOpportunity(title: "Director", company: "Rekon Labs"))
        let contact = try store.createContact(CreateContact(name: "Alex Morgan", employer: "Rekon Labs", email: "alex@example.com"))

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

        XCTAssertEqual(preview.rows, [CSVImportRow(id: 2, opportunity: CreateOpportunity(title: "Product Manager", company: "Rekon Labs"))])
        XCTAssertEqual(preview.invalidRowCount, 1)
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
        XCTAssertEqual(try store.activityEvents().suffix(2).map(\.kind), ["csv_duplicate_skipped", "csv_imported"])
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

    func testPostingCheckPersistsEvidenceWithoutChangingOpportunityStage() throws {
        let store = try makeStore()
        let opportunity = try store.create(CreateOpportunity(title: "Product Manager", company: "Rekon Labs", stage: .applied, jobURL: "https://jobs.example.com/123"))

        let check = try store.recordPostingCheck(RecordPostingCheck(opportunityID: opportunity.id, url: opportunity.jobURL, status: .closed, evidence: "Posting returned a closed notice."))

        XCTAssertEqual(try store.postingChecks(forOpportunityID: opportunity.id), [check])
        XCTAssertEqual(try store.opportunities().first?.stage, .applied)
        XCTAssertEqual(try store.activityEvents().last?.kind, "posting_checked")
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

    private func makeStore(failBeforeActivityInsert: Bool = false) throws -> WorkspaceStore {
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
            failBeforeActivityInsert: failBeforeActivityInsert
        )
    }
}
