import CryptoKit
import Foundation
import XCTest
@testable import RekonPursuit

@MainActor
final class PortableArchiveTests: XCTestCase {
    func testManifestV1MatchesFrozenSixtyThreeByteEncoding() throws {
        let archiveID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000001"))
        let createdAt = Date(timeIntervalSince1970: 1.25)
        let snapshot = Data([0xAA, 0xBB])
        var expected = Data("RPMAN01".utf8)
        expected.append(contentsOf: [
            0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 1
        ])
        expected.append(contentsOf: [0, 0, 0, 0, 0, 0, 4, 0xE2])
        expected.append(Data(SHA256.hash(data: snapshot)))

        let manifest = PortableArchiveService.manifestBytes(
            archiveID: archiveID,
            createdAt: createdAt,
            snapshot: snapshot
        )

        XCTAssertEqual(manifest.count, 63)
        XCTAssertEqual(manifest, expected)
    }

    func testVerifierRejectsEveryBoundHeaderAndPayloadMutation() throws {
        let recoveryKey = try RecoveryKey.generate()
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("archive-\(UUID().uuidString).tmp")
        defer { try? FileManager.default.removeItem(at: destination) }
        _ = try PortableArchiveService.writeAndVerify(
            snapshot: emptyCanonicalSnapshot(),
            recoveryKey: recoveryKey,
            signingKey: Curve25519.Signing.PrivateKey(),
            archiveID: UUID(),
            createdAt: Date(timeIntervalSince1970: 1_704_067_200),
            to: destination
        )
        let package = try Data(contentsOf: destination)
        let mutationOffsets = [
            14, 30, 38, 46, 47, 79, 111, 143, 175, 207, 267,
            package.index(before: package.endIndex)
        ]

        for offset in mutationOffsets {
            var mutated = package
            mutated[offset] ^= 0x01
            XCTAssertThrowsError(
                try PortableArchiveService.verify(data: mutated, recoveryKey: recoveryKey),
                "Mutation at package byte \(offset) must be rejected."
            )
        }
    }

