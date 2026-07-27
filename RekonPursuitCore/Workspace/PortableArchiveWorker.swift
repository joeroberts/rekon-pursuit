import CryptoKit
import Darwin
import Foundation

nonisolated struct PortableArchiveDatabaseConfiguration: Sendable {
    let url: URL
    let key: Data
}

nonisolated struct PortableArchiveRequest: Sendable {
    let recoveryKey: RecoveryKey
    let destinationURL: URL
    let archiveID: UUID
    let temporaryID: UUID
    let activityID: String
    let createdAt: Date
    let actorID: String
    let correlationID: String
}

/// Archive assembly stays inside the app container. The user-selected path is used only
/// after verification, because a sandbox save-panel grant may not permit sibling files.
nonisolated enum PortableArchiveStagingLocation {
    static func url(temporaryDirectory: URL, temporaryID: UUID) -> URL {
        temporaryDirectory.appendingPathComponent(".rekon-archive-\(temporaryID.uuidString.lowercased()).tmp")
    }
}

/// The destination's stable identity lets the worker reject a path that changes
/// after exclusive creation. It is a detection mechanism, not a deletion claim.
nonisolated struct PortableArchiveOutputOwnership: Equatable, Sendable {
    let device: UInt64
    let inode: UInt64

    static func current(at url: URL) -> PortableArchiveOutputOwnership? {
        var metadata = stat()
        guard lstat(url.path, &metadata) == 0 else { return nil }
        return PortableArchiveOutputOwnership(
            device: UInt64(metadata.st_dev),
            inode: UInt64(metadata.st_ino)
        )
    }

    func matchesCurrentOutput(at url: URL) -> Bool {
        Self.current(at: url) == self
    }
}

nonisolated struct PortableArchiveOutputWriteFailure: Error, Sendable {
}

