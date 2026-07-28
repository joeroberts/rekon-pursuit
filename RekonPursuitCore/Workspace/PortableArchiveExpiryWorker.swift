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

// Retained only for the external-archive compatibility seam. Expiry never
// resolves an external bookmark: external rows are always manual removal.
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

    init(identity: PortableArchiveExpiryFileIdentity, isRegular: Bool, isSymbolicLink: Bool, byteCount: Int64 = 0) {
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
    var moveTarget: @Sendable (URL, URL) throws -> Void
    var unlinkTarget: @Sendable (URL) throws -> Void

    static var live: PortableArchiveExpiryFileOperations {
        PortableArchiveExpiryFileOperations(
            openDescriptor: { url in
                let descriptor = Darwin.open(url.path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK)
                guard descriptor >= 0 else {
                    switch errno {
                    case ENOENT: throw PortableArchiveExpiryError.targetMissing
                    case ELOOP: throw PortableArchiveExpiryError.targetUnsafe
                    default: throw PortableArchiveExpiryError.ioFailure
                    }
                }
                return descriptor
            },
            descriptorMetadata: { descriptor in
                var value = stat()
                guard Darwin.fstat(descriptor, &value) == 0 else { throw PortableArchiveExpiryError.ioFailure }
                return metadata(value)
            },
            readDescriptor: { descriptor in
                let maximumArchiveBytes = 512 * 1024 * 1024 + 339
                guard Darwin.lseek(descriptor, 0, SEEK_SET) >= 0 else { throw PortableArchiveExpiryError.ioFailure }
                var result = Data()
                var buffer = [UInt8](repeating: 0, count: 1_048_576)
                while true {
                    let count = Darwin.read(descriptor, &buffer, buffer.count)
                    guard count >= 0 else {
                        if errno == EINTR { continue }
                        throw PortableArchiveExpiryError.ioFailure
                    }
                    guard count > 0 else { return result }
                    guard result.count <= maximumArchiveBytes - count else { throw PortableArchiveExpiryError.archiveMismatch }
                    result.append(contentsOf: buffer.prefix(count))
                }
            },
            closeDescriptor: { _ = Darwin.close($0) },
            targetMetadata: { url in
                var value = stat()
                guard Darwin.lstat(url.path, &value) == 0 else {
                    if errno == ENOENT { throw PortableArchiveExpiryError.targetMissing }
                    throw PortableArchiveExpiryError.ioFailure
                }
                return metadata(value)
            },
            moveTarget: { source, destination in
                guard Darwin.renameatx_np(AT_FDCWD, source.path, AT_FDCWD, destination.path, UInt32(RENAME_EXCL)) == 0 else {
                    switch errno {
                    case ENOENT: throw PortableArchiveExpiryError.targetMissing
                    case EEXIST: throw PortableArchiveExpiryError.targetUnsafe
                    default: throw PortableArchiveExpiryError.ioFailure
                    }
                }
            },
            unlinkTarget: { url in
                guard Darwin.unlink(url.path) == 0 else {
                    if errno == ENOENT { throw PortableArchiveExpiryError.targetMissing }
                    throw PortableArchiveExpiryError.ioFailure
                }
            }
        )
    }

    func replacingRead(_ replacement: @escaping @Sendable (Int32) throws -> Data) -> PortableArchiveExpiryFileOperations {
        var copy = self; copy.readDescriptor = replacement; return copy
    }

    func replacingTargetMetadata(_ replacement: @escaping @Sendable (URL) throws -> PortableArchiveExpiryFileMetadata) -> PortableArchiveExpiryFileOperations {
        var copy = self; copy.targetMetadata = replacement; return copy
    }

    func replacingUnlink(_ replacement: @escaping @Sendable (URL) throws -> Void) -> PortableArchiveExpiryFileOperations {
        var copy = self; copy.unlinkTarget = replacement; return copy
    }

    private static func metadata(_ value: stat) -> PortableArchiveExpiryFileMetadata {
        PortableArchiveExpiryFileMetadata(
            identity: .init(device: UInt64(value.st_dev), inode: UInt64(value.st_ino)),
            isRegular: (value.st_mode & S_IFMT) == S_IFREG,
            isSymbolicLink: (value.st_mode & S_IFMT) == S_IFLNK,
            byteCount: value.st_size
        )
    }
}

