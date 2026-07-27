import CryptoKit
import Darwin
import Foundation
import Security

nonisolated struct PortableArchiveRestoreConfirmation: Equatable, Sendable {
    let archiveID: UUID
    let createdAt: Date
    let signingKeyFingerprint: Data
}

nonisolated struct RestoredWorkspaceCandidate: Equatable, Sendable {
    let candidateID: UUID
    let archiveID: UUID
}

nonisolated struct PortableArchiveRestoreRequest: Sendable {
    let archiveURL: URL
    let recoveryKey: RecoveryKey
    let localCatalogue: [PortableArchiveCatalogueRow]
    let confirmation: PortableArchiveRestoreConfirmation?

    init(
        archiveURL: URL,
        recoveryKey: RecoveryKey,
        localCatalogue: [PortableArchiveCatalogueRow] = [],
        confirmation: PortableArchiveRestoreConfirmation?
    ) {
        self.archiveURL = archiveURL
        self.recoveryKey = recoveryKey
        self.localCatalogue = localCatalogue
        self.confirmation = confirmation
    }
}

nonisolated enum PortableArchiveRestoreError: Error, LocalizedError, Sendable {
    case confirmationRequired
    case catalogueMismatch
    case candidateCleanupPending
    case restoreFailed

    var errorDescription: String? {
        switch self {
        case .confirmationRequired:
            return "Confirm the verified archive identity before creating a new local workspace."
        case .catalogueMismatch:
            return "This archive does not match the local recovery catalogue. No workspace was created."
        case .candidateCleanupPending:
            return "A prior restore candidate needs cleanup before another restore can start."
        case .restoreFailed:
            return "The archive could not be restored. The current workspace and selected archive were not changed."
        }
    }
}

/// A narrow deterministic seam for restore-lifecycle tests. It is intentionally
/// not connected to preferences, launch arguments, or UI code.
nonisolated enum PortableArchiveRestoreFaultPoint: Equatable, Sendable {
    case afterReservation
    case afterKeyCreation
    case afterRootCreation
    case afterImport
    case afterCheckpoint
    case afterReopen
    case afterPromotion
    case beforeReady
    /// Simulates a failure while persisting the terminal ready-state record,
    /// after all candidate material has been promoted and verified.
    case markReadyPersistence
}

/// Archive I/O and cryptographic verification are deliberately serialized away
/// from the UI actor.  Candidate import remains behind the restore service's
/// explicit confirmation boundary.
actor PortableArchiveRestoreWorker {
    private let restoreService: PortableArchiveRestoreService
    private let executionObserver: @Sendable (Bool) -> Void

    init(
        restoreService: PortableArchiveRestoreService = .init(),
        executionObserver: @escaping @Sendable (Bool) -> Void = { _ in }
    ) {
        self.restoreService = restoreService
        self.executionObserver = executionObserver
    }

    func verifyArchive(at url: URL, recoveryKey: RecoveryKey) throws -> VerifiedPortableArchive {
        try PortableArchiveService.verify(data: Data(contentsOf: url), recoveryKey: recoveryKey)
    }

    func restore(_ request: PortableArchiveRestoreRequest) throws -> RestoredWorkspaceCandidate {
        executionObserver(Thread.isMainThread)
        let archiveData = try Data(contentsOf: request.archiveURL)
        return try restoreService.restore(
            archiveData: archiveData,
            recoveryKey: request.recoveryKey,
            localCatalogue: request.localCatalogue,
            confirmation: request.confirmation
        )
    }
}

nonisolated protocol RestoreCandidateKeyStoring: AnyObject {
    func readOrCreateKey() throws -> Data
}

nonisolated final class InMemoryRestoreCandidateKeyStore: RestoreCandidateKeyStoring {
    private var key: Data?

    func readOrCreateKey() throws -> Data {
        if let key { return key }
        var bytes = Data(repeating: 0, count: 32)
        guard bytes.withUnsafeMutableBytes({ SecRandomCopyBytes(kSecRandomDefault, 32, $0.baseAddress!) }) == errSecSuccess else {
            throw PortableArchiveRestoreError.restoreFailed
        }
        key = bytes
        return bytes
    }
}

