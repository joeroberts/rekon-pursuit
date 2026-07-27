import Foundation
import Darwin
import CryptoKit

enum WorkspaceLocationBookmarkError: Error, Equatable {
    case securityScopeUnavailable
    case missingWorkspaceDatabase
    case unsafeWorkspaceDatabase
    case workspaceNotWritable
    case bookmarkPersistenceFailed
}

enum WorkspaceLocationResolution: Equatable {
    case available(WorkspaceAccessLease)
    case missing
    case stale

    static func == (lhs: WorkspaceLocationResolution, rhs: WorkspaceLocationResolution) -> Bool {
        switch (lhs, rhs) {
        case (.available, .available), (.missing, .missing), (.stale, .stale): true
        default: false
        }
    }
}

/// Holds a security-scoped resource open until the workspace store closes.
/// `close()` is idempotent; deinitialization only protects abnormal teardown.
nonisolated final class WorkspaceAccessLease {
    let url: URL
    private let stopAccessing: (URL) -> Void
    private var isClosed = false

    init(url: URL, stopAccessing: @escaping (URL) -> Void) {
        self.url = url
        self.stopAccessing = stopAccessing
    }

    func close() {
        guard !isClosed else { return }
        isClosed = true
        stopAccessing(url)
    }

    deinit {
        close()
    }
}

struct WorkspaceLocationBookmarkDependencies {
    let loadBookmark: () -> Data?
    let saveBookmark: (Data) throws -> Void
    let createBookmark: (URL) throws -> Data
    let resolveBookmark: (Data) throws -> (URL, Bool)
    let startAccessing: (URL) -> Bool
    let stopAccessing: (URL) -> Void
    let validateWorkspace: (URL) -> WorkspaceLocationBookmarkError?

    static func live(defaults: UserDefaults = .standard) -> Self {
        let bookmarkKey = WorkspaceLocationBookmarkConfiguration.preferenceKey
        return Self(
            loadBookmark: { defaults.data(forKey: bookmarkKey) },
            saveBookmark: { bookmark in defaults.set(bookmark, forKey: bookmarkKey) },
            createBookmark: { url in
                try url.bookmarkData(
                    options: [.withSecurityScope],
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
            },
            resolveBookmark: { bookmark in
                var isStale = false
                let url = try URL(
                    resolvingBookmarkData: bookmark,
                    options: [.withSecurityScope],
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )
                return (url, isStale)
            },
            startAccessing: { $0.startAccessingSecurityScopedResource() },
            stopAccessing: { $0.stopAccessingSecurityScopedResource() },
            validateWorkspace: validateWorkspace
        )
    }

    /// This is intentionally a permission/metadata check: it verifies the
    /// directory and database can support SQLite sidecars without creating,
    /// modifying, or deleting anything in the selected workspace.
    private static func validateWorkspace(folder: URL) -> WorkspaceLocationBookmarkError? {
        var folderStatus = stat()
        guard lstat(folder.path, &folderStatus) == 0,
              (folderStatus.st_mode & S_IFMT) == S_IFDIR else {
            return .missingWorkspaceDatabase
        }

        let databaseURL = folder.appendingPathComponent("workspace.sqlite", isDirectory: false)
        var databaseStatus = stat()
        guard lstat(databaseURL.path, &databaseStatus) == 0 else {
            return .missingWorkspaceDatabase
        }
        guard (databaseStatus.st_mode & S_IFMT) == S_IFREG else {
            return .unsafeWorkspaceDatabase
        }

        let canReadDatabase = FileManager.default.isReadableFile(atPath: databaseURL.path)
        let canWriteDatabase = FileManager.default.isWritableFile(atPath: databaseURL.path)
        let canWriteDirectory = FileManager.default.isWritableFile(atPath: folder.path)
        let canTraverseDirectory = access(folder.path, X_OK) == 0
        guard canReadDatabase, canWriteDatabase, canWriteDirectory, canTraverseDirectory else {
            return .workspaceNotWritable
        }
        return nil
    }
}

nonisolated enum WorkspaceLocationBookmarkConfiguration {
    static let preferenceKey = "workspace-location-bookmark"
}

/// Persists only opaque bookmark data. It never creates or modifies files in a
/// user-selected folder.
final class WorkspaceLocationBookmarkStore {
    private let dependencies: WorkspaceLocationBookmarkDependencies

    init(dependencies: WorkspaceLocationBookmarkDependencies = .live()) {
        self.dependencies = dependencies
    }

