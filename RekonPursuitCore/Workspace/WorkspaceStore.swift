import CryptoKit
import Foundation
import Darwin

nonisolated private final class PortableArchiveExpiryClock: @unchecked Sendable {
    private let value: () -> Date

    init(_ value: @escaping () -> Date) {
        self.value = value
    }

    func now() -> Date {
        value()
    }
}

nonisolated private final class WorkspaceSynchronizationLock: @unchecked Sendable {
    private let value = NSLock()

    func lock() { value.lock() }
    func unlock() { value.unlock() }
}

nonisolated private struct ManagedArchivePurgeTarget: Sendable {
    let catalogue: PortableArchiveCatalogueRow
    let relativePath: String
}

final class WorkspaceStore {
    private let database: EncryptedDatabase
    private let clock: () -> Date
    private let nextIdentifier: () -> String
    private let actorID: String
    private let correlationID: String
    private let failBeforeActivityInsert: Bool
    private let portableArchiveWorker: any PortableArchiveWorking
    private let portableArchiveExpiryWorker: any PortableArchiveExpiryWorking
    private let protectedExportWorker: ProtectedExportWorker
    private let lock = WorkspaceSynchronizationLock()
    private let reconciliationResultSelect = "SELECT id, opportunity_id, url, recorded_at, outcome, classification, reason, confidence, evidence, error, review_task_reminder_id, closure_confirmed_at, legacy_posting_check_id, legacy_status, check_operation_id, method, checker_version, http_status, mime_type, declared_bytes, received_bytes, content_sha256, response_date, last_modified, etag, retry_after, redirect_target_redacted, evidence_excerpt, redacted_error_code"