nonisolated final class RestoreCandidateKeychainStore: RestoreCandidateKeyStoring {
    private static let service = "com.rekonlabs.RekonPursuit.restore-candidate-registry.v1"
    private static let account = "registry-key"

    func readOrCreateKey() throws -> Data {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Self.service,
            kSecAttrAccount: Self.account,
            kSecUseDataProtectionKeychain: true,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess, let data = result as? Data, data.count == 32 { return data }
        guard status == errSecItemNotFound else { throw PortableArchiveRestoreError.restoreFailed }
        var key = Data(repeating: 0, count: 32)
        guard key.withUnsafeMutableBytes({ SecRandomCopyBytes(kSecRandomDefault, 32, $0.baseAddress!) }) == errSecSuccess else {
            throw PortableArchiveRestoreError.restoreFailed
        }
        let add: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Self.service,
            kSecAttrAccount: Self.account,
            kSecValueData: key,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecUseDataProtectionKeychain: true
        ]
        guard SecItemAdd(add as CFDictionary, nil) == errSecSuccess else { throw PortableArchiveRestoreError.restoreFailed }
        return key
    }
}

nonisolated final class InMemoryRestoreWorkspaceKeys {
    private var stores: [UUID: InMemoryWorkspaceKeyStore] = [:]

    func store(for candidateID: UUID) -> WorkspaceKeyStore {
        if let store = stores[candidateID] { return store }
        let store = InMemoryWorkspaceKeyStore()
        stores[candidateID] = store
        return store
    }

    func key(for candidateID: UUID) -> Data? { stores[candidateID]?.primaryKey }
}

nonisolated protocol RestoreCandidateSigningIdentityStoring: AnyObject {
    func createAndVerify(for candidateID: UUID) throws
    func delete(for candidateID: UUID) throws
    func isAbsent(for candidateID: UUID) throws -> Bool
}

nonisolated final class InMemoryRestoreCandidateSigningIdentityStore: RestoreCandidateSigningIdentityStoring {
    private var identities: [UUID: Data] = [:]

    func createAndVerify(for candidateID: UUID) throws {
        identities[candidateID] = Curve25519.Signing.PrivateKey().rawRepresentation
    }

    func delete(for candidateID: UUID) throws { identities[candidateID] = nil }
    func isAbsent(for candidateID: UUID) throws -> Bool { identities[candidateID] == nil }
    func identity(for candidateID: UUID) -> Data? { identities[candidateID] }
}

nonisolated final class RestoreCandidateSigningIdentityStore: RestoreCandidateSigningIdentityStoring {
    private static let service = "com.rekonlabs.RekonPursuit.restore-candidate.v1"

    func createAndVerify(for candidateID: UUID) throws {
        let account = "\(candidateID.uuidString.lowercased()).signing"
        let key = Curve25519.Signing.PrivateKey().rawRepresentation
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Self.service,
            kSecAttrAccount: account,
            kSecUseDataProtectionKeychain: true
        ]
        let attributes: [CFString: Any] = [
            kSecValueData: key,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        _ = SecItemDelete(query as CFDictionary)
        guard SecItemAdd((query.merging(attributes) { _, new in new }) as CFDictionary, nil) == errSecSuccess else {
            throw PortableArchiveRestoreError.restoreFailed
        }
        var verify = query
        verify[kSecReturnData] = true
        verify[kSecMatchLimit] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(verify as CFDictionary, &result) == errSecSuccess,
              let saved = result as? Data,
              saved == key else { throw PortableArchiveRestoreError.restoreFailed }
    }

    func delete(for candidateID: UUID) throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Self.service,
            kSecAttrAccount: "\(candidateID.uuidString.lowercased()).signing",
            kSecUseDataProtectionKeychain: true
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw PortableArchiveRestoreError.candidateCleanupPending }
    }

    func isAbsent(for candidateID: UUID) throws -> Bool {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Self.service,
            kSecAttrAccount: "\(candidateID.uuidString.lowercased()).signing",
            kSecUseDataProtectionKeychain: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        if status == errSecItemNotFound { return true }
        if status == errSecSuccess { return false }
        throw PortableArchiveRestoreError.candidateCleanupPending
    }
}