nonisolated enum PortableArchiveOutputWriter {
    static func copyExclusively(
        from sourceURL: URL,
        to destinationURL: URL,
        metadataReader: (Int32, UnsafeMutablePointer<stat>) -> Int32 = { descriptor, metadata in
            fstat(descriptor, metadata)
        }
    ) throws -> PortableArchiveOutputOwnership {
        let descriptor = open(destinationURL.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else {
            if errno == EEXIST {
                throw PortableArchiveError.destinationExists
            }
            throw PortableArchiveError.destinationUnavailable
        }

        var metadata = stat()
        guard metadataReader(descriptor, &metadata) == 0 else {
            close(descriptor)
            throw PortableArchiveOutputWriteFailure()
        }
        let ownership = PortableArchiveOutputOwnership(
            device: UInt64(metadata.st_dev),
            inode: UInt64(metadata.st_ino)
        )
        let destination = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        do {
            let source = try FileHandle(forReadingFrom: sourceURL)
            defer { try? source.close() }
            defer { try? destination.close() }

            while let chunk = try source.read(upToCount: 1_048_576), !chunk.isEmpty {
                try destination.write(contentsOf: chunk)
            }
            try destination.synchronize()
            return ownership
        } catch {
            throw PortableArchiveOutputWriteFailure()
        }
    }
}

protocol PortableArchiveWorking: Actor {
    func createArchive(_ request: PortableArchiveRequest) async throws -> PortableArchiveCatalogueRow
}

actor PortableArchiveWorker: PortableArchiveWorking {
    private let configuration: PortableArchiveDatabaseConfiguration
    private let signingKeyStore: any ArchiveSigningKeyStoring
    private let archiveVerifier: @Sendable (Data, RecoveryKey) throws -> VerifiedPortableArchive
    private let finalOutputWriter: @Sendable (URL, URL) throws -> PortableArchiveOutputOwnership

    init(
        configuration: PortableArchiveDatabaseConfiguration,
        signingKeyStore: any ArchiveSigningKeyStoring,
        archiveVerifier: @escaping @Sendable (Data, RecoveryKey) throws -> VerifiedPortableArchive = { data, recoveryKey in
            try PortableArchiveService.verify(data: data, recoveryKey: recoveryKey)
        },
        finalOutputWriter: @escaping @Sendable (URL, URL) throws -> PortableArchiveOutputOwnership = { source, destination in
            try PortableArchiveOutputWriter.copyExclusively(from: source, to: destination)
        }
    ) {
        self.configuration = configuration
        self.signingKeyStore = signingKeyStore
        self.archiveVerifier = archiveVerifier
        self.finalOutputWriter = finalOutputWriter
    }

    func createArchive(_ request: PortableArchiveRequest) async throws -> PortableArchiveCatalogueRow {
        guard request.destinationURL.pathExtension.lowercased() == "rekonarchive" else {
            throw PortableArchiveError.invalidDestination
        }
        guard !FileManager.default.fileExists(atPath: request.destinationURL.path) else {
            throw PortableArchiveError.destinationExists
        }

        let accessed = request.destinationURL.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                request.destinationURL.stopAccessingSecurityScopedResource()
            }
        }

        let database = try EncryptedDatabase.open(
            url: configuration.url,
            key: configuration.key,
            createIfMissing: false
        )
        defer { try? database.close() }

        let capture: PortableArchiveCapture
        do {
            capture = try database.deferredReadTransaction {
                guard let row = try database.rows(
                    "SELECT fingerprint FROM recovery_enrollment WHERE id = 1"
                ).first,
                    case let .text(fingerprint) = row.first
                else {
                    throw PortableArchiveError.enrollmentRequired
                }
                guard fingerprint == request.recoveryKey.fingerprint else {
                    throw PortableArchiveError.invalidRecoveryKey
                }
                guard case let .text(workspaceID)? = try database.rows(
                    "SELECT value FROM workspace_metadata WHERE key = 'workspace_id'"
                ).first?.first else {
                    throw WorkspaceStoreError.unexpectedDatabaseValue
                }
                let catalogueExists = !(try database.rows(
                    "SELECT archive_id FROM portable_archive_catalogue LIMIT 1"
                )).isEmpty
                return PortableArchiveCapture(
                    snapshot: try PortableArchiveSnapshotCodec.encode(from: database),
                    workspaceID: workspaceID,
                    catalogueExists: catalogueExists
                )
            }
        } catch {
            try? recordFailure(request: request, category: failureCategory(for: error), in: database)
            throw error
        }

        let signingKey: Curve25519.Signing.PrivateKey
        do {
            let rawKey = try await signingKeyStore.privateKeyRawRepresentation(
                for: capture.workspaceID,
                catalogueExists: capture.catalogueExists
            )
            signingKey = try Curve25519.Signing.PrivateKey(rawRepresentation: rawKey)
        } catch {
            try? recordFailure(request: request, category: failureCategory(for: error), in: database)
            throw error
        }

        let temporaryURL = PortableArchiveStagingLocation.url(
            temporaryDirectory: FileManager.default.temporaryDirectory,
            temporaryID: request.temporaryID
        )
        defer { try? FileManager.default.removeItem(at: temporaryURL) }

        do {
            let package = try PortableArchiveService.writeAndVerify(
                snapshot: capture.snapshot,
                recoveryKey: request.recoveryKey,
                signingKey: signingKey,
                archiveID: request.archiveID,
                createdAt: request.createdAt,
                to: temporaryURL
            )
            let ownership: PortableArchiveOutputOwnership
            do {
                ownership = try finalOutputWriter(temporaryURL, request.destinationURL)
            } catch is PortableArchiveOutputWriteFailure {
                throw PortableArchiveError.archiveMayRemainAfterOutputFailure
            } catch {
                throw error
            }
            do {
                guard ownership.matchesCurrentOutput(at: request.destinationURL) else {
                    throw PortableArchiveError.archiveMayRemainAfterOutputFailure
                }
                let saved = try archiveVerifier(Data(contentsOf: request.destinationURL), request.recoveryKey)
                guard saved == package else {
                    throw PortableArchiveError.verificationFailed
                }
            } catch {
                throw PortableArchiveError.archiveMayRemainAfterOutputFailure
            }

            let bookmark: Data
            do {
                guard ownership.matchesCurrentOutput(at: request.destinationURL) else {
                    throw PortableArchiveError.archiveMayRemainAfterOutputFailure
                }
                bookmark = try request.destinationURL.bookmarkData(
                    options: [.withSecurityScope],
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
            } catch let error as PortableArchiveError {
                throw error
            } catch {
                throw PortableArchiveError.catalogueUnavailable
            }

            let catalogue = PortableArchiveCatalogueRow(
                archiveID: request.archiveID,
                displayFilename: request.destinationURL.lastPathComponent,
                formatVersion: Int(PortableArchiveService.formatVersion),
                createdAt: package.createdAt,
                expiresAt: package.expiresAt,
                verificationState: "Verified",
                ciphertextChecksum: package.ciphertextChecksum,
                signingKeyFingerprint: package.signingKeyFingerprint
            )
            do {
                guard ownership.matchesCurrentOutput(at: request.destinationURL) else {
                    throw PortableArchiveError.archiveMayRemainAfterOutputFailure
                }
                try database.execute("BEGIN IMMEDIATE")
                do {
                    guard ownership.matchesCurrentOutput(at: request.destinationURL) else {
                        throw PortableArchiveError.archiveMayRemainAfterOutputFailure
                    }
                    try database.execute(
                        "INSERT INTO portable_archive_catalogue (archive_id, destination_bookmark, display_filename, format_version, created_at, expires_at, verification_state, ciphertext_checksum, signing_key_fingerprint) VALUES (?, ?, ?, ?, ?, ?, 'Verified', ?, ?)",
                        values: [
                            .text(request.archiveID.uuidString),
                            .blob(bookmark),
                            .text(catalogue.displayFilename),
                            .integer(Int64(catalogue.formatVersion)),
                            .real(catalogue.createdAt.timeIntervalSince1970),
                            .real(catalogue.expiresAt.timeIntervalSince1970),
                            .blob(package.ciphertextChecksum),
                            .blob(package.signingKeyFingerprint)
                        ]
                    )
                    try insertActivity(
                        id: request.activityID,
                        kind: "portable_backup_created",
                        request: request,
                        database: database
                    )
                    try database.execute("COMMIT")
                } catch {
                    try? database.execute("ROLLBACK")
                    throw error
                }
            } catch let error as PortableArchiveError {
                throw error
            } catch {
                throw PortableArchiveError.catalogueUnavailable
            }
            return catalogue
        } catch {
            try? recordFailure(request: request, category: failureCategory(for: error), in: database)
            throw error
        }
    }

    private func recordFailure(
        request: PortableArchiveRequest,
        category: String,
        in database: EncryptedDatabase
    ) throws {
        try database.execute("BEGIN IMMEDIATE")
        do {
            try insertActivity(
                id: request.activityID,
                kind: "portable_backup_failed_\(category)",
                request: request,
                database: database
            )
            try database.execute("COMMIT")
        } catch {
            try? database.execute("ROLLBACK")
            throw error
        }
    }

    private func insertActivity(
        id: String,
        kind: String,
        request: PortableArchiveRequest,
        database: EncryptedDatabase
    ) throws {
        try database.execute(
            "INSERT INTO activity_events (id, kind, opportunity_id, contact_id, actor_id, correlation_id, occurred_at) VALUES (?, ?, NULL, NULL, ?, ?, ?)",
            values: [
                .text(id),
                .text(kind),
                .text(request.actorID),
                .text(request.archiveID.uuidString),
                .real(request.createdAt.timeIntervalSince1970)
            ]
        )
    }

    private func failureCategory(for error: Error) -> String {
        switch error {
        case PortableArchiveError.enrollmentRequired:
            return "enrollment_required"
        case PortableArchiveError.invalidRecoveryKey:
            return "invalid_key"
        case PortableArchiveError.destinationExists:
            return "destination_exists"
        case PortableArchiveError.invalidDestination:
            return "invalid_destination"
        case PortableArchiveError.destinationUnavailable:
            return "destination_unavailable"
        case PortableArchiveError.signingKeyUnavailable:
            return "signing_key_unavailable"
        case PortableArchiveError.catalogueUnavailable:
            return "catalogue_unavailable"
        default:
            return "verification_failed"
        }
    }
}

