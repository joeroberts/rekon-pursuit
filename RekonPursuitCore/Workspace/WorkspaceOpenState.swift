import Foundation
import Security

enum WorkspaceOpenState: Equatable {
    case ready(WorkspaceStore)
    case missingKey
    case missingExistingKey
    case locked
    case denied
    case corrupt
    case unavailable

    static func == (lhs: WorkspaceOpenState, rhs: WorkspaceOpenState) -> Bool {
        switch (lhs, rhs) {
        case (.ready, .ready), (.missingKey, .missingKey), (.missingExistingKey, .missingExistingKey), (.locked, .locked), (.denied, .denied), (.corrupt, .corrupt), (.unavailable, .unavailable):
            true
        default:
            false
        }
    }
}

@MainActor
final class WorkspaceSession {
    private let root: URL
    private let keyStore: WorkspaceKeyStore
    private let newKey: @MainActor () throws -> Data
    private let now: Date

    init(
        root: URL,
        keyStore: WorkspaceKeyStore = KeychainWorkspaceKeyStore(),
        newKey: @MainActor @escaping () throws -> Data = WorkspaceSession.generateKey,
        now: Date = .now
    ) {
        self.root = root
        self.keyStore = keyStore
        self.newKey = newKey
        self.now = now
    }

    func create() throws -> WorkspaceStore {
        guard !workspaceArtifactsExist() else { throw WorkspaceSessionError.workspaceAlreadyExists }
        let key = try newKey()
        guard key.count == 32 else { throw EncryptedDatabaseError.invalidKeyLength }
        let stagingRoot = root.appendingPathComponent(".creating-\(UUID().uuidString)", isDirectory: true)
        let stagingDatabaseURL = stagingRoot.appendingPathComponent("workspace.sqlite")
        try FileManager.default.createDirectory(at: stagingRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: stagingRoot) }
        let stagingStore = try openStore(at: stagingDatabaseURL, with: key, createIfMissing: true)
        try stagingStore.close()
        do {
            try keyStore.writePendingWorkspaceKey(key)
            try FileManager.default.moveItem(at: stagingDatabaseURL, to: databaseURL)
            try keyStore.promotePendingWorkspaceKey()
            return try openStore(with: key, createIfMissing: false)
        } catch {
            try? keyStore.deletePendingWorkspaceKey()
            try? FileManager.default.removeItem(at: databaseURL)
            try? FileManager.default.removeItem(at: sidecarURL("-wal"))
            try? FileManager.default.removeItem(at: sidecarURL("-shm"))
            throw error
        }
    }

    func open() throws -> WorkspaceOpenState {
        do {
            let databaseExists = FileManager.default.fileExists(atPath: databaseURL.path)
            guard databaseExists else {
                try? keyStore.deletePendingWorkspaceKey()
                return try keyStore.readWorkspaceKey() == nil ? .missingKey : .unavailable
            }
            let key: Data
            if let existingKey = try keyStore.readWorkspaceKey() {
                key = existingKey
            } else if try keyStore.readPendingWorkspaceKey() != nil {
                try keyStore.promotePendingWorkspaceKey()
                guard let recoveredKey = try keyStore.readWorkspaceKey() else { return .missingExistingKey }
                key = recoveredKey
            } else {
                return .missingExistingKey
            }
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

    private var databaseURL: URL {
        root.appendingPathComponent("workspace.sqlite")
    }

    private func workspaceArtifactsExist() -> Bool {
        [databaseURL, sidecarURL("-wal"), sidecarURL("-shm")]
            .contains { FileManager.default.fileExists(atPath: $0.path) }
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
        return try WorkspaceStore(
            database: database,
            now: now,
            actorID: "local-user",
            correlationID: UUID().uuidString
        )
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
}