nonisolated private final class InMemoryWorkspaceKeyStore: WorkspaceKeyStore {
    var primaryKey: Data?
    var pendingKey: Data?

    func readWorkspaceKey() throws -> Data? { primaryKey }
    func writeWorkspaceKey(_ key: Data) throws { primaryKey = key }
    func deleteWorkspaceKey() throws { primaryKey = nil }
    func readPendingWorkspaceKey() throws -> Data? { pendingKey }
    func writePendingWorkspaceKey(_ key: Data) throws { pendingKey = key }
    func promotePendingWorkspaceKey() throws { primaryKey = pendingKey; pendingKey = nil }
    func deletePendingWorkspaceKey() throws { pendingKey = nil }
}

/// This mutable coordinator is constructed once and then owned exclusively by
/// `PortableArchiveRestoreWorker`. Its collaborators are synchronous system
/// boundaries (Keychain and filesystem); it is not exposed to UI code.
nonisolated final class PortableArchiveRestoreService: @unchecked Sendable {
    private let candidatesRoot: URL
    private let registry: RestoreCandidateRegistry
    private let workspaceKeyStoreForCandidate: (UUID) -> WorkspaceKeyStore
    private let signingIdentityStore: RestoreCandidateSigningIdentityStoring
    private let injectedFault: PortableArchiveRestoreFaultPoint?

    init(
        candidatesRoot: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("com.rekonlabs.RekonPursuit", isDirectory: true)
            .appendingPathComponent("RestoredWorkspaces", isDirectory: true),
        candidateKeyStore: RestoreCandidateKeyStoring = RestoreCandidateKeychainStore(),
        workspaceKeyStoreForCandidate: @escaping (UUID) -> WorkspaceKeyStore = { KeychainWorkspaceKeyStore(restoreCandidate: $0) },
        signingIdentityStore: RestoreCandidateSigningIdentityStoring = RestoreCandidateSigningIdentityStore(),
        injectedFault: PortableArchiveRestoreFaultPoint? = nil
    ) {
        self.candidatesRoot = candidatesRoot
        self.registry = RestoreCandidateRegistry(
            root: candidatesRoot.deletingLastPathComponent(),
            keyStore: candidateKeyStore,
            failMarkReadyPersistence: injectedFault == .markReadyPersistence
        )
        self.workspaceKeyStoreForCandidate = workspaceKeyStoreForCandidate
        self.signingIdentityStore = signingIdentityStore
        self.injectedFault = injectedFault
    }

    func restore(
        archiveData: Data,
        recoveryKey: RecoveryKey,
        localCatalogue: [PortableArchiveCatalogueRow] = [],
        confirmation: PortableArchiveRestoreConfirmation?
    ) throws -> RestoredWorkspaceCandidate {
        try reconcileIncompleteCandidates()
        let contents = try PortableArchiveService.readVerifiedArchive(data: archiveData, recoveryKey: recoveryKey)
        if let matchingArchive = localCatalogue.first(where: { $0.archiveID == contents.archive.archiveID }) {
            guard matchingArchive.signingKeyFingerprint == contents.archive.signingKeyFingerprint else {
                throw PortableArchiveRestoreError.catalogueMismatch
            }
        }
        guard confirmation == PortableArchiveRestoreConfirmation(
            archiveID: contents.archive.archiveID,
            createdAt: contents.archive.createdAt,
            signingKeyFingerprint: contents.archive.signingKeyFingerprint
        ) else {
            throw PortableArchiveRestoreError.confirmationRequired
        }

        let candidateID = UUID()
        let candidateRoot = candidatesRoot.appendingPathComponent(candidateID.uuidString.lowercased(), isDirectory: true)
        let stagingRoot = candidateRoot.appendingPathComponent(".staging", isDirectory: true)
        let keyStore = workspaceKeyStoreForCandidate(candidateID)
        var reserved = false

        do {
            try registry.reserve(candidateID: candidateID, archiveID: contents.archive.archiveID)
            reserved = true
            try failIfInjected(.afterReservation)
            try RestoreCandidateBootstrap.createFreshDatabase(
                at: stagingRoot,
                keyStore: keyStore,
                snapshot: contents.snapshot,
                failIfInjected: failIfInjected
            )
            try signingIdentityStore.createAndVerify(for: candidateID)
            try registry.markKeyAndRootCreated(candidateID: candidateID)
            try FileManager.default.createDirectory(at: candidateRoot, withIntermediateDirectories: true)
            try FileManager.default.moveItem(at: stagingRoot.appendingPathComponent("workspace.sqlite"), to: candidateRoot.appendingPathComponent("workspace.sqlite"))
            try failIfInjected(.afterPromotion)
            let databaseKey = try requireCandidateDatabaseKey(keyStore)
            let reopened = try EncryptedDatabase.open(url: candidateRoot.appendingPathComponent("workspace.sqlite"), key: databaseKey, createIfMissing: false)
            try WorkspaceMigrations.apply(to: reopened)
            _ = try reopened.scalarInt("SELECT count(*) FROM sqlite_master")
            try failIfInjected(.afterReopen)
            try reopened.checkpointAndClose()
            try? FileManager.default.removeItem(at: stagingRoot)
            try failIfInjected(.beforeReady)
            try registry.markReady(candidateID: candidateID)
            return RestoredWorkspaceCandidate(candidateID: candidateID, archiveID: contents.archive.archiveID)
        } catch {
            if reserved {
                try cleanupCandidate(candidateID: candidateID, root: candidateRoot, keyStore: keyStore, originalFailure: error)
            }
            throw error is PortableArchiveRestoreError ? error : PortableArchiveRestoreError.restoreFailed
        }
    }

    func restoreCandidateRecordsForTesting() throws -> [RestoreCandidateRecord] {
        try registry.recordsForTesting()
    }

    private func reconcileIncompleteCandidates() throws {
        for record in try registry.incompleteRecords() {
            let root = candidatesRoot.appendingPathComponent(record.candidateID.uuidString.lowercased(), isDirectory: true)
            try cleanupCandidate(candidateID: record.candidateID, root: root, keyStore: workspaceKeyStoreForCandidate(record.candidateID), originalFailure: PortableArchiveRestoreError.restoreFailed)
            // A retry after a cleanup-only pass is intentional. Do not chain a
            // new candidate onto a previously interrupted restore attempt.
            throw PortableArchiveRestoreError.candidateCleanupPending
        }
    }

    private func cleanupCandidate(candidateID: UUID, root: URL, keyStore: WorkspaceKeyStore, originalFailure: Error) throws {
        do {
            try? FileManager.default.removeItem(at: root)
            try keyStore.deleteWorkspaceKey()
            try keyStore.deletePendingWorkspaceKey()
            try signingIdentityStore.delete(for: candidateID)
            let keyRemoved = try keyStore.readWorkspaceKey() == nil && keyStore.readPendingWorkspaceKey() == nil
            let rootRemoved = !FileManager.default.fileExists(atPath: root.path)
            let signingIdentityRemoved = try signingIdentityStore.isAbsent(for: candidateID)
            guard keyRemoved && rootRemoved && signingIdentityRemoved else { throw PortableArchiveRestoreError.candidateCleanupPending }
            try registry.markUnavailable(candidateID: candidateID, category: failureCategory(for: originalFailure))
        } catch {
            try? registry.markCleanupRetry(candidateID: candidateID, category: .cleanup)
            throw PortableArchiveRestoreError.candidateCleanupPending
        }
    }

    private func requireCandidateDatabaseKey(_ keyStore: WorkspaceKeyStore) throws -> Data {
        guard let key = try keyStore.readWorkspaceKey(), key.count == 32 else { throw PortableArchiveRestoreError.restoreFailed }
        return key
    }

    private func failIfInjected(_ point: PortableArchiveRestoreFaultPoint) throws {
        guard injectedFault == point else { return }
        throw RestoreCandidateLifecycleFault(point: point)
    }

    private func failureCategory(for error: Error) -> RestoreCandidateRecord.FailureCategory {
        guard let fault = error as? RestoreCandidateLifecycleFault else { return .bootstrap }
        switch fault.point {
        case .afterReservation: return .registry
        case .afterKeyCreation, .afterRootCreation, .afterImport, .afterCheckpoint: return .bootstrap
        case .afterReopen: return .reopen
        case .afterPromotion: return .promotion
        case .beforeReady, .markReadyPersistence: return .registry
        }
    }
}

