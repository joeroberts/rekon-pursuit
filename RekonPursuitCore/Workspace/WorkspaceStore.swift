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
                if !nextAction.isEmpty, let dueAt = opportunity.dueAt {
                    try database.execute("INSERT INTO task_reminders (id, opportunity_id, title, due_at) VALUES (?, ?, ?, ?)", values: [.text(nextIdentifier()), .text(opportunity.id), .text(nextAction), .real(dueAt.timeIntervalSince1970)])
                }
                if failBeforeActivityInsert { throw WorkspaceStoreError.injectedFailure }
                try database.execute(
                    "INSERT INTO activity_events (id, kind, opportunity_id, actor_id, correlation_id, occurred_at) VALUES (?, ?, ?, ?, ?, ?)",
                    values: [.text(event.id), .text(event.kind), .text(event.opportunityID), .text(event.actorID), .text(event.correlationID), .real(event.occurredAt.timeIntervalSince1970)]
                )
            }
            return opportunity
        }
    }

    func opportunities() throws -> [Opportunity] {
        try synchronized {
            try database.rows("SELECT id, title, company, created_at, stage, next_action, due_at FROM opportunities ORDER BY created_at, id").map(opportunity(from:))
        }
    }

    func needsAttention() throws -> [TaskReminder] {
        try synchronized {
            try database.rows("SELECT id, opportunity_id, title, due_at, is_complete FROM task_reminders WHERE is_complete = 0 ORDER BY due_at, id").map(task(from:))
        }
    }

    func activityEvents() throws -> [ActivityEvent] {
        try synchronized {
            try database.rows("SELECT id, kind, opportunity_id, actor_id, correlation_id, occurred_at FROM activity_events ORDER BY occurred_at, id").map(activityEvent(from:))
        }
    }

    private func synchronized<T>(_ work: () throws -> T) throws -> T {
        lock.lock()
        defer { lock.unlock() }
        return try work()
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
        guard row.count == 5, case let .text(id) = row[0], case let .text(opportunityID) = row[1], case let .text(title) = row[2], case let .real(dueAt) = row[3], case let .integer(isComplete) = row[4] else { throw WorkspaceStoreError.unexpectedDatabaseValue }
        return TaskReminder(id: id, opportunityID: opportunityID, title: title, dueAt: Date(timeIntervalSince1970: dueAt), isComplete: isComplete != 0)
    }

    private func activityEvent(from row: [DatabaseValue]) throws -> ActivityEvent {
        guard row.count == 6,
              case let .text(id) = row[0], case let .text(kind) = row[1], case let .text(opportunityID) = row[2],
              case let .text(actorID) = row[3], case let .text(correlationID) = row[4], case let .real(occurredAt) = row[5] else {
            throw WorkspaceStoreError.unexpectedDatabaseValue
        }
        return ActivityEvent(id: id, kind: kind, opportunityID: opportunityID, actorID: actorID, correlationID: correlationID, occurredAt: Date(timeIntervalSince1970: occurredAt))
    }
}
