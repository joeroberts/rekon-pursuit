import CryptoKit
import Foundation

final class WorkspaceStore {
    private let database: EncryptedDatabase
    private let clock: () -> Date
    private let nextIdentifier: () -> String
    private let actorID: String
    private let correlationID: String
    private let failBeforeActivityInsert: Bool
    private let lock = NSLock()

    init(
        database: EncryptedDatabase,
        now: Date? = nil,
        clock: @escaping () -> Date = { Date.now },
        nextIdentifier: @escaping () -> String = { UUID().uuidString },
        actorID: String,
        correlationID: String,
        failBeforeActivityInsert: Bool = false
    ) throws {
        self.database = database
        self.clock = now.map { fixedNow in { fixedNow } } ?? clock
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
        guard command.responseState == .noResponseRecorded || command.responseEffectiveDate != nil else {
            throw WorkspaceStoreError.invalidOpportunity
        }
        let commandNow = clock()

        return try synchronized {
            let nextAction = command.nextAction.trimmingCharacters(in: .whitespacesAndNewlines)
            let opportunity = Opportunity(id: nextIdentifier(), title: title, company: company, createdAt: commandNow, stage: command.stage, nextAction: nextAction, dueAt: command.dueAt, jobURL: command.jobURL.trimmingCharacters(in: .whitespacesAndNewlines), jobDescription: command.jobDescription.trimmingCharacters(in: .whitespacesAndNewlines), notes: command.notes.trimmingCharacters(in: .whitespacesAndNewlines), compensation: trimmedOptional(command.compensation), location: trimmedOptional(command.location), workArrangement: command.workArrangement, applicationDate: command.applicationDate, responseState: command.responseState, stageChangedAt: command.stageChangedAt ?? commandNow)
            let event = ActivityEvent(
                id: nextIdentifier(), kind: "opportunity_created", opportunityID: opportunity.id,
                actorID: actorID, correlationID: correlationID, occurredAt: commandNow
            )
            try database.transaction {
                try database.execute(
                    "INSERT INTO opportunities (id, title, company, created_at, stage, next_action, due_at, job_url, job_description, notes, compensation, location, work_arrangement, application_date, response_state, stage_changed_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                    values: opportunityValues(opportunity)
                )
                if !nextAction.isEmpty {
                    try database.execute("INSERT INTO task_reminders (id, opportunity_id, title, due_at) VALUES (?, ?, ?, ?)", values: [.text(nextIdentifier()), .text(opportunity.id), .text(nextAction), opportunity.dueAt.map { .real($0.timeIntervalSince1970) } ?? .null])
                }
                if failBeforeActivityInsert { throw WorkspaceStoreError.injectedFailure }
                try database.execute(
                    "INSERT INTO activity_events (id, kind, opportunity_id, actor_id, correlation_id, occurred_at) VALUES (?, ?, ?, ?, ?, ?)",
                    values: [.text(event.id), .text(event.kind), event.opportunityID.map(DatabaseValue.text) ?? .null, .text(event.actorID), .text(event.correlationID), .real(event.occurredAt.timeIntervalSince1970)]
                )
                try database.execute(
                    "INSERT INTO opportunity_stage_history (id, opportunity_id, from_stage, to_stage, occurred_at) VALUES (?, ?, NULL, ?, ?)",
                    values: [.text(nextIdentifier()), .text(opportunity.id), .text(opportunity.stage.rawValue), .real(opportunity.stageChangedAt!.timeIntervalSince1970)]
                )
                if opportunity.responseState != .noResponseRecorded {
                    let responseDate = command.responseEffectiveDate!
                    try database.execute("INSERT INTO opportunity_response_history (id, opportunity_id, from_state, to_state, occurred_at) VALUES (?, ?, ?, ?, ?)", values: [.text(nextIdentifier()), .text(opportunity.id), .text(ResponseState.noResponseRecorded.rawValue), .text(opportunity.responseState.rawValue), .real(responseDate.timeIntervalSince1970)])
                    try appendActivity(kind: "opportunity_response_changed", opportunityID: opportunity.id, occurredAt: commandNow)
                }
            }
            return opportunity
        }
    }

    func opportunities() throws -> [Opportunity] {
        try synchronized {
            try database.rows(opportunitySelect + " FROM opportunities WHERE deleted_at IS NULL ORDER BY created_at, id").map(opportunity(from:))
        }
    }

    func csvImportPlan(for preview: CSVImportPreview) throws -> [CSVImportPlanRow] {
        try synchronized {
            return try preview.rows.filter(\.isValid).map { row in
                let command = row.opportunity!
                let all = try database.rows(opportunitySelect + " FROM opportunities WHERE deleted_at IS NULL").map(opportunity(from:))
                let canonicalURL = command.jobURL.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let urlCandidates = canonicalURL.isEmpty ? [] : all.filter { !$0.jobURL.isEmpty && $0.jobURL.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == canonicalURL }.sorted { $0.id < $1.id }
                let titleCandidates = all.filter { normalizedOpportunityKey(title: command.title, company: command.company) == normalizedOpportunityKey(title: $0.title, company: $0.company) }.sorted { $0.id < $1.id }
                let candidate = (urlCandidates.isEmpty ? titleCandidates : urlCandidates).first
                let rationale: String? = candidate.map { !canonicalURL.isEmpty && canonicalURL == $0.jobURL.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ? "Exact job URL" : "Matching title and company" }
                let values: [CSVImportField: String] = candidate.map { [.jobURL: $0.jobURL, .jobDescription: $0.jobDescription, .notes: $0.notes, .compensation: $0.compensation ?? "", .location: $0.location ?? "", .workArrangement: $0.workArrangement.rawValue, .stage: $0.stage.rawValue, .stageDate: $0.stageChangedAt?.ISO8601Format().prefix(10).description ?? "", .nextAction: $0.nextAction, .dueDate: $0.dueAt?.ISO8601Format().prefix(10).description ?? "", .applicationDate: $0.applicationDate?.ISO8601Format().prefix(10).description ?? "", .responseState: $0.responseState.rawValue] } ?? [:]
                return CSVImportPlanRow(row: row, candidateID: candidate?.id, duplicateRationale: rationale, candidateTitle: candidate?.title, candidateCompany: candidate?.company, candidateValues: values, decision: candidate == nil ? .create : nil)
            }
        }
    }