nonisolated private struct RestoreCandidateLifecycleFault: Error {
    let point: PortableArchiveRestoreFaultPoint
}

/// The candidate bootstrap is deliberately independent of `WorkspaceSession`:
/// it never reads or updates the active-workspace selector, journal, or key
/// namespace. It is used only inside the restore worker actor.
nonisolated private enum RestoreCandidateBootstrap {
    static func createFreshDatabase(
        at root: URL,
        keyStore: WorkspaceKeyStore,
        snapshot: Data,
        failIfInjected: (PortableArchiveRestoreFaultPoint) throws -> Void
    ) throws {
        let databaseURL = root.appendingPathComponent("workspace.sqlite")
        guard !FileManager.default.fileExists(atPath: databaseURL.path),
              try keyStore.readWorkspaceKey() == nil,
              try keyStore.readPendingWorkspaceKey() == nil else {
            throw PortableArchiveRestoreError.restoreFailed
        }

        var key = Data(repeating: 0, count: 32)
        guard key.withUnsafeMutableBytes({ bytes in
            SecRandomCopyBytes(kSecRandomDefault, bytes.count, bytes.baseAddress!)
        }) == errSecSuccess else {
            throw PortableArchiveRestoreError.restoreFailed
        }

        try keyStore.writeWorkspaceKey(key)
        try failIfInjected(.afterKeyCreation)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try failIfInjected(.afterRootCreation)
        let database = try EncryptedDatabase.open(url: databaseURL, key: key)
        do {
            try WorkspaceMigrations.apply(to: database)
            try PortableArchiveSnapshotImporter.import(snapshot: snapshot, into: database)
            try failIfInjected(.afterImport)
            try database.checkpointAndClose()
            try failIfInjected(.afterCheckpoint)
        } catch {
            try? database.close()
            throw error
        }
    }
}

