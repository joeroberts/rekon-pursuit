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
