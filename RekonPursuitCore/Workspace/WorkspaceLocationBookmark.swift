import Foundation
import Darwin

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
