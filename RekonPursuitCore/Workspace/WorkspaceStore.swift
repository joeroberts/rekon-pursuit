import CryptoKit
import Foundation

final class WorkspaceStore {
    private let database: EncryptedDatabase
    private let now: Date
    private let nextIdentifier: () -> String
    private let actorID: String
    private let correlationID: String
    private let failBeforeActivityInsert: Bool
    private let lock = NSLock()

    init(
        database: EncryptedDatabase,
        now: Date = .now,
        nextIdentifier: @escaping () -> String = { UUID().uuidString },
        actorID: String,
        correlationID: String,
        failBeforeActivityInsert: Bool = false
    ) throws {
        self.database = database
        self.now = now
        self.nextIdentifier = nextIdentifier
        self.actorID = actorID
        self.correlationID = correlationID
        self.failBeforeActivityInsert = failBeforeActivityInsert
        try WorkspaceMigrations.apply(to: database)
    }

    func schemaVersion() throws -> Int {
        try synchronized {
            guard case let .integer(version)? = try database.rows("SELECT version FROM schema_migrations LIMIT 1").first?.first else {
                throw WorkspaceStoreError.unexpectedDatabaseValue
            }
            return Int(version)
        }
    }

    func close() throws {
        try synchronized {
            try database.checkpointAndClose()
        }
    }

    func create(_ command: CreateOpportunity) throws -> Opportunity {
        let title = command.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let company = command.company.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, !company.isEmpty else { throw WorkspaceStoreError.invalidOpportunity }

        return try synchronized {
            let nextAction = command.nextAction.trimmingCharacters(in: .whitespacesAndNewlines)
            let opportunity = Opportunity(id: nextIdentifier(), title: title, company: company, createdAt: now, stage: command.stage, nextAction: nextAction, dueAt: command.dueAt)
            let event = ActivityEvent(
                id: nextIdentifier(), kind: "opportunity_created", opportunityID: opportunity.id,
                actorID: actorID, correlationID: correlationID, occurredAt: now
            )
            try database.transaction {
                try database.execute(
                    "INSERT INTO opportunities (id, title, company, created_at, stage, next_action, due_at) VALUES (?, ?, ?, ?, ?, ?, ?)",
                    values: [.text(opportunity.id), .text(opportunity.title), .text(opportunity.company), .real(opportunity.createdAt.timeIntervalSince1970), .text(opportunity.stage.rawValue), .text(nextAction), opportunity.dueAt.map { .real($0.timeIntervalSince1970) } ?? .null]
                )
                if !nextAction.isEmpty {
                    try database.execute("INSERT INTO task_reminders (id, opportunity_id, title, due_at) VALUES (?, ?, ?, ?)", values: [.text(nextIdentifier()), .text(opportunity.id), .text(nextAction), opportunity.dueAt.map { .real($0.timeIntervalSince1970) } ?? .null])
                }
                if failBeforeActivityInsert { throw WorkspaceStoreError.injectedFailure }
                try database.execute(
                    "INSERT INTO activity_events (id, kind, opportunity_id, actor_id, correlation_id, occurred_at) VALUES (?, ?, ?, ?, ?, ?)",
                    values: [.text(event.id), .text(event.kind), event.opportunityID.map(DatabaseValue.text) ?? .null, .text(event.actorID), .text(event.correlationID), .real(event.occurredAt.timeIntervalSince1970)]
                )
            }
            return opportunity
        }
    }

    func opportunities() throws -> [Opportunity] {
        try synchronized {
            try database.rows("SELECT id, title, company, created_at, stage, next_action, due_at FROM opportunities WHERE deleted_at IS NULL ORDER BY created_at, id").map(opportunity(from:))
        }
    }

    func csvImportPlan(for preview: CSVImportPreview) throws -> [CSVImportPlanRow] {
        try synchronized {
            let existing = Set(try database.rows("SELECT title, company FROM opportunities WHERE deleted_at IS NULL").compactMap { row -> String? in
                guard row.count == 2, case let .text(title) = row[0], case let .text(company) = row[1] else { return nil }
                return normalizedOpportunityKey(title: title, company: company)
            })
            return preview.rows.map { row in
                CSVImportPlanRow(row: row, isDuplicate: existing.contains(normalizedOpportunityKey(title: row.opportunity.title, company: row.opportunity.company)), decision: nil)
            }
        }
    }

