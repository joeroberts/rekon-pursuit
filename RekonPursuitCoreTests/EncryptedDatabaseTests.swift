import Foundation
import XCTest
@testable import RekonPursuit

final class EncryptedDatabaseTests: XCTestCase {
    private var root: URL!
    private let key = Data(repeating: 0x5A, count: 32)

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("rekon-pursuit-encrypted-db-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: root)
    }

    func testCorrectKeyReopensEncryptedDatabase() throws {
        let url = root.appendingPathComponent("workspace.sqlite")
        let database = try EncryptedDatabase.open(url: url, key: key)
        try database.execute("CREATE TABLE records (value TEXT NOT NULL)")
        try database.execute("INSERT INTO records (value) VALUES ('local')")
        try database.close()

        let reopened = try EncryptedDatabase.open(url: url, key: key)
        XCTAssertEqual(try reopened.scalarInt("SELECT COUNT(*) FROM records"), 1)
        try reopened.close()
    }

    func testWrongKeyCannotOpenEncryptedDatabase() throws {
        let url = try createClosedDatabase()

        XCTAssertThrowsError(try EncryptedDatabase.open(url: url, key: Data(repeating: 0xA5, count: 32)))
    }

    func testStockSQLiteCannotReadClosedEncryptedDatabase() throws {
        let url = try createClosedDatabase()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = [url.path, "SELECT name FROM sqlite_master;"]
        let error = Pipe()
        process.standardError = error

        try process.run()
        process.waitUntilExit()

        XCTAssertNotEqual(process.terminationStatus, 0, String(data: error.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "")
    }

    private func createClosedDatabase() throws -> URL {
        let url = root.appendingPathComponent("workspace.sqlite")
        let database = try EncryptedDatabase.open(url: url, key: key)
        try database.execute("CREATE TABLE records (value TEXT NOT NULL)")
        try database.close()
        return url
    }
}