    func importCSV(_ rows: [CSVImportPlanRow], invalidCount: Int, invalidRows: [CSVImportRow] = [], sourceBasename: String = "CSV import", mapping: [CSVImportField: Int] = [:]) throws -> CSVImportReport {
        let commandNow = clock()
        return try synchronized {
            guard rows.allSatisfy({ row in
                guard let decision = row.decision else { return false }
                if decision == .updateSelectedFields { return row.candidateID != nil && !row.selectedFields.isEmpty && selectedFieldsAreCoupled(row.selectedFields) && row.selectedFields.allSatisfy { !(row.row.values[$0] ?? "").isEmpty } }
                if decision == .create { return row.candidateID == nil }
                return true
            }) else { throw WorkspaceStoreError.unresolvedImportDecision }
            let created = rows.filter { $0.decision == .create }.count
            let kept = rows.filter { $0.decision == .keepSeparate }.count
            let updated = rows.filter { $0.decision == .updateSelectedFields }.count
            let skipped = rows.filter { $0.decision == .skip }.count
            let summary = mapping.sorted { $0.key.rawValue < $1.key.rawValue }.map { "\($0.key.rawValue)=\($0.value)" }.joined(separator: ",")
            let report = CSVImportReport(id: nextIdentifier(), importedCount: created, updatedCount: updated, skippedCount: skipped, duplicateKeptCount: kept, invalidCount: invalidCount, sourceBasename: sourceBasename, mappingSummary: summary, createdAt: commandNow)
            try database.transaction {
                try database.execute("INSERT INTO import_reports (id, imported_count, updated_count, skipped_count, duplicate_kept_count, invalid_count, failed_count, source_basename, mapping_summary, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", values: [.text(report.id), .integer(Int64(report.importedCount)), .integer(Int64(report.updatedCount)), .integer(Int64(report.skippedCount)), .integer(Int64(report.duplicateKeptCount)), .integer(Int64(report.invalidCount)), .integer(Int64(report.failedCount)), .text(report.sourceBasename), .text(report.mappingSummary), .real(commandNow.timeIntervalSince1970)])
                for planRow in rows {
                    if planRow.decision == .skip {
                        if failBeforeActivityInsert { throw WorkspaceStoreError.injectedFailure }
                        try appendActivity(kind: "csv_import_row_\(planRow.row.sourceRow)_skipped", opportunityID: nil, occurredAt: commandNow)
                        try insertImportReportRow(reportID: report.id, planRow: planRow, outcome: "skipped", opportunityID: nil)
                        continue
                    }
                    if planRow.decision == .updateSelectedFields, let candidateID = planRow.candidateID {
                        try applyImportUpdate(id: candidateID, row: planRow, commandNow: commandNow)
                        if failBeforeActivityInsert { throw WorkspaceStoreError.injectedFailure }
                        try appendActivity(kind: "csv_import_row_\(planRow.row.sourceRow)_updated", opportunityID: candidateID, occurredAt: commandNow)
                        try insertImportReportRow(reportID: report.id, planRow: planRow, outcome: "updated", opportunityID: candidateID)
                        continue
                    }
                    let command = planRow.row.opportunity!
                    let opportunity = Opportunity(id: nextIdentifier(), title: command.title.trimmingCharacters(in: .whitespacesAndNewlines), company: command.company.trimmingCharacters(in: .whitespacesAndNewlines), createdAt: commandNow, stage: command.stage, nextAction: command.nextAction, dueAt: command.dueAt, jobURL: command.jobURL.trimmingCharacters(in: .whitespacesAndNewlines), jobDescription: command.jobDescription.trimmingCharacters(in: .whitespacesAndNewlines), notes: command.notes.trimmingCharacters(in: .whitespacesAndNewlines), compensation: command.compensation, location: command.location, workArrangement: command.workArrangement, applicationDate: command.applicationDate, responseState: command.responseState, stageChangedAt: command.stageChangedAt ?? commandNow)
                    try database.execute("INSERT INTO opportunities (id, title, company, created_at, stage, next_action, due_at, job_url, job_description, notes, compensation, location, work_arrangement, application_date, response_state, stage_changed_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", values: opportunityValues(opportunity))
                    if !opportunity.nextAction.isEmpty { try database.execute("INSERT INTO task_reminders (id, opportunity_id, title, due_at) VALUES (?, ?, ?, ?)", values: [.text(nextIdentifier()), .text(opportunity.id), .text(opportunity.nextAction), opportunity.dueAt.map { .real($0.timeIntervalSince1970) } ?? .null]) }
                    if failBeforeActivityInsert { throw WorkspaceStoreError.injectedFailure }
                    try appendActivity(kind: "csv_import_row_\(planRow.row.sourceRow)_\(planRow.decision == .keepSeparate ? "kept_separate" : "created")", opportunityID: opportunity.id, occurredAt: commandNow)
                    try database.execute("INSERT INTO opportunity_stage_history (id, opportunity_id, from_stage, to_stage, occurred_at) VALUES (?, ?, ?, ?, ?)", values: [.text(nextIdentifier()), .text(opportunity.id), .null, .text(opportunity.stage.rawValue), .real(opportunity.stageChangedAt!.timeIntervalSince1970)])
                    if opportunity.responseState != .noResponseRecorded, let responseDate = command.responseEffectiveDate { try database.execute("INSERT INTO opportunity_response_history (id, opportunity_id, from_state, to_state, occurred_at) VALUES (?, ?, ?, ?, ?)", values: [.text(nextIdentifier()), .text(opportunity.id), .text(ResponseState.noResponseRecorded.rawValue), .text(opportunity.responseState.rawValue), .real(responseDate.timeIntervalSince1970)]) }
                    try insertImportReportRow(reportID: report.id, planRow: planRow, outcome: planRow.decision == .keepSeparate ? "kept_separate" : "created", opportunityID: opportunity.id)
                }
                for invalid in invalidRows where !invalid.isValid {
                    try database.execute("INSERT INTO import_report_rows (id, report_id, source_row, outcome, reason, duplicate_rationale, opportunity_id) VALUES (?, ?, ?, 'invalid', ?, '', NULL)", values: [.text(nextIdentifier()), .text(report.id), .integer(Int64(invalid.sourceRow)), .text(invalid.reasons.joined(separator: " "))])
                }
                try appendActivity(kind: "csv_import_batch_completed", opportunityID: nil, occurredAt: commandNow)
            }
            return report
        }
    }

    func importReports() throws -> [CSVImportReport] {
        try synchronized {
            try database.rows("SELECT id, imported_count, updated_count, skipped_count, duplicate_kept_count, invalid_count, failed_count, source_basename, mapping_summary, created_at FROM import_reports ORDER BY created_at, id").map(importReport(from:))
        }
    }

    func importReportRows(for reportID: String) throws -> [CSVImportReportRow] {
        try synchronized {
            try database.rows("SELECT id, source_row, outcome, reason, duplicate_rationale, opportunity_id FROM import_report_rows WHERE report_id = ? ORDER BY source_row, id", values: [.text(reportID)]).map(importReportRow(from:))
        }
    }