    func testWorkerSuspensionLeavesMainActorResponsive() async throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("archive-worker-\(UUID().uuidString).sqlite")
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("archive-\(UUID().uuidString).rekonarchive")
        defer {
            try? FileManager.default.removeItem(at: databaseURL)
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: databaseURL.path + "-wal"))
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: databaseURL.path + "-shm"))
            try? FileManager.default.removeItem(at: destination)
        }
        let database = try EncryptedDatabase.open(url: databaseURL, key: Data(repeating: 9, count: 32))
        let keyStore = GatedArchiveSigningKeyStore()
        let store = try WorkspaceStore(
            database: database,
            now: Date(timeIntervalSince1970: 1_704_067_200),
            actorID: "test",
            correlationID: "test",
            archiveSigningKeyStore: keyStore
        )
        let recoveryKey = try RecoveryKey.generate()
        try store.enroll(recoveryKey: recoveryKey)

        let archiveTask = Task {
            try await store.createPortableArchive(recoveryKey: recoveryKey, at: destination)
        }
        while !(await keyStore.hasStarted) {
            await Task.yield()
        }

        XCTAssertTrue(Thread.isMainThread)
        let keyStoreFinished = await keyStore.hasFinished
        XCTAssertFalse(keyStoreFinished)

        await keyStore.release()
        _ = try await archiveTask.value
    }

    func testArchiveActivityCorrelatesOutcomeToOpaqueArchiveID() async throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("archive-audit-\(UUID().uuidString).sqlite")
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("archive-\(UUID().uuidString).rekonarchive")
        defer {
            removeDatabase(at: databaseURL)
            try? FileManager.default.removeItem(at: destination)
        }
        let database = try EncryptedDatabase.open(url: databaseURL, key: Data(repeating: 4, count: 32))
        let store = try WorkspaceStore(
            database: database,
            now: Date(timeIntervalSince1970: 1_704_067_200),
            actorID: "test",
            correlationID: "ordinary-command-correlation",
            archiveSigningKeyStore: StaticArchiveSigningKeyStore()
        )
        let recoveryKey = try RecoveryKey.generate()
        try store.enroll(recoveryKey: recoveryKey)

        let archive = try await store.createPortableArchive(recoveryKey: recoveryKey, at: destination)
        let activity = try XCTUnwrap(try store.activityEvents().last)

        XCTAssertEqual(activity.kind, "portable_backup_created")
        XCTAssertEqual(activity.correlationID, archive.archiveID.uuidString)
        XCTAssertFalse(activity.correlationID.contains(destination.path))
    }

    func testReadBackRejectsSnapshotRowsWithNoncanonicalColumnCount() throws {
        var snapshot = Data("RPSNAP01".utf8)
        let tableNames = [
            "opportunities",
            "task_reminders",
            "opportunity_stage_history",
            "opportunity_response_history",
            "contacts",
            "contact_opportunities",
            "interactions",
            "import_reports",
            "import_report_rows",
            "posting_checks",
            "reconciliation_reviews",
            "reconciliation_results",
            "reconciliation_check_operations",
            "document_references",
            "activity_events",
            "deletion_tombstones"
        ]
        appendUInt32(UInt32(tableNames.count), to: &snapshot)
        for (index, tableName) in tableNames.enumerated() {
            appendText(tableName, to: &snapshot)
            appendUInt32(index == 0 ? 1 : 0, to: &snapshot)
            if index == 0 {
                appendUInt32(0, to: &snapshot)
            }
        }

        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("archive-\(UUID().uuidString).tmp")
        defer { try? FileManager.default.removeItem(at: destination) }

        XCTAssertThrowsError(
            try PortableArchiveService.writeAndVerify(
                snapshot: snapshot,
                recoveryKey: RecoveryKey.generate(),
                signingKey: Curve25519.Signing.PrivateKey(),
                archiveID: UUID(),
                createdAt: Date(timeIntervalSince1970: 1_704_067_200),
                to: destination
            )
        )
    }

    func testSnapshotEncodesDateColumnsAsSignedUnixMilliseconds() throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("archive-date-codec-\(UUID().uuidString).sqlite")
        defer { removeDatabase(at: databaseURL) }
        let database = try EncryptedDatabase.open(url: databaseURL, key: Data(repeating: 7, count: 32))
        let store = try WorkspaceStore(
            database: database,
            now: Date(timeIntervalSince1970: 1.25),
            actorID: "test",
            correlationID: "test"
        )
        _ = try store.create(CreateOpportunity(title: "Active role", company: "Example"))

        let snapshot = try PortableArchiveSnapshotCodec.encode(from: database)
        let opportunity = try snapshotRows(snapshot, named: "opportunities").first

        XCTAssertEqual(opportunity?.values[3].tag, 1)
        XCTAssertEqual(opportunity?.values[3].integer, 1_250)
    }

    func testSnapshotExcludesOrphanInteractionsAndActivityEvents() throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("archive-active-subjects-\(UUID().uuidString).sqlite")
        defer { removeDatabase(at: databaseURL) }
        let database = try EncryptedDatabase.open(url: databaseURL, key: Data(repeating: 8, count: 32))
        let store = try WorkspaceStore(
            database: database,
            now: Date(timeIntervalSince1970: 2),
            actorID: "test",
            correlationID: "test"
        )
        _ = try store.create(CreateOpportunity(title: "Active role", company: "Example"))
        try database.execute(
            "INSERT INTO interactions (id, contact_id, opportunity_id, kind, summary, occurred_at, next_touch_at) VALUES ('orphan-interaction', NULL, NULL, 'Note', 'orphan', 2, NULL)"
        )
        try database.execute(
            "INSERT INTO activity_events (id, kind, opportunity_id, contact_id, actor_id, correlation_id, occurred_at) VALUES ('orphan-activity', 'orphan', NULL, NULL, 'test', 'test', 2)"
        )

        let snapshot = try PortableArchiveSnapshotCodec.encode(from: database)

        XCTAssertTrue(try snapshotRows(snapshot, named: "interactions").isEmpty)
        XCTAssertEqual(try snapshotRows(snapshot, named: "activity_events").count, 1)
    }

    func testSnapshotExcludesDeletedContentAndStripsDocumentBookmarks() throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("archive-privacy-projection-\(UUID().uuidString).sqlite")
        defer { removeDatabase(at: databaseURL) }
        let database = try EncryptedDatabase.open(url: databaseURL, key: Data(repeating: 6, count: 32))
        let store = try WorkspaceStore(
            database: database,
            now: Date(timeIntervalSince1970: 3),
            actorID: "test",
            correlationID: "test"
        )
        let active = try store.create(CreateOpportunity(title: "Active role", company: "Example"))
        let deleted = try store.create(CreateOpportunity(title: "Deleted confidential role", company: "Example"))
        _ = try store.recordDocumentReference(RecordDocumentReference(
            opportunityID: active.id,
            kind: .resume,
            filename: "resume.pdf",
            contentType: "application/pdf",
            sourceHash: String(repeating: "a", count: 64),
            byteCount: 100,
            bookmarkData: Data("opaque-bookmark-bytes".utf8)
        ))
        try store.deleteOpportunity(id: deleted.id)

        let snapshot = try PortableArchiveSnapshotCodec.encode(from: database)
        let opportunities = try snapshotRows(snapshot, named: "opportunities")
        let document = try XCTUnwrap(try snapshotRows(snapshot, named: "document_references").first)

        XCTAssertEqual(opportunities.count, 1)
        XCTAssertEqual(opportunities.first?.values[0].text, active.id)
        XCTAssertEqual(document.values[7].tag, 0)
        XCTAssertEqual(document.values[7].data, Data())
        XCTAssertEqual(document.values[8].text, "relink_required")
        XCTAssertFalse(snapshot.contains(Data("Deleted confidential role".utf8)))
        XCTAssertFalse(snapshot.contains(Data("opaque-bookmark-bytes".utf8)))
    }

    private func appendText(_ value: String, to data: inout Data) {
        let bytes = Data(value.utf8)
        data.append(3)
        appendUInt32(UInt32(bytes.count), to: &data)
        data.append(bytes)
    }

    private func appendUInt32(_ value: UInt32, to data: inout Data) {
        data.append(contentsOf: withUnsafeBytes(of: value.bigEndian, Array.init))
    }

    private func emptyCanonicalSnapshot() -> Data {
        var snapshot = Data("RPSNAP01".utf8)
        appendUInt32(UInt32(PortableArchiveSnapshotRegistry.tables.count), to: &snapshot)
        for table in PortableArchiveSnapshotRegistry.tables {
            appendText(table.name, to: &snapshot)
            appendUInt32(0, to: &snapshot)
        }
        return snapshot
    }

    private func removeDatabase(at url: URL) {
        for candidate in [url, URL(fileURLWithPath: url.path + "-wal"), URL(fileURLWithPath: url.path + "-shm")] {
            try? FileManager.default.removeItem(at: candidate)
        }
    }

    private func snapshotRows(_ snapshot: Data, named expectedName: String) throws -> [SnapshotRow] {
        var reader = SnapshotReader(snapshot)
        XCTAssertEqual(try reader.data(count: 8), Data("RPSNAP01".utf8))
        let tableCount = try reader.uint32()
        for _ in 0..<tableCount {
            let name = try reader.text()
            let rowCount = try reader.uint32()
            var rows: [SnapshotRow] = []
            for _ in 0..<rowCount {
                let valueCount = try reader.uint32()
                rows.append(SnapshotRow(values: try (0..<valueCount).map { _ in try reader.value() }))
            }
            if name == expectedName { return rows }
        }
        XCTFail("Missing table \(expectedName)")
        return []
    }
}

