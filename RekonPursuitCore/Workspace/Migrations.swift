import Foundation

enum WorkspaceMigrations {
    static let currentVersion = 2

    static func apply(to database: EncryptedDatabase) throws {
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
    }
}
