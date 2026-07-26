import Foundation
import Security

/// The only workspace combination that is opened automatically is a database with
/// one primary key and no interrupted-creation journal. Everything else is kept
/// intact for an explicit recovery flow.
enum WorkspaceOpenState: Equatable {
    case ready(WorkspaceStore)
    case createAvailable
    case recoveryRequired
    case locked
    case denied
    case corrupt
    case unavailable

    static func == (lhs: WorkspaceOpenState, rhs: WorkspaceOpenState) -> Bool {
        switch (lhs, rhs) {
        case (.ready, .ready), (.createAvailable, .createAvailable), (.recoveryRequired, .recoveryRequired), (.locked, .locked), (.denied, .denied), (.corrupt, .corrupt), (.unavailable, .unavailable):
            true
        default:
            false
        }
    }
}

enum WorkspaceCreationPhase: String, Codable, Equatable {
    case staging
    case pendingWritten = "pending-written"
    case databasePromoted = "database-promoted"
    case primaryPromoted = "primary-promoted"
    case cleanupPending = "cleanup-pending"
}

struct WorkspaceCreationJournal: Codable, Equatable {
    let attemptID: String
    let phase: WorkspaceCreationPhase
}

struct WorkspaceMaterialState: Equatable {
    let hasDatabase: Bool
    let hasSidecars: Bool
    let hasJournal: Bool
    let hasPrimaryKey: Bool
    let hasPendingKey: Bool

    var isEmpty: Bool {
        !hasDatabase && !hasSidecars && !hasJournal && !hasPrimaryKey && !hasPendingKey
    }

    var isVerifiedReadyPair: Bool {
        // SQLite WAL/SHM sidecars are normal while a healthy workspace is open.
        // They are database artifacts, not interrupted-creation evidence.
        hasDatabase && !hasJournal && hasPrimaryKey && !hasPendingKey
    }
}

enum WorkspaceCreationFault: Error, Equatable {
    case stagingClose
    case pendingKeyWrite
    case databasePromotion
    case primaryKeyPromotion
    case pendingKeyCleanup
    case finalReopen
}

@MainActor
final class WorkspaceSession {
    private let root: URL
    private let keyStore: WorkspaceKeyStore
    private let newKey: @MainActor () throws -> Data
    private let clock: () -> Date
    private let creationFault: WorkspaceCreationFault?

    init(
        root: URL,
        keyStore: WorkspaceKeyStore = KeychainWorkspaceKeyStore(),
        newKey: @MainActor @escaping () throws -> Data = WorkspaceSession.generateKey,
        now: Date? = nil,
        clock: @escaping () -> Date = { .now },
        creationFault: WorkspaceCreationFault? = nil
    ) {
        self.root = root
        self.keyStore = keyStore
        self.newKey = newKey
        self.clock = now.map { fixedNow in { fixedNow } } ?? clock
        self.creationFault = creationFault
    }

    func create() throws -> WorkspaceStore {
        let existingMaterials = try materials()
        if !existingMaterials.isEmpty {
            guard try retryableStagingAttempt(existingMaterials) else {
                throw WorkspaceSessionError.workspaceAlreadyExists
            }
            try FileManager.default.removeItem(at: journalURL)
        }

        let key = try newKey()
        guard key.count == 32 else { throw EncryptedDatabaseError.invalidKeyLength }
        let attemptID = UUID().uuidString
        let stagingRoot = root.appendingPathComponent(".creating-\(attemptID)", isDirectory: true)
        let stagingDatabaseURL = stagingRoot.appendingPathComponent("workspace.sqlite")
        try FileManager.default.createDirectory(at: stagingRoot, withIntermediateDirectories: true)
        try writeJournal(attemptID: attemptID, phase: .staging)

        do {
            let stagingStore = try openStore(at: stagingDatabaseURL, with: key, createIfMissing: true)
            try stagingStore.close()
            try throwIfInjected(.stagingClose)

            try keyStore.writePendingWorkspaceKey(key)
            try writeJournal(attemptID: attemptID, phase: .pendingWritten)
            try throwIfInjected(.pendingKeyWrite)

            try FileManager.default.moveItem(at: stagingDatabaseURL, to: databaseURL)
            try writeJournal(attemptID: attemptID, phase: .databasePromoted)
            try throwIfInjected(.databasePromotion)

            // Do not use a destructive "promote" primitive: if this fails, both
            // keys remain as evidence for a future explicit recovery flow.
            try keyStore.writeWorkspaceKey(key)
            try throwIfInjected(.primaryKeyPromotion)
            try writeJournal(attemptID: attemptID, phase: .primaryPromoted)

            try keyStore.deletePendingWorkspaceKey()
            try writeJournal(attemptID: attemptID, phase: .cleanupPending)
            try throwIfInjected(.pendingKeyCleanup)

            try? FileManager.default.removeItem(at: stagingRoot)

            // The journal is proof that this creation attempt is still in
            // progress until the database has been opened through the same
            // normal path used on a later launch. Do not remove it before
            // that final open succeeds.
            let openedStore = try openStore(with: key, createIfMissing: false)
            try FileManager.default.removeItem(at: journalURL)
            return openedStore
        } catch {
            // Only staging data belongs solely to this incomplete attempt. Once a
            // database is promoted, no database or key material is auto-deleted.
            if !FileManager.default.fileExists(atPath: databaseURL.path) {
                try? FileManager.default.removeItem(at: stagingRoot)
            }
            throw error
        }
    }

