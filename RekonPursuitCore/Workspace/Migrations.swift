import Foundation
import CryptoKit

enum WorkspaceMigrations {
    static let currentVersion = 5
    static let baselineChecksum = checksum(for: "rekon-pursuit:migrations:v1-v4")
    static let versionFiveChecksum = checksum(for: "5|ALTER TABLE opportunities ADD COLUMN deleted_at REAL")

    static func apply(to database: EncryptedDatabase, failVersionFive: Bool = false) throws {
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
        if version < 5 {
            try database.createVerifiedSnapshot()
            do {
                try database.transaction {
                    try database.execute("ALTER TABLE opportunities ADD COLUMN deleted_at REAL")
                    if failVersionFive { throw WorkspaceStoreError.injectedFailure }
                    try database.execute(
                        "INSERT INTO migration_history (version, checksum) VALUES (?, ?)",
                        values: [.integer(5), .text(versionFiveChecksum)]
                    )
                    try database.execute("UPDATE schema_migrations SET version = 5")
                }
                try? FileManager.default.removeItem(at: database.migrationSnapshotURL)
            } catch {
                throw error
            }
        }
    }

    private static func checksum(for manifest: String) -> String {
        SHA256.hash(data: Data(manifest.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
