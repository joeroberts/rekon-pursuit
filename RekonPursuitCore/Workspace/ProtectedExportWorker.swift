import CryptoKit
import Darwin
import Foundation

nonisolated struct ProtectedExportReview: Equatable, Sendable {
    let destinationURL: URL
    let sourceRevision: Int64
    let parentIdentity: ProtectedExportParentIdentity
    let destinationIdentityDigest: Data
    let confirmationFingerprint: String

    var displayFilename: String { destinationURL.lastPathComponent }
}

nonisolated struct ProtectedExportParentIdentity: Equatable, Sendable {
    let device: UInt64
    let inode: UInt64
}

nonisolated struct ProtectedExportRequest: Sendable {
    let review: ProtectedExportReview
    let recoveryKey: RecoveryKey
    let exportID: UUID
    let createdAt: Date
    let activityID: String
    let actorID: String
    let correlationID: String
}

nonisolated enum ProtectedExportWorkerError: LocalizedError, Sendable, Equatable {
    case invalidDestinationName, destinationUnavailable, destinationExists, destinationChanged, sourceChanged, enrollmentRequired, invalidRecoveryKey, verificationFailed, outputMayRemainAfterFailure

    var errorDescription: String? {
        switch self {
        case .invalidDestinationName: "Choose a new file name ending in .rekonexport."
        case .destinationUnavailable: "Rekon Pursuit can’t use that folder. Choose another local folder and review the export again."
        case .destinationExists: "That filename already exists. Choose a new filename; Rekon Pursuit will not replace a file."
        case .destinationChanged: "The selected destination changed before export. Choose the destination again and review it."
        case .sourceChanged: "Your workspace changed while you were reviewing the export. Review it again before confirming."
        case .enrollmentRequired: "Set up portable recovery before creating a protected export."
        case .invalidRecoveryKey: "The recovery key does not match this workspace."
        case .verificationFailed: "The protected export could not be verified. No success activity was recorded."
        case .outputMayRemainAfterFailure: "Final export writing or verification failed. The selected file may remain; treat it as unusable and remove it yourself."
        }
    }
}

nonisolated enum ProtectedExportWorkerFaultMode: Sendable {
    case none
    case parentOpenUnavailable
    case parentInspectionUnavailable
    case exclusiveCreateUnavailable
    case afterOutputCreation
}

