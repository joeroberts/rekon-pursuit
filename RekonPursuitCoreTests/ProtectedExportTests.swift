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
        try store.close()
    }
}
