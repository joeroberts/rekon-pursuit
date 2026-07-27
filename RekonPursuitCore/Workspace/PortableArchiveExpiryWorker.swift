import Darwin
import Foundation

nonisolated enum PortableArchiveExpiryError: Error, Equatable, Sendable {
    case scopeUnavailable
    case targetMissing
    case targetUnsafe
    case identityMismatch
    case archiveMismatch
    case ioFailure
}

nonisolated struct PortableArchiveExpiryScopedAccess: Sendable {
    let url: URL
    let stopAccessing: @Sendable () -> Void
}

nonisolated struct PortableArchiveExpiryFileIdentity: Equatable, Sendable {
    let device: UInt64
    let inode: UInt64
}

nonisolated struct PortableArchiveExpiryFileMetadata: Equatable, Sendable {
    let identity: PortableArchiveExpiryFileIdentity
    let isRegular: Bool
    let isSymbolicLink: Bool
    let byteCount: Int64

    init(
        identity: PortableArchiveExpiryFileIdentity,
        isRegular: Bool,
        isSymbolicLink: Bool,
        byteCount: Int64 = 0
    ) {
        self.identity = identity
        self.isRegular = isRegular
        self.isSymbolicLink = isSymbolicLink
        self.byteCount = byteCount
    }
}

nonisolated struct PortableArchiveExpiryFileOperations: Sendable {
    var openDescriptor: @Sendable (URL) throws -> Int32
    var descriptorMetadata: @Sendable (Int32) throws -> PortableArchiveExpiryFileMetadata
    var readDescriptor: @Sendable (Int32) throws -> Data
    var closeDescriptor: @Sendable (Int32) -> Void
    var targetMetadata: @Sendable (URL) throws -> PortableArchiveExpiryFileMetadata
    var unlinkTarget: @Sendable (URL) throws -> Void

    static var live: PortableArchiveExpiryFileOperations {
        PortableArchiveExpiryFileOperations(
            openDescriptor: { url in
                let descriptor = Darwin.open(url.path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW)
                guard descriptor >= 0 else {
                    switch errno {
                    case ENOENT:
                        throw PortableArchiveExpiryError.targetMissing
                    case ELOOP:
                        throw PortableArchiveExpiryError.targetUnsafe
                    default:
                        throw PortableArchiveExpiryError.ioFailure
                    }
                }
                return descriptor
            },
            descriptorMetadata: { descriptor in
                var value = stat()
                guard Darwin.fstat(descriptor, &value) == 0 else {
                    throw PortableArchiveExpiryError.ioFailure
                }
                return metadata(value)
            },
            readDescriptor: { descriptor in
                let maximumArchiveBytes = 512 * 1024 * 1024 + 339
                guard Darwin.lseek(descriptor, 0, SEEK_SET) >= 0 else {
                    throw PortableArchiveExpiryError.ioFailure
                }
                var result = Data()
                var buffer = [UInt8](repeating: 0, count: 1_048_576)
                while true {
                    let count = Darwin.read(descriptor, &buffer, buffer.count)
                    guard count >= 0 else {
                        if errno == EINTR { continue }
                        throw PortableArchiveExpiryError.ioFailure
                    }
                    guard count > 0 else { return result }
                    guard result.count <= maximumArchiveBytes - count else {
                        throw PortableArchiveExpiryError.archiveMismatch
                    }
                    result.append(contentsOf: buffer.prefix(count))
                }
            },
            closeDescriptor: { descriptor in
                _ = Darwin.close(descriptor)
            },
            targetMetadata: { url in
                var value = stat()
                guard Darwin.lstat(url.path, &value) == 0 else {
                    if errno == ENOENT {
                        throw PortableArchiveExpiryError.targetMissing
                    }
                    throw PortableArchiveExpiryError.ioFailure
                }
                return metadata(value)
            },
            unlinkTarget: { url in
                guard Darwin.unlink(url.path) == 0 else {
                    if errno == ENOENT {
                        throw PortableArchiveExpiryError.targetMissing
                    }
                    throw PortableArchiveExpiryError.ioFailure
                }
            }
        )
    }

    func replacingRead(
        _ replacement: @escaping @Sendable (Int32) throws -> Data
    ) -> PortableArchiveExpiryFileOperations {
        var copy = self
        copy.readDescriptor = replacement
        return copy
    }

    func replacingTargetMetadata(
        _ replacement: @escaping @Sendable (URL) throws -> PortableArchiveExpiryFileMetadata
    ) -> PortableArchiveExpiryFileOperations {
        var copy = self
        copy.targetMetadata = replacement
        return copy
    }

    func replacingUnlink(
        _ replacement: @escaping @Sendable (URL) throws -> Void
    ) -> PortableArchiveExpiryFileOperations {
        var copy = self
        copy.unlinkTarget = replacement
        return copy
    }

    private static func metadata(_ value: stat) -> PortableArchiveExpiryFileMetadata {
        PortableArchiveExpiryFileMetadata(
            identity: PortableArchiveExpiryFileIdentity(
                device: UInt64(value.st_dev),
                inode: UInt64(value.st_ino)
            ),
            isRegular: (value.st_mode & S_IFMT) == S_IFREG,
            isSymbolicLink: (value.st_mode & S_IFMT) == S_IFLNK,
            byteCount: value.st_size
        )
    }
}