    /// Validates a selected folder under a temporary security scope and swaps
    /// the stored bookmark only after validation and bookmark creation succeed.
    /// On success, ownership of that active scope transfers to the returned lease.
    func validateAndSave(url: URL, beforePersist: () throws -> Void = {}) throws -> WorkspaceAccessLease {
        guard dependencies.startAccessing(url) else { throw WorkspaceLocationBookmarkError.securityScopeUnavailable }
        var succeeds = false
        defer {
            if !succeeds { dependencies.stopAccessing(url) }
        }

        if let validationError = dependencies.validateWorkspace(url) {
            throw validationError
        }

        try beforePersist()
        let bookmark = try dependencies.createBookmark(url)
        do {
            try dependencies.saveBookmark(bookmark)
        } catch {
            throw WorkspaceLocationBookmarkError.bookmarkPersistenceFailed
        }

        succeeds = true
        return WorkspaceAccessLease(url: url, stopAccessing: dependencies.stopAccessing)
    }

    func resolve() -> WorkspaceLocationResolution {
        guard let bookmark = dependencies.loadBookmark() else { return .missing }
        do {
            let (url, isStale) = try dependencies.resolveBookmark(bookmark)
            guard !isStale, dependencies.startAccessing(url) else { return .stale }
            guard dependencies.validateWorkspace(url) == nil else {
                dependencies.stopAccessing(url)
                return .stale
            }
            return .available(WorkspaceAccessLease(url: url, stopAccessing: dependencies.stopAccessing))
        } catch {
            return .stale
        }
    }
}

enum DocumentReferenceBookmarkError: Error {
    case unavailable
    case unsupportedType
    case tooLarge
    case unsafeFile
    case mismatch
}

/// Owns short-lived access to an externally selected document. It stores no
/// path and returns only opaque bookmark data plus the identity needed by the
/// encrypted workspace record.
struct DocumentReferenceBookmarkStore {
    static let maximumByteCount = 25_000_000

    func create(from url: URL) throws -> (bookmark: Data, contentType: String, hash: String, byteCount: Int) {
        guard url.startAccessingSecurityScopedResource() else { throw DocumentReferenceBookmarkError.unavailable }
        defer { url.stopAccessingSecurityScopedResource() }
        let identity = try verify(url: url, expectedHash: nil, expectedByteCount: nil)
        let bookmark = try url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
        return (bookmark, identity.contentType, identity.hash, identity.byteCount)
    }

    func resolveAndVerify(_ reference: DocumentReference) throws -> URL {
        guard let bookmark = reference.bookmarkData else { throw DocumentReferenceBookmarkError.unavailable }
        var stale = false
        let url = try URL(resolvingBookmarkData: bookmark, options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &stale)
        guard !stale, url.startAccessingSecurityScopedResource() else { throw DocumentReferenceBookmarkError.unavailable }
        do {
            _ = try verify(url: url, expectedHash: reference.sourceHash, expectedByteCount: reference.byteCount)
            return url
        } catch {
            url.stopAccessingSecurityScopedResource()
            throw error
        }
    }

    func release(_ url: URL) { url.stopAccessingSecurityScopedResource() }

    static func validateContents(_ data: Data, pathExtension: String) throws -> String {
        guard data.count <= maximumByteCount else { throw DocumentReferenceBookmarkError.tooLarge }
        switch pathExtension.lowercased() {
        case "pdf":
            guard data.starts(with: Data("%PDF-".utf8)) else { throw DocumentReferenceBookmarkError.unsupportedType }
            return "application/pdf"
        case "docx":
            guard data.starts(with: Data([0x50, 0x4b, 0x03, 0x04])) else { throw DocumentReferenceBookmarkError.unsupportedType }
            return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        default:
            throw DocumentReferenceBookmarkError.unsupportedType
        }
    }

    private func verify(url: URL, expectedHash: String?, expectedByteCount: Int?) throws -> (contentType: String, hash: String, byteCount: Int) {
        var status = stat()
        guard lstat(url.path, &status) == 0, (status.st_mode & S_IFMT) == S_IFREG else { throw DocumentReferenceBookmarkError.unsafeFile }
        let ext = url.pathExtension.lowercased()
        let size = Int(status.st_size)
        guard size >= 0, size <= Self.maximumByteCount else { throw DocumentReferenceBookmarkError.tooLarge }
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        guard data.count == size else { throw DocumentReferenceBookmarkError.mismatch }
        let contentType = try Self.validateContents(data, pathExtension: ext)
        let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        if let expectedHash, let expectedByteCount, (hash != expectedHash || size != expectedByteCount) { throw DocumentReferenceBookmarkError.mismatch }
        return (contentType, hash, size)
    }
}
