import Foundation
import CryptoKit

enum WorkspaceMigrations {
    static let currentVersion = 13
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

    static func apply(to database: EncryptedDatabase, failVersionFive: Bool = false, failVersionSix: Bool = false) throws {
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
    }

    private static func checksum(for manifest: String) -> String {
        SHA256.hash(data: Data(manifest.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