    func open() throws -> WorkspaceOpenState {
        do {
            let material = try materials()
            if material.isEmpty { return .createAvailable }
            guard material.isVerifiedReadyPair else { return .recoveryRequired }
            guard let key = try keyStore.readWorkspaceKey() else { return .recoveryRequired }
            return .ready(try openStore(with: key, createIfMissing: false))
        } catch let error as WorkspaceKeyStoreError {
            switch error {
            case .locked: return .locked
            case .denied: return .denied
            case .unavailable: return .unavailable
            }
        } catch is EncryptedDatabaseError {
            return .corrupt
        } catch {
            return .unavailable
        }
    }

    /// Exposed for focused state fixtures only. It contains booleans, never a
    /// filesystem path, key value, Keychain account, or journal attempt ID.
    func materialState() throws -> WorkspaceMaterialState {
        try materials()
    }

    func creationJournal() throws -> WorkspaceCreationJournal? {
        guard FileManager.default.fileExists(atPath: journalURL.path) else { return nil }
        return try JSONDecoder().decode(WorkspaceCreationJournal.self, from: Data(contentsOf: journalURL))
    }

    func restore(from backupURL: URL) throws -> WorkspaceStore {
        guard FileManager.default.fileExists(atPath: databaseURL.path) else { throw WorkspaceSessionError.workspaceMissing }
        guard let key = try keyStore.readWorkspaceKey() else { throw WorkspaceSessionError.workspaceKeyMissing }

        let backup = try EncryptedDatabase.open(url: backupURL, key: key, createIfMissing: false)
        do {
            _ = try backup.scalarInt("SELECT count(*) FROM sqlite_master")
            try backup.close()
        } catch {
            try? backup.close()
            throw error
        }

        let stagingURL = root.appendingPathComponent(".restoring-\(UUID().uuidString)")
        let previousURL = root.appendingPathComponent(".restore-rollback-\(UUID().uuidString)")
        try FileManager.default.copyItem(at: backupURL, to: stagingURL)
        do {
            try FileManager.default.moveItem(at: databaseURL, to: previousURL)
            try FileManager.default.moveItem(at: stagingURL, to: databaseURL)
            let restored = try openStore(with: key, createIfMissing: false)
            try? FileManager.default.removeItem(at: previousURL)
            return restored
        } catch {
            try? FileManager.default.removeItem(at: databaseURL)
            if FileManager.default.fileExists(atPath: previousURL.path) {
                try? FileManager.default.moveItem(at: previousURL, to: databaseURL)
            }
            try? FileManager.default.removeItem(at: stagingURL)
            throw error
        }
    }

    private var databaseURL: URL { root.appendingPathComponent("workspace.sqlite") }
    private var journalURL: URL { root.appendingPathComponent("workspace-creation.json") }

    private func materials() throws -> WorkspaceMaterialState {
        WorkspaceMaterialState(
            hasDatabase: FileManager.default.fileExists(atPath: databaseURL.path),
            hasSidecars: [sidecarURL("-wal"), sidecarURL("-shm")].contains { FileManager.default.fileExists(atPath: $0.path) },
            hasJournal: FileManager.default.fileExists(atPath: journalURL.path),
            hasPrimaryKey: try keyStore.readWorkspaceKey() != nil,
            hasPendingKey: try keyStore.readPendingWorkspaceKey() != nil
        )
    }

    private func writeJournal(attemptID: String, phase: WorkspaceCreationPhase) throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(WorkspaceCreationJournal(attemptID: attemptID, phase: phase))
        try data.write(to: journalURL, options: .atomic)
    }

    private func retryableStagingAttempt(_ material: WorkspaceMaterialState) throws -> Bool {
        guard !material.hasDatabase,
              !material.hasSidecars,
              material.hasJournal,
              !material.hasPrimaryKey,
              !material.hasPendingKey else {
            return false
        }
        return try creationJournal()?.phase == .staging
    }

    private func throwIfInjected(_ point: WorkspaceCreationFault) throws {
        if creationFault == point { throw point }
    }

    private func sidecarURL(_ suffix: String) -> URL {
        URL(fileURLWithPath: databaseURL.path + suffix)
    }

    private func openStore(with key: Data, createIfMissing: Bool) throws -> WorkspaceStore {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return try openStore(at: databaseURL, with: key, createIfMissing: createIfMissing)
    }

    private func openStore(at url: URL, with key: Data, createIfMissing: Bool) throws -> WorkspaceStore {
        let database = try EncryptedDatabase.open(url: url, key: key, createIfMissing: createIfMissing)
        // This fault is deliberately inside the actual final reopen path. It
        // lets the focused fixture prove that a failed reopen retains the
        // journal and every committed artifact for non-destructive recovery.
        if creationFault == .finalReopen, url == databaseURL, !createIfMissing {
            try? database.close()
            throw WorkspaceCreationFault.finalReopen
        }
        return try WorkspaceStore(database: database, clock: clock, actorID: "local-user", correlationID: UUID().uuidString)
    }

    private static func generateKey() throws -> Data {
        var key = Data(count: 32)
        let status = key.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, bytes.count, bytes.baseAddress!)
        }
        guard status == errSecSuccess else { throw WorkspaceKeyStoreError.unavailable(status) }
        return key
    }
}

enum WorkspaceSessionError: Error {
    case workspaceAlreadyExists
    case workspaceMissing
    case workspaceKeyMissing
}