    func importCSV(_ rows: [CSVImportPlanRow], invalidCount: Int) throws -> CSVImportReport {
        try synchronized {
            guard rows.allSatisfy({ !$0.isDuplicate || $0.decision != nil }) else { throw WorkspaceStoreError.unresolvedImportDecision }
            let report = CSVImportReport(id: nextIdentifier(), importedCount: rows.filter { !$0.isDuplicate || $0.decision == .keepSeparate }.count, skippedCount: rows.filter { $0.decision == .skip }.count, duplicateKeptCount: rows.filter { $0.isDuplicate && $0.decision == .keepSeparate }.count, invalidCount: invalidCount, createdAt: now)
            try database.transaction {
                for planRow in rows {
                    if planRow.decision == .skip {
                        try appendActivity(kind: "csv_duplicate_skipped", opportunityID: nil)
                        continue
                    }
                    let command = planRow.row.opportunity
                    let opportunity = Opportunity(id: nextIdentifier(), title: command.title.trimmingCharacters(in: .whitespacesAndNewlines), company: command.company.trimmingCharacters(in: .whitespacesAndNewlines), createdAt: now, stage: command.stage, nextAction: command.nextAction, dueAt: command.dueAt)
                    try database.execute("INSERT INTO opportunities (id, title, company, created_at, stage, next_action, due_at) VALUES (?, ?, ?, ?, ?, ?, ?)", values: [.text(opportunity.id), .text(opportunity.title), .text(opportunity.company), .real(now.timeIntervalSince1970), .text(opportunity.stage.rawValue), .text(opportunity.nextAction), opportunity.dueAt.map { .real($0.timeIntervalSince1970) } ?? .null])
                    try appendActivity(kind: planRow.isDuplicate ? "csv_duplicate_kept" : "csv_imported", opportunityID: opportunity.id)
                }
                try database.execute("INSERT INTO import_reports (id, imported_count, skipped_count, duplicate_kept_count, invalid_count, created_at) VALUES (?, ?, ?, ?, ?, ?)", values: [.text(report.id), .integer(Int64(report.importedCount)), .integer(Int64(report.skippedCount)), .integer(Int64(report.duplicateKeptCount)), .integer(Int64(report.invalidCount)), .real(now.timeIntervalSince1970)])
            }
            return report
        }
    }

    func importReports() throws -> [CSVImportReport] {
        try synchronized {
            try database.rows("SELECT id, imported_count, skipped_count, duplicate_kept_count, invalid_count, created_at FROM import_reports ORDER BY created_at, id").map(importReport(from:))
        }
    }

