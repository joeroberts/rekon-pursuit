import Foundation
import CryptoKit

nonisolated enum WorkspaceMigrations {
    static let currentVersion = 34
    static let baselineChecksum = checksum(for: "rekon-pursuit:migrations:v1-v4")
    static let versionFiveChecksum = checksum(for: "5|ALTER TABLE opportunities ADD COLUMN deleted_at REAL")
    static let versionSixChecksum = checksum(for: "6|workspace_metadata|deletion_tombstones")
    static let versionSevenChecksum = checksum(for: "7|task_reminders.due_at nullable")
    static let versionEightChecksum = checksum(for: "8|activity_events.opportunity_id nullable")
    static let versionNineChecksum = checksum(for: "9|import_reports")
    static let versionTenChecksum = checksum(for: "10|opportunity_stage_history")
    static let versionElevenChecksum = checksum(for: "11|contacts.details.deleted_at|activity_events.contact_id")
    static let versionTwelveChecksum = checksum(for: "12|interactions.contact_id.optional_opportunity.kind.next_touch")
    static let versionThirteenChecksum = checksum(for: "13|opportunities.job_url|posting_checks")
    static let versionFourteenChecksum = checksum(for: "14|document_references.source_hash.final_sent_at")
    static let versionFifteenChecksum = checksum(for: "15|opportunities.job_description.notes")
    static let versionSixteenChecksum = checksum(for: "16|opportunities.core_tracker_fields|opportunity_response_history")
    static let versionSeventeenChecksum = checksum(for: "17|import_reports.completed_detail|import_report_rows")
    static let versionEighteenChecksum = checksum(for: "18|import_reports.failed_count")
    static let versionNineteenChecksum = checksum(for: "19|reconciliation_reviews|reconciliation_results|legacy_posting_check_provenance")
    static let versionTwentyChecksum = checksum(for: "20|reconciliation_check_operations|reconciliation_results.public_url_evidence")
    static let versionTwentyOneChecksum = checksum(for: "21|opportunities.structured_compensation|opportunities.typed_next_action")
    static let versionTwentyTwoChecksum = checksum(for: "22|import_report_rows.display_title_company")
    static let versionTwentyThreeChecksum = checksum(for: "23|document_references.bookmark_data.availability")
    static let versionTwentyFourChecksum = checksum(for: "24|recovery_enrollment.versioned_fingerprint")
    static let versionTwentyFiveChecksum = checksum(for: "25|portable_archive_catalogue.v1")
    static let versionTwentySixChecksum = checksum(for: "26|tracker_export_revision|protected_export_events|active-data-triggers.v1")
    static let versionTwentySevenChecksum = checksum(for: "27|ALTER TABLE portable_archive_catalogue ADD COLUMN lifecycle_state TEXT NOT NULL DEFAULT 'Verified'|ALTER TABLE portable_archive_catalogue ADD COLUMN last_expiry_outcome TEXT NOT NULL DEFAULT 'none'")
    static let versionTwentyEightChecksum = checksum(for: "28|portable_archive_catalogue.managed_expiry.v1")
    static let versionTwentyNineChecksum = checksum(for: "29|portable_archive_catalogue.expiry_quarantine_relative_path")
    static let versionThirtyChecksum = checksum(for: "30|portable_archive_catalogue.expiry_expected_identity")
    static let versionThirtyOneChecksum = checksum(for: "31|retained_data_purge_jobs.scope.archive_phases.operation_leases.v1")
    static let versionThirtyTwoChecksum = checksum(for: "32|retained_data_purge_scope.predecessor_identity.v1")
    static let versionThirtyThreeChecksum = checksum(for: "33|retained_data_purge_archive_phases.replacement_identity.v1")
    static let versionThirtyFourChecksum = checksum(for: "34|contacts.personal_email.mobile_phone.office_phone.instagram_url.facebook_url.v1")

    static func apply(to database: EncryptedDatabase, failVersionFive: Bool = false, failVersionSix: Bool = false, failVersionSixteen: Bool = false, failVersionSeventeen: Bool = false, failVersionNineteen: Bool = false, failVersionTwenty: Bool = false) throws {
        try database.execute("CREATE TABLE IF NOT EXISTS schema_migrations (version INTEGER NOT NULL)")
        let versions = try database.rows("SELECT version FROM schema_migrations LIMIT 1")
        if versions.isEmpty {
            try database.transaction {
                try database.execute("CREATE TABLE opportunities (id TEXT PRIMARY KEY NOT NULL, title TEXT NOT NULL, company TEXT NOT NULL, created_at REAL NOT NULL)")
                try database.execute("CREATE TABLE activity_events (id TEXT PRIMARY KEY NOT NULL, kind TEXT NOT NULL, opportunity_id TEXT NOT NULL REFERENCES opportunities(id), actor_id TEXT NOT NULL, correlation_id TEXT NOT NULL, occurred_at REAL NOT NULL)")
                try database.execute("INSERT INTO schema_migrations (version) VALUES (1)")
            }
        }
        guard case let .integer(version)? = try database.rows("SELECT version FROM schema_migrations LIMIT 1").first?.first else { return }
        if version < 2 {
            try database.transaction {
                try database.execute("ALTER TABLE opportunities ADD COLUMN stage TEXT NOT NULL DEFAULT 'Saved'")
                try database.execute("ALTER TABLE opportunities ADD COLUMN next_action TEXT NOT NULL DEFAULT ''")
                try database.execute("ALTER TABLE opportunities ADD COLUMN due_at REAL")
                try database.execute("CREATE TABLE task_reminders (id TEXT PRIMARY KEY NOT NULL, opportunity_id TEXT NOT NULL REFERENCES opportunities(id), title TEXT NOT NULL, due_at REAL NOT NULL, is_complete INTEGER NOT NULL DEFAULT 0)")
                try database.execute("UPDATE schema_migrations SET version = 2")
            }
        }
        if version < 3 {
            try database.transaction {
                try database.execute("CREATE TABLE contacts (id TEXT PRIMARY KEY NOT NULL, name TEXT NOT NULL, employer TEXT NOT NULL)")
                try database.execute("CREATE TABLE contact_opportunities (contact_id TEXT NOT NULL REFERENCES contacts(id), opportunity_id TEXT NOT NULL REFERENCES opportunities(id), PRIMARY KEY (contact_id, opportunity_id))")
                try database.execute("UPDATE schema_migrations SET version = 3")
            }
        }
        if version < 4 {
            try database.transaction {
                try database.execute("CREATE TABLE interactions (id TEXT PRIMARY KEY NOT NULL, opportunity_id TEXT NOT NULL REFERENCES opportunities(id), summary TEXT NOT NULL, occurred_at REAL NOT NULL)")
                try database.execute("UPDATE schema_migrations SET version = 4")
            }
        }
        try database.execute("CREATE TABLE IF NOT EXISTS migration_history (version INTEGER PRIMARY KEY NOT NULL, checksum TEXT NOT NULL)")
        try database.execute(
            "INSERT OR IGNORE INTO migration_history (version, checksum) VALUES (?, ?)",
            values: [.integer(4), .text(baselineChecksum)]
        )
        if version < 5 || version < 6 {
            try database.createVerifiedSnapshot()
            do {
                try database.transaction {
                    if version < 5 {
                        try database.execute("ALTER TABLE opportunities ADD COLUMN deleted_at REAL")
                        if failVersionFive { throw WorkspaceStoreError.injectedFailure }
                        try database.execute(
                            "INSERT INTO migration_history (version, checksum) VALUES (?, ?)",
                            values: [.integer(5), .text(versionFiveChecksum)]
                        )
                    }
                    if version < 6 {
                        try database.execute("CREATE TABLE workspace_metadata (key TEXT PRIMARY KEY NOT NULL, value TEXT NOT NULL)")
                        try database.execute("INSERT INTO workspace_metadata (key, value) VALUES ('workspace_id', lower(hex(randomblob(16))))")
                        try database.execute("CREATE TABLE deletion_tombstones (subject_id TEXT PRIMARY KEY NOT NULL, subject_type TEXT NOT NULL, deleted_at REAL NOT NULL, display_value TEXT NOT NULL)")
                        if failVersionSix { throw WorkspaceStoreError.injectedFailure }
                        try database.execute(
                            "INSERT INTO migration_history (version, checksum) VALUES (?, ?)",
                            values: [.integer(6), .text(versionSixChecksum)]
                        )
                    }
                    try database.execute("UPDATE schema_migrations SET version = 6")
                }
                database.removeMigrationSnapshot()
            } catch {
                throw error
            }
        }
        if version < 7 {
            try database.createVerifiedSnapshot()
            do {
                try database.transaction {
                    try database.execute("ALTER TABLE task_reminders RENAME TO task_reminders_v6")
                    try database.execute("CREATE TABLE task_reminders (id TEXT PRIMARY KEY NOT NULL, opportunity_id TEXT NOT NULL REFERENCES opportunities(id), title TEXT NOT NULL, due_at REAL, is_complete INTEGER NOT NULL DEFAULT 0)")
                    try database.execute("INSERT INTO task_reminders (id, opportunity_id, title, due_at, is_complete) SELECT id, opportunity_id, title, due_at, is_complete FROM task_reminders_v6")
                    try database.execute("DROP TABLE task_reminders_v6")
                    try database.execute("INSERT INTO migration_history (version, checksum) VALUES (?, ?)", values: [.integer(7), .text(versionSevenChecksum)])
                    try database.execute("UPDATE schema_migrations SET version = 7")
                }
                database.removeMigrationSnapshot()
            } catch {
                throw error
            }
        }
        if version < 8 {
            try database.createVerifiedSnapshot()
            do {
                try database.transaction {
                    try database.execute("ALTER TABLE activity_events RENAME TO activity_events_v7")
                    try database.execute("CREATE TABLE activity_events (id TEXT PRIMARY KEY NOT NULL, kind TEXT NOT NULL, opportunity_id TEXT REFERENCES opportunities(id), actor_id TEXT NOT NULL, correlation_id TEXT NOT NULL, occurred_at REAL NOT NULL)")
                    try database.execute("INSERT INTO activity_events (id, kind, opportunity_id, actor_id, correlation_id, occurred_at) SELECT id, kind, opportunity_id, actor_id, correlation_id, occurred_at FROM activity_events_v7")
                    try database.execute("DROP TABLE activity_events_v7")
                    try database.execute("INSERT INTO migration_history (version, checksum) VALUES (?, ?)", values: [.integer(8), .text(versionEightChecksum)])
                    try database.execute("UPDATE schema_migrations SET version = 8")
                }
                database.removeMigrationSnapshot()
            } catch {
                throw error
            }
        }
        if version < 9 {
            try database.createVerifiedSnapshot()
            do {
                try database.transaction {
                    try database.execute("CREATE TABLE import_reports (id TEXT PRIMARY KEY NOT NULL, imported_count INTEGER NOT NULL, skipped_count INTEGER NOT NULL, duplicate_kept_count INTEGER NOT NULL, invalid_count INTEGER NOT NULL, created_at REAL NOT NULL)")
                    try database.execute("INSERT INTO migration_history (version, checksum) VALUES (?, ?)", values: [.integer(9), .text(versionNineChecksum)])
                    try database.execute("UPDATE schema_migrations SET version = 9")
                }
                database.removeMigrationSnapshot()
            } catch {
                throw error
            }
        }
        if version < 10 {
            try database.createVerifiedSnapshot()
            do {
                try database.transaction {
                    try database.execute("CREATE TABLE opportunity_stage_history (id TEXT PRIMARY KEY NOT NULL, opportunity_id TEXT NOT NULL REFERENCES opportunities(id), from_stage TEXT, to_stage TEXT NOT NULL, occurred_at REAL NOT NULL)")
                    try database.execute("INSERT INTO opportunity_stage_history (id, opportunity_id, from_stage, to_stage, occurred_at) SELECT lower(hex(randomblob(16))), id, NULL, stage, created_at FROM opportunities")
                    try database.execute("INSERT INTO migration_history (version, checksum) VALUES (?, ?)", values: [.integer(10), .text(versionTenChecksum)])
                    try database.execute("UPDATE schema_migrations SET version = 10")
                }
                database.removeMigrationSnapshot()
            } catch {
                throw error
            }
        }
        if version < 11 {
            try database.createVerifiedSnapshot()
            do {
                try database.transaction {
                    try database.execute("CREATE TABLE IF NOT EXISTS contacts (id TEXT PRIMARY KEY NOT NULL, name TEXT NOT NULL, employer TEXT NOT NULL)")
                    try database.execute("CREATE TABLE IF NOT EXISTS contact_opportunities (contact_id TEXT NOT NULL REFERENCES contacts(id), opportunity_id TEXT NOT NULL REFERENCES opportunities(id), PRIMARY KEY (contact_id, opportunity_id))")
                    let contactColumns = Set(try database.rows("PRAGMA table_info(contacts)").compactMap { row -> String? in
                        guard row.count > 1, case let .text(name) = row[1] else { return nil }
                        return name
                    })
                    if !contactColumns.contains("title") { try database.execute("ALTER TABLE contacts ADD COLUMN title TEXT NOT NULL DEFAULT ''") }
                    if !contactColumns.contains("email") { try database.execute("ALTER TABLE contacts ADD COLUMN email TEXT NOT NULL DEFAULT ''") }
                    if !contactColumns.contains("profile_url") { try database.execute("ALTER TABLE contacts ADD COLUMN profile_url TEXT NOT NULL DEFAULT ''") }
                    if !contactColumns.contains("relationship_context") { try database.execute("ALTER TABLE contacts ADD COLUMN relationship_context TEXT NOT NULL DEFAULT ''") }
                    if !contactColumns.contains("notes") { try database.execute("ALTER TABLE contacts ADD COLUMN notes TEXT NOT NULL DEFAULT ''") }
                    if !contactColumns.contains("deleted_at") { try database.execute("ALTER TABLE contacts ADD COLUMN deleted_at REAL") }
                    try database.execute("ALTER TABLE activity_events RENAME TO activity_events_v10")
                    try database.execute("CREATE TABLE activity_events (id TEXT PRIMARY KEY NOT NULL, kind TEXT NOT NULL, opportunity_id TEXT REFERENCES opportunities(id), contact_id TEXT, actor_id TEXT NOT NULL, correlation_id TEXT NOT NULL, occurred_at REAL NOT NULL)")
                    try database.execute("INSERT INTO activity_events (id, kind, opportunity_id, contact_id, actor_id, correlation_id, occurred_at) SELECT id, kind, opportunity_id, NULL, actor_id, correlation_id, occurred_at FROM activity_events_v10")
                    try database.execute("DROP TABLE activity_events_v10")
                    try database.execute("INSERT INTO migration_history (version, checksum) VALUES (?, ?)", values: [.integer(11), .text(versionElevenChecksum)])
                    try database.execute("UPDATE schema_migrations SET version = 11")
                }
                database.removeMigrationSnapshot()
            } catch {
                throw error
            }
        }
        if version < 12 {
            try database.createVerifiedSnapshot()
            do {
                try database.transaction {
                    try database.execute("CREATE TABLE IF NOT EXISTS interactions (id TEXT PRIMARY KEY NOT NULL, opportunity_id TEXT NOT NULL REFERENCES opportunities(id), summary TEXT NOT NULL, occurred_at REAL NOT NULL)")
                    try database.execute("ALTER TABLE interactions RENAME TO interactions_v11")
                    try database.execute("CREATE TABLE interactions (id TEXT PRIMARY KEY NOT NULL, contact_id TEXT REFERENCES contacts(id), opportunity_id TEXT REFERENCES opportunities(id), kind TEXT NOT NULL, summary TEXT NOT NULL, occurred_at REAL NOT NULL, next_touch_at REAL)")
                    try database.execute("INSERT INTO interactions (id, contact_id, opportunity_id, kind, summary, occurred_at, next_touch_at) SELECT id, NULL, opportunity_id, 'Note', summary, occurred_at, NULL FROM interactions_v11")
                    try database.execute("DROP TABLE interactions_v11")
                    try database.execute("CREATE INDEX interactions_contact_occurred_at ON interactions(contact_id, occurred_at, id)")
                    try database.execute("INSERT INTO migration_history (version, checksum) VALUES (?, ?)", values: [.integer(12), .text(versionTwelveChecksum)])
                    try database.execute("UPDATE schema_migrations SET version = 12")
                }
                database.removeMigrationSnapshot()
            } catch {
                throw error
            }
        }
        if version < 13 {
            try database.createVerifiedSnapshot()
            do {
                try database.transaction {
                    try database.execute("ALTER TABLE opportunities ADD COLUMN job_url TEXT NOT NULL DEFAULT ''")
                    try database.execute("CREATE TABLE posting_checks (id TEXT PRIMARY KEY NOT NULL, opportunity_id TEXT NOT NULL REFERENCES opportunities(id), url TEXT NOT NULL, status TEXT NOT NULL, evidence TEXT NOT NULL, checked_at REAL NOT NULL)")
                    try database.execute("CREATE INDEX posting_checks_opportunity_checked_at ON posting_checks(opportunity_id, checked_at, id)")
                    try database.execute("INSERT INTO migration_history (version, checksum) VALUES (?, ?)", values: [.integer(13), .text(versionThirteenChecksum)])
                    try database.execute("UPDATE schema_migrations SET version = 13")
                }
                database.removeMigrationSnapshot()
            } catch {
                throw error
            }
        }
        if version < 14 {
            try database.createVerifiedSnapshot()
            do {
                try database.transaction {
                    try database.execute("CREATE TABLE document_references (id TEXT PRIMARY KEY NOT NULL, opportunity_id TEXT NOT NULL REFERENCES opportunities(id), kind TEXT NOT NULL, filename TEXT NOT NULL, content_type TEXT NOT NULL, source_hash TEXT NOT NULL, byte_count INTEGER NOT NULL, attached_at REAL NOT NULL, final_sent_at REAL)")
                    try database.execute("CREATE INDEX document_references_opportunity_attached_at ON document_references(opportunity_id, attached_at, id)")
                    try database.execute("INSERT INTO migration_history (version, checksum) VALUES (?, ?)", values: [.integer(14), .text(versionFourteenChecksum)])
                    try database.execute("UPDATE schema_migrations SET version = 14")
                }
                database.removeMigrationSnapshot()
            } catch {
                throw error
            }
        }
        if version < 15 {
            try database.createVerifiedSnapshot()
            do {
                try database.transaction {
                    try database.execute("ALTER TABLE opportunities ADD COLUMN job_description TEXT NOT NULL DEFAULT ''")
                    try database.execute("ALTER TABLE opportunities ADD COLUMN notes TEXT NOT NULL DEFAULT ''")
                    try database.execute("INSERT INTO migration_history (version, checksum) VALUES (?, ?)", values: [.integer(15), .text(versionFifteenChecksum)])
                    try database.execute("UPDATE schema_migrations SET version = 15")
                }
                database.removeMigrationSnapshot()
            } catch {
                throw error
            }
        }
        if version < 16 {
            try database.createVerifiedSnapshot()
            do {
                try database.transaction {
                    try database.execute("ALTER TABLE opportunities ADD COLUMN compensation TEXT")
                    try database.execute("ALTER TABLE opportunities ADD COLUMN location TEXT")
                    try database.execute("ALTER TABLE opportunities ADD COLUMN work_arrangement TEXT NOT NULL DEFAULT 'Not specified'")
                    try database.execute("ALTER TABLE opportunities ADD COLUMN application_date REAL")
                    try database.execute("ALTER TABLE opportunities ADD COLUMN response_state TEXT NOT NULL DEFAULT 'No response recorded'")
                    try database.execute("ALTER TABLE opportunities ADD COLUMN stage_changed_at REAL")
                    try database.execute("UPDATE opportunities SET stage_changed_at = created_at WHERE stage_changed_at IS NULL")
                    try database.execute("CREATE TABLE opportunity_response_history (id TEXT PRIMARY KEY NOT NULL, opportunity_id TEXT NOT NULL REFERENCES opportunities(id), from_state TEXT NOT NULL, to_state TEXT NOT NULL, occurred_at REAL NOT NULL)")
                    try database.execute("CREATE INDEX opportunity_response_history_opportunity_occurred_at ON opportunity_response_history(opportunity_id, occurred_at DESC, id DESC)")
                    if failVersionSixteen { throw WorkspaceStoreError.injectedFailure }
                    try database.execute("INSERT INTO migration_history (version, checksum) VALUES (?, ?)", values: [.integer(16), .text(versionSixteenChecksum)])
                    try database.execute("UPDATE schema_migrations SET version = 16")
                }
                database.removeMigrationSnapshot()
            } catch { throw error }
        }
        if version < 17 {
            try database.createVerifiedSnapshot()
            do {
                try database.transaction {
                    try database.execute("ALTER TABLE import_reports ADD COLUMN updated_count INTEGER NOT NULL DEFAULT 0")
                    try database.execute("ALTER TABLE import_reports ADD COLUMN source_basename TEXT NOT NULL DEFAULT ''")
                    try database.execute("ALTER TABLE import_reports ADD COLUMN mapping_summary TEXT NOT NULL DEFAULT ''")
                    try database.execute("CREATE TABLE import_report_rows (id TEXT PRIMARY KEY NOT NULL, report_id TEXT NOT NULL REFERENCES import_reports(id), source_row INTEGER NOT NULL, outcome TEXT NOT NULL, reason TEXT NOT NULL, duplicate_rationale TEXT NOT NULL, opportunity_id TEXT)")
                    try database.execute("CREATE INDEX import_report_rows_report_row ON import_report_rows(report_id, source_row)")
                    if failVersionSeventeen { throw WorkspaceStoreError.injectedFailure }
                    try database.execute("INSERT INTO migration_history (version, checksum) VALUES (?, ?)", values: [.integer(17), .text(versionSeventeenChecksum)])
                    try database.execute("UPDATE schema_migrations SET version = 17")
                }
                database.removeMigrationSnapshot()
            } catch { throw error }
        }
        if version < 18 {
            try database.transaction {
                try database.execute("ALTER TABLE import_reports ADD COLUMN failed_count INTEGER NOT NULL DEFAULT 0")
                try database.execute("INSERT INTO migration_history (version, checksum) VALUES (?, ?)", values: [.integer(18), .text(versionEighteenChecksum)])
                try database.execute("UPDATE schema_migrations SET version = 18")
            }
        }
        if version < 19 {
            try database.createVerifiedSnapshot()
            do {
                try database.transaction {
                    try database.execute("CREATE TABLE reconciliation_reviews (opportunity_id TEXT PRIMARY KEY NOT NULL REFERENCES opportunities(id), task_reminder_id TEXT NOT NULL UNIQUE REFERENCES task_reminders(id), created_at REAL NOT NULL, closure_confirmed_at REAL)")
                    try database.execute("CREATE INDEX reconciliation_reviews_task_reminder_id ON reconciliation_reviews(task_reminder_id)")
                    try database.execute("CREATE TABLE reconciliation_results (id TEXT PRIMARY KEY NOT NULL, opportunity_id TEXT NOT NULL REFERENCES opportunities(id), url TEXT NOT NULL, recorded_at REAL NOT NULL, outcome TEXT NOT NULL, classification TEXT NOT NULL, reason TEXT NOT NULL, confidence TEXT, evidence TEXT NOT NULL, error TEXT NOT NULL, review_task_reminder_id TEXT REFERENCES task_reminders(id), closure_confirmed_at REAL, legacy_posting_check_id TEXT UNIQUE, legacy_status TEXT)")
                    try database.execute("CREATE INDEX reconciliation_results_opportunity_recorded_at ON reconciliation_results(opportunity_id, recorded_at DESC, id DESC)")

                    let legacyRows = try database.rows("SELECT id, opportunity_id, url, status, evidence, checked_at FROM posting_checks ORDER BY checked_at, id")
                    var reviewOpportunityIDs = Set<String>()
                    for row in legacyRows {
                        guard row.count == 6,
                              case let .text(id) = row[0],
                              case let .text(opportunityID) = row[1],
                              case let .text(url) = row[2],
                              case let .text(status) = row[3],
                              case let .text(evidence) = row[4],
                              case let .real(checkedAt) = row[5] else {
                            throw WorkspaceStoreError.unexpectedDatabaseValue
                        }
                        let mapping: (outcome: String, classification: String) = switch status {
                        case "Still open": ("Still open", "Confirmed")
                        case "Possibly closed": ("Possibly closed", "Ambiguous")
                        case "Closed": ("Closed suggested", "Confirmed")
                        case "Needs manual review": ("Needs manual review", "Ambiguous")
                        default: throw WorkspaceStoreError.unexpectedDatabaseValue
                        }
                        try database.execute("INSERT INTO reconciliation_results (id, opportunity_id, url, recorded_at, outcome, classification, reason, confidence, evidence, error, review_task_reminder_id, closure_confirmed_at, legacy_posting_check_id, legacy_status) VALUES (?, ?, ?, ?, ?, ?, 'manual review', NULL, ?, '', NULL, NULL, ?, ?)", values: [.text("legacy-reconciliation-" + id), .text(opportunityID), .text(url), .real(checkedAt), .text(mapping.outcome), .text(mapping.classification), .text(evidence), .text(id), .text(status)])
                        if mapping.outcome != "Still open" { reviewOpportunityIDs.insert(opportunityID) }
                    }
                    for opportunityID in reviewOpportunityIDs.sorted() where try isActiveOpportunity(opportunityID, in: database) {
                        let taskID = UUID().uuidString
                        try database.execute("INSERT INTO task_reminders (id, opportunity_id, title, due_at, is_complete) VALUES (?, ?, 'Review reconciliation evidence', NULL, 0)", values: [.text(taskID), .text(opportunityID)])
                        try database.execute("INSERT INTO reconciliation_reviews (opportunity_id, task_reminder_id, created_at, closure_confirmed_at) VALUES (?, ?, ?, NULL)", values: [.text(opportunityID), .text(taskID), .real(Date.now.timeIntervalSince1970)])
                        try database.execute("UPDATE reconciliation_results SET review_task_reminder_id = ? WHERE opportunity_id = ? AND outcome != 'Still open'", values: [.text(taskID), .text(opportunityID)])
                    }
                    if failVersionNineteen { throw WorkspaceStoreError.injectedFailure }
                    try database.execute("INSERT INTO migration_history (version, checksum) VALUES (?, ?)", values: [.integer(19), .text(versionNineteenChecksum)])
                    try database.execute("UPDATE schema_migrations SET version = 19")
                }
                database.removeMigrationSnapshot()
            } catch {
                throw error
            }
        }
        if version < 20 {
            try database.createVerifiedSnapshot()
            do {
                try database.transaction {
                    try database.execute("CREATE TABLE reconciliation_check_operations (id TEXT PRIMARY KEY NOT NULL, opportunity_id TEXT NOT NULL REFERENCES opportunities(id), correlation_id TEXT NOT NULL UNIQUE, url_snapshot TEXT NOT NULL, state TEXT NOT NULL, started_at REAL NOT NULL, terminal_at REAL)")
                    try database.execute("CREATE INDEX reconciliation_check_operations_opportunity_state ON reconciliation_check_operations(opportunity_id, state)")
                    try database.execute("ALTER TABLE reconciliation_results ADD COLUMN check_operation_id TEXT REFERENCES reconciliation_check_operations(id)")
                    try database.execute("ALTER TABLE reconciliation_results ADD COLUMN method TEXT")
                    try database.execute("ALTER TABLE reconciliation_results ADD COLUMN checker_version TEXT")
                    try database.execute("ALTER TABLE reconciliation_results ADD COLUMN http_status INTEGER")
                    try database.execute("ALTER TABLE reconciliation_results ADD COLUMN mime_type TEXT")
                    try database.execute("ALTER TABLE reconciliation_results ADD COLUMN declared_bytes INTEGER")
                    try database.execute("ALTER TABLE reconciliation_results ADD COLUMN received_bytes INTEGER")
                    try database.execute("ALTER TABLE reconciliation_results ADD COLUMN content_sha256 TEXT")
                    try database.execute("ALTER TABLE reconciliation_results ADD COLUMN response_date TEXT")
                    try database.execute("ALTER TABLE reconciliation_results ADD COLUMN last_modified TEXT")
                    try database.execute("ALTER TABLE reconciliation_results ADD COLUMN etag TEXT")
                    try database.execute("ALTER TABLE reconciliation_results ADD COLUMN retry_after TEXT")
                    try database.execute("ALTER TABLE reconciliation_results ADD COLUMN redirect_target_redacted TEXT")
                    try database.execute("ALTER TABLE reconciliation_results ADD COLUMN evidence_excerpt TEXT")
                    try database.execute("ALTER TABLE reconciliation_results ADD COLUMN redacted_error_code TEXT")
                    if failVersionTwenty { throw WorkspaceStoreError.injectedFailure }
                    try database.execute("INSERT INTO migration_history (version, checksum) VALUES (?, ?)", values: [.integer(20), .text(versionTwentyChecksum)])
                    try database.execute("UPDATE schema_migrations SET version = 20")
                }
                database.removeMigrationSnapshot()
            } catch {
                throw error
            }
        }
        if version < 21 {
            try database.createVerifiedSnapshot()
            do {
                try database.transaction {
                    try database.execute("ALTER TABLE opportunities ADD COLUMN compensation_minimum REAL")
                    try database.execute("ALTER TABLE opportunities ADD COLUMN compensation_maximum REAL")
                    try database.execute("ALTER TABLE opportunities ADD COLUMN compensation_pay_period TEXT")
                    try database.execute("ALTER TABLE opportunities ADD COLUMN action_type TEXT NOT NULL DEFAULT 'No action'")
                    try database.execute("ALTER TABLE opportunities ADD COLUMN action_custom_text TEXT")
                    try database.execute("UPDATE opportunities SET action_type = CASE WHEN trim(next_action) = '' THEN 'No action' ELSE 'Other' END, action_custom_text = CASE WHEN trim(next_action) = '' THEN NULL ELSE next_action END")
                    try database.execute("INSERT INTO migration_history (version, checksum) VALUES (?, ?)", values: [.integer(21), .text(versionTwentyOneChecksum)])
                    try database.execute("UPDATE schema_migrations SET version = 21")
                }
                database.removeMigrationSnapshot()
            } catch { throw error }
        }
        if version < 22 {
            try database.transaction {
                try database.execute("ALTER TABLE import_report_rows ADD COLUMN display_title TEXT NOT NULL DEFAULT ''")
                try database.execute("ALTER TABLE import_report_rows ADD COLUMN display_company TEXT NOT NULL DEFAULT ''")
                try database.execute("INSERT INTO migration_history (version, checksum) VALUES (?, ?)", values: [.integer(22), .text(versionTwentyTwoChecksum)])
                try database.execute("UPDATE schema_migrations SET version = 22")
            }
        }
        if version < 23 {
            try database.createVerifiedSnapshot()
            do {
                try database.transaction {
                    try database.execute("ALTER TABLE document_references ADD COLUMN bookmark_data BLOB")
                    try database.execute("ALTER TABLE document_references ADD COLUMN availability TEXT NOT NULL DEFAULT 'relink_required'")
                    try database.execute("INSERT INTO migration_history (version, checksum) VALUES (?, ?)", values: [.integer(23), .text(versionTwentyThreeChecksum)])
                    try database.execute("UPDATE schema_migrations SET version = 23")
                }
                database.removeMigrationSnapshot()
            } catch { throw error }
        }
        if version < 24 {
            try database.createVerifiedSnapshot()
            do {
                try database.transaction {
                    try database.execute("CREATE TABLE recovery_enrollment (id INTEGER PRIMARY KEY CHECK (id = 1), fingerprint TEXT NOT NULL, enrolled_at REAL NOT NULL)")
                    try database.execute("INSERT INTO migration_history (version, checksum) VALUES (?, ?)", values: [.integer(24), .text(versionTwentyFourChecksum)])
                    try database.execute("UPDATE schema_migrations SET version = 24")
                }
                database.removeMigrationSnapshot()
            } catch { throw error }
        }
        if version < 25 {
            try database.createVerifiedSnapshot()
            do {
                try database.transaction {
                    try database.execute("CREATE TABLE portable_archive_catalogue (archive_id TEXT PRIMARY KEY NOT NULL, destination_bookmark BLOB NOT NULL, display_filename TEXT NOT NULL, format_version INTEGER NOT NULL, created_at REAL NOT NULL, expires_at REAL NOT NULL, verification_state TEXT NOT NULL, ciphertext_checksum BLOB NOT NULL, signing_key_fingerprint BLOB NOT NULL)")
                    try database.execute("INSERT INTO migration_history (version, checksum) VALUES (?, ?)", values: [.integer(25), .text(versionTwentyFiveChecksum)])
                    try database.execute("UPDATE schema_migrations SET version = 25")
                }
                database.removeMigrationSnapshot()
            } catch { throw error }
        }
        if version < 26 {
            try database.createVerifiedSnapshot()
            do {
                try database.transaction {
                    try database.execute("CREATE TABLE tracker_export_revision (id INTEGER PRIMARY KEY CHECK (id = 1), revision INTEGER NOT NULL CHECK (revision >= 0))")
                    try database.execute("INSERT INTO tracker_export_revision (id, revision) VALUES (1, 0)")
                    try database.execute("CREATE TABLE protected_export_events (id TEXT PRIMARY KEY NOT NULL, export_id TEXT NOT NULL, category TEXT NOT NULL, destination_class TEXT NOT NULL, confirmation_fingerprint TEXT NOT NULL, outcome TEXT NOT NULL, occurred_at REAL NOT NULL)")
                    for table in protectedExportRevisionTables {
                        try database.execute(exportRevisionTriggerSQL(table: table, operation: "INSERT"))
                        try database.execute(exportRevisionTriggerSQL(table: table, operation: "UPDATE"))
                        try database.execute(exportRevisionTriggerSQL(table: table, operation: "DELETE"))
                    }
                    try database.execute("INSERT INTO migration_history (version, checksum) VALUES (?, ?)", values: [.integer(26), .text(versionTwentySixChecksum)])
                    try database.execute("UPDATE schema_migrations SET version = 26")
                }
                database.removeMigrationSnapshot()
            } catch { throw error }
        }
        if version < 27 {
            try database.createVerifiedSnapshot()
            do {
                try database.transaction {
                    try database.execute("ALTER TABLE portable_archive_catalogue ADD COLUMN lifecycle_state TEXT NOT NULL DEFAULT 'Verified'")
                    try database.execute("ALTER TABLE portable_archive_catalogue ADD COLUMN last_expiry_outcome TEXT NOT NULL DEFAULT 'none'")
                    try database.execute("INSERT INTO migration_history (version, checksum) VALUES (?, ?)", values: [.integer(27), .text(versionTwentySevenChecksum)])
                    try database.execute("UPDATE schema_migrations SET version = 27")
                }
                database.removeMigrationSnapshot()
            } catch { throw error }
        }
        if version < 28 {
            try database.createVerifiedSnapshot()
            do {
                try database.transaction {
                    let existingColumns = try database.rows("PRAGMA table_info(portable_archive_catalogue)").compactMap { values -> String? in
                        guard values.count > 1, case let .text(name) = values[1] else { return nil }
                        return name
                    }
                    if !existingColumns.contains("storage_class") { try database.execute("ALTER TABLE portable_archive_catalogue ADD COLUMN storage_class TEXT NOT NULL DEFAULT 'external'") }
                    if !existingColumns.contains("managed_relative_path") { try database.execute("ALTER TABLE portable_archive_catalogue ADD COLUMN managed_relative_path TEXT") }
                    if !existingColumns.contains("expiry_token") { try database.execute("ALTER TABLE portable_archive_catalogue ADD COLUMN expiry_token TEXT") }
                    if !existingColumns.contains("expiry_revision") { try database.execute("ALTER TABLE portable_archive_catalogue ADD COLUMN expiry_revision INTEGER NOT NULL DEFAULT 0") }
                    try database.execute("INSERT OR IGNORE INTO migration_history (version, checksum) VALUES (?, ?)", values: [.integer(28), .text(versionTwentyEightChecksum)])
                    try database.execute("UPDATE schema_migrations SET version = 28")
                }
                database.removeMigrationSnapshot()
            } catch { throw error }
        }
        if version < 29 {
            try database.createVerifiedSnapshot()
            do {
                try database.transaction {
                    let existingColumns = try database.rows("PRAGMA table_info(portable_archive_catalogue)").compactMap { values -> String? in
                        guard values.count > 1, case let .text(name) = values[1] else { return nil }
                        return name
                    }
                    if !existingColumns.contains("expiry_quarantine_relative_path") {
                        try database.execute("ALTER TABLE portable_archive_catalogue ADD COLUMN expiry_quarantine_relative_path TEXT")
                    }
                    try database.execute("INSERT OR IGNORE INTO migration_history (version, checksum) VALUES (?, ?)", values: [.integer(29), .text(versionTwentyNineChecksum)])
                    try database.execute("UPDATE schema_migrations SET version = 29")
                }
                database.removeMigrationSnapshot()
            } catch { throw error }
        }
        if version < 30 {
            try database.createVerifiedSnapshot()
            do {
                try database.transaction {
                    let existingColumns = try database.rows("PRAGMA table_info(portable_archive_catalogue)").compactMap { values -> String? in
                        guard values.count > 1, case let .text(name) = values[1] else { return nil }
                        return name
                    }
                    if !existingColumns.contains("expiry_expected_device") {
                        try database.execute("ALTER TABLE portable_archive_catalogue ADD COLUMN expiry_expected_device INTEGER")
                    }
                    if !existingColumns.contains("expiry_expected_inode") {
                        try database.execute("ALTER TABLE portable_archive_catalogue ADD COLUMN expiry_expected_inode INTEGER")
                    }
                    try database.execute("INSERT OR IGNORE INTO migration_history (version, checksum) VALUES (?, ?)", values: [.integer(30), .text(versionThirtyChecksum)])
                    try database.execute("UPDATE schema_migrations SET version = 30")
                }
                database.removeMigrationSnapshot()
            } catch { throw error }
        }
        if version < 31 {
            try database.createVerifiedSnapshot()
            do {
                try database.transaction {
                    try database.execute("CREATE TABLE retained_data_purge_jobs (id TEXT PRIMARY KEY NOT NULL, state TEXT NOT NULL, tombstone_snapshot TEXT NOT NULL, started_at REAL NOT NULL, finished_at REAL)")
                    try database.execute("CREATE TABLE retained_data_purge_scope (job_id TEXT NOT NULL REFERENCES retained_data_purge_jobs(id), archive_id TEXT NOT NULL, archive_revision INTEGER NOT NULL, expires_at REAL NOT NULL, created_at REAL NOT NULL, lifecycle_state TEXT NOT NULL, checksum BLOB NOT NULL, fingerprint BLOB NOT NULL, relative_path TEXT NOT NULL, PRIMARY KEY(job_id, archive_id))")
                    try database.execute("CREATE TABLE retained_data_purge_archive_phases (job_id TEXT NOT NULL REFERENCES retained_data_purge_jobs(id), archive_id TEXT NOT NULL, phase TEXT NOT NULL, replacement_archive_id TEXT, outcome TEXT NOT NULL DEFAULT '', PRIMARY KEY(job_id, archive_id))")
                    try database.execute("CREATE TABLE portable_archive_operation_leases (archive_id TEXT PRIMARY KEY NOT NULL, owner_kind TEXT NOT NULL, owner_id TEXT NOT NULL, acquired_at REAL NOT NULL)")
                    try database.execute("INSERT INTO migration_history (version, checksum) VALUES (?, ?)", values: [.integer(31), .text(versionThirtyOneChecksum)])
                    try database.execute("UPDATE schema_migrations SET version = 31")
                }
                database.removeMigrationSnapshot()
            } catch { throw error }
        }
        if version < 32 {
            try database.createVerifiedSnapshot()
            do {
                try database.transaction {
                    let existingColumns = try database.rows("PRAGMA table_info(retained_data_purge_scope)").compactMap { values -> String? in
                        guard values.count > 1, case let .text(name) = values[1] else { return nil }
                        return name
                    }
                    if !existingColumns.contains("predecessor_device") {
                        try database.execute("ALTER TABLE retained_data_purge_scope ADD COLUMN predecessor_device INTEGER")
                    }
                    if !existingColumns.contains("predecessor_inode") {
                        try database.execute("ALTER TABLE retained_data_purge_scope ADD COLUMN predecessor_inode INTEGER")
                    }
                    try database.execute("INSERT OR IGNORE INTO migration_history (version, checksum) VALUES (?, ?)", values: [.integer(32), .text(versionThirtyTwoChecksum)])
                    try database.execute("UPDATE schema_migrations SET version = 32")
                }
                database.removeMigrationSnapshot()
            } catch { throw error }
        }
        if version < 33 {
            try database.createVerifiedSnapshot()
            do {
                try database.transaction {
                    let existingColumns = try database.rows("PRAGMA table_info(retained_data_purge_archive_phases)").compactMap { values -> String? in
                        guard values.count > 1, case let .text(name) = values[1] else { return nil }
                        return name
                    }
                    if !existingColumns.contains("replacement_device") {
                        try database.execute("ALTER TABLE retained_data_purge_archive_phases ADD COLUMN replacement_device INTEGER")
                    }
                    if !existingColumns.contains("replacement_inode") {
                        try database.execute("ALTER TABLE retained_data_purge_archive_phases ADD COLUMN replacement_inode INTEGER")
                    }
                    try database.execute("INSERT OR IGNORE INTO migration_history (version, checksum) VALUES (?, ?)", values: [.integer(33), .text(versionThirtyThreeChecksum)])
                    try database.execute("UPDATE schema_migrations SET version = 33")
                }
                database.removeMigrationSnapshot()
            } catch { throw error }
        }
        if version < 34 {
            try database.createVerifiedSnapshot()
            do {
                try database.transaction {
                    let existingColumns = try database.rows("PRAGMA table_info(contacts)").compactMap { values -> String? in
                        guard values.count > 1, case let .text(name) = values[1] else { return nil }
                        return name
                    }
                    if !existingColumns.contains("personal_email") {
                        try database.execute("ALTER TABLE contacts ADD COLUMN personal_email TEXT NOT NULL DEFAULT ''")
                    }
                    if !existingColumns.contains("mobile_phone") {
                        try database.execute("ALTER TABLE contacts ADD COLUMN mobile_phone TEXT NOT NULL DEFAULT ''")
                    }
                    if !existingColumns.contains("office_phone") {
                        try database.execute("ALTER TABLE contacts ADD COLUMN office_phone TEXT NOT NULL DEFAULT ''")
                    }
                    if !existingColumns.contains("instagram_url") {
                        try database.execute("ALTER TABLE contacts ADD COLUMN instagram_url TEXT NOT NULL DEFAULT ''")
                    }
                    if !existingColumns.contains("facebook_url") {
                        try database.execute("ALTER TABLE contacts ADD COLUMN facebook_url TEXT NOT NULL DEFAULT ''")
                    }
                    try database.execute("INSERT OR IGNORE INTO migration_history (version, checksum) VALUES (?, ?)", values: [.integer(34), .text(versionThirtyFourChecksum)])
                    try database.execute("UPDATE schema_migrations SET version = 34")
                }
                database.removeMigrationSnapshot()
            } catch { throw error }
        }
    }

    private static func isActiveOpportunity(_ opportunityID: String, in database: EncryptedDatabase) throws -> Bool {
        guard case .text? = try database.rows("SELECT id FROM opportunities WHERE id = ? AND deleted_at IS NULL", values: [.text(opportunityID)]).first?.first else { return false }
        return true
    }

    private static let protectedExportRevisionTables = [
        "opportunities", "task_reminders", "opportunity_stage_history", "opportunity_response_history",
        "contacts", "contact_opportunities", "interactions", "import_reports", "import_report_rows",
        "posting_checks", "reconciliation_reviews", "reconciliation_results", "reconciliation_check_operations",
        "document_references", "activity_events", "deletion_tombstones"
    ]

    private static func exportRevisionTriggerSQL(table: String, operation: String) -> String {
        let trigger = "tracker_export_revision_\(table)_\(operation.lowercased())"
        let activityReference = operation == "DELETE" ? "OLD.kind" : "NEW.kind"
        let condition = table == "activity_events" ? " WHEN \(activityReference) <> 'protected_export_verified'" : ""
        return "CREATE TRIGGER \(trigger) AFTER \(operation) ON \(table)\(condition) BEGIN UPDATE tracker_export_revision SET revision = CASE WHEN revision >= 9223372036854775807 THEN RAISE(ABORT, 'tracker export revision overflow') ELSE revision + 1 END WHERE id = 1; END"
    }

    private static func checksum(for manifest: String) -> String {
        SHA256.hash(data: Data(manifest.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