nonisolated private struct PortableArchiveCapture: Sendable {
    let snapshot: Data
    let workspaceID: String
    let catalogueExists: Bool
}

nonisolated struct PortableArchiveSnapshotTable: Sendable {
    let name: String
    let columns: [String]
    /// Zero-based projection columns that represent signed Unix milliseconds in v1.
    let timestampColumnIndexes: Set<Int>
    let query: String
}

nonisolated enum PortableArchiveSnapshotRegistry {
    static let tables: [PortableArchiveSnapshotTable] = [
        .init(
            name: "opportunities",
            columns: ["id", "title", "company", "created_at", "stage", "next_action", "due_at", "job_url", "job_description", "notes", "compensation", "compensation_minimum", "compensation_maximum", "compensation_pay_period", "location", "work_arrangement", "application_date", "response_state", "stage_changed_at", "action_type", "action_custom_text"],
            timestampColumnIndexes: [3, 6, 16, 18],
            query: "SELECT id, title, company, created_at, stage, next_action, due_at, job_url, job_description, notes, compensation, compensation_minimum, compensation_maximum, compensation_pay_period, location, work_arrangement, application_date, response_state, stage_changed_at, action_type, action_custom_text FROM opportunities WHERE deleted_at IS NULL ORDER BY id"
        ),
        .init(name: "task_reminders", columns: ["id", "opportunity_id", "title", "due_at", "is_complete"], timestampColumnIndexes: [3], query: "SELECT task_reminders.id, task_reminders.opportunity_id, task_reminders.title, task_reminders.due_at, task_reminders.is_complete FROM task_reminders JOIN opportunities ON opportunities.id = task_reminders.opportunity_id WHERE opportunities.deleted_at IS NULL ORDER BY task_reminders.id"),
        .init(name: "opportunity_stage_history", columns: ["id", "opportunity_id", "from_stage", "to_stage", "occurred_at"], timestampColumnIndexes: [4], query: "SELECT opportunity_stage_history.id, opportunity_stage_history.opportunity_id, opportunity_stage_history.from_stage, opportunity_stage_history.to_stage, opportunity_stage_history.occurred_at FROM opportunity_stage_history JOIN opportunities ON opportunities.id = opportunity_stage_history.opportunity_id WHERE opportunities.deleted_at IS NULL ORDER BY opportunity_stage_history.id"),
        .init(name: "opportunity_response_history", columns: ["id", "opportunity_id", "from_state", "to_state", "occurred_at"], timestampColumnIndexes: [4], query: "SELECT opportunity_response_history.id, opportunity_response_history.opportunity_id, opportunity_response_history.from_state, opportunity_response_history.to_state, opportunity_response_history.occurred_at FROM opportunity_response_history JOIN opportunities ON opportunities.id = opportunity_response_history.opportunity_id WHERE opportunities.deleted_at IS NULL ORDER BY opportunity_response_history.id"),
        .init(name: "contacts", columns: ["id", "name", "employer", "title", "email", "profile_url", "relationship_context", "notes"], timestampColumnIndexes: [], query: "SELECT id, name, employer, title, email, profile_url, relationship_context, notes FROM contacts WHERE deleted_at IS NULL ORDER BY id"),
        .init(name: "contact_opportunities", columns: ["contact_id", "opportunity_id"], timestampColumnIndexes: [], query: "SELECT contact_opportunities.contact_id, contact_opportunities.opportunity_id FROM contact_opportunities JOIN contacts ON contacts.id = contact_opportunities.contact_id JOIN opportunities ON opportunities.id = contact_opportunities.opportunity_id WHERE contacts.deleted_at IS NULL AND opportunities.deleted_at IS NULL ORDER BY contact_opportunities.contact_id, contact_opportunities.opportunity_id"),
        .init(name: "interactions", columns: ["id", "contact_id", "opportunity_id", "kind", "summary", "occurred_at", "next_touch_at"], timestampColumnIndexes: [5, 6], query: "SELECT interactions.id, interactions.contact_id, interactions.opportunity_id, interactions.kind, interactions.summary, interactions.occurred_at, interactions.next_touch_at FROM interactions LEFT JOIN contacts ON contacts.id = interactions.contact_id LEFT JOIN opportunities ON opportunities.id = interactions.opportunity_id WHERE (interactions.contact_id IS NOT NULL OR interactions.opportunity_id IS NOT NULL) AND (interactions.contact_id IS NULL OR (contacts.id IS NOT NULL AND contacts.deleted_at IS NULL)) AND (interactions.opportunity_id IS NULL OR (opportunities.id IS NOT NULL AND opportunities.deleted_at IS NULL)) ORDER BY interactions.id"),
        .init(name: "import_reports", columns: ["id", "imported_count", "skipped_count", "duplicate_kept_count", "invalid_count", "created_at", "updated_count", "source_basename", "mapping_summary", "failed_count"], timestampColumnIndexes: [5], query: "SELECT import_reports.id, import_reports.imported_count, import_reports.skipped_count, import_reports.duplicate_kept_count, import_reports.invalid_count, import_reports.created_at, import_reports.updated_count, import_reports.source_basename, import_reports.mapping_summary, import_reports.failed_count FROM import_reports WHERE EXISTS (SELECT 1 FROM import_report_rows JOIN opportunities ON opportunities.id = import_report_rows.opportunity_id WHERE import_report_rows.report_id = import_reports.id AND opportunities.deleted_at IS NULL) ORDER BY import_reports.id"),
        .init(name: "import_report_rows", columns: ["id", "report_id", "source_row", "outcome", "reason", "duplicate_rationale", "opportunity_id", "display_title", "display_company"], timestampColumnIndexes: [], query: "SELECT import_report_rows.id, import_report_rows.report_id, import_report_rows.source_row, import_report_rows.outcome, import_report_rows.reason, import_report_rows.duplicate_rationale, import_report_rows.opportunity_id, import_report_rows.display_title, import_report_rows.display_company FROM import_report_rows JOIN opportunities ON opportunities.id = import_report_rows.opportunity_id WHERE opportunities.deleted_at IS NULL ORDER BY import_report_rows.id"),
        .init(name: "posting_checks", columns: ["id", "opportunity_id", "url", "status", "evidence", "checked_at"], timestampColumnIndexes: [5], query: "SELECT posting_checks.id, posting_checks.opportunity_id, posting_checks.url, posting_checks.status, posting_checks.evidence, posting_checks.checked_at FROM posting_checks JOIN opportunities ON opportunities.id = posting_checks.opportunity_id WHERE opportunities.deleted_at IS NULL ORDER BY posting_checks.id"),
        .init(name: "reconciliation_reviews", columns: ["opportunity_id", "task_reminder_id", "created_at", "closure_confirmed_at"], timestampColumnIndexes: [2, 3], query: "SELECT reconciliation_reviews.opportunity_id, reconciliation_reviews.task_reminder_id, reconciliation_reviews.created_at, reconciliation_reviews.closure_confirmed_at FROM reconciliation_reviews JOIN opportunities ON opportunities.id = reconciliation_reviews.opportunity_id WHERE opportunities.deleted_at IS NULL ORDER BY reconciliation_reviews.opportunity_id"),
        .init(name: "reconciliation_results", columns: ["id", "opportunity_id", "url", "recorded_at", "outcome", "classification", "reason", "confidence", "evidence", "error", "review_task_reminder_id", "closure_confirmed_at", "legacy_posting_check_id", "legacy_status", "check_operation_id", "method", "checker_version", "http_status", "mime_type", "declared_bytes", "received_bytes", "content_sha256", "response_date", "last_modified", "etag", "retry_after", "redirect_target_redacted", "evidence_excerpt", "redacted_error_code"], timestampColumnIndexes: [3, 11], query: "SELECT reconciliation_results.id, reconciliation_results.opportunity_id, reconciliation_results.url, reconciliation_results.recorded_at, reconciliation_results.outcome, reconciliation_results.classification, reconciliation_results.reason, reconciliation_results.confidence, reconciliation_results.evidence, reconciliation_results.error, reconciliation_results.review_task_reminder_id, reconciliation_results.closure_confirmed_at, reconciliation_results.legacy_posting_check_id, reconciliation_results.legacy_status, reconciliation_results.check_operation_id, reconciliation_results.method, reconciliation_results.checker_version, reconciliation_results.http_status, reconciliation_results.mime_type, reconciliation_results.declared_bytes, reconciliation_results.received_bytes, reconciliation_results.content_sha256, reconciliation_results.response_date, reconciliation_results.last_modified, reconciliation_results.etag, reconciliation_results.retry_after, reconciliation_results.redirect_target_redacted, reconciliation_results.evidence_excerpt, reconciliation_results.redacted_error_code FROM reconciliation_results JOIN opportunities ON opportunities.id = reconciliation_results.opportunity_id WHERE opportunities.deleted_at IS NULL ORDER BY reconciliation_results.id"),
        .init(name: "reconciliation_check_operations", columns: ["id", "opportunity_id", "correlation_id", "url_snapshot", "state", "started_at", "terminal_at"], timestampColumnIndexes: [5, 6], query: "SELECT reconciliation_check_operations.id, reconciliation_check_operations.opportunity_id, reconciliation_check_operations.correlation_id, reconciliation_check_operations.url_snapshot, reconciliation_check_operations.state, reconciliation_check_operations.started_at, reconciliation_check_operations.terminal_at FROM reconciliation_check_operations JOIN opportunities ON opportunities.id = reconciliation_check_operations.opportunity_id WHERE opportunities.deleted_at IS NULL ORDER BY reconciliation_check_operations.id"),
        .init(name: "document_references", columns: ["id", "opportunity_id", "kind", "filename", "content_type", "source_hash", "byte_count", "bookmark_data", "availability", "attached_at", "final_sent_at"], timestampColumnIndexes: [9, 10], query: "SELECT document_references.id, document_references.opportunity_id, document_references.kind, document_references.filename, document_references.content_type, document_references.source_hash, document_references.byte_count, NULL, 'relink_required', document_references.attached_at, document_references.final_sent_at FROM document_references JOIN opportunities ON opportunities.id = document_references.opportunity_id WHERE opportunities.deleted_at IS NULL ORDER BY document_references.id"),
        .init(name: "activity_events", columns: ["id", "kind", "opportunity_id", "contact_id", "actor_id", "correlation_id", "occurred_at"], timestampColumnIndexes: [6], query: "SELECT activity_events.id, activity_events.kind, activity_events.opportunity_id, activity_events.contact_id, activity_events.actor_id, activity_events.correlation_id, activity_events.occurred_at FROM activity_events LEFT JOIN opportunities ON opportunities.id = activity_events.opportunity_id LEFT JOIN contacts ON contacts.id = activity_events.contact_id WHERE (activity_events.opportunity_id IS NOT NULL OR activity_events.contact_id IS NOT NULL) AND (activity_events.opportunity_id IS NULL OR (opportunities.id IS NOT NULL AND opportunities.deleted_at IS NULL)) AND (activity_events.contact_id IS NULL OR (contacts.id IS NOT NULL AND contacts.deleted_at IS NULL)) ORDER BY activity_events.id"),
        .init(name: "deletion_tombstones", columns: ["subject_id", "subject_type", "deleted_at", "display_value"], timestampColumnIndexes: [2], query: "SELECT subject_id, subject_type, deleted_at, display_value FROM deletion_tombstones ORDER BY subject_id, subject_type")
    ]
}