    func needsAttention() throws -> [TaskReminder] {
        try synchronized {
            let calendar = Calendar(identifier: .gregorian)
            let startOfToday = calendar.startOfDay(for: now)
            let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday)!
            return try database.rows("SELECT task_reminders.id, task_reminders.opportunity_id, task_reminders.title, task_reminders.due_at, task_reminders.is_complete FROM task_reminders JOIN opportunities ON opportunities.id = task_reminders.opportunity_id WHERE task_reminders.is_complete = 0 AND opportunities.deleted_at IS NULL AND opportunities.stage != 'Closed' ORDER BY CASE WHEN task_reminders.due_at IS NULL THEN 4 WHEN task_reminders.due_at < ? THEN 1 WHEN task_reminders.due_at < ? THEN 2 ELSE 3 END, task_reminders.due_at, task_reminders.id", values: [.real(startOfToday.timeIntervalSince1970), .real(startOfTomorrow.timeIntervalSince1970)]).map(task(from:))
        }
    }

    func deleteOpportunity(id: String) throws {
        try synchronized {
            guard try isActiveOpportunity(id) else { throw WorkspaceStoreError.unexpectedDatabaseValue }
            let reference = try deletedOpportunityReferenceUnlocked(for: id)
            let event = ActivityEvent(id: nextIdentifier(), kind: "opportunity_deleted", opportunityID: id, actorID: actorID, correlationID: correlationID, occurredAt: now)
            try database.transaction {
                try database.execute("UPDATE opportunities SET deleted_at = ? WHERE id = ?", values: [.real(now.timeIntervalSince1970), .text(id)])
                try database.execute("DELETE FROM task_reminders WHERE opportunity_id = ?", values: [.text(id)])
                try database.execute(
                    "INSERT INTO deletion_tombstones (subject_id, subject_type, deleted_at, display_value) VALUES (?, 'opportunity', ?, ?)",
                    values: [.text(id), .real(now.timeIntervalSince1970), .text("Deleted opportunity #\(reference)")]
                )
                try database.execute("INSERT INTO activity_events (id, kind, opportunity_id, actor_id, correlation_id, occurred_at) VALUES (?, ?, ?, ?, ?, ?)", values: [.text(event.id), .text(event.kind), event.opportunityID.map(DatabaseValue.text) ?? .null, .text(event.actorID), .text(event.correlationID), .real(event.occurredAt.timeIntervalSince1970)])
            }
        }
    }

    func tombstones() throws -> [DeletionTombstone] {
        try synchronized {
            try database.rows("SELECT subject_id, subject_type, deleted_at, display_value FROM deletion_tombstones ORDER BY deleted_at, subject_id").map(tombstone(from:))
        }
    }

    func deletedOpportunityReference(for opportunityID: String) throws -> String {
        try synchronized {
            try deletedOpportunityReferenceUnlocked(for: opportunityID)
        }
    }

    func completeTask(id: String) throws {
        try synchronized {
            let opportunityID = try activeTaskOpportunityID(id)
            let event = ActivityEvent(id: nextIdentifier(), kind: "task_completed", opportunityID: opportunityID, actorID: actorID, correlationID: correlationID, occurredAt: now)
            try database.transaction {
                try database.execute("UPDATE task_reminders SET is_complete = 1 WHERE id = ?", values: [.text(id)])
                try database.execute("INSERT INTO activity_events (id, kind, opportunity_id, actor_id, correlation_id, occurred_at) VALUES (?, ?, ?, ?, ?, ?)", values: [.text(event.id), .text(event.kind), event.opportunityID.map(DatabaseValue.text) ?? .null, .text(event.actorID), .text(event.correlationID), .real(event.occurredAt.timeIntervalSince1970)])
            }
        }
    }

    func rescheduleTask(id: String, dueAt: Date) throws {
        try synchronized {
            let opportunityID = try activeTaskOpportunityID(id)
            let event = ActivityEvent(id: nextIdentifier(), kind: "task_rescheduled", opportunityID: opportunityID, actorID: actorID, correlationID: correlationID, occurredAt: now)
            try database.transaction {
                try database.execute("UPDATE task_reminders SET due_at = ? WHERE id = ?", values: [.real(dueAt.timeIntervalSince1970), .text(id)])
                try database.execute("INSERT INTO activity_events (id, kind, opportunity_id, actor_id, correlation_id, occurred_at) VALUES (?, ?, ?, ?, ?, ?)", values: [.text(event.id), .text(event.kind), event.opportunityID.map(DatabaseValue.text) ?? .null, .text(event.actorID), .text(event.correlationID), .real(event.occurredAt.timeIntervalSince1970)])
            }
        }
    }

    func changeStage(opportunityID: String, to stage: PipelineStage) throws {
        try synchronized {
            guard try isActiveOpportunity(opportunityID) else { throw WorkspaceStoreError.unexpectedDatabaseValue }
            let event = ActivityEvent(id: nextIdentifier(), kind: "opportunity_stage_changed", opportunityID: opportunityID, actorID: actorID, correlationID: correlationID, occurredAt: now)
            try database.transaction {
                try database.execute("UPDATE opportunities SET stage = ? WHERE id = ?", values: [.text(stage.rawValue), .text(opportunityID)])
                try database.execute("INSERT INTO activity_events (id, kind, opportunity_id, actor_id, correlation_id, occurred_at) VALUES (?, ?, ?, ?, ?, ?)", values: [.text(event.id), .text(event.kind), event.opportunityID.map(DatabaseValue.text) ?? .null, .text(event.actorID), .text(event.correlationID), .real(event.occurredAt.timeIntervalSince1970)])
            }
        }
    }

    func updateOpportunity(
        id: String,
        title: String,
        company: String,
        stage: PipelineStage,
        nextAction: String,
        dueAt: Date?
    ) throws {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let company = company.trimmingCharacters(in: .whitespacesAndNewlines)
        let nextAction = nextAction.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, !company.isEmpty else { throw WorkspaceStoreError.invalidOpportunity }

        try synchronized {
            guard try isActiveOpportunity(id) else { throw WorkspaceStoreError.unexpectedDatabaseValue }
            let event = ActivityEvent(id: nextIdentifier(), kind: "opportunity_updated", opportunityID: id, actorID: actorID, correlationID: correlationID, occurredAt: now)
            try database.transaction {
                try database.execute(
                    "UPDATE opportunities SET title = ?, company = ?, stage = ?, next_action = ?, due_at = ? WHERE id = ?",
                    values: [.text(title), .text(company), .text(stage.rawValue), .text(nextAction), dueAt.map { .real($0.timeIntervalSince1970) } ?? .null, .text(id)]
                )

                let activeTaskID = try database.rows(
                    "SELECT id FROM task_reminders WHERE opportunity_id = ? AND is_complete = 0 ORDER BY id LIMIT 1",
                    values: [.text(id)]
                ).first?.first
                if nextAction.isEmpty {
                    try database.execute("DELETE FROM task_reminders WHERE opportunity_id = ? AND is_complete = 0", values: [.text(id)])
                } else if case let .text(taskID)? = activeTaskID {
                    try database.execute("UPDATE task_reminders SET title = ?, due_at = ? WHERE id = ?", values: [.text(nextAction), dueAt.map { .real($0.timeIntervalSince1970) } ?? .null, .text(taskID)])
                } else {
                    try database.execute("INSERT INTO task_reminders (id, opportunity_id, title, due_at) VALUES (?, ?, ?, ?)", values: [.text(nextIdentifier()), .text(id), .text(nextAction), dueAt.map { .real($0.timeIntervalSince1970) } ?? .null])
                }
                try database.execute("INSERT INTO activity_events (id, kind, opportunity_id, actor_id, correlation_id, occurred_at) VALUES (?, ?, ?, ?, ?, ?)", values: [.text(event.id), .text(event.kind), .text(id), .text(event.actorID), .text(event.correlationID), .real(event.occurredAt.timeIntervalSince1970)])
            }
        }
    }

    func createContact(_ command: CreateContact) throws -> Contact {
        let name = command.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let employer = command.employer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !employer.isEmpty else { throw WorkspaceStoreError.invalidOpportunity }
        return try synchronized {
            let contact = Contact(id: nextIdentifier(), name: name, employer: employer)
            let event = ActivityEvent(id: nextIdentifier(), kind: "contact_created", opportunityID: nil, actorID: actorID, correlationID: correlationID, occurredAt: now)
            try database.transaction {
                try database.execute("INSERT INTO contacts (id, name, employer) VALUES (?, ?, ?)", values: [.text(contact.id), .text(contact.name), .text(contact.employer)])
                try database.execute("INSERT INTO activity_events (id, kind, opportunity_id, actor_id, correlation_id, occurred_at) VALUES (?, ?, ?, ?, ?, ?)", values: [.text(event.id), .text(event.kind), .null, .text(event.actorID), .text(event.correlationID), .real(event.occurredAt.timeIntervalSince1970)])
            }
            return contact
        }
    }

    func linkContact(contactID: String, toOpportunityID opportunityID: String) throws {
        try synchronized {
            guard try isActiveOpportunity(opportunityID) else { throw WorkspaceStoreError.unexpectedDatabaseValue }
            guard (try database.rows("SELECT contact_id FROM contact_opportunities WHERE contact_id = ? AND opportunity_id = ?", values: [.text(contactID), .text(opportunityID)])).isEmpty else { return }
            let event = ActivityEvent(id: nextIdentifier(), kind: "contact_linked", opportunityID: opportunityID, actorID: actorID, correlationID: correlationID, occurredAt: now)
            try database.transaction {
                try database.execute("INSERT INTO contact_opportunities (contact_id, opportunity_id) VALUES (?, ?)", values: [.text(contactID), .text(opportunityID)])
                try database.execute("INSERT INTO activity_events (id, kind, opportunity_id, actor_id, correlation_id, occurred_at) VALUES (?, ?, ?, ?, ?, ?)", values: [.text(event.id), .text(event.kind), .text(event.opportunityID!), .text(event.actorID), .text(event.correlationID), .real(event.occurredAt.timeIntervalSince1970)])
            }
        }
    }

    func contacts(forOpportunityID opportunityID: String) throws -> [Contact] {
        try synchronized {
            guard try isActiveOpportunity(opportunityID) else { return [] }
            return try database.rows("SELECT contacts.id, contacts.name, contacts.employer FROM contacts JOIN contact_opportunities ON contacts.id = contact_opportunities.contact_id WHERE contact_opportunities.opportunity_id = ? ORDER BY contacts.name", values: [.text(opportunityID)]).map(contact(from:))
        }
    }

    func contacts() throws -> [Contact] {
        try synchronized {
            try database.rows("SELECT id, name, employer FROM contacts ORDER BY name, id").map(contact(from:))
        }
    }

    func recordInteraction(_ command: CreateInteraction) throws -> Interaction {
        let summary = command.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !summary.isEmpty else { throw WorkspaceStoreError.invalidOpportunity }
        return try synchronized {
            guard try isActiveOpportunity(command.opportunityID) else { throw WorkspaceStoreError.unexpectedDatabaseValue }
            let interaction = Interaction(id: nextIdentifier(), opportunityID: command.opportunityID, summary: summary, occurredAt: now)
            let event = ActivityEvent(id: nextIdentifier(), kind: "interaction_recorded", opportunityID: command.opportunityID, actorID: actorID, correlationID: correlationID, occurredAt: now)
            try database.transaction {
                try database.execute("INSERT INTO interactions (id, opportunity_id, summary, occurred_at) VALUES (?, ?, ?, ?)", values: [.text(interaction.id), .text(interaction.opportunityID), .text(interaction.summary), .real(interaction.occurredAt.timeIntervalSince1970)])
                try database.execute("INSERT INTO activity_events (id, kind, opportunity_id, actor_id, correlation_id, occurred_at) VALUES (?, ?, ?, ?, ?, ?)", values: [.text(event.id), .text(event.kind), event.opportunityID.map(DatabaseValue.text) ?? .null, .text(event.actorID), .text(event.correlationID), .real(event.occurredAt.timeIntervalSince1970)])
            }
            return interaction
        }
    }

    func interactions(forOpportunityID opportunityID: String) throws -> [Interaction] {
        try synchronized {
            guard try isActiveOpportunity(opportunityID) else { return [] }
            return try database.rows("SELECT id, opportunity_id, summary, occurred_at FROM interactions WHERE opportunity_id = ? ORDER BY occurred_at, id", values: [.text(opportunityID)]).map(interaction(from:))
        }
    }

    func activityEvents() throws -> [ActivityEvent] {
        try synchronized {
            try database.rows("SELECT id, kind, opportunity_id, actor_id, correlation_id, occurred_at FROM activity_events ORDER BY occurred_at, rowid").map(activityEvent(from:))
        }
    }

    private func synchronized<T>(_ work: () throws -> T) throws -> T {
        lock.lock()
        defer { lock.unlock() }
        return try work()
    }

    private func activeTaskOpportunityID(_ taskID: String) throws -> String {
        guard case let .text(opportunityID)? = try database.rows("SELECT task_reminders.opportunity_id FROM task_reminders JOIN opportunities ON opportunities.id = task_reminders.opportunity_id WHERE task_reminders.id = ? AND task_reminders.is_complete = 0 AND opportunities.deleted_at IS NULL AND opportunities.stage != 'Closed'", values: [.text(taskID)]).first?.first else { throw WorkspaceStoreError.unexpectedDatabaseValue }
        return opportunityID
    }

    private func isActiveOpportunity(_ id: String) throws -> Bool {
        guard case .text? = try database.rows("SELECT id FROM opportunities WHERE id = ? AND deleted_at IS NULL", values: [.text(id)]).first?.first else { return false }
        return true
    }

    private func normalizedOpportunityKey(title: String, company: String) -> String {
        "\(title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())\u{1F}\(company.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())"
    }

    private func appendActivity(kind: String, opportunityID: String?) throws {
        let event = ActivityEvent(id: nextIdentifier(), kind: kind, opportunityID: opportunityID, actorID: actorID, correlationID: correlationID, occurredAt: now)
        try database.execute("INSERT INTO activity_events (id, kind, opportunity_id, actor_id, correlation_id, occurred_at) VALUES (?, ?, ?, ?, ?, ?)", values: [.text(event.id), .text(event.kind), event.opportunityID.map(DatabaseValue.text) ?? .null, .text(event.actorID), .text(event.correlationID), .real(event.occurredAt.timeIntervalSince1970)])
    }

    private func deletedOpportunityReferenceUnlocked(for opportunityID: String) throws -> String {
        guard case let .text(workspaceID)? = try database.rows("SELECT value FROM workspace_metadata WHERE key = 'workspace_id'").first?.first else {
            throw WorkspaceStoreError.unexpectedDatabaseValue
        }
        return SHA256.hash(data: Data((workspaceID + opportunityID).utf8)).map { String(format: "%02x", $0) }.joined().prefix(12).description
    }

    private func opportunity(from row: [DatabaseValue]) throws -> Opportunity {
        guard row.count == 7,
              case let .text(id) = row[0], case let .text(title) = row[1],
              case let .text(company) = row[2], case let .real(createdAt) = row[3], case let .text(stageValue) = row[4], let stage = PipelineStage(rawValue: stageValue), case let .text(nextAction) = row[5] else {
            throw WorkspaceStoreError.unexpectedDatabaseValue
        }
        let dueAt: Date?
        if case let .real(value) = row[6] { dueAt = Date(timeIntervalSince1970: value) } else { dueAt = nil }
        return Opportunity(id: id, title: title, company: company, createdAt: Date(timeIntervalSince1970: createdAt), stage: stage, nextAction: nextAction, dueAt: dueAt)
    }

    private func task(from row: [DatabaseValue]) throws -> TaskReminder {
        guard row.count == 5, case let .text(id) = row[0], case let .text(opportunityID) = row[1], case let .text(title) = row[2], case let .integer(isComplete) = row[4] else { throw WorkspaceStoreError.unexpectedDatabaseValue }
        let dueAt: Date?
        if case let .real(value) = row[3] { dueAt = Date(timeIntervalSince1970: value) } else { dueAt = nil }
        return TaskReminder(id: id, opportunityID: opportunityID, title: title, dueAt: dueAt, isComplete: isComplete != 0)
    }

    private func contact(from row: [DatabaseValue]) throws -> Contact {
        guard row.count == 3, case let .text(id) = row[0], case let .text(name) = row[1], case let .text(employer) = row[2] else { throw WorkspaceStoreError.unexpectedDatabaseValue }
        return Contact(id: id, name: name, employer: employer)
    }

    private func interaction(from row: [DatabaseValue]) throws -> Interaction {
        guard row.count == 4, case let .text(id) = row[0], case let .text(opportunityID) = row[1], case let .text(summary) = row[2], case let .real(occurredAt) = row[3] else { throw WorkspaceStoreError.unexpectedDatabaseValue }
        return Interaction(id: id, opportunityID: opportunityID, summary: summary, occurredAt: Date(timeIntervalSince1970: occurredAt))
    }

    private func activityEvent(from row: [DatabaseValue]) throws -> ActivityEvent {
        guard row.count == 6,
              case let .text(id) = row[0], case let .text(kind) = row[1],
              case let .text(actorID) = row[3], case let .text(correlationID) = row[4], case let .real(occurredAt) = row[5] else {
            throw WorkspaceStoreError.unexpectedDatabaseValue
        }
        let opportunityID: String?
        if case let .text(value) = row[2] { opportunityID = value } else { opportunityID = nil }
        return ActivityEvent(id: id, kind: kind, opportunityID: opportunityID, actorID: actorID, correlationID: correlationID, occurredAt: Date(timeIntervalSince1970: occurredAt))
    }

    private func tombstone(from row: [DatabaseValue]) throws -> DeletionTombstone {
        guard row.count == 4,
              case let .text(subjectID) = row[0], case let .text(subjectType) = row[1],
              case let .real(deletedAt) = row[2], case let .text(displayValue) = row[3] else {
            throw WorkspaceStoreError.unexpectedDatabaseValue
        }
        return DeletionTombstone(subjectID: subjectID, subjectType: subjectType, deletedAt: Date(timeIntervalSince1970: deletedAt), displayValue: displayValue)
    }

    private func importReport(from row: [DatabaseValue]) throws -> CSVImportReport {
        guard row.count == 6, case let .text(id) = row[0], case let .integer(imported) = row[1], case let .integer(skipped) = row[2], case let .integer(duplicateKept) = row[3], case let .integer(invalid) = row[4], case let .real(createdAt) = row[5] else { throw WorkspaceStoreError.unexpectedDatabaseValue }
        return CSVImportReport(id: id, importedCount: Int(imported), skippedCount: Int(skipped), duplicateKeptCount: Int(duplicateKept), invalidCount: Int(invalid), createdAt: Date(timeIntervalSince1970: createdAt))
    }
}
