import XCTest
@testable import RekonPursuit

@MainActor
final class ProtectedExportTests: XCTestCase {
    func testProtectedExportUsesDistinctVersionedContainer() {
        XCTAssertEqual(ProtectedExportService.formatVersion, 1)
        XCTAssertEqual(ProtectedExportService.magic, Data("RPEXPT01".utf8))
    }

    func testProtectedExportIsEncryptedAndVerifiableWithRecoveryKey() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("protected-export-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let database = try EncryptedDatabase.open(url: root.appendingPathComponent("workspace.sqlite"), key: Data(repeating: 7, count: 32), createIfMissing: true)
        let store = try WorkspaceStore(database: database, actorID: "test", correlationID: "test")
        let key = try RecoveryKey.generate()
        try store.enroll(recoveryKey: key)
        let destination = root.appendingPathComponent("job-search.rekonexport")

        let review = try await store.reviewProtectedExport(recoveryKey: key, at: destination)
        let receipt = try await store.createProtectedExport(review: review, recoveryKey: key)

        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path))
        XCTAssertEqual(try ProtectedExportService.verify(data: Data(contentsOf: destination), recoveryKey: key), receipt)
        XCTAssertThrowsError(try ProtectedExportService.verify(data: Data(contentsOf: destination), recoveryKey: try RecoveryKey.generate()))
        var tampered = try Data(contentsOf: destination)
        tampered[20] ^= 0x01
        XCTAssertThrowsError(try ProtectedExportService.verify(data: tampered, recoveryKey: key))
        try store.close()
    }

    func testReviewBindsDestinationParentIdentity() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("protected-export-parent-\(UUID().uuidString)")
        let destinationDirectory = root.appendingPathComponent("exports", isDirectory: true)
        try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let database = try EncryptedDatabase.open(url: root.appendingPathComponent("workspace.sqlite"), key: Data(repeating: 8, count: 32), createIfMissing: true)
        let store = try WorkspaceStore(database: database, actorID: "test", correlationID: "test")
        let key = try RecoveryKey.generate()
        try store.enroll(recoveryKey: key)

        let review = try await store.reviewProtectedExport(recoveryKey: key, at: destinationDirectory.appendingPathComponent("bound.rekonexport"))

        XCTAssertNotEqual(review.parentIdentity.device, 0)
        try store.close()
    }

    func testSourceRevisionChangeRejectsReviewedExportWithoutCreatingAFile() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("protected-export-revision-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let database = try EncryptedDatabase.open(url: root.appendingPathComponent("workspace.sqlite"), key: Data(repeating: 9, count: 32), createIfMissing: true)
        let store = try WorkspaceStore(database: database, actorID: "test", correlationID: "test")
        let key = try RecoveryKey.generate()
        try store.enroll(recoveryKey: key)
        let destination = root.appendingPathComponent("changed.rekonexport")
        let review = try await store.reviewProtectedExport(recoveryKey: key, at: destination)
        _ = try store.create(.init(title: "Changed", company: "Example"))

        do {
            _ = try await store.createProtectedExport(review: review, recoveryKey: key)
            XCTFail("Expected the reviewed export to be rejected after source data changed.")
        } catch {
            XCTAssertEqual(error as? ProtectedExportWorkerError, .sourceChanged)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
        try store.close()
    }

    func testExistingTargetIsRejectedWithoutOverwritingIt() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("protected-export-existing-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let database = try EncryptedDatabase.open(url: root.appendingPathComponent("workspace.sqlite"), key: Data(repeating: 10, count: 32), createIfMissing: true)
        let store = try WorkspaceStore(database: database, actorID: "test", correlationID: "test")
        let key = try RecoveryKey.generate()
        try store.enroll(recoveryKey: key)
        let destination = root.appendingPathComponent("existing.rekonexport")
        let original = Data("do not replace".utf8)
        try original.write(to: destination)

        do { _ = try await store.reviewProtectedExport(recoveryKey: key, at: destination); XCTFail("Expected existing target rejection.") }
        catch { XCTAssertEqual(error as? ProtectedExportWorkerError, .destinationExists) }
        XCTAssertEqual(try Data(contentsOf: destination), original)
        try store.close()
    }
}