nonisolated struct RestoreCandidateRecord: Codable, Equatable {
    enum State: String, Codable { case reserved, keyRootCreated = "key_root_created", ready, cleanupRetry = "cleanup_retry", unavailable }
    enum FailureCategory: String, Codable { case bootstrap, signingIdentity = "signing_identity", promotion, reopen, registry, cleanup }
    let candidateID: UUID
    let archiveID: UUID
    var state: State
    let createdAt: Date
    var updatedAt: Date
    var cleanupAttempts: Int
    var failureCategory: FailureCategory?
}

nonisolated final class RestoreCandidateRegistry {
    private let fileURL: URL
    private let keyStore: RestoreCandidateKeyStoring
    private let failMarkReadyPersistence: Bool

    init(root: URL, keyStore: RestoreCandidateKeyStoring, failMarkReadyPersistence: Bool = false) {
        self.fileURL = root.appendingPathComponent("restore-candidates.v1")
        self.keyStore = keyStore
        self.failMarkReadyPersistence = failMarkReadyPersistence
    }

    func reserve(candidateID: UUID, archiveID: UUID) throws {
        var records = try read()
        records.append(.init(candidateID: candidateID, archiveID: archiveID, state: .reserved, createdAt: .now, updatedAt: .now, cleanupAttempts: 0, failureCategory: nil))
        try write(records)
    }

    func markKeyAndRootCreated(candidateID: UUID) throws { try update(candidateID: candidateID, state: .keyRootCreated) }
    func markReady(candidateID: UUID) throws {
        var records = try read()
        guard let index = records.firstIndex(where: { $0.candidateID == candidateID }) else { throw PortableArchiveRestoreError.restoreFailed }
        records[index].state = .ready
        records[index].updatedAt = .now
        records[index].failureCategory = nil
        // This is deliberately inside the ready-state transition, rather than
        // before it, so the failure seam models a failed terminal persistence.
        if failMarkReadyPersistence {
            throw RestoreCandidateLifecycleFault(point: .markReadyPersistence)
        }
        try write(records)
    }
    func markUnavailable(candidateID: UUID, category: RestoreCandidateRecord.FailureCategory) throws { try update(candidateID: candidateID, state: .unavailable, category: category) }

    func markCleanupRetry(candidateID: UUID, category: RestoreCandidateRecord.FailureCategory) throws {
        var records = try read()
        guard let index = records.firstIndex(where: { $0.candidateID == candidateID }) else { throw PortableArchiveRestoreError.restoreFailed }
        records[index].state = .cleanupRetry
        records[index].updatedAt = .now
        records[index].cleanupAttempts += 1
        records[index].failureCategory = category
        try write(records)
    }

    func incompleteRecords() throws -> [RestoreCandidateRecord] {
        try read().filter { $0.state != .ready && $0.state != .unavailable }
    }

    func recordsForTesting() throws -> [RestoreCandidateRecord] { try read() }

    private func update(candidateID: UUID, state: RestoreCandidateRecord.State, category: RestoreCandidateRecord.FailureCategory? = nil) throws {
        var records = try read()
        guard let index = records.firstIndex(where: { $0.candidateID == candidateID }) else { throw PortableArchiveRestoreError.restoreFailed }
        records[index].state = state
        records[index].updatedAt = .now
        records[index].failureCategory = category
        try write(records)
    }

    private func read() throws -> [RestoreCandidateRecord] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let key = try keyStore.readOrCreateKey()
        let sealed = try AES.GCM.SealedBox(combined: Data(contentsOf: fileURL))
        let plain = try AES.GCM.open(sealed, using: SymmetricKey(data: key), authenticating: Data("RekonPursuit/restore-candidates/v1".utf8))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return try decoder.decode([RestoreCandidateRecord].self, from: plain)
    }

    private func write(_ records: [RestoreCandidateRecord]) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .millisecondsSince1970
        let plain = try encoder.encode(records)
        let key = try keyStore.readOrCreateKey()
        guard let sealed = try AES.GCM.seal(plain, using: SymmetricKey(data: key), authenticating: Data("RekonPursuit/restore-candidates/v1".utf8)).combined else {
            throw PortableArchiveRestoreError.restoreFailed
        }
        let parent = fileURL.deletingLastPathComponent()
        let temporary = parent.appendingPathComponent(".restore-candidates-\(UUID().uuidString).tmp")
        try writeDurably(sealed, toNewFile: temporary)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: temporary, backupItemName: nil, options: [])
        } else {
            try FileManager.default.moveItem(at: temporary, to: fileURL)
        }
        try syncDirectory(parent)
    }

    private func writeDurably(_ data: Data, toNewFile url: URL) throws {
        let descriptor = open(url.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { throw PortableArchiveRestoreError.restoreFailed }
        defer { close(descriptor) }
        let result = data.withUnsafeBytes { buffer -> Bool in
            var cursor = buffer.baseAddress
            var remaining = buffer.count
            while remaining > 0 {
                let written = Darwin.write(descriptor, cursor, remaining)
                guard written > 0 else { return false }
                cursor = cursor?.advanced(by: written)
                remaining -= written
            }
            return true
        }
        guard result, fsync(descriptor) == 0 else { throw PortableArchiveRestoreError.restoreFailed }
    }

    private func syncDirectory(_ url: URL) throws {
        let descriptor = open(url.path, O_RDONLY | O_DIRECTORY)
        guard descriptor >= 0 else { throw PortableArchiveRestoreError.restoreFailed }
        defer { close(descriptor) }
        guard fsync(descriptor) == 0 else { throw PortableArchiveRestoreError.restoreFailed }
    }
}