protocol PortableArchiveExpiryWorking: Actor { func run() throws }

/// A serial actor around a small, durable state machine. Database claims and
/// finalization are short SQLite transactions; no WorkspaceStore lock is ever
/// held while this actor performs filesystem I/O.
actor PortableArchiveExpiryWorker: PortableArchiveExpiryWorking {
    typealias BookmarkResolver = @Sendable (Data) throws -> PortableArchiveExpiryScopedAccess
    typealias ActivityWriter = @Sendable (EncryptedDatabase, String, String, UUID, Date) throws -> Void

    private let configuration: PortableArchiveDatabaseConfiguration
    private let now: @Sendable () -> Date
    private let bookmarkResolver: BookmarkResolver
    private let fileOperations: PortableArchiveExpiryFileOperations
    private let actorID: String
    private let activityID: @Sendable () -> String
    private let activityWriter: ActivityWriter

    init(
        configuration: PortableArchiveDatabaseConfiguration,
        now: @escaping @Sendable () -> Date = { .now },
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
        let database = try EncryptedDatabase.open(url: configuration.url, key: configuration.key, createIfMissing: false)
        defer { try? database.close() }
        let opportunityTime = now()

        for candidate in try dueCandidates(at: opportunityTime, in: database) {
            if candidate.storageClass != "managed" {
                try markExternalManualRemoval(candidate, in: database)
                continue
            }
            var activeCandidate = candidate
            do {
                let claimed = try claim(candidate, in: database)
                guard let claimed else { continue }
                activeCandidate = claimed
                try process(claimed, at: opportunityTime, in: database)
            } catch let error as PortableArchiveExpiryError {
                try persist(error, for: activeCandidate, in: database)
            } catch {
                try persist(.ioFailure, for: activeCandidate, in: database)
            }
        }
    }

    private func process(_ candidate: PortableArchiveExpiryCandidate, at opportunityTime: Date, in database: EncryptedDatabase) throws {
        let root = try managedRoot()
        guard let archiveURL = managedArchiveURL(for: candidate, root: root),
              let quarantineURL = managedQuarantineURL(for: candidate, root: root) else {
            throw PortableArchiveExpiryError.targetUnsafe
        }
        try ensurePrivateQuarantineDirectory(root: root)

        if fileExists(quarantineURL) {
            var quarantined = candidate
            if candidate.lifecycleState != .expiredQuarantined {
                quarantined = try transition(candidate, state: .expiredQuarantined, outcome: .none, in: database)
            }
            try removeQuarantined(quarantined, at: quarantineURL, opportunityTime: opportunityTime, in: database)
            return
        }

        guard candidate.lifecycleState != .expiredQuarantined else { throw PortableArchiveExpiryError.targetMissing }
        let prepared = try verifyAndRememberIdentity(candidate, at: archiveURL, in: database)
        try fileOperations.moveTarget(archiveURL, quarantineURL)
        let quarantined = try transition(prepared, state: .expiredQuarantined, outcome: .none, in: database)
        try removeQuarantined(quarantined, at: quarantineURL, opportunityTime: opportunityTime, in: database)
    }

    private func removeQuarantined(
        _ candidate: PortableArchiveExpiryCandidate,
        at quarantineURL: URL,
        opportunityTime: Date,
        in database: EncryptedDatabase
    ) throws {
        let verified = try verifyAndRememberIdentity(candidate, at: quarantineURL, in: database)
        let finalMetadata = try fileOperations.targetMetadata(quarantineURL)
        guard finalMetadata.isRegular, !finalMetadata.isSymbolicLink,
              finalMetadata.identity == verified.expectedIdentity else {
            throw PortableArchiveExpiryError.identityMismatch
        }
        try fileOperations.unlinkTarget(quarantineURL)
        do {
            try database.transaction {
                guard try claimedRowExists(verified, in: database) else { throw PortableArchiveExpiryError.ioFailure }
                try database.execute(
                    "DELETE FROM portable_archive_catalogue WHERE archive_id = ? AND expiry_token = ? AND expiry_revision = ?",
                    values: [.text(verified.row.archiveID.uuidString), .text(verified.expiryToken), .integer(verified.expiryRevision)]
                )
                try activityWriter(database, activityID(), actorID, verified.row.archiveID, opportunityTime)
            }
        } catch {
            // The bytes are already absent. Keep the durable claimed locator and
            // make the following run report missing rather than claiming success.
            _ = try? transition(verified, state: .expiredRetryable, outcome: .ioFailure, in: database)
        }
    }

    private func verifyAndRememberIdentity(
        _ candidate: PortableArchiveExpiryCandidate,
        at url: URL,
        in database: EncryptedDatabase
    ) throws -> PortableArchiveExpiryCandidate {
        let descriptor = try fileOperations.openDescriptor(url)
        defer { fileOperations.closeDescriptor(descriptor) }
        let opened = try fileOperations.descriptorMetadata(descriptor)
        guard opened.isRegular, !opened.isSymbolicLink else { throw PortableArchiveExpiryError.targetUnsafe }
        if let expected = candidate.expectedIdentity, expected != opened.identity {
            throw PortableArchiveExpiryError.identityMismatch
        }
        let data = try fileOperations.readDescriptor(descriptor)
        let binding: PortableArchivePublicBinding
        do { binding = try PortableArchiveService.verifyPublicBinding(data: data) }
        catch { throw PortableArchiveExpiryError.archiveMismatch }
        guard candidate.row.formatVersion == Int(PortableArchiveService.formatVersion),
              candidate.row.verificationState == "Verified",
              binding.archiveID == candidate.row.archiveID,
              binding.expiresAt == candidate.row.expiresAt,
              binding.ciphertextChecksum == candidate.row.ciphertextChecksum,
              binding.signingKeyFingerprint == candidate.row.signingKeyFingerprint else {
            throw PortableArchiveExpiryError.archiveMismatch
        }
        let current = try fileOperations.targetMetadata(url)
        guard current.isRegular, !current.isSymbolicLink, current.identity == opened.identity else {
            throw PortableArchiveExpiryError.identityMismatch
        }
        if candidate.expectedIdentity == opened.identity { return candidate }
        return try rememberIdentity(opened.identity, for: candidate, in: database)
    }

    private func claim(_ candidate: PortableArchiveExpiryCandidate, in database: EncryptedDatabase) throws -> PortableArchiveExpiryCandidate? {
        if candidate.lifecycleState == .expiredPrepared ||
            candidate.lifecycleState == .expiredQuarantined ||
            candidate.lifecycleState == .expiredRetryable {
            guard !candidate.expiryToken.isEmpty, candidate.quarantineRelativePath != nil else {
                return try claimFresh(candidate, in: database)
            }
            return candidate
        }
        return try claimFresh(candidate, in: database)
    }

    private func claimFresh(_ candidate: PortableArchiveExpiryCandidate, in database: EncryptedDatabase) throws -> PortableArchiveExpiryCandidate? {
        let token = UUID().uuidString.lowercased()
        let quarantine = "quarantine/\(candidate.row.archiveID.uuidString.lowercased()).\(token).pending"
        try database.transaction {
            try database.execute(
                """
                UPDATE portable_archive_catalogue
                SET lifecycle_state = ?, last_expiry_outcome = ?, expiry_token = ?,
                    expiry_quarantine_relative_path = ?, expiry_expected_device = NULL,
                    expiry_expected_inode = NULL, expiry_revision = expiry_revision + 1
                WHERE archive_id = ? AND expiry_revision = ?
                  AND lifecycle_state IN ('Verified', 'expired_pending_removal', 'expired_retryable')
                """,
                values: [.text(PortableArchiveLifecycleState.expiredPrepared.rawValue), .text(PortableArchiveExpiryOutcome.none.rawValue), .text(token), .text(quarantine), .text(candidate.row.archiveID.uuidString), .integer(candidate.expiryRevision)]
            )
        }
        return try candidateForClaim(archiveID: candidate.row.archiveID, token: token, in: database)
    }

    private func candidateForClaim(archiveID: UUID, token: String, in database: EncryptedDatabase) throws -> PortableArchiveExpiryCandidate? {
        guard let row = try candidateRow(whereClause: "archive_id = ? AND expiry_token = ?", values: [.text(archiveID.uuidString), .text(token)], in: database).first else { return nil }
        return row
    }

    private func rememberIdentity(_ identity: PortableArchiveExpiryFileIdentity, for candidate: PortableArchiveExpiryCandidate, in database: EncryptedDatabase) throws -> PortableArchiveExpiryCandidate {
        try database.transaction {
            guard try claimedRowExists(candidate, in: database) else { throw PortableArchiveExpiryError.ioFailure }
            try database.execute(
                "UPDATE portable_archive_catalogue SET expiry_expected_device = ?, expiry_expected_inode = ?, expiry_revision = expiry_revision + 1 WHERE archive_id = ? AND expiry_token = ? AND expiry_revision = ?",
                values: [.integer(Int64(bitPattern: identity.device)), .integer(Int64(bitPattern: identity.inode)), .text(candidate.row.archiveID.uuidString), .text(candidate.expiryToken), .integer(candidate.expiryRevision)]
            )
        }
        guard let updated = try candidateForClaim(archiveID: candidate.row.archiveID, token: candidate.expiryToken, in: database) else { throw PortableArchiveExpiryError.ioFailure }
        return updated
    }

    private func transition(_ candidate: PortableArchiveExpiryCandidate, state: PortableArchiveLifecycleState, outcome: PortableArchiveExpiryOutcome, in database: EncryptedDatabase) throws -> PortableArchiveExpiryCandidate {
        try database.transaction {
            guard try claimedRowExists(candidate, in: database) else { throw PortableArchiveExpiryError.ioFailure }
            try database.execute(
                "UPDATE portable_archive_catalogue SET lifecycle_state = ?, last_expiry_outcome = ?, expiry_revision = expiry_revision + 1 WHERE archive_id = ? AND expiry_token = ? AND expiry_revision = ?",
                values: [.text(state.rawValue), .text(outcome.rawValue), .text(candidate.row.archiveID.uuidString), .text(candidate.expiryToken), .integer(candidate.expiryRevision)]
            )
        }
        guard let updated = try candidateForClaim(archiveID: candidate.row.archiveID, token: candidate.expiryToken, in: database) else { throw PortableArchiveExpiryError.ioFailure }
        return updated
    }

    private func claimedRowExists(_ candidate: PortableArchiveExpiryCandidate, in database: EncryptedDatabase) throws -> Bool {
        !(try database.rows(
            "SELECT archive_id FROM portable_archive_catalogue WHERE archive_id = ? AND expiry_token = ? AND expiry_revision = ?",
            values: [.text(candidate.row.archiveID.uuidString), .text(candidate.expiryToken), .integer(candidate.expiryRevision)]
        )).isEmpty
    }

    private func markExternalManualRemoval(_ candidate: PortableArchiveExpiryCandidate, in database: EncryptedDatabase) throws {
        try database.execute(
            "UPDATE portable_archive_catalogue SET lifecycle_state = ?, last_expiry_outcome = ? WHERE archive_id = ? AND lifecycle_state NOT IN ('expired_manual_removal_required', 'expired_missing')",
            values: [.text(PortableArchiveLifecycleState.expiredManualRemovalRequired.rawValue), .text(PortableArchiveExpiryOutcome.manualRemovalRequired.rawValue), .text(candidate.row.archiveID.uuidString)]
        )
    }

    private func persist(_ error: PortableArchiveExpiryError, for original: PortableArchiveExpiryCandidate, in database: EncryptedDatabase) throws {
        // Reload by token so an error following a successful prepared/quarantined
        // transition updates the current revision rather than an obsolete claim.
        let candidate: PortableArchiveExpiryCandidate
        if !original.expiryToken.isEmpty,
           let reloaded = try candidateForClaim(archiveID: original.row.archiveID, token: original.expiryToken, in: database) {
            candidate = reloaded
        } else {
            candidate = original
        }
        let state: PortableArchiveLifecycleState
        let outcome: PortableArchiveExpiryOutcome
        switch error {
        case .targetMissing: state = .expiredMissing; outcome = .targetMissing
        case .scopeUnavailable: state = .expiredRetryable; outcome = .scopeUnavailable
        case .ioFailure: state = .expiredRetryable; outcome = .ioFailure
        case .targetUnsafe: state = .expiredBlocked; outcome = .targetUnsafe
        case .identityMismatch: state = .expiredBlocked; outcome = .identityMismatch
        case .archiveMismatch: state = .expiredBlocked; outcome = .archiveMismatch
        }
        if candidate.expiryToken.isEmpty {
            try database.execute(
                "UPDATE portable_archive_catalogue SET lifecycle_state = ?, last_expiry_outcome = ? WHERE archive_id = ?",
                values: [.text(state.rawValue), .text(outcome.rawValue), .text(candidate.row.archiveID.uuidString)]
            )
        } else {
            _ = try? transition(candidate, state: state, outcome: outcome, in: database)
        }
    }

    private func dueCandidates(at opportunityTime: Date, in database: EncryptedDatabase) throws -> [PortableArchiveExpiryCandidate] {
        try candidateRow(
            whereClause: "expires_at <= ? AND lifecycle_state IN ('Verified', 'expired_pending_removal', 'expired_retryable', 'expired_prepared', 'expired_quarantined')",
            values: [.real(opportunityTime.timeIntervalSince1970)], in: database
        )
    }

    private func candidateRow(whereClause: String, values: [DatabaseValue], in database: EncryptedDatabase) throws -> [PortableArchiveExpiryCandidate] {
        try database.rows(
            """
            SELECT archive_id, destination_bookmark, display_filename, format_version, created_at, expires_at,
                   verification_state, ciphertext_checksum, signing_key_fingerprint, lifecycle_state,
                   last_expiry_outcome, storage_class, managed_relative_path, expiry_token, expiry_revision,
                   expiry_quarantine_relative_path, expiry_expected_device, expiry_expected_inode
            FROM portable_archive_catalogue WHERE \(whereClause) ORDER BY expires_at, archive_id
            """, values: values
        ).map { values in
            guard values.count == 18,
                  case let .text(id) = values[0], let archiveID = UUID(uuidString: id),
                  case let .blob(bookmark) = values[1], case let .text(filename) = values[2],
                  case let .integer(version) = values[3], case let .real(createdAt) = values[4],
                  case let .real(expiresAt) = values[5], case let .text(verificationState) = values[6],
                  case let .blob(checksum) = values[7], case let .blob(fingerprint) = values[8],
                  case let .text(lifecycleText) = values[9], let lifecycle = PortableArchiveLifecycleState(rawValue: lifecycleText),
                  case let .text(outcomeText) = values[10], let outcome = PortableArchiveExpiryOutcome(rawValue: outcomeText),
                  case let .text(storageClass) = values[11], case let .integer(revision) = values[14] else {
                throw WorkspaceStoreError.unexpectedDatabaseValue
            }
            let optionalText: (DatabaseValue) throws -> String? = { value in
                if case let .text(text) = value { return text }
                if case .null = value { return nil }
                throw WorkspaceStoreError.unexpectedDatabaseValue
            }
            let optionalInteger: (DatabaseValue) throws -> Int64? = { value in
                if case let .integer(integer) = value { return integer }
                if case .null = value { return nil }
                throw WorkspaceStoreError.unexpectedDatabaseValue
            }
            let device = try optionalInteger(values[16])
            let inode = try optionalInteger(values[17])
            let expected: PortableArchiveExpiryFileIdentity?
            if let device, let inode { expected = .init(device: UInt64(bitPattern: device), inode: UInt64(bitPattern: inode)) }
            else if device == nil && inode == nil { expected = nil }
            else { throw WorkspaceStoreError.unexpectedDatabaseValue }
            return .init(
                row: .init(archiveID: archiveID, displayFilename: filename, formatVersion: Int(version), createdAt: .init(timeIntervalSince1970: createdAt), expiresAt: .init(timeIntervalSince1970: expiresAt), verificationState: verificationState, ciphertextChecksum: checksum, signingKeyFingerprint: fingerprint, lifecycleState: lifecycle, lastExpiryOutcome: outcome),
                bookmark: bookmark, storageClass: storageClass, managedRelativePath: try optionalText(values[12]),
                expiryToken: try optionalText(values[13]) ?? "", expiryRevision: revision,
                quarantineRelativePath: try optionalText(values[15]), expectedIdentity: expected
            )
        }
    }

    private func managedRoot() throws -> URL {
        let root = configuration.url.deletingLastPathComponent().appendingPathComponent("portable-archives", isDirectory: true)
        var value = stat()
        guard Darwin.lstat(root.path, &value) == 0 else {
            if errno == ENOENT { throw PortableArchiveExpiryError.targetMissing }
            throw PortableArchiveExpiryError.ioFailure
        }
        guard (value.st_mode & S_IFMT) == S_IFDIR, (value.st_mode & S_IFLNK) == 0 else { throw PortableArchiveExpiryError.targetUnsafe }
        guard Darwin.chmod(root.path, S_IRWXU) == 0 else { throw PortableArchiveExpiryError.ioFailure }
        return root
    }

    private func managedArchiveURL(for candidate: PortableArchiveExpiryCandidate, root: URL) -> URL? {
        let expected = "\(candidate.row.archiveID.uuidString.lowercased()).rekonarchive"
        guard candidate.managedRelativePath == expected else { return nil }
        return root.appendingPathComponent(expected, isDirectory: false)
    }

    private func managedQuarantineURL(for candidate: PortableArchiveExpiryCandidate, root: URL) -> URL? {
        guard let tokenID = UUID(uuidString: candidate.expiryToken),
              tokenID.uuidString.lowercased() == candidate.expiryToken else {
            return nil
        }
        let token = tokenID.uuidString.lowercased()
        let expected = "quarantine/\(candidate.row.archiveID.uuidString.lowercased()).\(token).pending"
        guard candidate.quarantineRelativePath == expected else { return nil }
        return root
            .appendingPathComponent("quarantine", isDirectory: true)
            .appendingPathComponent("\(candidate.row.archiveID.uuidString.lowercased()).\(token).pending", isDirectory: false)
    }

    private func ensurePrivateQuarantineDirectory(root: URL) throws {
        let quarantine = root.appendingPathComponent("quarantine", isDirectory: true)
        if !FileManager.default.fileExists(atPath: quarantine.path) {
            try FileManager.default.createDirectory(at: quarantine, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        }
        var value = stat()
        guard Darwin.lstat(quarantine.path, &value) == 0,
              (value.st_mode & S_IFMT) == S_IFDIR, (value.st_mode & S_IFLNK) == 0 else {
            throw PortableArchiveExpiryError.targetUnsafe
        }
        guard Darwin.chmod(quarantine.path, S_IRWXU) == 0 else { throw PortableArchiveExpiryError.ioFailure }
    }

    private func fileExists(_ url: URL) -> Bool {
        do { _ = try fileOperations.targetMetadata(url); return true }
        catch PortableArchiveExpiryError.targetMissing { return false }
        catch { return true }
    }

    private static func resolveBookmark(_ bookmark: Data) throws -> PortableArchiveExpiryScopedAccess {
        var stale = false
        let url: URL
        do { url = try URL(resolvingBookmarkData: bookmark, options: [.withSecurityScope, .withoutUI], relativeTo: nil, bookmarkDataIsStale: &stale) }
        catch { throw PortableArchiveExpiryError.scopeUnavailable }
        guard !stale, url.startAccessingSecurityScopedResource() else { throw PortableArchiveExpiryError.scopeUnavailable }
        return .init(url: url, stopAccessing: { url.stopAccessingSecurityScopedResource() })
    }

    private static func insertRemovalActivity(into database: EncryptedDatabase, id: String, actorID: String, archiveID: UUID, occurredAt: Date) throws {
        try database.execute(
            "INSERT INTO activity_events (id, kind, opportunity_id, contact_id, actor_id, correlation_id, occurred_at) VALUES (?, 'portable_backup_expired_removed', NULL, NULL, ?, ?, ?)",
            values: [.text(id), .text(actorID), .text(archiveID.uuidString), .real(occurredAt.timeIntervalSince1970)]
        )
    }
}

nonisolated private struct PortableArchiveExpiryCandidate {
    let row: PortableArchiveCatalogueRow
    let bookmark: Data
    let storageClass: String
    let managedRelativePath: String?
    let expiryToken: String
    let expiryRevision: Int64
    let quarantineRelativePath: String?
    let expectedIdentity: PortableArchiveExpiryFileIdentity?
    var lifecycleState: PortableArchiveLifecycleState { row.lifecycleState }
}