    init(
        database: EncryptedDatabase,
        now: Date? = nil,
        clock: @escaping () -> Date = { Date.now },
        nextIdentifier: @escaping () -> String = { UUID().uuidString },
        actorID: String,
        correlationID: String,
        failBeforeActivityInsert: Bool = false,
        archiveSigningKeyStore: any ArchiveSigningKeyStoring = ArchiveSigningKeyStore(),
        portableArchiveWorker: (any PortableArchiveWorking)? = nil,
        portableArchiveExpiryWorker: (any PortableArchiveExpiryWorking)? = nil,
        protectedExportWorker: ProtectedExportWorker? = nil
    ) throws {
        let resolvedClock: () -> Date
        if let now {
            resolvedClock = { now }
        } else {
            resolvedClock = clock
        }
        self.database = database
        self.clock = resolvedClock
        self.nextIdentifier = nextIdentifier
        self.actorID = actorID
        self.correlationID = correlationID
        self.failBeforeActivityInsert = failBeforeActivityInsert
        self.portableArchiveWorker = portableArchiveWorker ?? PortableArchiveWorker(
            configuration: database.portableArchiveConnectionConfiguration(),
            signingKeyStore: archiveSigningKeyStore
        )
        let expiryClock = PortableArchiveExpiryClock(resolvedClock)
        self.portableArchiveExpiryWorker = portableArchiveExpiryWorker ?? PortableArchiveExpiryWorker(
            configuration: database.portableArchiveConnectionConfiguration(),
            now: expiryClock.now,
            actorID: actorID
        )
        self.protectedExportWorker = protectedExportWorker ?? ProtectedExportWorker(
            configuration: database.portableArchiveConnectionConfiguration()
        )
        try WorkspaceMigrations.apply(to: database)
        try interruptAbandonedPublicURLChecksAtLaunch()
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
        let jobURL = command.jobURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidJobURL(jobURL) else { throw WorkspaceStoreError.invalidOpportunityURL }
        guard isValidCompensation(minimum: command.compensationMinimum, maximum: command.compensationMaximum) else { throw WorkspaceStoreError.invalidCompensation }
        guard command.responseState == .noResponseRecorded || command.responseEffectiveDate != nil else {
            throw WorkspaceStoreError.invalidOpportunity
        }
        let commandNow = clock()

        return try synchronized {
            let legacyNextAction = command.nextAction.trimmingCharacters(in: .whitespacesAndNewlines)
            let action = resolvedAction(type: command.actionType, customText: command.actionCustomText, legacyText: legacyNextAction)
            let isStructuredCompensation = command.compensationMinimum != nil || command.compensationMaximum != nil || command.compensationPayPeriod != nil
            let opportunity = Opportunity(id: nextIdentifier(), title: title, company: company, createdAt: commandNow, stage: command.stage, nextAction: action.title, dueAt: command.dueAt, jobURL: jobURL, jobDescription: command.jobDescription.trimmingCharacters(in: .whitespacesAndNewlines), notes: command.notes.trimmingCharacters(in: .whitespacesAndNewlines), compensation: isStructuredCompensation ? nil : trimmedOptional(command.compensation), compensationMinimum: command.compensationMinimum, compensationMaximum: command.compensationMaximum, compensationPayPeriod: command.compensationPayPeriod, location: trimmedOptional(command.location), workArrangement: command.workArrangement, applicationDate: command.applicationDate ?? commandNow, responseState: command.responseState, stageChangedAt: command.stageChangedAt ?? commandNow, actionType: action.type, actionCustomText: action.customText)
            let event = ActivityEvent(
                id: nextIdentifier(), kind: "opportunity_created", opportunityID: opportunity.id,
                actorID: actorID, correlationID: correlationID, occurredAt: commandNow
            )
            try database.transaction {
                try database.execute(
                    "INSERT INTO opportunities (id, title, company, created_at, stage, next_action, due_at, job_url, job_description, notes, compensation, compensation_minimum, compensation_maximum, compensation_pay_period, location, work_arrangement, application_date, response_state, stage_changed_at, action_type, action_custom_text) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                    values: opportunityValues(opportunity)
                )
                if !opportunity.nextAction.isEmpty {
                    try database.execute("INSERT INTO task_reminders (id, opportunity_id, title, due_at) VALUES (?, ?, ?, ?)", values: [.text(nextIdentifier()), .text(opportunity.id), .text(opportunity.nextAction), opportunity.dueAt.map { .real($0.timeIntervalSince1970) } ?? .null])
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
                let responseDate: String
                if let candidate, case let .real(value)? = try database.rows("SELECT occurred_at FROM opportunity_response_history WHERE opportunity_id = ? ORDER BY occurred_at DESC, id DESC LIMIT 1", values: [.text(candidate.id)]).first?.first {
                    responseDate = Date(timeIntervalSince1970: value).ISO8601Format().prefix(10).description
                } else { responseDate = "" }
                let values: [CSVImportField: String] = candidate.map { [.jobURL: $0.jobURL, .jobDescription: $0.jobDescription, .notes: $0.notes, .compensation: $0.compensation ?? "", .location: $0.location ?? "", .workArrangement: $0.workArrangement.rawValue, .stage: $0.stage.rawValue, .stageDate: $0.stageChangedAt?.ISO8601Format().prefix(10).description ?? "", .nextAction: $0.nextAction, .dueDate: $0.dueAt?.ISO8601Format().prefix(10).description ?? "", .applicationDate: $0.applicationDate?.ISO8601Format().prefix(10).description ?? "", .responseState: $0.responseState.rawValue, .responseDate: responseDate] } ?? [:]
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
                    let action = resolvedAction(type: nil, customText: nil, legacyText: command.nextAction.trimmingCharacters(in: .whitespacesAndNewlines))
                    let opportunity = Opportunity(id: nextIdentifier(), title: command.title.trimmingCharacters(in: .whitespacesAndNewlines), company: command.company.trimmingCharacters(in: .whitespacesAndNewlines), createdAt: commandNow, stage: command.stage, nextAction: action.title, dueAt: command.dueAt, jobURL: command.jobURL.trimmingCharacters(in: .whitespacesAndNewlines), jobDescription: command.jobDescription.trimmingCharacters(in: .whitespacesAndNewlines), notes: command.notes.trimmingCharacters(in: .whitespacesAndNewlines), compensation: command.compensation, location: command.location, workArrangement: command.workArrangement, applicationDate: command.applicationDate, responseState: command.responseState, stageChangedAt: command.stageChangedAt ?? commandNow, actionType: action.type, actionCustomText: action.customText)
                    try database.execute("INSERT INTO opportunities (id, title, company, created_at, stage, next_action, due_at, job_url, job_description, notes, compensation, compensation_minimum, compensation_maximum, compensation_pay_period, location, work_arrangement, application_date, response_state, stage_changed_at, action_type, action_custom_text) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", values: opportunityValues(opportunity))
                    if !opportunity.nextAction.isEmpty { try database.execute("INSERT INTO task_reminders (id, opportunity_id, title, due_at) VALUES (?, ?, ?, ?)", values: [.text(nextIdentifier()), .text(opportunity.id), .text(opportunity.nextAction), opportunity.dueAt.map { .real($0.timeIntervalSince1970) } ?? .null]) }
                    if failBeforeActivityInsert { throw WorkspaceStoreError.injectedFailure }
                    try appendActivity(kind: "csv_import_row_\(planRow.row.sourceRow)_\(planRow.decision == .keepSeparate ? "kept_separate" : "created")", opportunityID: opportunity.id, occurredAt: commandNow)
                    try database.execute("INSERT INTO opportunity_stage_history (id, opportunity_id, from_stage, to_stage, occurred_at) VALUES (?, ?, ?, ?, ?)", values: [.text(nextIdentifier()), .text(opportunity.id), .null, .text(opportunity.stage.rawValue), .real(opportunity.stageChangedAt!.timeIntervalSince1970)])
                    if opportunity.responseState != .noResponseRecorded, let responseDate = command.responseEffectiveDate { try database.execute("INSERT INTO opportunity_response_history (id, opportunity_id, from_state, to_state, occurred_at) VALUES (?, ?, ?, ?, ?)", values: [.text(nextIdentifier()), .text(opportunity.id), .text(ResponseState.noResponseRecorded.rawValue), .text(opportunity.responseState.rawValue), .real(responseDate.timeIntervalSince1970)]) }
                    try insertImportReportRow(reportID: report.id, planRow: planRow, outcome: planRow.decision == .keepSeparate ? "kept_separate" : "created", opportunityID: opportunity.id)
                }
                for invalid in invalidRows where !invalid.isValid {
                    try database.execute("INSERT INTO import_report_rows (id, report_id, source_row, outcome, reason, duplicate_rationale, opportunity_id, display_title, display_company) VALUES (?, ?, ?, 'invalid', ?, '', NULL, ?, ?)", values: [.text(nextIdentifier()), .text(report.id), .integer(Int64(invalid.sourceRow)), .text(invalid.reasons.joined(separator: " ")), .text(invalid.values[.title]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""), .text(invalid.values[.company]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")])
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
            try database.rows("SELECT id, source_row, outcome, reason, duplicate_rationale, opportunity_id, display_title, display_company FROM import_report_rows WHERE report_id = ? ORDER BY source_row, id", values: [.text(reportID)]).map(importReportRow(from:))
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
                "SELECT task_reminders.id, task_reminders.opportunity_id, task_reminders.title, task_reminders.due_at, task_reminders.is_complete FROM task_reminders JOIN opportunities ON opportunities.id = task_reminders.opportunity_id WHERE task_reminders.opportunity_id = ? AND opportunities.deleted_at IS NULL AND NOT EXISTS (SELECT 1 FROM reconciliation_reviews WHERE reconciliation_reviews.task_reminder_id = task_reminders.id) ORDER BY task_reminders.rowid DESC LIMIT 1",
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
            let activeOperations = try database.rows("SELECT id, url_snapshot FROM reconciliation_check_operations WHERE opportunity_id = ? AND state = 'started'", values: [.text(id)])
            try database.transaction {
                for row in activeOperations {
                    guard row.count == 2, case let .text(operationID) = row[0], case let .text(urlSnapshot) = row[1] else {
                        throw WorkspaceStoreError.unexpectedDatabaseValue
                    }
                    try database.execute(
                        "UPDATE reconciliation_check_operations SET state = 'cancelled', terminal_at = ?, url_snapshot = ? WHERE id = ? AND state = 'started'",
                        values: [.real(commandNow.timeIntervalSince1970), .text(redactedURLSnapshot(urlSnapshot)), .text(operationID)]
                    )
                }
                try database.execute("UPDATE document_references SET bookmark_data = NULL, availability = 'relink_required' WHERE opportunity_id = ?", values: [.text(id)])
                try database.execute("UPDATE opportunities SET deleted_at = ? WHERE id = ?", values: [.real(commandNow.timeIntervalSince1970), .text(id)])
                try database.execute("DELETE FROM task_reminders WHERE opportunity_id = ? AND NOT EXISTS (SELECT 1 FROM reconciliation_reviews WHERE reconciliation_reviews.task_reminder_id = task_reminders.id)", values: [.text(id)])
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
            guard !(try isReconciliationReviewTask(id)) else { throw WorkspaceStoreError.reconciliationTaskRequiresClosure }
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
            if stage == .closed, try hasUnconfirmedReconciliationReview(forOpportunityID: opportunityID) {
                throw WorkspaceStoreError.closureNotConfirmed
            }
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
        compensationMinimum: Double? = nil,
        compensationMaximum: Double? = nil,
        compensationPayPeriod: CompensationPayPeriod? = nil,
        structuredCompensationEdited: Bool = false,
        location: String? = nil,
        workArrangement: WorkArrangement = .notSpecified,
        applicationDate: Date? = nil,
        responseState: ResponseState = .noResponseRecorded,
        responseEffectiveDate: Date? = nil,
        stageChangedAt: Date? = nil,
        actionType: OpportunityActionType = .noAction,
        actionCustomText: String? = nil,
        typedActionEdited: Bool = false
    ) throws {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let company = company.trimmingCharacters(in: .whitespacesAndNewlines)
        let nextAction = typedActionEdited ? nextAction.trimmingCharacters(in: .whitespacesAndNewlines) : nextAction
        guard !title.isEmpty, !company.isEmpty else { throw WorkspaceStoreError.invalidOpportunity }
        guard !structuredCompensationEdited || isValidCompensation(minimum: compensationMinimum, maximum: compensationMaximum) else { throw WorkspaceStoreError.invalidCompensation }
        let commandNow = clock()

        try synchronized {
            guard try isActiveOpportunity(id) else { throw WorkspaceStoreError.unexpectedDatabaseValue }
            guard let current = try database.rows(opportunitySelect + " FROM opportunities WHERE id = ? AND deleted_at IS NULL", values: [.text(id)]).first.map(opportunity(from:)) else { throw WorkspaceStoreError.unexpectedDatabaseValue }
            let submittedJobURL = jobURL
            let jobURL = submittedJobURL.trimmingCharacters(in: .whitespacesAndNewlines)
            let retainsLegacyJobURL = submittedJobURL == current.jobURL && isHostfulAbsoluteURL(current.jobURL)
            guard isValidJobURL(jobURL) || retainsLegacyJobURL else { throw WorkspaceStoreError.invalidOpportunityURL }
            let persistedJobURL = retainsLegacyJobURL ? current.jobURL : jobURL
            let action = typedActionEdited ? resolvedAction(type: actionType, customText: actionCustomText, legacyText: "") : resolvedAction(type: nil, customText: nil, legacyText: nextAction)
            let effectiveNextAction = action.title
            let currentStage = try activeOpportunityStage(id: id)
            let currentResponse = try activeOpportunityResponseState(id: id)
            let didChangeStage = currentStage != stage
            let didChangeResponse = currentResponse != responseState
            if didChangeStage, stage == .closed, try hasUnconfirmedReconciliationReview(forOpportunityID: id) {
                throw WorkspaceStoreError.closureNotConfirmed
            }
            guard !didChangeStage || stageChangedAt != nil,
                  !didChangeResponse || responseEffectiveDate != nil else {
                throw WorkspaceStoreError.invalidOpportunity
            }
            let event = ActivityEvent(id: nextIdentifier(), kind: didChangeStage ? "opportunity_stage_changed" : "opportunity_updated", opportunityID: id, actorID: actorID, correlationID: correlationID, occurredAt: commandNow)
            try database.transaction {
                try database.execute(
                    "UPDATE opportunities SET title = ?, company = ?, stage = ?, next_action = ?, due_at = ?, job_url = ?, job_description = ?, notes = ?, compensation = ?, compensation_minimum = ?, compensation_maximum = ?, compensation_pay_period = ?, location = ?, work_arrangement = ?, application_date = ?, response_state = ?, stage_changed_at = ?, action_type = ?, action_custom_text = ? WHERE id = ?",
                    values: [.text(title), .text(company), .text(stage.rawValue), .text(effectiveNextAction), dueAt.map { .real($0.timeIntervalSince1970) } ?? .null, .text(persistedJobURL), .text(jobDescription.trimmingCharacters(in: .whitespacesAndNewlines)), .text(notes.trimmingCharacters(in: .whitespacesAndNewlines)), (structuredCompensationEdited ? nil : current.compensation).map(DatabaseValue.text) ?? .null, (structuredCompensationEdited ? compensationMinimum : current.compensationMinimum).map(DatabaseValue.real) ?? .null, (structuredCompensationEdited ? compensationMaximum : current.compensationMaximum).map(DatabaseValue.real) ?? .null, (structuredCompensationEdited ? compensationPayPeriod : current.compensationPayPeriod).map { .text($0.rawValue) } ?? .null, trimmedOptional(location).map(DatabaseValue.text) ?? .null, .text(workArrangement.rawValue), applicationDate.map { .real($0.timeIntervalSince1970) } ?? .null, .text(responseState.rawValue), (didChangeStage ? stageChangedAt : try currentStageChangedAt(id: id)).map { .real($0.timeIntervalSince1970) } ?? .null, .text(action.type.rawValue), action.customText.map(DatabaseValue.text) ?? .null, .text(id)]
                )

                let activeTaskID = try database.rows(
                    "SELECT id FROM task_reminders WHERE opportunity_id = ? AND is_complete = 0 AND NOT EXISTS (SELECT 1 FROM reconciliation_reviews WHERE reconciliation_reviews.task_reminder_id = task_reminders.id) ORDER BY id LIMIT 1",
                    values: [.text(id)]
                ).first?.first
                if effectiveNextAction.isEmpty {
                    try database.execute("DELETE FROM task_reminders WHERE opportunity_id = ? AND is_complete = 0 AND NOT EXISTS (SELECT 1 FROM reconciliation_reviews WHERE reconciliation_reviews.task_reminder_id = task_reminders.id)", values: [.text(id)])
                } else if case let .text(taskID)? = activeTaskID {
                    try database.execute("UPDATE task_reminders SET title = ?, due_at = ? WHERE id = ?", values: [.text(effectiveNextAction), dueAt.map { .real($0.timeIntervalSince1970) } ?? .null, .text(taskID)])
                } else {
                    try database.execute("INSERT INTO task_reminders (id, opportunity_id, title, due_at) VALUES (?, ?, ?, ?)", values: [.text(nextIdentifier()), .text(id), .text(effectiveNextAction), dueAt.map { .real($0.timeIntervalSince1970) } ?? .null])
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
            return try database.rows(opportunitySelect + " FROM opportunities JOIN contact_opportunities ON opportunities.id = contact_opportunities.opportunity_id WHERE contact_opportunities.contact_id = ? AND opportunities.deleted_at IS NULL ORDER BY opportunities.company, opportunities.title, opportunities.id", values: [.text(contactID)]).map(opportunity(from:))
        }
    }

    func opportunities(forEmployer employer: String) throws -> [Opportunity] {
        let employer = employer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !employer.isEmpty else { return [] }
        return try synchronized {
            try database.rows(opportunitySelect + " FROM opportunities WHERE deleted_at IS NULL AND lower(trim(company)) = lower(trim(?)) ORDER BY company, title, id", values: [.text(employer)]).map(opportunity(from:))
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

    func recordReconciliationResult(_ command: RecordReconciliationResult) throws -> ReconciliationResult {
        let url = command.url
        let evidence = command.evidence.trimmingCharacters(in: .whitespacesAndNewlines)
        let error = command.error.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidLocalReviewURL(url), isValidReconciliationTuple(command, evidence: evidence, error: error) else {
            throw WorkspaceStoreError.invalidReconciliationResult
        }
        let commandNow = clock()
        return try synchronized {
            guard try isActiveOpportunity(command.opportunityID) else { throw WorkspaceStoreError.unexpectedDatabaseValue }
            let requiresReview = command.outcome != .stillOpen
            let existingReview = try activeReconciliationReviewTaskID(forOpportunityID: command.opportunityID)
            let taskID = requiresReview ? (existingReview ?? nextIdentifier()) : nil
            let result = ReconciliationResult(id: nextIdentifier(), opportunityID: command.opportunityID, url: url, recordedAt: commandNow, outcome: command.outcome, classification: command.classification, reason: command.reason, confidence: command.confidence, evidence: evidence, error: error, reviewTaskID: taskID, closureConfirmedAt: nil, legacyPostingCheckID: nil, legacyStatus: nil)
            try database.transaction {
                if requiresReview, existingReview == nil {
                    try database.execute("INSERT INTO task_reminders (id, opportunity_id, title, due_at, is_complete) VALUES (?, ?, 'Review reconciliation evidence', NULL, 0)", values: [.text(taskID!), .text(command.opportunityID)])
                    if try reconciliationReviewTaskID(forOpportunityID: command.opportunityID) == nil {
                        try database.execute("INSERT INTO reconciliation_reviews (opportunity_id, task_reminder_id, created_at, closure_confirmed_at) VALUES (?, ?, ?, NULL)", values: [.text(command.opportunityID), .text(taskID!), .real(commandNow.timeIntervalSince1970)])
                    } else {
                        try database.execute("UPDATE reconciliation_reviews SET task_reminder_id = ?, created_at = ?, closure_confirmed_at = NULL WHERE opportunity_id = ?", values: [.text(taskID!), .real(commandNow.timeIntervalSince1970), .text(command.opportunityID)])
                    }
                    try appendActivity(kind: "reconciliation_review_task_created", opportunityID: command.opportunityID, occurredAt: commandNow)
                } else if requiresReview {
                    try appendActivity(kind: "reconciliation_review_task_reused", opportunityID: command.opportunityID, occurredAt: commandNow)
                }
                try database.execute("INSERT INTO reconciliation_results (id, opportunity_id, url, recorded_at, outcome, classification, reason, confidence, evidence, error, review_task_reminder_id, closure_confirmed_at, legacy_posting_check_id, legacy_status) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL, NULL, NULL)", values: reconciliationValues(result))
                if failBeforeActivityInsert { throw WorkspaceStoreError.injectedFailure }
                try appendActivity(kind: "reconciliation_result_recorded", opportunityID: command.opportunityID, occurredAt: commandNow)
            }
            return result
        }
    }

    func beginPublicURLCheck(opportunityID: String, urlSnapshot: String) throws -> BeginPublicURLCheck {
        let startedAt = clock()
        return try synchronized {
            guard try isActiveOpportunity(opportunityID),
                  case let .text(savedURL)? = try database.rows("SELECT job_url FROM opportunities WHERE id = ? AND deleted_at IS NULL", values: [.text(opportunityID)]).first?.first,
                  savedURL == urlSnapshot,
                  let host = URLComponents(string: urlSnapshot)?.host?.lowercased(),
                  !host.isEmpty else {
                throw WorkspaceStoreError.invalidPublicURLCheck
            }

            for row in try database.rows("SELECT id, opportunity_id, correlation_id, url_snapshot, state, started_at, terminal_at FROM reconciliation_check_operations WHERE state = 'started' ORDER BY started_at, id") {
                let operation = try publicURLCheckOperation(from: row)
                if operation.opportunityID == opportunityID || URLComponents(string: operation.urlSnapshot)?.host?.lowercased() == host {
                    return BeginPublicURLCheck(operation: operation, isNew: false)
                }
            }

            let operation = ReconciliationCheckOperation(
                id: nextIdentifier(),
                opportunityID: opportunityID,
                correlationID: nextIdentifier(),
                urlSnapshot: urlSnapshot,
                state: .started,
                startedAt: startedAt,
                terminalAt: nil
            )
            try database.transaction {
                try database.execute(
                    "INSERT INTO reconciliation_check_operations (id, opportunity_id, correlation_id, url_snapshot, state, started_at, terminal_at) VALUES (?, ?, ?, ?, 'started', ?, NULL)",
                    values: [.text(operation.id), .text(operation.opportunityID), .text(operation.correlationID), .text(operation.urlSnapshot), .real(operation.startedAt.timeIntervalSince1970)]
                )
                try appendActivity(kind: "public_url_check_started", opportunityID: opportunityID, occurredAt: startedAt)
            }
            return BeginPublicURLCheck(operation: operation, isNew: true)
        }
    }

    func finishPublicURLCheck(operationID: String, completion: PublicURLCheckCompletion) throws -> ReconciliationResult? {
        let terminalAt = clock()
        return try synchronized {
            guard let row = try database.rows("SELECT id, opportunity_id, correlation_id, url_snapshot, state, started_at, terminal_at FROM reconciliation_check_operations WHERE id = ?", values: [.text(operationID)]).first else {
                throw WorkspaceStoreError.invalidPublicURLCheck
            }
            let operation = try publicURLCheckOperation(from: row)
            guard operation.state == .started else {
                return try database.rows(reconciliationResultSelect + " FROM reconciliation_results WHERE check_operation_id = ? ORDER BY recorded_at DESC, id DESC LIMIT 1", values: [.text(operationID)]).first.map(reconciliationResult(from:))
            }

            guard try isActiveOpportunity(operation.opportunityID),
                  case let .text(currentURL)? = try database.rows("SELECT job_url FROM opportunities WHERE id = ? AND deleted_at IS NULL", values: [.text(operation.opportunityID)]).first?.first else {
                try database.execute(
                    "UPDATE reconciliation_check_operations SET state = 'cancelled', terminal_at = ?, url_snapshot = ? WHERE id = ? AND state = 'started'",
                    values: [.real(terminalAt.timeIntervalSince1970), .text(redactedURLSnapshot(operation.urlSnapshot)), .text(operationID)]
                )
                return nil
            }

            let effectiveCompletion: PublicURLCheckCompletion
            if currentURL != operation.urlSnapshot {
                effectiveCompletion = PublicURLCheckCompletion(
                    terminalState: .failed,
                    outcome: .needsManualReview,
                    classification: .failed,
                    reason: .sourceFailed,
                    evidence: "The saved posting URL changed while the check was running.",
                    redactedErrorCode: "url_changed"
                )
            } else {
                effectiveCompletion = completion
            }
            let sanitizedCompletion = sanitizedPublicURLCheckCompletion(effectiveCompletion)

            let evidence = sanitizedCompletion.evidence.trimmingCharacters(in: .whitespacesAndNewlines)
            let error = sanitizedCompletion.error.trimmingCharacters(in: .whitespacesAndNewlines)
            let requiresReview = sanitizedCompletion.outcome != .stillOpen
            let existingReview = try activeReconciliationReviewTaskID(forOpportunityID: operation.opportunityID)
            let taskID = requiresReview ? (existingReview ?? nextIdentifier()) : nil
            let result = ReconciliationResult(
                id: nextIdentifier(),
                opportunityID: operation.opportunityID,
                url: operation.urlSnapshot,
                recordedAt: terminalAt,
                outcome: sanitizedCompletion.outcome,
                classification: sanitizedCompletion.classification,
                reason: sanitizedCompletion.reason,
                confidence: sanitizedCompletion.confidence,
                evidence: evidence,
                error: error,
                reviewTaskID: taskID,
                closureConfirmedAt: nil,
                legacyPostingCheckID: nil,
                legacyStatus: nil,
                checkOperationID: operation.id,
                method: sanitizedCompletion.method,
                checkerVersion: sanitizedCompletion.checkerVersion,
                httpStatus: sanitizedCompletion.httpStatus,
                mimeType: sanitizedCompletion.mimeType,
                declaredBytes: sanitizedCompletion.declaredBytes,
                receivedBytes: sanitizedCompletion.receivedBytes,
                contentSHA256: sanitizedCompletion.contentSHA256,
                responseDate: sanitizedCompletion.responseDate,
                lastModified: sanitizedCompletion.lastModified,
                etag: sanitizedCompletion.etag,
                retryAfter: sanitizedCompletion.retryAfter,
                redirectTargetRedacted: sanitizedCompletion.redirectTargetRedacted,
                evidenceExcerpt: sanitizedCompletion.evidenceExcerpt,
                redactedErrorCode: sanitizedCompletion.redactedErrorCode
            )

            try database.transaction {
                if requiresReview, existingReview == nil {
                    try database.execute("INSERT INTO task_reminders (id, opportunity_id, title, due_at, is_complete) VALUES (?, ?, 'Review reconciliation evidence', NULL, 0)", values: [.text(taskID!), .text(operation.opportunityID)])
                    if try reconciliationReviewTaskID(forOpportunityID: operation.opportunityID) == nil {
                        try database.execute("INSERT INTO reconciliation_reviews (opportunity_id, task_reminder_id, created_at, closure_confirmed_at) VALUES (?, ?, ?, NULL)", values: [.text(operation.opportunityID), .text(taskID!), .real(terminalAt.timeIntervalSince1970)])
                    } else {
                        try database.execute("UPDATE reconciliation_reviews SET task_reminder_id = ?, created_at = ?, closure_confirmed_at = NULL WHERE opportunity_id = ?", values: [.text(taskID!), .real(terminalAt.timeIntervalSince1970), .text(operation.opportunityID)])
                    }
                    try appendActivity(kind: "reconciliation_review_task_created", opportunityID: operation.opportunityID, occurredAt: terminalAt)
                } else if requiresReview {
                    try appendActivity(kind: "reconciliation_review_task_reused", opportunityID: operation.opportunityID, occurredAt: terminalAt)
                } else if let currentReviewTaskID = try reconciliationReviewTaskID(forOpportunityID: operation.opportunityID) {
                    try database.execute("UPDATE task_reminders SET is_complete = 1 WHERE id = ?", values: [.text(currentReviewTaskID)])
                    try database.execute("DELETE FROM reconciliation_reviews WHERE opportunity_id = ?", values: [.text(operation.opportunityID)])
                    try appendActivity(kind: "reconciliation_review_task_resolved", opportunityID: operation.opportunityID, occurredAt: terminalAt)
                }
                try database.execute(
                    "INSERT INTO reconciliation_results (id, opportunity_id, url, recorded_at, outcome, classification, reason, confidence, evidence, error, review_task_reminder_id, closure_confirmed_at, legacy_posting_check_id, legacy_status, check_operation_id, method, checker_version, http_status, mime_type, declared_bytes, received_bytes, content_sha256, response_date, last_modified, etag, retry_after, redirect_target_redacted, evidence_excerpt, redacted_error_code) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL, NULL, NULL, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                    values: publicURLCheckResultValues(result)
                )
                try database.execute(
                    "UPDATE reconciliation_check_operations SET state = ?, terminal_at = ? WHERE id = ? AND state = 'started'",
                    values: [.text(sanitizedCompletion.terminalState.rawValue), .real(terminalAt.timeIntervalSince1970), .text(operationID)]
                )
                if failBeforeActivityInsert { throw WorkspaceStoreError.injectedFailure }
                try appendActivity(kind: "public_url_check_\(sanitizedCompletion.terminalState.rawValue)", opportunityID: operation.opportunityID, occurredAt: terminalAt)
            }
            return result
        }
    }

    func publicURLCheckOperations() throws -> [ReconciliationCheckOperation] {
        try synchronized {
            try database.rows("SELECT id, opportunity_id, correlation_id, url_snapshot, state, started_at, terminal_at FROM reconciliation_check_operations ORDER BY started_at, id").map(publicURLCheckOperation(from:))
        }
    }

    func publicURLCheckOperation(id: String) throws -> ReconciliationCheckOperation? {
        try synchronized {
            try database.rows("SELECT id, opportunity_id, correlation_id, url_snapshot, state, started_at, terminal_at FROM reconciliation_check_operations WHERE id = ?", values: [.text(id)]).first.map(publicURLCheckOperation(from:))
        }
    }

    func reconciliationResults(forOpportunityID opportunityID: String) throws -> [ReconciliationResult] {
        try synchronized {
            guard try isActiveOpportunity(opportunityID) else { return [] }
            return try database.rows(reconciliationResultSelect + " FROM reconciliation_results WHERE opportunity_id = ? ORDER BY recorded_at DESC, id DESC", values: [.text(opportunityID)]).map(reconciliationResult(from:))
        }
    }

    func reconciliationReviewTask(forOpportunityID opportunityID: String) throws -> TaskReminder? {
        try synchronized {
            guard let taskID = try reconciliationReviewTaskID(forOpportunityID: opportunityID) else { return nil }
            return try database.rows("SELECT id, opportunity_id, title, due_at, is_complete FROM task_reminders WHERE id = ?", values: [.text(taskID)]).first.map(task(from:))
        }
    }

    func taskReminder(id: String) throws -> TaskReminder? {
        try synchronized {
            try database.rows("SELECT id, opportunity_id, title, due_at, is_complete FROM task_reminders WHERE id = ?", values: [.text(id)]).first.map(task(from:))
        }
    }

    func confirmReconciliationClosure(forOpportunityID opportunityID: String) throws {
        let commandNow = clock()
        try synchronized {
            guard try isActiveOpportunity(opportunityID), let reviewTaskID = try reconciliationReviewTaskID(forOpportunityID: opportunityID) else { throw WorkspaceStoreError.closureNotConfirmed }
            guard let latest = try database.rows("SELECT id FROM reconciliation_results WHERE opportunity_id = ? AND outcome = ? AND closure_confirmed_at IS NULL ORDER BY recorded_at DESC, id DESC LIMIT 1", values: [.text(opportunityID), .text(ReconciliationOutcome.closedSuggested.rawValue)]).first,
                  case let .text(resultID) = latest[0] else { throw WorkspaceStoreError.closureNotConfirmed }
            let currentStage = try activeOpportunityStage(id: opportunityID)
            try database.transaction {
                try database.execute("UPDATE reconciliation_results SET closure_confirmed_at = ? WHERE id = ?", values: [.real(commandNow.timeIntervalSince1970), .text(resultID)])
                try database.execute("UPDATE reconciliation_reviews SET closure_confirmed_at = ? WHERE opportunity_id = ?", values: [.real(commandNow.timeIntervalSince1970), .text(opportunityID)])
                try database.execute("UPDATE task_reminders SET is_complete = 1 WHERE id = ?", values: [.text(reviewTaskID)])
                if currentStage != .closed {
                    try database.execute("UPDATE opportunities SET stage = 'Closed', stage_changed_at = ? WHERE id = ?", values: [.real(commandNow.timeIntervalSince1970), .text(opportunityID)])
                    try database.execute("INSERT INTO opportunity_stage_history (id, opportunity_id, from_stage, to_stage, occurred_at) VALUES (?, ?, ?, 'Closed', ?)", values: [.text(nextIdentifier()), .text(opportunityID), .text(currentStage.rawValue), .real(commandNow.timeIntervalSince1970)])
                }
                if failBeforeActivityInsert { throw WorkspaceStoreError.injectedFailure }
                try appendActivity(kind: "reconciliation_closure_confirmed", opportunityID: opportunityID, occurredAt: commandNow)
            }
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

    func recoveryEnrollmentState() throws -> RecoveryEnrollmentState {
        try synchronized {
            RecoveryEnrollmentState(isEnabled: !(try database.rows("SELECT fingerprint FROM recovery_enrollment WHERE id = 1")).isEmpty)
        }
    }

    func enroll(recoveryKey: RecoveryKey) throws {
        let commandNow = clock()
        try synchronized {
            guard try database.rows("SELECT id FROM recovery_enrollment WHERE id = 1").isEmpty else {
                throw WorkspaceStoreError.recoveryAlreadyEnrolled
            }
            try database.transaction {
                try database.execute("INSERT INTO recovery_enrollment (id, fingerprint, enrolled_at) VALUES (1, ?, ?)", values: [.text(recoveryKey.fingerprint), .real(commandNow.timeIntervalSince1970)])
                if failBeforeActivityInsert { throw WorkspaceStoreError.injectedFailure }
                try appendActivity(kind: "recovery_enrollment_enabled", opportunityID: nil, occurredAt: commandNow)
            }
        }
    }

    func recoveryEnrollmentRecordForTesting() throws -> RecoveryEnrollmentRecord? {
        try synchronized {
            guard let row = try database.rows("SELECT fingerprint, enrolled_at FROM recovery_enrollment WHERE id = 1").first,
                  row.count == 2, case let .text(fingerprint) = row[0], case let .real(enrolledAt) = row[1] else { return nil }
            return RecoveryEnrollmentRecord(fingerprint: fingerprint, enrolledAt: Date(timeIntervalSince1970: enrolledAt))
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

    func portableArchiveCatalogue() throws -> [PortableArchiveCatalogueRow] {
        try portableArchiveCatalogueRows()
    }

    func portableArchiveCatalogueRows() throws -> [PortableArchiveCatalogueRow] {
        try synchronized {
            try portableArchiveCatalogueRowsLocked()
        }
    }

    func runPortableArchiveExpiryServiceOpportunity() async throws -> [PortableArchiveCatalogueRow] {
        try await portableArchiveExpiryWorker.run()
        return try synchronized { try portableArchiveCatalogueRowsLocked() }
    }

    func updatePortableArchiveCatalogueLifecycle(
        archiveID: UUID,
        lifecycleState: PortableArchiveLifecycleState,
        lastExpiryOutcome: PortableArchiveExpiryOutcome
    ) throws {
        try synchronized {
            try database.execute(
                "UPDATE portable_archive_catalogue SET lifecycle_state = ?, last_expiry_outcome = ? WHERE archive_id = ?",
                values: [.text(lifecycleState.rawValue), .text(lastExpiryOutcome.rawValue), .text(archiveID.uuidString)]
            )
        }
    }

    private func portableArchiveCatalogueRowsLocked() throws -> [PortableArchiveCatalogueRow] {
        try database.rows("SELECT archive_id, display_filename, format_version, created_at, expires_at, verification_state, ciphertext_checksum, signing_key_fingerprint, lifecycle_state, last_expiry_outcome FROM portable_archive_catalogue ORDER BY created_at DESC, archive_id DESC").compactMap { row in
            guard row.count == 10, case let .text(id) = row[0], let archiveID = UUID(uuidString: id), case let .text(filename) = row[1], case let .integer(version) = row[2], case let .real(createdAt) = row[3], case let .real(expiresAt) = row[4], case let .text(verificationState) = row[5], case let .blob(checksum) = row[6], case let .blob(fingerprint) = row[7], case let .text(lifecycleStateText) = row[8], case let .text(lastExpiryOutcomeText) = row[9], let lifecycleState = PortableArchiveLifecycleState(rawValue: lifecycleStateText), let lastExpiryOutcome = PortableArchiveExpiryOutcome(rawValue: lastExpiryOutcomeText) else { throw WorkspaceStoreError.unexpectedDatabaseValue }
            return PortableArchiveCatalogueRow(archiveID: archiveID, displayFilename: filename, formatVersion: Int(version), createdAt: Date(timeIntervalSince1970: createdAt), expiresAt: Date(timeIntervalSince1970: expiresAt), verificationState: verificationState, ciphertextChecksum: checksum, signingKeyFingerprint: fingerprint, lifecycleState: lifecycleState, lastExpiryOutcome: lastExpiryOutcome)
        }
    }

    func createPortableArchive(
        recoveryKey: RecoveryKey,
        at destinationURL: URL
    ) async throws -> PortableArchiveCatalogueRow {
        let request = PortableArchiveRequest(
            recoveryKey: recoveryKey,
            destinationURL: destinationURL,
            archiveID: UUID(),
            temporaryID: UUID(),
            activityID: nextIdentifier(),
            createdAt: clock(),
            actorID: actorID,
            correlationID: correlationID
        )
        return try await portableArchiveWorker.createArchive(request)
    }

    func createManagedPortableArchive(recoveryKey: RecoveryKey) async throws -> PortableArchiveCatalogueRow {
        let archiveID = UUID()
        let relativePath = "\(archiveID.uuidString.lowercased()).rekonarchive"
        let root = database.portableArchiveConnectionConfiguration().url
            .deletingLastPathComponent()
            .appendingPathComponent("portable-archives", isDirectory: true)
        try synchronized {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            var metadata = stat()
            guard Darwin.lstat(root.path, &metadata) == 0,
                  (metadata.st_mode & S_IFMT) == S_IFDIR,
                  (metadata.st_mode & S_IFLNK) == 0 else {
                throw PortableArchiveError.destinationUnavailable
            }
            guard Darwin.chmod(root.path, S_IRWXU) == 0 else { throw PortableArchiveError.destinationUnavailable }
        }
        let request = PortableArchiveRequest(
            recoveryKey: recoveryKey, destinationURL: root.appendingPathComponent(relativePath),
            archiveID: archiveID, temporaryID: UUID(), activityID: nextIdentifier(), createdAt: clock(),
            actorID: actorID, correlationID: correlationID, managedRelativePath: relativePath
        )
        return try await portableArchiveWorker.createArchive(request)
    }

    /// Rebuilds each eligible, app-managed archive from the current active
    /// workspace state. The snapshot encoder excludes logically deleted data,
    /// so a verified replacement is written before the older archive is removed.
    func purgeRetainedDeletedData(recoveryKey: RecoveryKey) async throws -> RetainedDataPurgeResult {
        let commandNow = clock()
        let root = managedPortableArchiveRoot()
        let targets = try synchronized {
            try eligibleManagedArchivePurgeTargetsLocked(after: commandNow)
        }
        var purgedArchiveIDs: [UUID] = []

        for target in targets {
            let predecessorURL = try managedArchiveURL(root: root, relativePath: target.relativePath)
            let predecessorData = try Data(contentsOf: predecessorURL, options: [.mappedIfSafe])
            let predecessor = try PortableArchiveService.readVerifiedArchive(data: predecessorData, recoveryKey: recoveryKey).archive
            guard predecessor.archiveID == target.catalogue.archiveID,
                  predecessor.createdAt == target.catalogue.createdAt,
                  predecessor.expiresAt == target.catalogue.expiresAt,
                  predecessor.ciphertextChecksum == target.catalogue.ciphertextChecksum,
                  predecessor.signingKeyFingerprint == target.catalogue.signingKeyFingerprint else {
                throw PortableArchiveError.verificationFailed
            }

            let replacementID = UUID()
            let replacementRelativePath = "\(replacementID.uuidString.lowercased()).rekonarchive"
            let replacement = try await portableArchiveWorker.createArchive(.init(
                recoveryKey: recoveryKey,
                destinationURL: try managedArchiveURL(root: root, relativePath: replacementRelativePath),
                archiveID: replacementID,
                temporaryID: UUID(),
                activityID: nextIdentifier(),
                createdAt: target.catalogue.createdAt,
                actorID: actorID,
                correlationID: correlationID,
                managedRelativePath: replacementRelativePath
            ))
            guard replacement.createdAt == target.catalogue.createdAt,
                  replacement.expiresAt == target.catalogue.expiresAt else {
                throw PortableArchiveError.verificationFailed
            }

            try synchronized {
                // The predecessor is an app-managed regular file proven above;
                // do not follow a substituted symlink during the delete step.
                var metadata = stat()
                guard Darwin.lstat(predecessorURL.path, &metadata) == 0,
                      (metadata.st_mode & S_IFMT) == S_IFREG else {
                    throw PortableArchiveError.destinationUnavailable
                }
                guard Darwin.unlink(predecessorURL.path) == 0 else {
                    throw PortableArchiveError.destinationUnavailable
                }
                try database.transaction {
                    try database.execute(
                        "DELETE FROM portable_archive_catalogue WHERE archive_id = ? AND storage_class = 'managed' AND managed_relative_path = ?",
                        values: [.text(target.catalogue.archiveID.uuidString), .text(target.relativePath)]
                    )
                    try appendActivity(kind: "portable_backup_deleted_data_purged", opportunityID: nil, occurredAt: commandNow)
                }
            }
            purgedArchiveIDs.append(target.catalogue.archiveID)
        }
        return RetainedDataPurgeResult(state: .complete, purgedArchiveIDs: purgedArchiveIDs)
    }

    private func managedPortableArchiveRoot() -> URL {
        database.portableArchiveConnectionConfiguration().url
            .deletingLastPathComponent()
            .appendingPathComponent("portable-archives", isDirectory: true)
    }

    private func eligibleManagedArchivePurgeTargetsLocked(after now: Date) throws -> [ManagedArchivePurgeTarget] {
        try database.rows("SELECT archive_id, display_filename, format_version, created_at, expires_at, verification_state, ciphertext_checksum, signing_key_fingerprint, lifecycle_state, last_expiry_outcome, managed_relative_path FROM portable_archive_catalogue WHERE storage_class = 'managed' AND verification_state = 'Verified' AND lifecycle_state = 'Verified' AND expires_at > ? ORDER BY created_at ASC, archive_id ASC", values: [.real(now.timeIntervalSince1970)]).compactMap { row in
            guard row.count == 11,
                  case let .text(id) = row[0], let archiveID = UUID(uuidString: id),
                  case let .text(filename) = row[1], case let .integer(version) = row[2],
                  case let .real(createdAt) = row[3], case let .real(expiresAt) = row[4],
                  case let .text(verificationState) = row[5], case let .blob(checksum) = row[6],
                  case let .blob(fingerprint) = row[7], case let .text(lifecycleStateText) = row[8],
                  let lifecycleState = PortableArchiveLifecycleState(rawValue: lifecycleStateText),
                  case let .text(lastExpiryOutcomeText) = row[9],
                  let lastExpiryOutcome = PortableArchiveExpiryOutcome(rawValue: lastExpiryOutcomeText),
                  case let .text(relativePath) = row[10] else { throw WorkspaceStoreError.unexpectedDatabaseValue }
            return ManagedArchivePurgeTarget(
                catalogue: .init(archiveID: archiveID, displayFilename: filename, formatVersion: Int(version), createdAt: Date(timeIntervalSince1970: createdAt), expiresAt: Date(timeIntervalSince1970: expiresAt), verificationState: verificationState, ciphertextChecksum: checksum, signingKeyFingerprint: fingerprint, lifecycleState: lifecycleState, lastExpiryOutcome: lastExpiryOutcome),
                relativePath: relativePath
            )
        }
    }

    private func managedArchiveURL(root: URL, relativePath: String) throws -> URL {
        guard !relativePath.isEmpty,
              !relativePath.contains("/"),
              !relativePath.contains("\\"),
              !relativePath.contains(".."),
              (relativePath as NSString).pathExtension.lowercased() == "rekonarchive" else {
            throw PortableArchiveError.destinationUnavailable
        }
        return root.appendingPathComponent(relativePath, isDirectory: false)
    }

    func reviewProtectedExport(recoveryKey: RecoveryKey, at destinationURL: URL) async throws -> ProtectedExportReview {
        try await protectedExportWorker.review(destinationURL: destinationURL, recoveryKey: recoveryKey)
    }

    func createProtectedExport(review: ProtectedExportReview, recoveryKey: RecoveryKey) async throws -> ProtectedExportReceipt {
        try await protectedExportWorker.create(.init(
            review: review, recoveryKey: recoveryKey, exportID: UUID(), createdAt: clock(),
            activityID: nextIdentifier(), actorID: actorID, correlationID: correlationID
        ))
    }

    func recordDocumentReference(_ command: RecordDocumentReference) throws -> DocumentReference {
        let commandNow = clock()
        let filename = command.filename.trimmingCharacters(in: .whitespacesAndNewlines)
        let sourceHash = command.sourceHash.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !filename.isEmpty, !sourceHash.isEmpty, command.byteCount >= 0 else { throw WorkspaceStoreError.invalidDocumentReference }
        return try synchronized {
            guard try isActiveOpportunity(command.opportunityID) else { throw WorkspaceStoreError.unexpectedDatabaseValue }
            let reference = DocumentReference(id: nextIdentifier(), opportunityID: command.opportunityID, kind: command.kind, filename: filename, contentType: command.contentType, sourceHash: sourceHash, byteCount: command.byteCount, bookmarkData: command.bookmarkData, availability: command.bookmarkData == nil ? .relinkRequired : .available, attachedAt: commandNow, finalSentAt: nil)
            try database.transaction {
                try database.execute("INSERT INTO document_references (id, opportunity_id, kind, filename, content_type, source_hash, byte_count, bookmark_data, availability, attached_at, final_sent_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL)", values: [.text(reference.id), .text(reference.opportunityID), .text(reference.kind.rawValue), .text(reference.filename), .text(reference.contentType), .text(reference.sourceHash), .integer(Int64(reference.byteCount)), reference.bookmarkData.map(DatabaseValue.blob) ?? .null, .text(reference.availability.rawValue), .real(reference.attachedAt.timeIntervalSince1970)])
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

    func replaceDocumentReferenceBookmark(id: String, bookmarkData: Data) throws {
        let commandNow = clock()
        try synchronized {
            try database.transaction {
                let rows = try database.rows("SELECT opportunity_id FROM document_references WHERE id = ?", values: [.text(id)])
                guard let row = rows.first, case let .text(opportunityID) = row.first else { throw WorkspaceStoreError.unexpectedDatabaseValue }
                try database.execute("UPDATE document_references SET bookmark_data = ?, availability = 'available' WHERE id = ?", values: [.blob(bookmarkData), .text(id)])
                try appendActivity(kind: "document_reference_relinked", opportunityID: opportunityID, occurredAt: commandNow)
            }
        }
    }

    func markDocumentReferenceRelinkRequired(id: String) throws {
        let commandNow = clock()
        try synchronized {
            try database.transaction {
                let rows = try database.rows("SELECT opportunity_id FROM document_references WHERE id = ?", values: [.text(id)])
                guard let row = rows.first, case let .text(opportunityID) = row.first else { throw WorkspaceStoreError.unexpectedDatabaseValue }
                try database.execute("UPDATE document_references SET availability = 'relink_required' WHERE id = ?", values: [.text(id)])
                try appendActivity(kind: "document_reference_relink_required", opportunityID: opportunityID, occurredAt: commandNow)
            }
        }
    }

    func removeDocumentReference(id: String) throws {
        let commandNow = clock()
        try synchronized {
            try database.transaction {
                let rows = try database.rows("SELECT opportunity_id FROM document_references WHERE id = ?", values: [.text(id)])
                guard let row = rows.first, case let .text(opportunityID) = row.first else { throw WorkspaceStoreError.unexpectedDatabaseValue }
                try database.execute("UPDATE document_references SET bookmark_data = NULL, availability = 'relink_required' WHERE id = ?", values: [.text(id)])
                try database.execute("DELETE FROM document_references WHERE id = ?", values: [.text(id)])
                try appendActivity(kind: "document_reference_removed", opportunityID: opportunityID, occurredAt: commandNow)
            }
        }
    }

    /// Restore is a capability boundary: backup-created bookmarks are never
    /// trusted, even on the same Mac. This runs against the staging database
    /// before it can replace the active workspace.
    func revokeDocumentReferenceBookmarksForRestore() throws {
        try synchronized {
            try database.transaction {
                try database.execute("UPDATE document_references SET bookmark_data = NULL, availability = 'relink_required'")
            }
        }
    }

    func documentReferences(forOpportunityID opportunityID: String) throws -> [DocumentReference] {
        try synchronized {
            guard try isActiveOpportunity(opportunityID) else { return [] }
            return try database.rows("SELECT id, opportunity_id, kind, filename, content_type, source_hash, byte_count, bookmark_data, availability, attached_at, final_sent_at FROM document_references WHERE opportunity_id = ? ORDER BY attached_at DESC, id DESC", values: [.text(opportunityID)]).map(documentReference(from:))
        }
    }

    func documentReferenceSummary() throws -> DocumentReferenceSummary {
        try synchronized {
            let rows = try database.rows(
                "SELECT availability, COUNT(*) FROM document_references JOIN opportunities ON opportunities.id = document_references.opportunity_id WHERE opportunities.deleted_at IS NULL GROUP BY availability"
            )
            var availableCount = 0
            var relinkRequiredCount = 0
            for row in rows {
                guard row.count == 2, case let .text(availability) = row[0], case let .integer(count) = row[1] else {
                    throw WorkspaceStoreError.unexpectedDatabaseValue
                }
                switch availability {
                case DocumentReferenceAvailability.available.rawValue:
                    availableCount = Int(count)
                case DocumentReferenceAvailability.relinkRequired.rawValue:
                    relinkRequiredCount = Int(count)
                default:
                    throw WorkspaceStoreError.unexpectedDatabaseValue
                }
            }
            return DocumentReferenceSummary(availableCount: availableCount, relinkRequiredCount: relinkRequiredCount)
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

    private func interruptAbandonedPublicURLChecksAtLaunch() throws {
        let operationIDs = try synchronized {
            try database.rows(
                "SELECT id FROM reconciliation_check_operations WHERE state = 'started' ORDER BY started_at, id"
            ).compactMap { row -> String? in
                guard case let .text(operationID)? = row.first else { return nil }
                return operationID
            }
        }
        for operationID in operationIDs {
            _ = try finishPublicURLCheck(
                operationID: operationID,
                completion: PublicURLCheckCompletion(
                    terminalState: .interrupted,
                    outcome: .needsManualReview,
                    classification: .failed,
                    reason: .sourceFailed,
                    evidence: "The previous public URL check ended before completion.",
                    redactedErrorCode: "interrupted"
                )
            )
        }
    }

    private func synchronized<T>(_ work: () throws -> T) throws -> T {
        acquireWorkspaceLock()
        defer { releaseWorkspaceLock() }
        return try work()
    }

    private func acquireWorkspaceLock() {
        lock.lock()
    }

    private func releaseWorkspaceLock() {
        lock.unlock()
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
        "SELECT id, title, company, created_at, stage, next_action, due_at, job_url, job_description, notes, compensation, compensation_minimum, compensation_maximum, compensation_pay_period, location, work_arrangement, application_date, response_state, stage_changed_at, action_type, action_custom_text"
    }

    private func opportunityValues(_ opportunity: Opportunity) -> [DatabaseValue] {
        [.text(opportunity.id), .text(opportunity.title), .text(opportunity.company), .real(opportunity.createdAt.timeIntervalSince1970), .text(opportunity.stage.rawValue), .text(opportunity.nextAction), opportunity.dueAt.map { .real($0.timeIntervalSince1970) } ?? .null, .text(opportunity.jobURL), .text(opportunity.jobDescription), .text(opportunity.notes), opportunity.compensation.map(DatabaseValue.text) ?? .null, opportunity.compensationMinimum.map(DatabaseValue.real) ?? .null, opportunity.compensationMaximum.map(DatabaseValue.real) ?? .null, opportunity.compensationPayPeriod.map { .text($0.rawValue) } ?? .null, opportunity.location.map(DatabaseValue.text) ?? .null, .text(opportunity.workArrangement.rawValue), opportunity.applicationDate.map { .real($0.timeIntervalSince1970) } ?? .null, .text(opportunity.responseState.rawValue), opportunity.stageChangedAt.map { .real($0.timeIntervalSince1970) } ?? .null, .text(opportunity.actionType.rawValue), opportunity.actionCustomText.map(DatabaseValue.text) ?? .null]
    }

    private func trimmedOptional(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func isValidJobURL(_ value: String) -> Bool {
        guard !value.isEmpty else { return true }
        guard let components = URLComponents(string: value),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              let host = components.host,
              !host.isEmpty else {
            return false
        }
        return true
    }

    private func isValidContactProfileURL(_ value: String) -> Bool {
        guard !value.isEmpty else { return true }
        guard let components = URLComponents(string: value),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              let host = components.host,
              isPublicHostname(host) else {
            return false
        }
        return true
    }

    private func isPublicHostname(_ host: String) -> Bool {
        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        return labels.count > 1 && labels.allSatisfy { !$0.isEmpty }
    }

    private func isHostfulAbsoluteURL(_ value: String) -> Bool {
        guard let components = URLComponents(string: value),
              let scheme = components.scheme,
              !scheme.isEmpty,
              let host = components.host,
              !host.isEmpty else {
            return false
        }
        return true
    }

    private func isValidCompensation(minimum: Double?, maximum: Double?) -> Bool {
        guard minimum.map({ $0 >= 0 }) ?? true, maximum.map({ $0 >= 0 }) ?? true else { return false }
        guard let minimum, let maximum else { return true }
        return minimum <= maximum
    }

    private func resolvedAction(type: OpportunityActionType?, customText: String?, legacyText: String) -> (type: OpportunityActionType, customText: String?, title: String) {
        guard let type else {
            return legacyText.isEmpty ? (.noAction, nil, "") : (.other, legacyText, legacyText)
        }
        let customText = trimmedOptional(customText)
        switch type {
        case .noAction:
            return (.noAction, nil, "")
        case .other:
            return (.other, customText, customText ?? "")
        default:
            return (type, nil, type.rawValue)
        }
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
        let email = command.email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidContactEmail(email) else { throw WorkspaceStoreError.invalidContactEmail }
        let profileURL = command.profileURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidContactProfileURL(profileURL) else { throw WorkspaceStoreError.invalidContactProfileURL }
        return Contact(
            id: id ?? "",
            name: name,
            employer: command.employer.trimmingCharacters(in: .whitespacesAndNewlines),
            title: command.title.trimmingCharacters(in: .whitespacesAndNewlines),
            email: email,
            profileURL: profileURL,
            relationshipContext: command.relationshipContext.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: command.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private func isValidContactEmail(_ value: String) -> Bool {
        guard !value.isEmpty else { return true }
        return value.range(of: "^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", options: .regularExpression) != nil
    }

    private func normalizedOpportunityKey(title: String, company: String) -> String {
        "\(title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())\u{1F}\(company.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())"
    }

    private func insertImportReportRow(reportID: String, planRow: CSVImportPlanRow, outcome: String, opportunityID: String?) throws {
        let detail = planRow.selectedFields.isEmpty ? planRow.row.reasons.joined(separator: " ") : "Selected fields: " + planRow.selectedFields.map(\.label).sorted().joined(separator: ", ")
        let title = planRow.row.opportunity?.title ?? planRow.row.values[.title] ?? ""
        let company = planRow.row.opportunity?.company ?? planRow.row.values[.company] ?? ""
        try database.execute("INSERT INTO import_report_rows (id, report_id, source_row, outcome, reason, duplicate_rationale, opportunity_id, display_title, display_company) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)", values: [.text(nextIdentifier()), .text(reportID), .integer(Int64(planRow.row.sourceRow)), .text(outcome), .text(detail), .text(planRow.duplicateRationale ?? ""), opportunityID.map(DatabaseValue.text) ?? .null, .text(title.trimmingCharacters(in: .whitespacesAndNewlines)), .text(company.trimmingCharacters(in: .whitespacesAndNewlines))])
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
        if stage == .closed, try hasUnconfirmedReconciliationReview(forOpportunityID: id) {
            throw WorkspaceStoreError.closureNotConfirmed
        }
        let response = fields.contains(.responseState) ? imported.responseState : existing.responseState
        let stageDate = fields.contains(.stage) ? (imported.stageChangedAt ?? commandNow) : existing.stageChangedAt
        let responseDate = fields.contains(.responseState) ? imported.responseEffectiveDate : nil
        if response != existing.responseState && responseDate == nil { throw WorkspaceStoreError.invalidOpportunity }
        let action: (type: OpportunityActionType, customText: String?, title: String)
        if fields.contains(.nextAction) {
            action = resolvedAction(type: nil, customText: nil, legacyText: imported.nextAction)
        } else {
            action = (type: existing.actionType, customText: existing.actionCustomText, title: existing.nextAction)
        }
        let compensationChanged = fields.contains(.compensation)
        let updated = Opportunity(id: existing.id, title: existing.title, company: existing.company, createdAt: existing.createdAt, stage: stage, nextAction: nextAction, dueAt: dueAt, jobURL: fields.contains(.jobURL) ? imported.jobURL : existing.jobURL, jobDescription: fields.contains(.jobDescription) ? imported.jobDescription : existing.jobDescription, notes: fields.contains(.notes) ? imported.notes : existing.notes, compensation: compensationChanged ? imported.compensation : existing.compensation, compensationMinimum: compensationChanged ? nil : existing.compensationMinimum, compensationMaximum: compensationChanged ? nil : existing.compensationMaximum, compensationPayPeriod: compensationChanged ? nil : existing.compensationPayPeriod, location: fields.contains(.location) ? imported.location : existing.location, workArrangement: fields.contains(.workArrangement) ? imported.workArrangement : existing.workArrangement, applicationDate: fields.contains(.applicationDate) ? imported.applicationDate : existing.applicationDate, responseState: response, stageChangedAt: stageDate, actionType: action.type, actionCustomText: action.customText)
        let updateValues: [DatabaseValue] = [.text(updated.stage.rawValue), .text(updated.nextAction), updated.dueAt.map { .real($0.timeIntervalSince1970) } ?? .null, .text(updated.jobURL), .text(updated.jobDescription), .text(updated.notes), updated.compensation.map(DatabaseValue.text) ?? .null, updated.compensationMinimum.map(DatabaseValue.real) ?? .null, updated.compensationMaximum.map(DatabaseValue.real) ?? .null, updated.compensationPayPeriod.map { .text($0.rawValue) } ?? .null, updated.location.map(DatabaseValue.text) ?? .null, .text(updated.workArrangement.rawValue), updated.applicationDate.map { .real($0.timeIntervalSince1970) } ?? .null, .text(updated.responseState.rawValue), updated.stageChangedAt.map { .real($0.timeIntervalSince1970) } ?? .null, .text(updated.actionType.rawValue), updated.actionCustomText.map(DatabaseValue.text) ?? .null, .text(id)]
        try database.execute("UPDATE opportunities SET stage = ?, next_action = ?, due_at = ?, job_url = ?, job_description = ?, notes = ?, compensation = ?, compensation_minimum = ?, compensation_maximum = ?, compensation_pay_period = ?, location = ?, work_arrangement = ?, application_date = ?, response_state = ?, stage_changed_at = ?, action_type = ?, action_custom_text = ? WHERE id = ?", values: updateValues)
        if fields.contains(.nextAction) || fields.contains(.dueDate) {
            let task = try database.rows("SELECT id FROM task_reminders WHERE opportunity_id = ? AND is_complete = 0 AND NOT EXISTS (SELECT 1 FROM reconciliation_reviews WHERE reconciliation_reviews.task_reminder_id = task_reminders.id) ORDER BY id LIMIT 1", values: [.text(id)]).first?.first
            if nextAction.isEmpty { try database.execute("DELETE FROM task_reminders WHERE opportunity_id = ? AND is_complete = 0 AND NOT EXISTS (SELECT 1 FROM reconciliation_reviews WHERE reconciliation_reviews.task_reminder_id = task_reminders.id)", values: [.text(id)])
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
        guard row.count == 21,
              case let .text(id) = row[0], case let .text(title) = row[1],
              case let .text(company) = row[2], case let .real(createdAt) = row[3], case let .text(stageValue) = row[4], let stage = PipelineStage(rawValue: stageValue), case let .text(nextAction) = row[5] else {
            throw WorkspaceStoreError.unexpectedDatabaseValue
        }
        let dueAt: Date?
        if case let .real(value) = row[6] { dueAt = Date(timeIntervalSince1970: value) } else { dueAt = nil }
        guard case let .text(jobURL) = row[7], case let .text(jobDescription) = row[8], case let .text(notes) = row[9], case let .text(workValue) = row[15], let workArrangement = WorkArrangement(rawValue: workValue), case let .text(responseValue) = row[17], let responseState = ResponseState(rawValue: responseValue), case let .text(actionTypeValue) = row[19], let actionType = OpportunityActionType(rawValue: actionTypeValue) else { throw WorkspaceStoreError.unexpectedDatabaseValue }
        let compensation: String? = if case let .text(value) = row[10] { value } else { nil }
        let compensationMinimum: Double? = if case let .real(value) = row[11] { value } else { nil }
        let compensationMaximum: Double? = if case let .real(value) = row[12] { value } else { nil }
        let compensationPayPeriod: CompensationPayPeriod? = if case let .text(value) = row[13] { CompensationPayPeriod(rawValue: value) } else { nil }
        let location: String? = if case let .text(value) = row[14] { value } else { nil }
        let applicationDate: Date? = if case let .real(value) = row[16] { Date(timeIntervalSince1970: value) } else { nil }
        let stageChangedAt: Date? = if case let .real(value) = row[18] { Date(timeIntervalSince1970: value) } else { nil }
        let actionCustomText: String? = if case let .text(value) = row[20] { value } else { nil }
        return Opportunity(id: id, title: title, company: company, createdAt: Date(timeIntervalSince1970: createdAt), stage: stage, nextAction: nextAction, dueAt: dueAt, jobURL: jobURL, jobDescription: jobDescription, notes: notes, compensation: compensation, compensationMinimum: compensationMinimum, compensationMaximum: compensationMaximum, compensationPayPeriod: compensationPayPeriod, location: location, workArrangement: workArrangement, applicationDate: applicationDate, responseState: responseState, stageChangedAt: stageChangedAt, actionType: actionType, actionCustomText: actionCustomText)
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

    private func reconciliationReviewTaskID(forOpportunityID opportunityID: String) throws -> String? {
        guard case let .text(taskID)? = try database.rows("SELECT task_reminder_id FROM reconciliation_reviews WHERE opportunity_id = ?", values: [.text(opportunityID)]).first?.first else { return nil }
        return taskID
    }

    private func activeReconciliationReviewTaskID(forOpportunityID opportunityID: String) throws -> String? {
        guard case let .text(taskID)? = try database.rows("SELECT task_reminder_id FROM reconciliation_reviews JOIN task_reminders ON task_reminders.id = reconciliation_reviews.task_reminder_id WHERE reconciliation_reviews.opportunity_id = ? AND task_reminders.is_complete = 0", values: [.text(opportunityID)]).first?.first else { return nil }
        return taskID
    }

    private func isReconciliationReviewTask(_ taskID: String) throws -> Bool {
        !(try database.rows("SELECT task_reminder_id FROM reconciliation_reviews WHERE task_reminder_id = ?", values: [.text(taskID)])).isEmpty
    }

    private func hasUnconfirmedReconciliationReview(forOpportunityID opportunityID: String) throws -> Bool {
        !(try database.rows("SELECT opportunity_id FROM reconciliation_reviews WHERE opportunity_id = ? AND closure_confirmed_at IS NULL", values: [.text(opportunityID)])).isEmpty
    }

    private func reconciliationValues(_ result: ReconciliationResult) -> [DatabaseValue] {
        [.text(result.id), .text(result.opportunityID), .text(result.url), .real(result.recordedAt.timeIntervalSince1970), .text(result.outcome.rawValue), .text(result.classification.rawValue), .text(result.reason.rawValue), result.confidence.map { .text($0.rawValue) } ?? .null, .text(result.evidence), .text(result.error), result.reviewTaskID.map(DatabaseValue.text) ?? .null]
    }

    private func reconciliationResult(from row: [DatabaseValue]) throws -> ReconciliationResult {
        guard row.count == 29,
              case let .text(id) = row[0], case let .text(opportunityID) = row[1], case let .text(url) = row[2], case let .real(recordedAt) = row[3],
              case let .text(outcomeValue) = row[4], let outcome = ReconciliationOutcome(rawValue: outcomeValue),
              case let .text(classificationValue) = row[5], let classification = ReconciliationClassification(rawValue: classificationValue),
              case let .text(reasonValue) = row[6], let reason = ReconciliationReason(rawValue: reasonValue),
              case let .text(evidence) = row[8], case let .text(error) = row[9] else { throw WorkspaceStoreError.unexpectedDatabaseValue }
        let confidence: ReconciliationConfidence? = if case let .text(value) = row[7] { ReconciliationConfidence(rawValue: value) } else { nil }
        guard row[7] == .null || confidence != nil else { throw WorkspaceStoreError.unexpectedDatabaseValue }
        let reviewTaskID: String? = if case let .text(value) = row[10] { value } else { nil }
        let closureConfirmedAt: Date? = if case let .real(value) = row[11] { Date(timeIntervalSince1970: value) } else { nil }
        let legacyPostingCheckID: String? = if case let .text(value) = row[12] { value } else { nil }
        let legacyStatus: String? = if case let .text(value) = row[13] { value } else { nil }
        return ReconciliationResult(
            id: id,
            opportunityID: opportunityID,
            url: url,
            recordedAt: Date(timeIntervalSince1970: recordedAt),
            outcome: outcome,
            classification: classification,
            reason: reason,
            confidence: confidence,
            evidence: evidence,
            error: error,
            reviewTaskID: reviewTaskID,
            closureConfirmedAt: closureConfirmedAt,
            legacyPostingCheckID: legacyPostingCheckID,
            legacyStatus: legacyStatus,
            checkOperationID: optionalText(row[14]),
            method: optionalText(row[15]),
            checkerVersion: optionalText(row[16]),
            httpStatus: optionalInteger(row[17]),
            mimeType: optionalText(row[18]),
            declaredBytes: optionalInteger(row[19]),
            receivedBytes: optionalInteger(row[20]),
            contentSHA256: optionalText(row[21]),
            responseDate: optionalText(row[22]),
            lastModified: optionalText(row[23]),
            etag: optionalText(row[24]),
            retryAfter: optionalText(row[25]),
            redirectTargetRedacted: optionalText(row[26]),
            evidenceExcerpt: optionalText(row[27]),
            redactedErrorCode: optionalText(row[28])
        )
    }

    private func publicURLCheckOperation(from row: [DatabaseValue]) throws -> ReconciliationCheckOperation {
        guard row.count == 7,
              case let .text(id) = row[0],
              case let .text(opportunityID) = row[1],
              case let .text(correlationID) = row[2],
              case let .text(urlSnapshot) = row[3],
              case let .text(stateValue) = row[4],
              let state = ReconciliationCheckOperationState(rawValue: stateValue),
              case let .real(startedAt) = row[5] else {
            throw WorkspaceStoreError.unexpectedDatabaseValue
        }
        let terminalAt: Date? = if case let .real(value) = row[6] { Date(timeIntervalSince1970: value) } else { nil }
        return ReconciliationCheckOperation(id: id, opportunityID: opportunityID, correlationID: correlationID, urlSnapshot: urlSnapshot, state: state, startedAt: Date(timeIntervalSince1970: startedAt), terminalAt: terminalAt)
    }

    private func publicURLCheckResultValues(_ result: ReconciliationResult) -> [DatabaseValue] {
        reconciliationValues(result) + [
            result.checkOperationID.map(DatabaseValue.text) ?? .null,
            result.method.map(DatabaseValue.text) ?? .null,
            result.checkerVersion.map(DatabaseValue.text) ?? .null,
            result.httpStatus.map { .integer(Int64($0)) } ?? .null,
            result.mimeType.map(DatabaseValue.text) ?? .null,
            result.declaredBytes.map { .integer(Int64($0)) } ?? .null,
            result.receivedBytes.map { .integer(Int64($0)) } ?? .null,
            result.contentSHA256.map(DatabaseValue.text) ?? .null,
            result.responseDate.map(DatabaseValue.text) ?? .null,
            result.lastModified.map(DatabaseValue.text) ?? .null,
            result.etag.map(DatabaseValue.text) ?? .null,
            result.retryAfter.map(DatabaseValue.text) ?? .null,
            result.redirectTargetRedacted.map(DatabaseValue.text) ?? .null,
            result.evidenceExcerpt.map(DatabaseValue.text) ?? .null,
            result.redactedErrorCode.map(DatabaseValue.text) ?? .null
        ]
    }

    private func isValidPublicURLCheckCompletion(_ completion: PublicURLCheckCompletion) -> Bool {
        guard completion.terminalState.isTerminal,
              completion.method == "GET",
              completion.checkerVersion == "1",
              (completion.httpStatus == nil || (100...599).contains(completion.httpStatus!)),
              (completion.declaredBytes == nil || completion.declaredBytes! >= 0),
              (completion.receivedBytes == nil || (0...524_288).contains(completion.receivedBytes!)),
              completion.evidence.count <= 512,
              completion.error.count <= 256,
              completion.evidenceExcerpt?.count ?? 0 <= 512,
              completion.mimeType?.count ?? 0 <= 128,
              completion.responseDate?.count ?? 0 <= 256,
              completion.lastModified?.count ?? 0 <= 256,
              completion.etag?.count ?? 0 <= 256,
              completion.retryAfter?.count ?? 0 <= 256 else {
            return false
        }
        if let hash = completion.contentSHA256,
           hash.count != 64 || hash.range(of: "^[0-9a-f]{64}$", options: .regularExpression) == nil {
            return false
        }
        if let code = completion.redactedErrorCode,
           code.range(of: "^[a-z0-9_]{1,64}$", options: .regularExpression) == nil {
            return false
        }
        if let target = completion.redirectTargetRedacted, !isRedactedRedirectTarget(target) {
            return false
        }
        let command = RecordReconciliationResult(
            opportunityID: "validation",
            url: "https://validation.invalid/",
            outcome: completion.outcome,
            classification: completion.classification,
            reason: completion.reason,
            confidence: completion.confidence,
            evidence: completion.evidence,
            error: completion.error
        )
        return isValidReconciliationTuple(
            command,
            evidence: completion.evidence.trimmingCharacters(in: .whitespacesAndNewlines),
            error: completion.error.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private func sanitizedPublicURLCheckCompletion(_ completion: PublicURLCheckCompletion) -> PublicURLCheckCompletion {
        let mimeIsValid = completion.mimeType == nil || completion.mimeType!.range(
            of: "^[a-z0-9!#$&^_.+-]+/[a-z0-9!#$&^_.+-]+$",
            options: [.regularExpression, .caseInsensitive]
        ) != nil
        guard isValidPublicURLCheckCompletion(completion),
              completion.httpStatus == nil || (200...599).contains(completion.httpStatus!),
              completion.declaredBytes == nil || (0...524_288).contains(completion.declaredBytes!),
              mimeIsValid else {
            return PublicURLCheckCompletion(
                terminalState: .failed,
                outcome: .needsManualReview,
                classification: .failed,
                reason: .sourceFailed,
                evidence: "The public URL check returned malformed technical evidence.",
                redactedErrorCode: "malformed_completion"
            )
        }
        return completion
    }

    private func isRedactedRedirectTarget(_ value: String) -> Bool {
        guard value.count <= 512,
              let components = URLComponents(string: value),
              let scheme = components.scheme?.lowercased(),
              scheme == "https",
              components.host != nil,
              components.user == nil,
              components.password == nil,
              components.query == nil,
              components.fragment == nil,
              components.percentEncodedPath.count <= 256 else {
            return false
        }
        return true
    }

    private func redactedURLSnapshot(_ value: String) -> String {
        guard var components = URLComponents(string: value),
              let scheme = components.scheme?.lowercased(),
              let host = components.host?.lowercased() else {
            return "redacted://invalid"
        }
        components.scheme = scheme
        components.host = host
        components.user = nil
        components.password = nil
        components.query = nil
        components.fragment = nil
        let path = String(components.percentEncodedPath.prefix(256))
        components.percentEncodedPath = path.isEmpty ? "/" : path
        return components.string ?? "\(scheme)://\(host)/"
    }

    private func optionalText(_ value: DatabaseValue) -> String? {
        if case let .text(text) = value { return text }
        return nil
    }

    private func optionalInteger(_ value: DatabaseValue) -> Int? {
        if case let .integer(integer) = value { return Int(integer) }
        return nil
    }

    private func isValidReconciliationTuple(_ command: RecordReconciliationResult, evidence: String, error: String) -> Bool {
        switch command.outcome {
        case .stillOpen:
            return command.classification == .confirmed && !evidence.isEmpty && command.confidence != nil
        case .possiblyClosed:
            return command.classification == .ambiguous && !evidence.isEmpty && (command.confidence == .low || command.confidence == .medium)
        case .closedSuggested:
            return (command.classification == .confirmed || command.classification == .ambiguous) && !evidence.isEmpty && command.confidence != nil
        case .needsManualReview:
            return (command.classification == .ambiguous || command.classification == .failed || command.classification == .offlineUnchecked) && (!evidence.isEmpty || !error.isEmpty)
        }
    }

    private func isValidLocalReviewURL(_ value: String) -> Bool {
        guard let components = URLComponents(string: value), let scheme = components.scheme?.lowercased(), (scheme == "http" || scheme == "https"), let rawHost = components.host?.lowercased(), !rawHost.isEmpty, components.user == nil, components.password == nil else { return false }
        let host = rawHost.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        guard host != "localhost" else { return false }
        if host.contains(":") { return !isRestrictedIPv6Literal(host) }
        let pieces = host.split(separator: ".").compactMap { Int($0) }
        if pieces.count == 4 && pieces.allSatisfy({ (0...255).contains($0) }) {
            return !(pieces[0] == 127 || pieces[0] == 10 || (pieces[0] == 192 && pieces[1] == 168) || (pieces[0] == 169 && pieces[1] == 254) || (pieces[0] == 172 && (16...31).contains(pieces[1])))
        }
        return true
    }

    private func isRestrictedIPv6Literal(_ host: String) -> Bool {
        var address = in6_addr()
        guard inet_pton(AF_INET6, host, &address) == 1 else { return false }
        let bytes = withUnsafeBytes(of: &address) { Array($0) }
        if bytes.dropLast().allSatisfy({ $0 == 0 }) && bytes.last == 1 { return true }
        if bytes.prefix(10).allSatisfy({ $0 == 0 }) && bytes[10] == 0xff && bytes[11] == 0xff {
            let mapped = bytes.suffix(4).map(Int.init)
            return isRestrictedIPv4(mapped)
        }
        if bytes[0] == 0xfe && (bytes[1] & 0xc0) == 0x80 { return true }
        return (bytes[0] & 0xfe) == 0xfc
    }

    private func isRestrictedIPv4(_ pieces: [Int]) -> Bool {
        pieces.count == 4 && (pieces[0] == 127 || pieces[0] == 10 || (pieces[0] == 192 && pieces[1] == 168) || (pieces[0] == 169 && pieces[1] == 254) || (pieces[0] == 172 && (16...31).contains(pieces[1])))
    }

    private func documentReference(from row: [DatabaseValue]) throws -> DocumentReference {
        guard row.count == 11,
              case let .text(id) = row[0], case let .text(opportunityID) = row[1],
              case let .text(kindValue) = row[2], let kind = DocumentReferenceKind(rawValue: kindValue),
              case let .text(filename) = row[3], case let .text(contentType) = row[4],
              case let .text(sourceHash) = row[5], case let .integer(byteCount) = row[6],
              case let .text(availabilityValue) = row[8], let availability = DocumentReferenceAvailability(rawValue: availabilityValue),
              case let .real(attachedAt) = row[9] else { throw WorkspaceStoreError.unexpectedDatabaseValue }
        let bookmarkData: Data?
        if case let .blob(value) = row[7] { bookmarkData = value } else { bookmarkData = nil }
        let finalSentAt: Date?
        if case let .real(value) = row[10] { finalSentAt = Date(timeIntervalSince1970: value) } else { finalSentAt = nil }
        return DocumentReference(id: id, opportunityID: opportunityID, kind: kind, filename: filename, contentType: contentType, sourceHash: sourceHash, byteCount: Int(byteCount), bookmarkData: bookmarkData, availability: availability, attachedAt: Date(timeIntervalSince1970: attachedAt), finalSentAt: finalSentAt)
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
        guard row.count == 8, case let .text(id) = row[0], case let .integer(sourceRow) = row[1], case let .text(outcome) = row[2], case let .text(reason) = row[3], case let .text(rationale) = row[4], case let .text(title) = row[6], case let .text(company) = row[7] else { throw WorkspaceStoreError.unexpectedDatabaseValue }
        let opportunityID: String? = if case let .text(value) = row[5] { value } else { nil }
        return CSVImportReportRow(id: id, sourceRow: Int(sourceRow), outcome: outcome, reason: reason, duplicateRationale: rationale, opportunityID: opportunityID, title: title, company: company)
    }
}