nonisolated enum PortableArchiveSnapshotImporter {
    static func `import`(snapshot: Data, into database: EncryptedDatabase) throws {
        let decoded = try decode(snapshot)
        try database.transaction {
            for table in PortableArchiveSnapshotRegistry.tables {
                guard let rows = decoded[table.name] else { throw PortableArchiveRestoreError.restoreFailed }
                let columns = table.columns.joined(separator: ", ")
                let placeholders = Array(repeating: "?", count: table.columns.count).joined(separator: ", ")
                let statement = "INSERT INTO \(table.name) (\(columns)) VALUES (\(placeholders))"
                for var row in rows {
                    guard row.count == table.columns.count else { throw PortableArchiveRestoreError.restoreFailed }
                    // Archives never transport document bookmarks.  Enforce the
                    // boundary again at import so even an authenticated but
                    // malformed snapshot cannot make a local file reachable.
                    if table.name == "document_references" {
                        row[7] = .null
                        row[8] = .text(DocumentReferenceAvailability.relinkRequired.rawValue)
                    }
                    try database.execute(statement, values: row)
                }
            }
        }
    }

    private static func decode(_ snapshot: Data) throws -> [String: [[DatabaseValue]]] {
        var reader = RestoreSnapshotReader(snapshot)
        guard try reader.take(8) == Data("RPSNAP01".utf8),
              try reader.uint32() == UInt32(PortableArchiveSnapshotRegistry.tables.count) else {
            throw PortableArchiveRestoreError.restoreFailed
        }
        var result: [String: [[DatabaseValue]]] = [:]
        for table in PortableArchiveSnapshotRegistry.tables {
            guard try reader.text() == table.name else { throw PortableArchiveRestoreError.restoreFailed }
            let count = try reader.uint32()
            guard count <= 1_000_000 else { throw PortableArchiveRestoreError.restoreFailed }
            var rows: [[DatabaseValue]] = []
            rows.reserveCapacity(Int(count))
            for _ in 0..<count {
                guard try reader.uint32() == UInt32(table.columns.count) else { throw PortableArchiveRestoreError.restoreFailed }
                var row: [DatabaseValue] = []
                row.reserveCapacity(table.columns.count)
                for index in table.columns.indices {
                    row.append(try reader.value(timestamp: table.timestampColumnIndexes.contains(index)))
                }
                rows.append(row)
            }
            result[table.name] = rows
        }
        guard reader.isAtEnd else { throw PortableArchiveRestoreError.restoreFailed }
        return result
    }
}

