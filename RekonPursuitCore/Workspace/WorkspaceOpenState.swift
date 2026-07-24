import Foundation
import Security

enum WorkspaceOpenState: Equatable {
    case ready(WorkspaceStore)
    case missingKey
    case locked
    case denied
    case unavailable

    static func == (lhs: WorkspaceOpenState, rhs: WorkspaceOpenState) -> Bool {
        switch (lhs, rhs) {
        case (.ready, .ready), (.missingKey, .missingKey), (.locked, .locked), (.denied, .denied), (.unavailable, .unavailable):
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
        let key = try newKey()
        guard key.count == 32 else { throw EncryptedDatabaseError.invalidKeyLength }
        try keyStore.writeWorkspaceKey(key)
        return try openStore(with: key)
    }

    func open() throws -> WorkspaceOpenState {
        do {
            guard let key = try keyStore.readWorkspaceKey() else { return .missingKey }
            return .ready(try openStore(with: key))
        } catch let error as WorkspaceKeyStoreError {
            switch error {
            case .locked: return .locked
            case .denied: return .denied
            case .unavailable: return .unavailable
            }
        } catch {
            return .unavailable
        }
    }

    private func openStore(with key: Data) throws -> WorkspaceStore {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let database = try EncryptedDatabase.open(url: root.appendingPathComponent("workspace.sqlite"), key: key)
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