actor ProtectedExportWorker {
    private let configuration: PortableArchiveDatabaseConfiguration
    private let faultMode: ProtectedExportWorkerFaultMode

    init(configuration: PortableArchiveDatabaseConfiguration,
         faultMode: ProtectedExportWorkerFaultMode = .none) {
        self.configuration = configuration
        self.faultMode = faultMode
    }

    func review(destinationURL: URL, recoveryKey: RecoveryKey) throws -> ProtectedExportReview {
        let accessed = destinationURL.startAccessingSecurityScopedResource()
        defer { if accessed { destinationURL.stopAccessingSecurityScopedResource() } }
        let parent = try Self.openParent(for: destinationURL, faultMode: faultMode)
        defer { close(parent.descriptor) }
        guard !Self.destinationExists(parent.descriptor, filename: parent.filename) else { throw ProtectedExportWorkerError.destinationExists }
        let database = try EncryptedDatabase.open(url: configuration.url, key: configuration.key, createIfMissing: false)
        defer { try? database.close() }
        let revision = try database.deferredReadTransaction {
            try Self.validateEnrollment(recoveryKey, database: database)
            return try Self.exportRevision(in: database)
        }
        return ProtectedExportReview(
            destinationURL: destinationURL,
            sourceRevision: revision,
            parentIdentity: parent.identity,
            destinationIdentityDigest: Self.destinationIdentityDigest(filename: parent.filename, parentIdentity: parent.identity),
            confirmationFingerprint: Self.confirmationFingerprint(filename: parent.filename, destinationIdentityDigest: Self.destinationIdentityDigest(filename: parent.filename, parentIdentity: parent.identity), revision: revision)
        )
    }

    func create(_ request: ProtectedExportRequest) throws -> ProtectedExportReceipt {
        let accessed = request.review.destinationURL.startAccessingSecurityScopedResource()
        defer { if accessed { request.review.destinationURL.stopAccessingSecurityScopedResource() } }
        let parent = try Self.openParent(for: request.review.destinationURL, faultMode: faultMode)
        defer { close(parent.descriptor) }
        guard parent.identity == request.review.parentIdentity,
              request.review.destinationIdentityDigest == Self.destinationIdentityDigest(filename: parent.filename, parentIdentity: parent.identity),
              request.review.confirmationFingerprint == Self.confirmationFingerprint(filename: parent.filename, destinationIdentityDigest: request.review.destinationIdentityDigest, revision: request.review.sourceRevision) else {
            throw ProtectedExportWorkerError.destinationChanged
        }
        guard !Self.destinationExists(parent.descriptor, filename: parent.filename) else { throw ProtectedExportWorkerError.destinationExists }
        let database = try EncryptedDatabase.open(url: configuration.url, key: configuration.key, createIfMissing: false)
        defer { try? database.close() }
        let snapshot = try database.deferredReadTransaction { () throws -> Data in
            try Self.validateEnrollment(request.recoveryKey, database: database)
            guard try Self.exportRevision(in: database) == request.review.sourceRevision else { throw ProtectedExportWorkerError.sourceChanged }
            return try ProtectedExportSnapshotCodec.encode(from: database)
        }
        let temporaryURL = FileManager.default.temporaryDirectory.appendingPathComponent(".rekon-export-\(UUID().uuidString).tmp")
        defer { try? FileManager.default.removeItem(at: temporaryURL) }
        let receipt = try ProtectedExportService.writeAndVerify(
            snapshot: snapshot, sourceRevision: request.review.sourceRevision, recoveryKey: request.recoveryKey,
            exportID: request.exportID, createdAt: request.createdAt, to: temporaryURL
        )
        let saved: Data
        do {
            saved = try Self.copyExclusivelyAndReadBack(from: temporaryURL, parent: parent, faultMode: faultMode)
        } catch {
            if let protectedError = error as? ProtectedExportWorkerError { throw protectedError }
            throw ProtectedExportWorkerError.outputMayRemainAfterFailure
        }
        do {
            let verified = try ProtectedExportService.verify(data: saved, recoveryKey: request.recoveryKey)
            guard verified == receipt else { throw ProtectedExportWorkerError.verificationFailed }
        } catch {
            throw ProtectedExportWorkerError.outputMayRemainAfterFailure
        }
        do {
            try database.transaction {
                try database.execute(
                    "INSERT INTO protected_export_events (id, export_id, category, destination_class, confirmation_fingerprint, outcome, occurred_at) VALUES (?, ?, 'tracker_workspace_data', 'selected_local_folder', ?, 'verified', ?)",
                    values: [.text(UUID().uuidString), .text(receipt.exportID.uuidString), .text(request.review.confirmationFingerprint), .real(request.createdAt.timeIntervalSince1970)]
                )
                try database.execute(
                    "INSERT INTO activity_events (id, kind, opportunity_id, contact_id, actor_id, correlation_id, occurred_at) VALUES (?, 'protected_export_verified', NULL, NULL, ?, ?, ?)",
                    values: [.text(request.activityID), .text(request.actorID), .text(request.correlationID), .real(request.createdAt.timeIntervalSince1970)]
                )
            }
        } catch {
            throw ProtectedExportWorkerError.outputMayRemainAfterFailure
        }
        return receipt
    }

    nonisolated private static func validateEnrollment(_ key: RecoveryKey, database: EncryptedDatabase) throws {
        guard let row = try database.rows("SELECT fingerprint FROM recovery_enrollment WHERE id = 1").first,
              case let .text(fingerprint) = row.first else { throw ProtectedExportWorkerError.enrollmentRequired }
        guard fingerprint == key.fingerprint else { throw ProtectedExportWorkerError.invalidRecoveryKey }
    }

    nonisolated private static func exportRevision(in database: EncryptedDatabase) throws -> Int64 {
        guard case let .integer(revision)? = try database.rows("SELECT revision FROM tracker_export_revision WHERE id = 1").first?.first else { throw ProtectedExportWorkerError.verificationFailed }
        return revision
    }

    private static func openParent(for destination: URL, faultMode: ProtectedExportWorkerFaultMode) throws -> (descriptor: Int32, filename: String, identity: ProtectedExportParentIdentity) {
        let filename = destination.lastPathComponent.precomposedStringWithCanonicalMapping
        guard destination.pathExtension.lowercased() == "rekonexport", !filename.isEmpty, filename != ".", filename != "..", !filename.contains("/") else { throw ProtectedExportWorkerError.invalidDestinationName }
        if case .parentOpenUnavailable = faultMode { throw ProtectedExportWorkerError.destinationUnavailable }
        let descriptor = open(destination.deletingLastPathComponent().path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW)
        guard descriptor >= 0 else { throw ProtectedExportWorkerError.destinationUnavailable }
        if case .parentInspectionUnavailable = faultMode {
            close(descriptor)
            throw ProtectedExportWorkerError.destinationUnavailable
        }
        var metadata = stat()
        guard fstat(descriptor, &metadata) == 0 else { close(descriptor); throw ProtectedExportWorkerError.destinationUnavailable }
        return (descriptor, filename, .init(device: UInt64(metadata.st_dev), inode: UInt64(metadata.st_ino)))
    }

    private static func destinationExists(_ parentFD: Int32, filename: String) -> Bool {
        var metadata = stat()
        let result = fstatat(parentFD, filename, &metadata, AT_SYMLINK_NOFOLLOW)
        return result == 0 || errno != ENOENT
    }

    private static func destinationIdentityDigest(filename: String, parentIdentity: ProtectedExportParentIdentity) -> Data {
        let filenameBytes = Data(filename.utf8)
        var bytes = Data("RekonPursuit/export/destination/v1\0".utf8)
        append(parentIdentity.device, to: &bytes)
        append(parentIdentity.inode, to: &bytes)
        append(UInt32(filenameBytes.count), to: &bytes)
        bytes.append(filenameBytes)
        return Data(SHA256.hash(data: bytes))
    }

    private static func confirmationFingerprint(filename: String, destinationIdentityDigest: Data, revision: Int64) -> String {
        let filenameBytes = Data(filename.utf8)
        guard destinationIdentityDigest.count == 32 else { return "" }
        var bytes = Data("RekonPursuit/export/review/v1\0".utf8)
        append(UInt16(1), to: &bytes) // format version
        bytes.append(1) // export type: logical projection
        bytes.append(1) // category: tracker workspace data
        append(UInt32(filenameBytes.count), to: &bytes)
        bytes.append(filenameBytes)
        bytes.append(destinationIdentityDigest)
        append(UInt64(bitPattern: revision), to: &bytes)
        return SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    }

    private static func copyExclusivelyAndReadBack(from source: URL, parent: (descriptor: Int32, filename: String, identity: ProtectedExportParentIdentity), faultMode: ProtectedExportWorkerFaultMode) throws -> Data {
        var created = false
        var outputFD: Int32 = -1
        defer { if outputFD >= 0 { close(outputFD) } }
        do {
            guard currentIdentity(parent.descriptor) == parent.identity else { throw ProtectedExportWorkerError.destinationChanged }
            if case .exclusiveCreateUnavailable = faultMode { throw ProtectedExportWorkerError.destinationUnavailable }
            outputFD = openat(parent.descriptor, parent.filename, O_RDWR | O_CREAT | O_EXCL | O_NOFOLLOW, S_IRUSR | S_IWUSR)
            let openError = errno
            guard outputFD >= 0 else { throw openError == EEXIST ? ProtectedExportWorkerError.destinationExists : ProtectedExportWorkerError.destinationUnavailable }
            created = true
            if case .afterOutputCreation = faultMode { throw ProtectedExportWorkerError.outputMayRemainAfterFailure }
            var outputMetadata = stat()
            guard fstat(outputFD, &outputMetadata) == 0 else { throw ProtectedExportWorkerError.outputMayRemainAfterFailure }
            let outputIdentity = ProtectedExportParentIdentity(device: UInt64(outputMetadata.st_dev), inode: UInt64(outputMetadata.st_ino))
            let sourceHandle = try FileHandle(forReadingFrom: source)
            defer { try? sourceHandle.close() }
            while let chunk = try sourceHandle.read(upToCount: 1_048_576), !chunk.isEmpty { try writeAll(chunk, to: outputFD) }
            guard fsync(outputFD) == 0, currentIdentity(parent.descriptor) == parent.identity else { throw ProtectedExportWorkerError.outputMayRemainAfterFailure }
            var verifiedMetadata = stat()
            guard fstat(outputFD, &verifiedMetadata) == 0,
                  outputIdentity == ProtectedExportParentIdentity(device: UInt64(verifiedMetadata.st_dev), inode: UInt64(verifiedMetadata.st_ino)),
                  lseek(outputFD, 0, SEEK_SET) >= 0 else { throw ProtectedExportWorkerError.outputMayRemainAfterFailure }
            return try readAll(from: outputFD)
        } catch {
            if created { throw ProtectedExportWorkerError.outputMayRemainAfterFailure }
            throw error
        }
    }

    private static func currentIdentity(_ descriptor: Int32) -> ProtectedExportParentIdentity? { var metadata = stat(); guard fstat(descriptor, &metadata) == 0 else { return nil }; return .init(device: UInt64(metadata.st_dev), inode: UInt64(metadata.st_ino)) }
    private static func writeAll(_ data: Data, to descriptor: Int32) throws { var offset = 0; try data.withUnsafeBytes { bytes in while offset < data.count { let written = Darwin.write(descriptor, bytes.baseAddress!.advanced(by: offset), data.count - offset); guard written > 0 else { throw ProtectedExportWorkerError.outputMayRemainAfterFailure }; offset += written } } }
    private static func readAll(from descriptor: Int32) throws -> Data { var data = Data(); var buffer = [UInt8](repeating: 0, count: 1_048_576); while true { let count = Darwin.read(descriptor, &buffer, buffer.count); guard count >= 0 else { throw ProtectedExportWorkerError.outputMayRemainAfterFailure }; if count == 0 { return data }; data.append(buffer, count: count) } }
    private static func append<T: FixedWidthInteger>(_ value: T, to data: inout Data) { var encoded = value.bigEndian; withUnsafeBytes(of: &encoded) { data.append(contentsOf: $0) } }
}