private struct SnapshotRow {
    let values: [SnapshotValue]
}

private struct SnapshotValue {
    let tag: UInt8
    let integer: Int64?
    let data: Data

    var text: String? {
        guard tag == 3 else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

private struct SnapshotReader {
    private let source: Data
    private var offset = 0

    init(_ source: Data) { self.source = source }

    mutating func data(count: Int) throws -> Data {
        guard count >= 0, offset + count <= source.count else { throw PortableArchiveError.archiveInvalid }
        defer { offset += count }
        return source.subdata(in: offset..<(offset + count))
    }

    mutating func uint32() throws -> UInt32 {
        try data(count: 4).reduce(0) { ($0 << 8) | UInt32($1) }
    }

    mutating func text() throws -> String {
        guard try data(count: 1).first == 3,
              let text = String(data: try data(count: Int(try uint32())), encoding: .utf8) else {
            throw PortableArchiveError.archiveInvalid
        }
        return text
    }

    mutating func value() throws -> SnapshotValue {
        let tag = try data(count: 1).first!
        let bytes = try data(count: Int(try uint32()))
        guard tag <= 4 else { throw PortableArchiveError.archiveInvalid }
        let integer: Int64?
        if tag == 1 {
            guard bytes.count == 8 else { throw PortableArchiveError.archiveInvalid }
            integer = Int64(bitPattern: bytes.reduce(0) { ($0 << 8) | UInt64($1) })
        } else {
            integer = nil
        }
        return SnapshotValue(tag: tag, integer: integer, data: bytes)
    }
}

private actor GatedArchiveSigningKeyStore: ArchiveSigningKeyStoring {
    private let rawKey = Curve25519.Signing.PrivateKey().rawRepresentation
    private(set) var hasStarted = false
    private(set) var hasFinished = false
    private var isReleased = false

    func privateKeyRawRepresentation(
        for workspaceID: String,
        catalogueExists: Bool
    ) async throws -> Data {
        hasStarted = true
        while !isReleased {
            await Task.yield()
        }
        hasFinished = true
        return rawKey
    }

    func release() {
        isReleased = true
    }
}

private actor StaticArchiveSigningKeyStore: ArchiveSigningKeyStoring {
    private let rawKey = Curve25519.Signing.PrivateKey().rawRepresentation

    func privateKeyRawRepresentation(
        for workspaceID: String,
        catalogueExists: Bool
    ) async throws -> Data {
        rawKey
    }
}
