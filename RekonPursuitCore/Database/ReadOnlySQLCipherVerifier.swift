import CryptoKit
import Foundation
import SQLCipher

/// An intentionally narrow SQLCipher path for proving only that a known key can
/// read the encrypted schema. Immutable URI mode does not claim a current
/// WAL-consistent snapshot and must never be used for normal workspace access.
nonisolated struct ReadOnlySQLiteDriver: @unchecked Sendable {
    nonisolated struct OpenResult: @unchecked Sendable {
        let status: Int32
        let handle: OpaquePointer?
    }

    let open: (String, Int32) -> OpenResult
    let key: (OpaquePointer, Data) -> Int32
    let prepare: (OpaquePointer, String) -> OpaquePointer?
    let step: (OpaquePointer) -> Int32
    let finalize: (OpaquePointer?) -> Int32
    let close: (OpaquePointer) -> Int32
    let errorMessage: (OpaquePointer?) -> String

    static let live = ReadOnlySQLiteDriver(
        open: { uri, flags in
            var handle: OpaquePointer?
            let status = sqlite3_open_v2(uri, &handle, flags, nil)
            return OpenResult(status: status, handle: handle)
        },
        key: { handle, key in
            key.withUnsafeBytes { sqlite3_key(handle, $0.baseAddress, Int32($0.count)) }
        },
        prepare: { handle, sql in
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK else { return nil }
            return statement
        },
        step: sqlite3_step,
        finalize: sqlite3_finalize,
        close: sqlite3_close_v2,
        errorMessage: { handle in
            handle.map { String(cString: sqlite3_errmsg($0)) } ?? "Unknown SQLite error."
        }
    )
}

nonisolated enum ReadOnlySQLCipherVerifierError: Error, LocalizedError, Equatable {
    case invalidKeyLength
    case openFailed
    case keyFailed
    case prepareFailed
    case schemaReadFailed
    case finalizeFailed
    case closeFailed
    case artifactChanged

    var errorDescription: String? {
        switch self {
        case .invalidKeyLength: "The workspace key is unavailable."
        case .openFailed, .keyFailed, .prepareFailed, .schemaReadFailed, .finalizeFailed, .closeFailed:
            "The encrypted workspace could not be verified read-only."
        case .artifactChanged: "Read-only verification changed workspace material unexpectedly."
        }
    }
}

nonisolated struct ReadOnlySQLCipherVerifier {
    private static let schemaSQL = "SELECT count(*) FROM sqlite_master"
    private let driver: ReadOnlySQLiteDriver

    init(driver: ReadOnlySQLiteDriver = .live) {
        self.driver = driver
    }

    func verify(url: URL, key: Data) throws {
        guard key.count == 32 else { throw ReadOnlySQLCipherVerifierError.invalidKeyLength }
        let before = try WorkspaceArtifactManifest.capture(for: url)
        let openResult = driver.open(
            Self.immutableURI(for: url),
            SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX | SQLITE_OPEN_URI | SQLITE_OPEN_NOFOLLOW
        )
        var statement: OpaquePointer?
        var semanticError: Error?

        if openResult.status != SQLITE_OK || openResult.handle == nil {
            semanticError = ReadOnlySQLCipherVerifierError.openFailed
        } else if let handle = openResult.handle {
            if driver.key(handle, key) != SQLITE_OK {
                semanticError = ReadOnlySQLCipherVerifierError.keyFailed
            } else if let prepared = driver.prepare(handle, Self.schemaSQL) {
                statement = prepared
                if driver.step(prepared) != SQLITE_ROW {
                    semanticError = ReadOnlySQLCipherVerifierError.schemaReadFailed
                }
            } else {
                semanticError = ReadOnlySQLCipherVerifierError.prepareFailed
            }
        }

        if let statement, driver.finalize(statement) != SQLITE_OK, semanticError == nil {
            semanticError = ReadOnlySQLCipherVerifierError.finalizeFailed
        }
        if let handle = openResult.handle, driver.close(handle) != SQLITE_OK, semanticError == nil {
            semanticError = ReadOnlySQLCipherVerifierError.closeFailed
        }
        guard try WorkspaceArtifactManifest.capture(for: url) == before else {
            throw ReadOnlySQLCipherVerifierError.artifactChanged
        }
        if let semanticError { throw semanticError }
    }

    static func immutableURI(for url: URL) -> String {
        let disallowed = CharacterSet(charactersIn: "?#%")
        let allowed = CharacterSet.urlPathAllowed.subtracting(disallowed)
        let encodedPath = url.standardizedFileURL.path.addingPercentEncoding(withAllowedCharacters: allowed) ?? url.standardizedFileURL.path
        return "file://\(encodedPath)?mode=ro&immutable=1"
    }
}

nonisolated struct WorkspaceArtifactManifest: Equatable {
    nonisolated struct Artifact: Equatable {
        let name: String
        let exists: Bool
        let fileType: UInt32?
        let inode: UInt64?
        let size: Int64?
        let modificationTime: Int64?
        let sha256: String?
    }

    let directoryContents: [String]
    let artifacts: [Artifact]

    static func capture(for databaseURL: URL) throws -> WorkspaceArtifactManifest {
        let directory = databaseURL.deletingLastPathComponent()
        let contents = try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted()
        let artifactURLs = [
            databaseURL,
            URL(fileURLWithPath: databaseURL.path + "-wal"),
            URL(fileURLWithPath: databaseURL.path + "-shm"),
            URL(fileURLWithPath: databaseURL.path + "-journal")
        ]
        return WorkspaceArtifactManifest(
            directoryContents: contents,
            artifacts: try artifactURLs.map { try captureArtifact(at: $0) }
        )
    }

    private static func captureArtifact(at url: URL) throws -> Artifact {
        var status = stat()
        guard lstat(url.path, &status) == 0 else {
            return Artifact(name: url.lastPathComponent, exists: false, fileType: nil, inode: nil, size: nil, modificationTime: nil, sha256: nil)
        }
        let isRegularFile = (status.st_mode & S_IFMT) == S_IFREG
        let digest = isRegularFile ? SHA256.hash(data: try Data(contentsOf: url)).map { String(format: "%02x", $0) }.joined() : nil
        return Artifact(
            name: url.lastPathComponent,
            exists: true,
            fileType: UInt32(status.st_mode & S_IFMT),
            inode: UInt64(status.st_ino),
            size: Int64(status.st_size),
            modificationTime: Int64(status.st_mtimespec.tv_sec),
            sha256: digest
        )
    }
}
