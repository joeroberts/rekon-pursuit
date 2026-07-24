import Foundation

enum WorkspaceMigrations {
    static let currentVersion = 1

    static func apply(to database: EncryptedDatabase) throws {
        try database.execute("CREATE TABLE IF NOT EXISTS schema_migrations (version INTEGER NOT NULL)")
        let versions = try database.rows("SELECT version FROM schema_migrations LIMIT 1")
        if versions.isEmpty {
            try database.transaction {
                try database.execute("CREATE TABLE opportunities (id TEXT PRIMARY KEY NOT NULL, title TEXT NOT NULL, company TEXT NOT NULL, created_at REAL NOT NULL)")
                try database.execute("CREATE TABLE activity_events (id TEXT PRIMARY KEY NOT NULL, kind TEXT NOT NULL, opportunity_id TEXT NOT NULL REFERENCES opportunities(id), actor_id TEXT NOT NULL, correlation_id TEXT NOT NULL, occurred_at REAL NOT NULL)")
                try database.execute("INSERT INTO schema_migrations (version) VALUES (?)", values: [.integer(Int64(currentVersion))])
            }
        }
    }
}