protocol PortableArchiveExpiryWorking: Actor {
    func run() throws
}

actor PortableArchiveExpiryWorker: PortableArchiveExpiryWorking {
    typealias BookmarkResolver = @Sendable (Data) throws -> PortableArchiveExpiryScopedAccess
    typealias ActivityWriter = @Sendable (
        EncryptedDatabase,
        String,
        String,
        UUID,
        Date
    ) throws -> Void

    private let configuration: PortableArchiveDatabaseConfiguration
    private let now: @Sendable () -> Date
    private let bookmarkResolver: BookmarkResolver
    private let fileOperations: PortableArchiveExpiryFileOperations
    private let actorID: String
    private let activityID: @Sendable () -> String
    private let activityWriter: ActivityWriter

    init(
        configuration: PortableArchiveDatabaseConfiguration,
        now: @escaping @Sendable () -> Date = { Date.now },
        bookmarkResolver: @escaping BookmarkResolver = PortableArchiveExpiryWorker.resolveBookmark,
        fileOperations: PortableArchiveExpiryFileOperations = .live,
        actorID: String,
        activityID: @escaping @Sendable () -> String = { UUID().uuidString },
        activityWriter: @escaping ActivityWriter = PortableArchiveExpiryWorker.insertRemovalActivity
    ) {
        self.configuration = configuration
        self.now = now
        self.bookmarkResolver = bookmarkResolver
        self.fileOperations = fileOperations
        self.actorID = actorID
        self.activityID = activityID
        self.activityWriter = activityWriter
    }

    func run() throws {
        let database = try EncryptedDatabase.open(
            url: configuration.url,
            key: configuration.key,
            createIfMissing: false
        )
        defer { try? database.close() }
        let opportunityTime = now()
        let candidates = try dueCandidates(at: opportunityTime, in: database)

        for candidate in candidates {
            try update(
                candidate.row.archiveID,
                lifecycleState: .expiredPendingRemoval,
                outcome: .none,
                in: database
            )
            do {
                try remove(candidate, at: opportunityTime, from: database)
            } catch let error as PortableArchiveExpiryError {
                try persist(error, for: candidate.row.archiveID, in: database)
            } catch {
                try persist(.ioFailure, for: candidate.row.archiveID, in: database)
            }
        }
    }

    private func remove(
        _ candidate: PortableArchiveExpiryCandidate,
        at opportunityTime: Date,
        from database: EncryptedDatabase
    ) throws {
        let scope: PortableArchiveExpiryScopedAccess
        do {
            scope = try bookmarkResolver(candidate.bookmark)
        } catch {
            throw PortableArchiveExpiryError.scopeUnavailable
        }
        defer { scope.stopAccessing() }

        let descriptor = try fileOperations.openDescriptor(scope.url)
        defer { fileOperations.closeDescriptor(descriptor) }
        let openedMetadata = try fileOperations.descriptorMetadata(descriptor)
        guard openedMetadata.isRegular, !openedMetadata.isSymbolicLink else {
            throw PortableArchiveExpiryError.targetUnsafe
        }
        let archiveData = try fileOperations.readDescriptor(descriptor)
        let binding: PortableArchivePublicBinding
        do {
            binding = try PortableArchiveService.verifyPublicBinding(data: archiveData)
        } catch {
            throw PortableArchiveExpiryError.archiveMismatch
        }
        guard candidate.row.formatVersion == Int(PortableArchiveService.formatVersion),
              candidate.row.verificationState == "Verified",
              binding.archiveID == candidate.row.archiveID,
              binding.ciphertextChecksum == candidate.row.ciphertextChecksum,
              binding.signingKeyFingerprint == candidate.row.signingKeyFingerprint else {
            throw PortableArchiveExpiryError.archiveMismatch
        }

        let currentMetadata = try fileOperations.targetMetadata(scope.url)
        guard currentMetadata.isRegular, !currentMetadata.isSymbolicLink else {
            throw PortableArchiveExpiryError.targetUnsafe
        }
        guard currentMetadata.identity == openedMetadata.identity else {
            throw PortableArchiveExpiryError.identityMismatch
        }
        try fileOperations.unlinkTarget(scope.url)

        do {
            try database.transaction {
                try database.execute(
                    "DELETE FROM portable_archive_catalogue WHERE archive_id = ?",
                    values: [.text(candidate.row.archiveID.uuidString)]
                )
                try activityWriter(
                    database,
                    activityID(),
                    actorID,
                    candidate.row.archiveID,
                    opportunityTime
                )
            }
        } catch {
            try update(
                candidate.row.archiveID,
                lifecycleState: .expiredRetryable,
                outcome: .ioFailure,
                in: database
            )
        }
    }

    private func dueCandidates(
        at opportunityTime: Date,
        in database: EncryptedDatabase
    ) throws -> [PortableArchiveExpiryCandidate] {
        try database.rows(
            """
            SELECT archive_id, destination_bookmark, display_filename, format_version,
                   created_at, expires_at, verification_state, ciphertext_checksum,
                   signing_key_fingerprint, lifecycle_state, last_expiry_outcome
            FROM portable_archive_catalogue
            WHERE expires_at <= ?
              AND lifecycle_state IN ('Verified', 'expired_pending_removal', 'expired_retryable')
            ORDER BY expires_at, archive_id
            """,
            values: [.real(opportunityTime.timeIntervalSince1970)]
        ).map { values in
            guard values.count == 11,
                  case let .text(id) = values[0],
                  let archiveID = UUID(uuidString: id),
                  case let .blob(bookmark) = values[1],
                  case let .text(filename) = values[2],
                  case let .integer(version) = values[3],
                  case let .real(createdAt) = values[4],
                  case let .real(expiresAt) = values[5],
                  case let .text(verificationState) = values[6],
                  case let .blob(checksum) = values[7],
                  case let .blob(fingerprint) = values[8],
                  case let .text(lifecycleText) = values[9],
                  let lifecycle = PortableArchiveLifecycleState(rawValue: lifecycleText),
                  case let .text(outcomeText) = values[10],
                  let outcome = PortableArchiveExpiryOutcome(rawValue: outcomeText)
            else {
                throw WorkspaceStoreError.unexpectedDatabaseValue
            }
            return PortableArchiveExpiryCandidate(
                row: PortableArchiveCatalogueRow(
                    archiveID: archiveID,
                    displayFilename: filename,
                    formatVersion: Int(version),
                    createdAt: Date(timeIntervalSince1970: createdAt),
                    expiresAt: Date(timeIntervalSince1970: expiresAt),
                    verificationState: verificationState,
                    ciphertextChecksum: checksum,
                    signingKeyFingerprint: fingerprint,
                    lifecycleState: lifecycle,
                    lastExpiryOutcome: outcome
                ),
                bookmark: bookmark
            )
        }
    }

    private func persist(
        _ error: PortableArchiveExpiryError,
        for archiveID: UUID,
        in database: EncryptedDatabase
    ) throws {
        switch error {
        case .targetMissing:
            try update(
                archiveID,
                lifecycleState: .expiredMissing,
                outcome: .targetMissing,
                in: database
            )
        case .scopeUnavailable:
            try update(
                archiveID,
                lifecycleState: .expiredRetryable,
                outcome: .scopeUnavailable,
                in: database
            )
        case .ioFailure:
            try update(
                archiveID,
                lifecycleState: .expiredRetryable,
                outcome: .ioFailure,
                in: database
            )
        case .targetUnsafe:
            try update(
                archiveID,
                lifecycleState: .expiredBlocked,
                outcome: .targetUnsafe,
                in: database
            )
        case .identityMismatch:
            try update(
                archiveID,
                lifecycleState: .expiredBlocked,
                outcome: .identityMismatch,
                in: database
            )
        case .archiveMismatch:
            try update(
                archiveID,
                lifecycleState: .expiredBlocked,
                outcome: .archiveMismatch,
                in: database
            )
        }
    }

    private func update(
        _ archiveID: UUID,
        lifecycleState: PortableArchiveLifecycleState,
        outcome: PortableArchiveExpiryOutcome,
        in database: EncryptedDatabase
    ) throws {
        try database.execute(
            """
            UPDATE portable_archive_catalogue
            SET lifecycle_state = ?, last_expiry_outcome = ?
            WHERE archive_id = ?
            """,
            values: [
                .text(lifecycleState.rawValue),
                .text(outcome.rawValue),
                .text(archiveID.uuidString)
            ]
        )
    }

    private static func resolveBookmark(
        _ bookmark: Data
    ) throws -> PortableArchiveExpiryScopedAccess {
        var stale = false
        let url: URL
        do {
            url = try URL(
                resolvingBookmarkData: bookmark,
                options: [.withSecurityScope, .withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            )
        } catch {
            throw PortableArchiveExpiryError.scopeUnavailable
        }
        guard !stale, url.startAccessingSecurityScopedResource() else {
            throw PortableArchiveExpiryError.scopeUnavailable
        }
        return PortableArchiveExpiryScopedAccess(
            url: url,
            stopAccessing: {
                url.stopAccessingSecurityScopedResource()
            }
        )
    }

    private static func insertRemovalActivity(
        into database: EncryptedDatabase,
        id: String,
        actorID: String,
        archiveID: UUID,
        occurredAt: Date
    ) throws {
        try database.execute(
            """
            INSERT INTO activity_events
                (id, kind, opportunity_id, contact_id, actor_id, correlation_id, occurred_at)
            VALUES (?, 'portable_backup_expired_removed', NULL, NULL, ?, ?, ?)
            """,
            values: [
                .text(id),
                .text(actorID),
                .text(archiveID.uuidString),
                .real(occurredAt.timeIntervalSince1970)
            ]
        )
    }
}

nonisolated private struct PortableArchiveExpiryCandidate {
    let row: PortableArchiveCatalogueRow
    let bookmark: Data
}