nonisolated private struct RestoreSnapshotReader {
    private let data: Data
    private var offset = 0

    init(_ data: Data) { self.data = data }
    var isAtEnd: Bool { offset == data.count }

    mutating func take(_ count: Int) throws -> Data {
        guard count >= 0, offset <= data.count - count else { throw PortableArchiveRestoreError.restoreFailed }
        defer { offset += count }
        return data.subdata(in: offset..<(offset + count))
    }

    mutating func uint32() throws -> UInt32 {
        try take(4).reduce(0) { ($0 << 8) | UInt32($1) }
    }

    mutating func uint64() throws -> UInt64 {
        try take(8).reduce(0) { ($0 << 8) | UInt64($1) }
    }

    mutating func text() throws -> String {
        guard try take(1) == Data([3]),
              let text = String(data: try take(Int(try uint32())), encoding: .utf8) else {
            throw PortableArchiveRestoreError.restoreFailed
        }
        return text
    }

    mutating func value(timestamp: Bool) throws -> DatabaseValue {
        let tag = try take(1).first!
        let length = try uint32()
        guard length <= 64 * 1024 * 1024 else { throw PortableArchiveRestoreError.restoreFailed }
        let bytes = try take(Int(length))
        if timestamp {
            guard (tag == 0 && bytes.isEmpty) || (tag == 1 && bytes.count == 8) else {
                throw PortableArchiveRestoreError.restoreFailed
            }
            guard tag == 1 else { return .null }
            return .real(Double(Int64(bitPattern: bytes.reduce(0) { ($0 << 8) | UInt64($1) })) / 1_000)
        }
        switch tag {
        case 0:
            guard bytes.isEmpty else { throw PortableArchiveRestoreError.restoreFailed }
            return .null
        case 1:
            guard bytes.count == 8 else { throw PortableArchiveRestoreError.restoreFailed }
            return .integer(Int64(bitPattern: bytes.reduce(0) { ($0 << 8) | UInt64($1) }))
        case 2:
            guard bytes.count == 8 else { throw PortableArchiveRestoreError.restoreFailed }
            return .real(Double(bitPattern: bytes.reduce(0) { ($0 << 8) | UInt64($1) }))
        case 3:
            guard let value = String(data: bytes, encoding: .utf8) else { throw PortableArchiveRestoreError.restoreFailed }
            return .text(value)
        case 4:
            return .blob(bytes)
        default:
            throw PortableArchiveRestoreError.restoreFailed
        }
    }
}
