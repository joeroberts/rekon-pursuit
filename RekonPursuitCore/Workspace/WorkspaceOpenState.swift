import Foundation
import Security

enum WorkspaceOpenState: Equatable {
    case ready(WorkspaceStore)
    case missingKey
    case locked
    case denied
    case corrupt
    case unavailable

    static func == (lhs: WorkspaceOpenState, rhs: WorkspaceOpenState) -> Bool {
        switch (lhs, rhs) {
        case (.ready, .ready), (.missingKey, .missingKey), (.locked, .locked), (.denied, .denied), (.corrupt, .corrupt), (.unavailable, .unavailable):
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
        let store = try openStore(with: key, createIfMissing: true)
        do {
            try keyStore.writeWorkspaceKey(key)
            return store
        } catch {
            try? FileManager.default.removeItem(at: databaseURL)
            try? FileManager.default.removeItem(at: databaseURL.appendingPathExtension("sqlite-wal"))
            try? FileManager.default.removeItem(at: databaseURL.appendingPathExtension("sqlite-shm"))
            throw error
        }
    }

    func open() throws -> WorkspaceOpenState {
        do {
            guard let key = try keyStore.readWorkspaceKey() else { return .missingKey }
            guard FileManager.default.fileExists(atPath: databaseURL.path) else { return .unavailable }
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
        [databaseURL, databaseURL.appendingPathExtension("sqlite-wal"), databaseURL.appendingPathExtension("sqlite-shm")]
            .contains { FileManager.default.fileExists(atPath: $0.path) }
    }

    private func openStore(with key: Data, createIfMissing: Bool) throws -> WorkspaceStore {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let database = try EncryptedDatabase.open(url: databaseURL, key: key, createIfMissing: createIfMissing)
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