nonisolated enum PortableArchiveSnapshotCodec {
    static func encode(from database: EncryptedDatabase) throws -> Data {
        var result = Data("RPSNAP01".utf8)
        result.appendArchiveUInt32(UInt32(PortableArchiveSnapshotRegistry.tables.count))
        for table in PortableArchiveSnapshotRegistry.tables {
            let rows = try database.rows(table.query)
            try append(.text(table.name), timestamp: false, to: &result)
            result.appendArchiveUInt32(UInt32(rows.count))
            for row in rows {
                guard row.count == table.columns.count else {
                    throw PortableArchiveError.archiveInvalid
                }
                result.appendArchiveUInt32(UInt32(row.count))
                for (index, value) in row.enumerated() {
                    try append(value, timestamp: table.timestampColumnIndexes.contains(index), to: &result)
                }
            }
        }
        return result
    }

    private static func append(_ value: DatabaseValue, timestamp: Bool, to data: inout Data) throws {
        if timestamp {
            switch value {
            case .null:
                data.append(0)
                data.appendArchiveUInt32(0)
                return
            case let .real(seconds):
                data.append(1)
                data.appendArchiveUInt32(8)
                data.appendArchiveUInt64(UInt64(bitPattern: Int64((seconds * 1_000).rounded())))
                return
            case let .integer(milliseconds):
                data.append(1)
                data.appendArchiveUInt32(8)
                data.appendArchiveUInt64(UInt64(bitPattern: milliseconds))
                return
            default:
                throw PortableArchiveError.archiveInvalid
            }
        }
        switch value {
        case .null:
            data.append(0)
            data.appendArchiveUInt32(0)
        case let .integer(number):
            data.append(1)
            data.appendArchiveUInt32(8)
            data.appendArchiveUInt64(UInt64(bitPattern: number))
        case let .real(number):
            data.append(2)
            data.appendArchiveUInt32(8)
            data.appendArchiveUInt64(number.bitPattern)
        case let .text(text):
            let bytes = Data(text.utf8)
            data.append(3)
            data.appendArchiveUInt32(UInt32(bytes.count))
            data.append(bytes)
        case let .blob(blob):
            data.append(4)
            data.appendArchiveUInt32(UInt32(blob.count))
            data.append(blob)
        }
    }
}

nonisolated private extension Data {
    mutating func appendArchiveUInt32(_ value: UInt32) {
        append(contentsOf: Swift.withUnsafeBytes(of: value.bigEndian, Array.init))
    }

    mutating func appendArchiveUInt64(_ value: UInt64) {
        append(contentsOf: Swift.withUnsafeBytes(of: value.bigEndian, Array.init))
    }
}
