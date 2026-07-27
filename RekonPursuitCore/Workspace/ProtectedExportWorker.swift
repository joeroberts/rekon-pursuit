import CryptoKit
import Darwin
import Foundation

nonisolated struct ProtectedExportReview: Equatable, Sendable {
    let destinationURL: URL
    let sourceRevision: Int64
    let confirmationFingerprint: String

    var displayFilename: String { destinationURL.lastPathComponent }
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

nonisolated enum ProtectedExportWorkerError: LocalizedError, Sendable {
    case invalidDestination, destinationExists, destinationChanged, sourceChanged, enrollmentRequired, invalidRecoveryKey, verificationFailed

    var errorDescription: String? {
        switch self {
        case .invalidDestination: "Choose a new file named with the .rekonexport extension."
        case .destinationExists: "That filename already exists. Choose a new filename; Rekon Pursuit will not replace a file."
        case .destinationChanged: "The selected destination changed before export. Choose the destination again and review it."
        case .sourceChanged: "Your workspace changed while you were reviewing the export. Review it again before confirming."
        case .enrollmentRequired: "Set up portable recovery before creating a protected export."
        case .invalidRecoveryKey: "The recovery key does not match this workspace."
        case .verificationFailed: "The protected export could not be verified. No success activity was recorded."
        }
    }
}

actor ProtectedExportWorker {
    private let configuration: PortableArchiveDatabaseConfiguration

    init(configuration: PortableArchiveDatabaseConfiguration) {
        self.configuration = configuration
    }

    func review(destinationURL: URL, recoveryKey: RecoveryKey) throws -> ProtectedExportReview {
        try validateDestination(destinationURL)
        let database = try EncryptedDatabase.open(url: configuration.url, key: configuration.key, createIfMissing: false)
        defer { try? database.close() }
        let revision = try database.deferredReadTransaction {
            try Self.validateEnrollment(recoveryKey, database: database)
            return try Self.exportRevision(in: database)
        }
        return ProtectedExportReview(
            destinationURL: destinationURL,
            sourceRevision: revision,
            confirmationFingerprint: confirmationFingerprint(destinationURL: destinationURL, revision: revision)
        )
    }

    func create(_ request: ProtectedExportRequest) throws -> ProtectedExportReceipt {
        try validateDestination(request.review.destinationURL)
        guard request.review.confirmationFingerprint == confirmationFingerprint(destinationURL: request.review.destinationURL, revision: request.review.sourceRevision) else {
            throw ProtectedExportWorkerError.destinationChanged
        }
        let accessed = request.review.destinationURL.startAccessingSecurityScopedResource()
        defer { if accessed { request.review.destinationURL.stopAccessingSecurityScopedResource() } }

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
        try copyExclusively(from: temporaryURL, to: request.review.destinationURL)
        do {
            let saved = try ProtectedExportService.verify(data: Data(contentsOf: request.review.destinationURL), recoveryKey: request.recoveryKey)
            guard saved == receipt else { throw ProtectedExportWorkerError.verificationFailed }
        } catch {
            throw ProtectedExportWorkerError.verificationFailed
        }
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

    private func validateDestination(_ url: URL) throws {
        guard url.pathExtension.lowercased() == "rekonexport", !url.lastPathComponent.isEmpty else { throw ProtectedExportWorkerError.invalidDestination }
        guard !FileManager.default.fileExists(atPath: url.path) else { throw ProtectedExportWorkerError.destinationExists }
    }

    private func confirmationFingerprint(destinationURL: URL, revision: Int64) -> String {
        let parent = destinationURL.deletingLastPathComponent()
        var metadata = stat()
        let identity: String
        if lstat(parent.path, &metadata) == 0 { identity = "\(metadata.st_dev):\(metadata.st_ino)" } else { identity = "unavailable" }
        let message = "RekonPursuit/export/review/v1\\0\(identity)\\0\(destinationURL.lastPathComponent.precomposedStringWithCanonicalMapping)\\0\(revision)"
        return SHA256.hash(data: Data(message.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private func copyExclusively(from source: URL, to destination: URL) throws {
        let descriptor = open(destination.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { throw errno == EEXIST ? ProtectedExportWorkerError.destinationExists : ProtectedExportWorkerError.invalidDestination }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        defer { try? handle.close() }
        let sourceHandle = try FileHandle(forReadingFrom: source)
        defer { try? sourceHandle.close() }
        while let chunk = try sourceHandle.read(upToCount: 1_048_576), !chunk.isEmpty { try handle.write(contentsOf: chunk) }
        try handle.synchronize()
    }
}