    func needsAttention() throws -> [TaskReminder] {
        let readNow = clock()
        return try synchronized {
            let calendar = Calendar(identifier: .gregorian)
            let startOfToday = calendar.startOfDay(for: readNow)
            let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday)!
            return try database.rows("SELECT task_reminders.id, task_reminders.opportunity_id, task_reminders.title, task_reminders.due_at, task_reminders.is_complete FROM task_reminders JOIN opportunities ON opportunities.id = task_reminders.opportunity_id WHERE task_reminders.is_complete = 0 AND opportunities.deleted_at IS NULL AND opportunities.stage != 'Closed' ORDER BY CASE WHEN task_reminders.due_at IS NULL THEN 4 WHEN task_reminders.due_at < ? THEN 1 WHEN task_reminders.due_at < ? THEN 2 ELSE 3 END, task_reminders.due_at, task_reminders.id", values: [.real(startOfToday.timeIntervalSince1970), .real(startOfTomorrow.timeIntervalSince1970)]).map(task(from:))
        }
    }

    func latestTask(forOpportunityID opportunityID: String) throws -> TaskReminder? {
        try synchronized {
            try database.rows(
                "SELECT task_reminders.id, task_reminders.opportunity_id, task_reminders.title, task_reminders.due_at, task_reminders.is_complete FROM task_reminders JOIN opportunities ON opportunities.id = task_reminders.opportunity_id WHERE task_reminders.opportunity_id = ? AND opportunities.deleted_at IS NULL ORDER BY task_reminders.rowid DESC LIMIT 1",
                values: [.text(opportunityID)]
            ).first.map(task(from:))
        }
    }

    func deleteOpportunity(id: String) throws {
        let commandNow = clock()
        try synchronized {
            guard try isActiveOpportunity(id) else { throw WorkspaceStoreError.unexpectedDatabaseValue }
            let reference = try deletedOpportunityReferenceUnlocked(for: id)
            let event = ActivityEvent(id: nextIdentifier(), kind: "opportunity_deleted", opportunityID: id, actorID: actorID, correlationID: correlationID, occurredAt: commandNow)
            try database.transaction {
                try database.execute("UPDATE opportunities SET deleted_at = ? WHERE id = ?", values: [.real(commandNow.timeIntervalSince1970), .text(id)])
                try database.execute("DELETE FROM task_reminders WHERE opportunity_id = ?", values: [.text(id)])
                try database.execute(
                    "INSERT INTO deletion_tombstones (subject_id, subject_type, deleted_at, display_value) VALUES (?, 'opportunity', ?, ?)",
                    values: [.text(id), .real(commandNow.timeIntervalSince1970), .text("Deleted opportunity #\(reference)")]
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
        let commandNow = clock()
        try synchronized {
            let opportunityID = try activeTaskOpportunityID(id)
            let event = ActivityEvent(id: nextIdentifier(), kind: "task_completed", opportunityID: opportunityID, actorID: actorID, correlationID: correlationID, occurredAt: commandNow)
            try database.transaction {
                try database.execute("UPDATE task_reminders SET is_complete = 1 WHERE id = ?", values: [.text(id)])
                try database.execute("INSERT INTO activity_events (id, kind, opportunity_id, actor_id, correlation_id, occurred_at) VALUES (?, ?, ?, ?, ?, ?)", values: [.text(event.id), .text(event.kind), event.opportunityID.map(DatabaseValue.text) ?? .null, .text(event.actorID), .text(event.correlationID), .real(event.occurredAt.timeIntervalSince1970)])
            }
        }
    }

    func openTask(id: String) throws {
        let commandNow = clock()
        try synchronized {
            let opportunityID = try activeTaskOpportunityID(id)
            let event = ActivityEvent(id: nextIdentifier(), kind: "task_opened", opportunityID: opportunityID, actorID: actorID, correlationID: correlationID, occurredAt: commandNow)
            try database.transaction {
                try database.execute("INSERT INTO activity_events (id, kind, opportunity_id, actor_id, correlation_id, occurred_at) VALUES (?, ?, ?, ?, ?, ?)", values: [.text(event.id), .text(event.kind), .text(opportunityID), .text(event.actorID), .text(event.correlationID), .real(event.occurredAt.timeIntervalSince1970)])
            }
        }
    }

    func rescheduleTask(id: String, dueAt: Date) throws {
        let commandNow = clock()
        try synchronized {
            let opportunityID = try activeTaskOpportunityID(id)
            let event = ActivityEvent(id: nextIdentifier(), kind: "task_rescheduled", opportunityID: opportunityID, actorID: actorID, correlationID: correlationID, occurredAt: commandNow)
            try database.transaction {
                try database.execute("UPDATE task_reminders SET due_at = ? WHERE id = ?", values: [.real(dueAt.timeIntervalSince1970), .text(id)])
                try database.execute("INSERT INTO activity_events (id, kind, opportunity_id, actor_id, correlation_id, occurred_at) VALUES (?, ?, ?, ?, ?, ?)", values: [.text(event.id), .text(event.kind), event.opportunityID.map(DatabaseValue.text) ?? .null, .text(event.actorID), .text(event.correlationID), .real(event.occurredAt.timeIntervalSince1970)])
            }
        }
    }

    func snoozeTask(id: String) throws {
        let commandNow = clock()
        try synchronized {
            let opportunityID = try activeTaskOpportunityID(id)
            let snoozedDueAt = commandNow.addingTimeInterval(86_400)
            let event = ActivityEvent(id: nextIdentifier(), kind: "task_snoozed", opportunityID: opportunityID, actorID: actorID, correlationID: correlationID, occurredAt: commandNow)
            try database.transaction {
                try database.execute("UPDATE task_reminders SET due_at = ? WHERE id = ?", values: [.real(snoozedDueAt.timeIntervalSince1970), .text(id)])
                try database.execute("INSERT INTO activity_events (id, kind, opportunity_id, actor_id, correlation_id, occurred_at) VALUES (?, ?, ?, ?, ?, ?)", values: [.text(event.id), .text(event.kind), event.opportunityID.map(DatabaseValue.text) ?? .null, .text(event.actorID), .text(event.correlationID), .real(event.occurredAt.timeIntervalSince1970)])
            }
        }
    }

    func changeStage(opportunityID: String, to stage: PipelineStage) throws {
        let commandNow = clock()
        try synchronized {
            guard try isActiveOpportunity(opportunityID) else { throw WorkspaceStoreError.unexpectedDatabaseValue }
            let currentStage = try activeOpportunityStage(id: opportunityID)
            guard currentStage != stage else { return }
            let event = ActivityEvent(id: nextIdentifier(), kind: "opportunity_stage_changed", opportunityID: opportunityID, actorID: actorID, correlationID: correlationID, occurredAt: commandNow)
            try database.transaction {
                try database.execute("UPDATE opportunities SET stage = ?, stage_changed_at = ? WHERE id = ?", values: [.text(stage.rawValue), .real(commandNow.timeIntervalSince1970), .text(opportunityID)])
                try database.execute("INSERT INTO activity_events (id, kind, opportunity_id, actor_id, correlation_id, occurred_at) VALUES (?, ?, ?, ?, ?, ?)", values: [.text(event.id), .text(event.kind), event.opportunityID.map(DatabaseValue.text) ?? .null, .text(event.actorID), .text(event.correlationID), .real(event.occurredAt.timeIntervalSince1970)])
                try database.execute("INSERT INTO opportunity_stage_history (id, opportunity_id, from_stage, to_stage, occurred_at) VALUES (?, ?, ?, ?, ?)", values: [.text(nextIdentifier()), .text(opportunityID), .text(currentStage.rawValue), .text(stage.rawValue), .real(commandNow.timeIntervalSince1970)])
            }
        }
    }

    func updateOpportunity(
        id: String,
        title: String,
        company: String,
        stage: PipelineStage,
        nextAction: String,
        dueAt: Date?,
        jobURL: String = "",
        jobDescription: String = "",
        notes: String = "",
        compensation: String? = nil,
        location: String? = nil,
        workArrangement: WorkArrangement = .notSpecified,
        applicationDate: Date? = nil,
        responseState: ResponseState = .noResponseRecorded,
        responseEffectiveDate: Date? = nil,
        stageChangedAt: Date? = nil
    ) throws {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let company = company.trimmingCharacters(in: .whitespacesAndNewlines)
        let nextAction = nextAction.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, !company.isEmpty else { throw WorkspaceStoreError.invalidOpportunity }
        let commandNow = clock()

        try synchronized {
            guard try isActiveOpportunity(id) else { throw WorkspaceStoreError.unexpectedDatabaseValue }
            let currentStage = try activeOpportunityStage(id: id)
            let currentResponse = try activeOpportunityResponseState(id: id)
            let didChangeStage = currentStage != stage
            let didChangeResponse = currentResponse != responseState
            guard !didChangeStage || stageChangedAt != nil,
                  !didChangeResponse || responseEffectiveDate != nil else {
                throw WorkspaceStoreError.invalidOpportunity
            }
            let event = ActivityEvent(id: nextIdentifier(), kind: didChangeStage ? "opportunity_stage_changed" : "opportunity_updated", opportunityID: id, actorID: actorID, correlationID: correlationID, occurredAt: commandNow)
            try database.transaction {
                try database.execute(
                    "UPDATE opportunities SET title = ?, company = ?, stage = ?, next_action = ?, due_at = ?, job_url = ?, job_description = ?, notes = ?, compensation = ?, location = ?, work_arrangement = ?, application_date = ?, response_state = ?, stage_changed_at = ? WHERE id = ?",
                    values: [.text(title), .text(company), .text(stage.rawValue), .text(nextAction), dueAt.map { .real($0.timeIntervalSince1970) } ?? .null, .text(jobURL.trimmingCharacters(in: .whitespacesAndNewlines)), .text(jobDescription.trimmingCharacters(in: .whitespacesAndNewlines)), .text(notes.trimmingCharacters(in: .whitespacesAndNewlines)), trimmedOptional(compensation).map(DatabaseValue.text) ?? .null, trimmedOptional(location).map(DatabaseValue.text) ?? .null, .text(workArrangement.rawValue), applicationDate.map { .real($0.timeIntervalSince1970) } ?? .null, .text(responseState.rawValue), (didChangeStage ? stageChangedAt : try currentStageChangedAt(id: id)).map { .real($0.timeIntervalSince1970) } ?? .null, .text(id)]
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
                if didChangeStage {
                    try database.execute("INSERT INTO opportunity_stage_history (id, opportunity_id, from_stage, to_stage, occurred_at) VALUES (?, ?, ?, ?, ?)", values: [.text(nextIdentifier()), .text(id), .text(currentStage.rawValue), .text(stage.rawValue), .real(stageChangedAt!.timeIntervalSince1970)])
                }
                if failBeforeActivityInsert { throw WorkspaceStoreError.injectedFailure }
                try database.execute("INSERT INTO activity_events (id, kind, opportunity_id, actor_id, correlation_id, occurred_at) VALUES (?, ?, ?, ?, ?, ?)", values: [.text(event.id), .text(event.kind), .text(id), .text(event.actorID), .text(event.correlationID), .real(event.occurredAt.timeIntervalSince1970)])
                if didChangeResponse {
                    try database.execute("INSERT INTO opportunity_response_history (id, opportunity_id, from_state, to_state, occurred_at) VALUES (?, ?, ?, ?, ?)", values: [.text(nextIdentifier()), .text(id), .text(currentResponse.rawValue), .text(responseState.rawValue), .real(responseEffectiveDate!.timeIntervalSince1970)])
                    try appendActivity(kind: "opportunity_response_changed", opportunityID: id, occurredAt: commandNow)
                }
            }
        }
    }

    func createContact(_ command: CreateContact) throws -> Contact {
        let commandNow = clock()
        let contact = try validatedContact(id: nil, command: command)
        return try synchronized {
            let contact = Contact(id: nextIdentifier(), name: contact.name, employer: contact.employer, title: contact.title, email: contact.email, profileURL: contact.profileURL, relationshipContext: contact.relationshipContext, notes: contact.notes)
            try database.transaction {
                try database.execute("INSERT INTO contacts (id, name, employer, title, email, profile_url, relationship_context, notes) VALUES (?, ?, ?, ?, ?, ?, ?, ?)", values: [.text(contact.id), .text(contact.name), .text(contact.employer), .text(contact.title), .text(contact.email), .text(contact.profileURL), .text(contact.relationshipContext), .text(contact.notes)])
                try appendActivity(kind: "contact_created", opportunityID: nil, contactID: contact.id, occurredAt: commandNow)
            }
            return contact
        }
    }

    func updateContact(id: String, command: CreateContact) throws -> Contact {
        let commandNow = clock()
        let contact = try validatedContact(id: id, command: command)
        return try synchronized {
            guard try isActiveContact(id) else { throw WorkspaceStoreError.unexpectedDatabaseValue }
            try database.transaction {
                try database.execute("UPDATE contacts SET name = ?, employer = ?, title = ?, email = ?, profile_url = ?, relationship_context = ?, notes = ? WHERE id = ?", values: [.text(contact.name), .text(contact.employer), .text(contact.title), .text(contact.email), .text(contact.profileURL), .text(contact.relationshipContext), .text(contact.notes), .text(id)])
                try appendActivity(kind: "contact_updated", opportunityID: nil, contactID: id, occurredAt: commandNow)
            }
            return contact
        }
    }

    func deleteContact(id: String) throws {
        let commandNow = clock()
        try synchronized {
            guard try isActiveContact(id) else { throw WorkspaceStoreError.unexpectedDatabaseValue }
            let reference = try deletedContactReferenceUnlocked(for: id)
            try database.transaction {
                try database.execute("UPDATE contacts SET deleted_at = ? WHERE id = ?", values: [.real(commandNow.timeIntervalSince1970), .text(id)])
                try database.execute("INSERT INTO deletion_tombstones (subject_id, subject_type, deleted_at, display_value) VALUES (?, 'contact', ?, ?)", values: [.text(id), .real(commandNow.timeIntervalSince1970), .text("Deleted contact #\(reference)")])
                try appendActivity(kind: "contact_deleted", opportunityID: nil, contactID: id, occurredAt: commandNow)
            }
        }
    }

    func linkContact(contactID: String, toOpportunityID opportunityID: String) throws {
        let commandNow = clock()
        try synchronized {
            guard try isActiveOpportunity(opportunityID) else { throw WorkspaceStoreError.unexpectedDatabaseValue }
            guard try isActiveContact(contactID) else { throw WorkspaceStoreError.unexpectedDatabaseValue }
            guard (try database.rows("SELECT contact_id FROM contact_opportunities WHERE contact_id = ? AND opportunity_id = ?", values: [.text(contactID), .text(opportunityID)])).isEmpty else { return }
            try database.transaction {
                try database.execute("INSERT INTO contact_opportunities (contact_id, opportunity_id) VALUES (?, ?)", values: [.text(contactID), .text(opportunityID)])
                try appendActivity(kind: "contact_linked", opportunityID: opportunityID, contactID: contactID, occurredAt: commandNow)
            }
        }
    }

    func unlinkContact(contactID: String, fromOpportunityID opportunityID: String) throws {
        let commandNow = clock()
        try synchronized {
            guard try isActiveOpportunity(opportunityID), try isActiveContact(contactID) else { throw WorkspaceStoreError.unexpectedDatabaseValue }
            guard !(try database.rows("SELECT contact_id FROM contact_opportunities WHERE contact_id = ? AND opportunity_id = ?", values: [.text(contactID), .text(opportunityID)])).isEmpty else { return }
            try database.transaction {
                try database.execute("DELETE FROM contact_opportunities WHERE contact_id = ? AND opportunity_id = ?", values: [.text(contactID), .text(opportunityID)])
                try appendActivity(kind: "contact_unlinked", opportunityID: opportunityID, contactID: contactID, occurredAt: commandNow)
            }
        }
    }

    func contacts(forOpportunityID opportunityID: String) throws -> [Contact] {
        try synchronized {
            guard try isActiveOpportunity(opportunityID) else { return [] }
            return try database.rows("SELECT contacts.id, contacts.name, contacts.employer, contacts.title, contacts.email, contacts.profile_url, contacts.relationship_context, contacts.notes FROM contacts JOIN contact_opportunities ON contacts.id = contact_opportunities.contact_id WHERE contact_opportunities.opportunity_id = ? AND contacts.deleted_at IS NULL ORDER BY contacts.name, contacts.id", values: [.text(opportunityID)]).map(contact(from:))
        }
    }

    func contacts() throws -> [Contact] {
        try synchronized {
            try database.rows("SELECT id, name, employer, title, email, profile_url, relationship_context, notes FROM contacts WHERE deleted_at IS NULL ORDER BY name, id").map(contact(from:))
        }
    }

    func sameEmployerContacts(forOpportunityID opportunityID: String) throws -> [Contact] {
        try synchronized {
            guard try isActiveOpportunity(opportunityID) else { return [] }
            return try database.rows("SELECT contacts.id, contacts.name, contacts.employer, contacts.title, contacts.email, contacts.profile_url, contacts.relationship_context, contacts.notes FROM contacts JOIN opportunities ON lower(trim(contacts.employer)) = lower(trim(opportunities.company)) WHERE opportunities.id = ? AND contacts.deleted_at IS NULL AND trim(contacts.employer) != '' AND NOT EXISTS (SELECT 1 FROM contact_opportunities WHERE contact_opportunities.contact_id = contacts.id AND contact_opportunities.opportunity_id = opportunities.id) ORDER BY contacts.name, contacts.id", values: [.text(opportunityID)]).map(contact(from:))
        }
    }

    func opportunities(forContactID contactID: String) throws -> [Opportunity] {
        try synchronized {
            guard try isActiveContact(contactID) else { return [] }
            return try database.rows("SELECT opportunities.id, opportunities.title, opportunities.company, opportunities.created_at, opportunities.stage, opportunities.next_action, opportunities.due_at, opportunities.job_url, opportunities.job_description, opportunities.notes, opportunities.compensation, opportunities.location, opportunities.work_arrangement, opportunities.application_date, opportunities.response_state, opportunities.stage_changed_at FROM opportunities JOIN contact_opportunities ON opportunities.id = contact_opportunities.opportunity_id WHERE contact_opportunities.contact_id = ? AND opportunities.deleted_at IS NULL ORDER BY opportunities.company, opportunities.title, opportunities.id", values: [.text(contactID)]).map(opportunity(from:))
        }
    }

    func interactions(forOpportunityID opportunityID: String) throws -> [Interaction] {
        try synchronized {
            guard try isActiveOpportunity(opportunityID) else { return [] }
            return try database.rows("SELECT id, opportunity_id, summary, occurred_at FROM interactions WHERE opportunity_id = ? ORDER BY occurred_at, id", values: [.text(opportunityID)]).map(interaction(from:))
        }
    }

    func recordContactInteraction(_ command: CreateContactInteraction) throws -> ContactInteraction {
        let commandNow = clock()
        let summary = command.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !summary.isEmpty, command.nextTouchAt.map({ $0 >= command.occurredAt }) ?? true else {
            throw WorkspaceStoreError.invalidInteraction
        }
        return try synchronized {
            guard try isActiveContact(command.contactID) else { throw WorkspaceStoreError.unexpectedDatabaseValue }
            if let opportunityID = command.opportunityID {
                guard try isActiveOpportunity(opportunityID),
                      !(try database.rows("SELECT contact_id FROM contact_opportunities WHERE contact_id = ? AND opportunity_id = ?", values: [.text(command.contactID), .text(opportunityID)])).isEmpty else {
                    throw WorkspaceStoreError.invalidInteraction
                }
            }
            let interaction = ContactInteraction(id: nextIdentifier(), contactID: command.contactID, opportunityID: command.opportunityID, kind: command.kind, summary: summary, occurredAt: command.occurredAt, nextTouchAt: command.nextTouchAt)
            try database.transaction {
                try database.execute("INSERT INTO interactions (id, contact_id, opportunity_id, kind, summary, occurred_at, next_touch_at) VALUES (?, ?, ?, ?, ?, ?, ?)", values: [.text(interaction.id), .text(interaction.contactID), interaction.opportunityID.map(DatabaseValue.text) ?? .null, .text(interaction.kind.rawValue), .text(interaction.summary), .real(interaction.occurredAt.timeIntervalSince1970), interaction.nextTouchAt.map { .real($0.timeIntervalSince1970) } ?? .null])
                try appendActivity(kind: "interaction_recorded", opportunityID: interaction.opportunityID, contactID: interaction.contactID, occurredAt: commandNow)
            }
            return interaction
        }
    }

    func contactInteractions(forContactID contactID: String) throws -> [ContactInteraction] {
        try synchronized {
            guard try isActiveContact(contactID) else { return [] }
            return try database.rows("SELECT id, contact_id, opportunity_id, kind, summary, occurred_at, next_touch_at FROM interactions WHERE contact_id = ? ORDER BY occurred_at DESC, id DESC", values: [.text(contactID)]).map(contactInteraction(from:))
        }
    }

    func opportunityInteractions(forOpportunityID opportunityID: String) throws -> [OpportunityInteraction] {
        try synchronized {
            guard try isActiveOpportunity(opportunityID) else { return [] }
            return try database.rows("SELECT interactions.id, interactions.contact_id, contacts.name, interactions.kind, interactions.summary, interactions.occurred_at, interactions.next_touch_at FROM interactions LEFT JOIN contacts ON contacts.id = interactions.contact_id WHERE interactions.opportunity_id = ? AND (interactions.contact_id IS NULL OR contacts.deleted_at IS NULL) ORDER BY interactions.occurred_at DESC, interactions.id DESC", values: [.text(opportunityID)]).map(opportunityInteraction(from:))
        }
    }

    func recordPostingCheck(_ command: RecordPostingCheck) throws -> PostingCheck {
        let commandNow = clock()
        let url = command.url.trimmingCharacters(in: .whitespacesAndNewlines)
        let evidence = command.evidence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty, !evidence.isEmpty else { throw WorkspaceStoreError.invalidPostingCheck }
        return try synchronized {
            guard try isActiveOpportunity(command.opportunityID) else { throw WorkspaceStoreError.unexpectedDatabaseValue }
            let check = PostingCheck(id: nextIdentifier(), opportunityID: command.opportunityID, url: url, status: command.status, evidence: evidence, checkedAt: commandNow)
            try database.transaction {
                try database.execute("INSERT INTO posting_checks (id, opportunity_id, url, status, evidence, checked_at) VALUES (?, ?, ?, ?, ?, ?)", values: [.text(check.id), .text(check.opportunityID), .text(check.url), .text(check.status.rawValue), .text(check.evidence), .real(check.checkedAt.timeIntervalSince1970)])
                try appendActivity(kind: "posting_checked", opportunityID: check.opportunityID, occurredAt: commandNow)
            }
            return check
        }
    }

    func postingChecks(forOpportunityID opportunityID: String) throws -> [PostingCheck] {
        try synchronized {
            guard try isActiveOpportunity(opportunityID) else { return [] }
            return try database.rows("SELECT id, opportunity_id, url, status, evidence, checked_at FROM posting_checks WHERE opportunity_id = ? ORDER BY checked_at DESC, id DESC", values: [.text(opportunityID)]).map(postingCheck(from:))
        }
    }

    func recordOpportunitiesExport() throws {
        let commandNow = clock()
        try synchronized {
            try database.transaction {
                try appendActivity(kind: "opportunities_exported", opportunityID: nil, occurredAt: commandNow)
            }
        }
    }

    func createEncryptedBackup(at destinationURL: URL) throws {
        let commandNow = clock()
        try synchronized {
            try database.createEncryptedBackup(at: destinationURL)
            try database.transaction {
                try appendActivity(kind: "workspace_backed_up", opportunityID: nil, occurredAt: commandNow)
            }
        }
    }

    func recordDocumentReference(_ command: RecordDocumentReference) throws -> DocumentReference {
        let commandNow = clock()
        let filename = command.filename.trimmingCharacters(in: .whitespacesAndNewlines)
        let sourceHash = command.sourceHash.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !filename.isEmpty, !sourceHash.isEmpty, command.byteCount >= 0 else { throw WorkspaceStoreError.invalidDocumentReference }
        return try synchronized {
            guard try isActiveOpportunity(command.opportunityID) else { throw WorkspaceStoreError.unexpectedDatabaseValue }
            let reference = DocumentReference(id: nextIdentifier(), opportunityID: command.opportunityID, kind: command.kind, filename: filename, contentType: command.contentType, sourceHash: sourceHash, byteCount: command.byteCount, attachedAt: commandNow, finalSentAt: nil)
            try database.transaction {
                try database.execute("INSERT INTO document_references (id, opportunity_id, kind, filename, content_type, source_hash, byte_count, attached_at, final_sent_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, NULL)", values: [.text(reference.id), .text(reference.opportunityID), .text(reference.kind.rawValue), .text(reference.filename), .text(reference.contentType), .text(reference.sourceHash), .integer(Int64(reference.byteCount)), .real(reference.attachedAt.timeIntervalSince1970)])
                try appendActivity(kind: "document_reference_linked", opportunityID: reference.opportunityID, occurredAt: commandNow)
            }
            return reference
        }
    }

    func markDocumentReferenceFinalSent(id: String) throws {
        let commandNow = clock()
        try synchronized {
            let rows = try database.rows("SELECT opportunity_id FROM document_references WHERE id = ? AND final_sent_at IS NULL", values: [.text(id)])
            guard let row = rows.first, case let .text(opportunityID) = row.first else { throw WorkspaceStoreError.unexpectedDatabaseValue }
            try database.transaction {
                try database.execute("UPDATE document_references SET final_sent_at = ? WHERE id = ?", values: [.real(commandNow.timeIntervalSince1970), .text(id)])
                try appendActivity(kind: "document_reference_marked_final", opportunityID: opportunityID, occurredAt: commandNow)
            }
        }
    }

    func documentReferences(forOpportunityID opportunityID: String) throws -> [DocumentReference] {
        try synchronized {
            guard try isActiveOpportunity(opportunityID) else { return [] }
            return try database.rows("SELECT id, opportunity_id, kind, filename, content_type, source_hash, byte_count, attached_at, final_sent_at FROM document_references WHERE opportunity_id = ? ORDER BY attached_at DESC, id DESC", values: [.text(opportunityID)]).map(documentReference(from:))
        }
    }

    func lastTouch(forContactID contactID: String) throws -> Date? {
        try contactInteractions(forContactID: contactID).map(\.occurredAt).max()
    }

    func nextTouch(forContactID contactID: String) throws -> Date? {
        try contactInteractions(forContactID: contactID).compactMap(\.nextTouchAt).min()
    }

    func activityEvents() throws -> [ActivityEvent] {
        try synchronized {
            try database.rows("SELECT id, kind, opportunity_id, contact_id, actor_id, correlation_id, occurred_at FROM activity_events ORDER BY occurred_at, rowid").map(activityEvent(from:))
        }
    }

    func stageHistory(forOpportunityID opportunityID: String) throws -> [StageHistoryEntry] {
        try synchronized {
            try database.rows("SELECT id, opportunity_id, from_stage, to_stage, occurred_at FROM opportunity_stage_history WHERE opportunity_id = ? ORDER BY occurred_at ASC, id ASC", values: [.text(opportunityID)]).map(stageHistoryEntry(from:))
        }
    }

    func responseHistory(forOpportunityID opportunityID: String) throws -> [ResponseHistoryEntry] {
        try synchronized {
            try database.rows("SELECT id, opportunity_id, from_state, to_state, occurred_at FROM opportunity_response_history WHERE opportunity_id = ? ORDER BY occurred_at DESC, id DESC", values: [.text(opportunityID)]).map(responseHistoryEntry(from:))
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

    private func activeOpportunityStage(id: String) throws -> PipelineStage {
        guard case let .text(stageValue)? = try database.rows("SELECT stage FROM opportunities WHERE id = ? AND deleted_at IS NULL", values: [.text(id)]).first?.first,
              let stage = PipelineStage(rawValue: stageValue) else {
            throw WorkspaceStoreError.unexpectedDatabaseValue
        }
        return stage
    }

    private func activeOpportunityResponseState(id: String) throws -> ResponseState {
        guard case let .text(value)? = try database.rows("SELECT response_state FROM opportunities WHERE id = ? AND deleted_at IS NULL", values: [.text(id)]).first?.first,
              let state = ResponseState(rawValue: value) else { throw WorkspaceStoreError.unexpectedDatabaseValue }
        return state
    }

    private func currentStageChangedAt(id: String) throws -> Date? {
        guard let value = try database.rows("SELECT stage_changed_at FROM opportunities WHERE id = ? AND deleted_at IS NULL", values: [.text(id)]).first?.first else { throw WorkspaceStoreError.unexpectedDatabaseValue }
        if case let .real(date) = value { return Date(timeIntervalSince1970: date) }
        return nil
    }

    private var opportunitySelect: String {
        "SELECT id, title, company, created_at, stage, next_action, due_at, job_url, job_description, notes, compensation, location, work_arrangement, application_date, response_state, stage_changed_at"
    }

    private func opportunityValues(_ opportunity: Opportunity) -> [DatabaseValue] {
        [.text(opportunity.id), .text(opportunity.title), .text(opportunity.company), .real(opportunity.createdAt.timeIntervalSince1970), .text(opportunity.stage.rawValue), .text(opportunity.nextAction), opportunity.dueAt.map { .real($0.timeIntervalSince1970) } ?? .null, .text(opportunity.jobURL), .text(opportunity.jobDescription), .text(opportunity.notes), opportunity.compensation.map(DatabaseValue.text) ?? .null, opportunity.location.map(DatabaseValue.text) ?? .null, .text(opportunity.workArrangement.rawValue), opportunity.applicationDate.map { .real($0.timeIntervalSince1970) } ?? .null, .text(opportunity.responseState.rawValue), opportunity.stageChangedAt.map { .real($0.timeIntervalSince1970) } ?? .null]
    }

    private func trimmedOptional(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func isActiveOpportunity(_ id: String) throws -> Bool {
        guard case .text? = try database.rows("SELECT id FROM opportunities WHERE id = ? AND deleted_at IS NULL", values: [.text(id)]).first?.first else { return false }
        return true
    }

    private func isActiveContact(_ id: String) throws -> Bool {
        guard case .text? = try database.rows("SELECT id FROM contacts WHERE id = ? AND deleted_at IS NULL", values: [.text(id)]).first?.first else { return false }
        return true
    }

    private func validatedContact(id: String?, command: CreateContact) throws -> Contact {
        let name = command.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw WorkspaceStoreError.invalidContact }
        return Contact(
            id: id ?? "",
            name: name,
            employer: command.employer.trimmingCharacters(in: .whitespacesAndNewlines),
            title: command.title.trimmingCharacters(in: .whitespacesAndNewlines),
            email: command.email.trimmingCharacters(in: .whitespacesAndNewlines),
            profileURL: command.profileURL.trimmingCharacters(in: .whitespacesAndNewlines),
            relationshipContext: command.relationshipContext.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: command.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private func normalizedOpportunityKey(title: String, company: String) -> String {
        "\(title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())\u{1F}\(company.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())"
    }

    private func insertImportReportRow(reportID: String, planRow: CSVImportPlanRow, outcome: String, opportunityID: String?) throws {
        try database.execute("INSERT INTO import_report_rows (id, report_id, source_row, outcome, reason, duplicate_rationale, opportunity_id) VALUES (?, ?, ?, ?, ?, ?, ?)", values: [.text(nextIdentifier()), .text(reportID), .integer(Int64(planRow.row.sourceRow)), .text(outcome), .text(planRow.row.reasons.joined(separator: " ")), .text(planRow.duplicateRationale ?? ""), opportunityID.map(DatabaseValue.text) ?? .null])
    }

    private func selectedFieldsAreCoupled(_ fields: Set<CSVImportField>) -> Bool {
        if fields.contains(.stageDate) && !fields.contains(.stage) { return false }
        if fields.contains(.dueDate) && !fields.contains(.nextAction) { return false }
        if fields.contains(.responseDate) != fields.contains(.responseState) { return false }
        return true
    }

    private func applyImportUpdate(id: String, row: CSVImportPlanRow, commandNow: Date) throws {
        guard let imported = row.row.opportunity else { throw WorkspaceStoreError.invalidOpportunity }
        guard let existing = try database.rows(opportunitySelect + " FROM opportunities WHERE id = ? AND deleted_at IS NULL", values: [.text(id)]).first.map(opportunity(from:)) else { throw WorkspaceStoreError.unexpectedDatabaseValue }
        let fields = row.selectedFields
        let nextAction = fields.contains(.nextAction) ? imported.nextAction : existing.nextAction
        let dueAt = fields.contains(.dueDate) ? imported.dueAt : existing.dueAt
        if fields.contains(.dueDate) && !nextAction.isEmpty == false && dueAt != nil { throw WorkspaceStoreError.invalidOpportunity }
        let stage = fields.contains(.stage) ? imported.stage : existing.stage
        let response = fields.contains(.responseState) ? imported.responseState : existing.responseState
        let stageDate = fields.contains(.stage) ? (imported.stageChangedAt ?? commandNow) : existing.stageChangedAt
        let responseDate = fields.contains(.responseState) ? imported.responseEffectiveDate : nil
        if response != existing.responseState && responseDate == nil { throw WorkspaceStoreError.invalidOpportunity }
        let updated = Opportunity(id: existing.id, title: existing.title, company: existing.company, createdAt: existing.createdAt, stage: stage, nextAction: nextAction, dueAt: dueAt, jobURL: fields.contains(.jobURL) ? imported.jobURL : existing.jobURL, jobDescription: fields.contains(.jobDescription) ? imported.jobDescription : existing.jobDescription, notes: fields.contains(.notes) ? imported.notes : existing.notes, compensation: fields.contains(.compensation) ? imported.compensation : existing.compensation, location: fields.contains(.location) ? imported.location : existing.location, workArrangement: fields.contains(.workArrangement) ? imported.workArrangement : existing.workArrangement, applicationDate: fields.contains(.applicationDate) ? imported.applicationDate : existing.applicationDate, responseState: response, stageChangedAt: stageDate)
        try database.execute("UPDATE opportunities SET stage = ?, next_action = ?, due_at = ?, job_url = ?, job_description = ?, notes = ?, compensation = ?, location = ?, work_arrangement = ?, application_date = ?, response_state = ?, stage_changed_at = ? WHERE id = ?", values: [.text(updated.stage.rawValue), .text(updated.nextAction), updated.dueAt.map { .real($0.timeIntervalSince1970) } ?? .null, .text(updated.jobURL), .text(updated.jobDescription), .text(updated.notes), updated.compensation.map(DatabaseValue.text) ?? .null, updated.location.map(DatabaseValue.text) ?? .null, .text(updated.workArrangement.rawValue), updated.applicationDate.map { .real($0.timeIntervalSince1970) } ?? .null, .text(updated.responseState.rawValue), updated.stageChangedAt.map { .real($0.timeIntervalSince1970) } ?? .null, .text(id)])
        if fields.contains(.nextAction) || fields.contains(.dueDate) {
            let task = try database.rows("SELECT id FROM task_reminders WHERE opportunity_id = ? AND is_complete = 0 ORDER BY id LIMIT 1", values: [.text(id)]).first?.first
            if nextAction.isEmpty { try database.execute("DELETE FROM task_reminders WHERE opportunity_id = ? AND is_complete = 0", values: [.text(id)])
            } else if case let .text(taskID)? = task { try database.execute("UPDATE task_reminders SET title = ?, due_at = ? WHERE id = ?", values: [.text(nextAction), dueAt.map { .real($0.timeIntervalSince1970) } ?? .null, .text(taskID)])
            } else { try database.execute("INSERT INTO task_reminders (id, opportunity_id, title, due_at) VALUES (?, ?, ?, ?)", values: [.text(nextIdentifier()), .text(id), .text(nextAction), dueAt.map { .real($0.timeIntervalSince1970) } ?? .null]) }
        }
        if stage != existing.stage { try database.execute("INSERT INTO opportunity_stage_history (id, opportunity_id, from_stage, to_stage, occurred_at) VALUES (?, ?, ?, ?, ?)", values: [.text(nextIdentifier()), .text(id), .text(existing.stage.rawValue), .text(stage.rawValue), .real(stageDate!.timeIntervalSince1970)]) }
        if response != existing.responseState { try database.execute("INSERT INTO opportunity_response_history (id, opportunity_id, from_state, to_state, occurred_at) VALUES (?, ?, ?, ?, ?)", values: [.text(nextIdentifier()), .text(id), .text(existing.responseState.rawValue), .text(response.rawValue), .real(responseDate!.timeIntervalSince1970)]) }
    }

    private func appendActivity(kind: String, opportunityID: String?, contactID: String? = nil, occurredAt: Date) throws {
        let event = ActivityEvent(id: nextIdentifier(), kind: kind, opportunityID: opportunityID, contactID: contactID, actorID: actorID, correlationID: correlationID, occurredAt: occurredAt)
        try database.execute("INSERT INTO activity_events (id, kind, opportunity_id, contact_id, actor_id, correlation_id, occurred_at) VALUES (?, ?, ?, ?, ?, ?, ?)", values: [.text(event.id), .text(event.kind), event.opportunityID.map(DatabaseValue.text) ?? .null, event.contactID.map(DatabaseValue.text) ?? .null, .text(event.actorID), .text(event.correlationID), .real(event.occurredAt.timeIntervalSince1970)])
    }

    private func deletedOpportunityReferenceUnlocked(for opportunityID: String) throws -> String {
        guard case let .text(workspaceID)? = try database.rows("SELECT value FROM workspace_metadata WHERE key = 'workspace_id'").first?.first else {
            throw WorkspaceStoreError.unexpectedDatabaseValue
        }
        return SHA256.hash(data: Data((workspaceID + opportunityID).utf8)).map { String(format: "%02x", $0) }.joined().prefix(12).description
    }

    private func deletedContactReferenceUnlocked(for contactID: String) throws -> String {
        guard case let .text(workspaceID)? = try database.rows("SELECT value FROM workspace_metadata WHERE key = 'workspace_id'").first?.first else {
            throw WorkspaceStoreError.unexpectedDatabaseValue
        }
        return SHA256.hash(data: Data((workspaceID + contactID).utf8)).map { String(format: "%02x", $0) }.joined().prefix(12).description
    }

    private func opportunity(from row: [DatabaseValue]) throws -> Opportunity {
        guard row.count == 16,
              case let .text(id) = row[0], case let .text(title) = row[1],
              case let .text(company) = row[2], case let .real(createdAt) = row[3], case let .text(stageValue) = row[4], let stage = PipelineStage(rawValue: stageValue), case let .text(nextAction) = row[5] else {
            throw WorkspaceStoreError.unexpectedDatabaseValue
        }
        let dueAt: Date?
        if case let .real(value) = row[6] { dueAt = Date(timeIntervalSince1970: value) } else { dueAt = nil }
        guard case let .text(jobURL) = row[7], case let .text(jobDescription) = row[8], case let .text(notes) = row[9], case let .text(workValue) = row[12], let workArrangement = WorkArrangement(rawValue: workValue), case let .text(responseValue) = row[14], let responseState = ResponseState(rawValue: responseValue) else { throw WorkspaceStoreError.unexpectedDatabaseValue }
        let compensation: String? = if case let .text(value) = row[10] { value } else { nil }
        let location: String? = if case let .text(value) = row[11] { value } else { nil }
        let applicationDate: Date? = if case let .real(value) = row[13] { Date(timeIntervalSince1970: value) } else { nil }
        let stageChangedAt: Date? = if case let .real(value) = row[15] { Date(timeIntervalSince1970: value) } else { nil }
        return Opportunity(id: id, title: title, company: company, createdAt: Date(timeIntervalSince1970: createdAt), stage: stage, nextAction: nextAction, dueAt: dueAt, jobURL: jobURL, jobDescription: jobDescription, notes: notes, compensation: compensation, location: location, workArrangement: workArrangement, applicationDate: applicationDate, responseState: responseState, stageChangedAt: stageChangedAt)
    }

    private func responseHistoryEntry(from row: [DatabaseValue]) throws -> ResponseHistoryEntry {
        guard row.count == 5, case let .text(id) = row[0], case let .text(opportunityID) = row[1], case let .text(from) = row[2], let fromState = ResponseState(rawValue: from), case let .text(to) = row[3], let toState = ResponseState(rawValue: to), case let .real(occurredAt) = row[4] else { throw WorkspaceStoreError.unexpectedDatabaseValue }
        return ResponseHistoryEntry(id: id, opportunityID: opportunityID, fromState: fromState, toState: toState, occurredAt: Date(timeIntervalSince1970: occurredAt))
    }

    private func task(from row: [DatabaseValue]) throws -> TaskReminder {
        guard row.count == 5, case let .text(id) = row[0], case let .text(opportunityID) = row[1], case let .text(title) = row[2], case let .integer(isComplete) = row[4] else { throw WorkspaceStoreError.unexpectedDatabaseValue }
        let dueAt: Date?
        if case let .real(value) = row[3] { dueAt = Date(timeIntervalSince1970: value) } else { dueAt = nil }
        return TaskReminder(id: id, opportunityID: opportunityID, title: title, dueAt: dueAt, isComplete: isComplete != 0)
    }

    private func contact(from row: [DatabaseValue]) throws -> Contact {
        guard row.count == 8,
              case let .text(id) = row[0], case let .text(name) = row[1], case let .text(employer) = row[2],
              case let .text(title) = row[3], case let .text(email) = row[4], case let .text(profileURL) = row[5],
              case let .text(relationshipContext) = row[6], case let .text(notes) = row[7] else { throw WorkspaceStoreError.unexpectedDatabaseValue }
        return Contact(id: id, name: name, employer: employer, title: title, email: email, profileURL: profileURL, relationshipContext: relationshipContext, notes: notes)
    }

    private func interaction(from row: [DatabaseValue]) throws -> Interaction {
        guard row.count == 4, case let .text(id) = row[0], case let .text(opportunityID) = row[1], case let .text(summary) = row[2], case let .real(occurredAt) = row[3] else { throw WorkspaceStoreError.unexpectedDatabaseValue }
        return Interaction(id: id, opportunityID: opportunityID, summary: summary, occurredAt: Date(timeIntervalSince1970: occurredAt))
    }

    private func contactInteraction(from row: [DatabaseValue]) throws -> ContactInteraction {
        guard row.count == 7,
              case let .text(id) = row[0], case let .text(contactID) = row[1],
              case let .text(kindValue) = row[3], let kind = InteractionKind(rawValue: kindValue),
              case let .text(summary) = row[4], case let .real(occurredAt) = row[5] else {
            throw WorkspaceStoreError.unexpectedDatabaseValue
        }
        let opportunityID: String?
        if case let .text(value) = row[2] { opportunityID = value } else { opportunityID = nil }
        let nextTouchAt: Date?
        if case let .real(value) = row[6] { nextTouchAt = Date(timeIntervalSince1970: value) } else { nextTouchAt = nil }
        return ContactInteraction(id: id, contactID: contactID, opportunityID: opportunityID, kind: kind, summary: summary, occurredAt: Date(timeIntervalSince1970: occurredAt), nextTouchAt: nextTouchAt)
    }

    private func opportunityInteraction(from row: [DatabaseValue]) throws -> OpportunityInteraction {
        guard row.count == 7,
              case let .text(id) = row[0], case let .text(kindValue) = row[3],
              let kind = InteractionKind(rawValue: kindValue), case let .text(summary) = row[4],
              case let .real(occurredAt) = row[5] else {
            throw WorkspaceStoreError.unexpectedDatabaseValue
        }
        let contactID: String?
        if case let .text(value) = row[1] { contactID = value } else { contactID = nil }
        let contactName: String?
        if case let .text(value) = row[2] { contactName = value } else { contactName = nil }
        let nextTouchAt: Date?
        if case let .real(value) = row[6] { nextTouchAt = Date(timeIntervalSince1970: value) } else { nextTouchAt = nil }
        return OpportunityInteraction(id: id, contactID: contactID, contactName: contactName, kind: kind, summary: summary, occurredAt: Date(timeIntervalSince1970: occurredAt), nextTouchAt: nextTouchAt)
    }

    private func postingCheck(from row: [DatabaseValue]) throws -> PostingCheck {
        guard row.count == 6,
              case let .text(id) = row[0], case let .text(opportunityID) = row[1],
              case let .text(url) = row[2], case let .text(statusValue) = row[3],
              let status = PostingStatus(rawValue: statusValue), case let .text(evidence) = row[4],
              case let .real(checkedAt) = row[5] else { throw WorkspaceStoreError.unexpectedDatabaseValue }
        return PostingCheck(id: id, opportunityID: opportunityID, url: url, status: status, evidence: evidence, checkedAt: Date(timeIntervalSince1970: checkedAt))
    }

    private func documentReference(from row: [DatabaseValue]) throws -> DocumentReference {
        guard row.count == 9,
              case let .text(id) = row[0], case let .text(opportunityID) = row[1],
              case let .text(kindValue) = row[2], let kind = DocumentReferenceKind(rawValue: kindValue),
              case let .text(filename) = row[3], case let .text(contentType) = row[4],
              case let .text(sourceHash) = row[5], case let .integer(byteCount) = row[6],
              case let .real(attachedAt) = row[7] else { throw WorkspaceStoreError.unexpectedDatabaseValue }
        let finalSentAt: Date?
        if case let .real(value) = row[8] { finalSentAt = Date(timeIntervalSince1970: value) } else { finalSentAt = nil }
        return DocumentReference(id: id, opportunityID: opportunityID, kind: kind, filename: filename, contentType: contentType, sourceHash: sourceHash, byteCount: Int(byteCount), attachedAt: Date(timeIntervalSince1970: attachedAt), finalSentAt: finalSentAt)
    }

    private func activityEvent(from row: [DatabaseValue]) throws -> ActivityEvent {
        guard row.count == 7,
              case let .text(id) = row[0], case let .text(kind) = row[1],
              case let .text(actorID) = row[4], case let .text(correlationID) = row[5], case let .real(occurredAt) = row[6] else {
            throw WorkspaceStoreError.unexpectedDatabaseValue
        }
        let opportunityID: String?
        if case let .text(value) = row[2] { opportunityID = value } else { opportunityID = nil }
        let contactID: String?
        if case let .text(value) = row[3] { contactID = value } else { contactID = nil }
        return ActivityEvent(id: id, kind: kind, opportunityID: opportunityID, contactID: contactID, actorID: actorID, correlationID: correlationID, occurredAt: Date(timeIntervalSince1970: occurredAt))
    }

    private func stageHistoryEntry(from row: [DatabaseValue]) throws -> StageHistoryEntry {
        guard row.count == 5,
              case let .text(id) = row[0],
              case let .text(opportunityID) = row[1],
              case let .text(toStageValue) = row[3],
              let toStage = PipelineStage(rawValue: toStageValue),
              case let .real(occurredAt) = row[4] else {
            throw WorkspaceStoreError.unexpectedDatabaseValue
        }
        let fromStage: PipelineStage?
        if case let .text(fromStageValue) = row[2] {
            guard let stage = PipelineStage(rawValue: fromStageValue) else { throw WorkspaceStoreError.unexpectedDatabaseValue }
            fromStage = stage
        } else {
            fromStage = nil
        }
        return StageHistoryEntry(id: id, opportunityID: opportunityID, fromStage: fromStage, toStage: toStage, occurredAt: Date(timeIntervalSince1970: occurredAt))
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
        guard row.count == 10, case let .text(id) = row[0], case let .integer(imported) = row[1], case let .integer(updated) = row[2], case let .integer(skipped) = row[3], case let .integer(duplicateKept) = row[4], case let .integer(invalid) = row[5], case let .integer(failed) = row[6], case let .text(source) = row[7], case let .text(mapping) = row[8], case let .real(createdAt) = row[9] else { throw WorkspaceStoreError.unexpectedDatabaseValue }
        return CSVImportReport(id: id, importedCount: Int(imported), updatedCount: Int(updated), skippedCount: Int(skipped), duplicateKeptCount: Int(duplicateKept), invalidCount: Int(invalid), failedCount: Int(failed), sourceBasename: source, mappingSummary: mapping, createdAt: Date(timeIntervalSince1970: createdAt))
    }

    private func importReportRow(from row: [DatabaseValue]) throws -> CSVImportReportRow {
        guard row.count == 6, case let .text(id) = row[0], case let .integer(sourceRow) = row[1], case let .text(outcome) = row[2], case let .text(reason) = row[3], case let .text(rationale) = row[4] else { throw WorkspaceStoreError.unexpectedDatabaseValue }
        let opportunityID: String? = if case let .text(value) = row[5] { value } else { nil }
        return CSVImportReportRow(id: id, sourceRow: Int(sourceRow), outcome: outcome, reason: reason, duplicateRationale: rationale, opportunityID: opportunityID)
    }
}
