import Foundation
import SQLCipher

enum EncryptedDatabaseError: Error, LocalizedError {
    case invalidKeyLength
    case sqlite(code: Int32, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidKeyLength:
            return "The workspace key is unavailable."
        case let .sqlite(code, message):
            return "The encrypted workspace could not be opened (SQLite error \(code)): \(message)."
        }
    }
}

nonisolated final class EncryptedDatabase {
    private var handle: OpaquePointer?
    private static let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    private init(handle: OpaquePointer) {
        self.handle = handle
    }

    deinit {
        if let handle {
            sqlite3_close_v2(handle)
        }
    }

    static func open(url: URL, key: Data) throws -> EncryptedDatabase {
        guard key.count == 32 else {
            throw EncryptedDatabaseError.invalidKeyLength
        }

        var handle: OpaquePointer?
        let openResult = sqlite3_open_v2(
            url.path,
            &handle,
            SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX,
            nil
        )
        guard openResult == SQLITE_OK, let handle else {
            throw sqliteError(handle: handle, code: openResult)
        }

        let database = EncryptedDatabase(handle: handle)
        do {
            let keyResult = key.withUnsafeBytes { bytes in
                sqlite3_key(handle, bytes.baseAddress, Int32(bytes.count))
            }
            guard keyResult == SQLITE_OK else {
                throw sqliteError(handle: handle, code: keyResult)
            }
            try database.execute("SELECT count(*) FROM sqlite_master")
            try database.execute("PRAGMA foreign_keys = ON")
            try database.execute("PRAGMA journal_mode = WAL")
            return database
        } catch {
            try? database.close()
            throw error
        }
    }

    func execute(_ sql: String, values: [DatabaseValue] = []) throws {
        guard let handle else {
            throw EncryptedDatabaseError.sqlite(code: SQLITE_MISUSE, message: "Database is closed.")
        }
        var statement: OpaquePointer?
        let prepareResult = sqlite3_prepare_v2(handle, sql, -1, &statement, nil)
        guard prepareResult == SQLITE_OK else {
            throw Self.sqliteError(handle: handle, code: prepareResult)
        }
        defer { sqlite3_finalize(statement) }

        try Self.bind(values, to: statement, handle: handle)

        let stepResult = sqlite3_step(statement)
        guard stepResult == SQLITE_DONE || stepResult == SQLITE_ROW else {
            throw Self.sqliteError(handle: handle, code: stepResult)
        }
    }

    func rows(_ sql: String, values: [DatabaseValue] = []) throws -> [[DatabaseValue]] {
        guard let handle else {
            throw EncryptedDatabaseError.sqlite(code: SQLITE_MISUSE, message: "Database is closed.")
        }
        var statement: OpaquePointer?
        let prepareResult = sqlite3_prepare_v2(handle, sql, -1, &statement, nil)
        guard prepareResult == SQLITE_OK else {
            throw Self.sqliteError(handle: handle, code: prepareResult)
        }
        defer { sqlite3_finalize(statement) }

        try Self.bind(values, to: statement, handle: handle)
        var result: [[DatabaseValue]] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            result.append((0..<sqlite3_column_count(statement)).map { column in
                switch sqlite3_column_type(statement, column) {
                case SQLITE_INTEGER:
                    .integer(sqlite3_column_int64(statement, column))
                case SQLITE_FLOAT:
                    .real(sqlite3_column_double(statement, column))
                case SQLITE_TEXT:
                    .text(String(cString: sqlite3_column_text(statement, column)))
                default:
                    .null
                }
            })
        }
        let resultCode = sqlite3_errcode(handle)
        guard resultCode == SQLITE_OK || resultCode == SQLITE_DONE else {
            throw Self.sqliteError(handle: handle, code: resultCode)
        }
        return result
    }

    func transaction(_ work: () throws -> Void) throws {
        try execute("BEGIN IMMEDIATE")
        do {
            try work()
            try execute("COMMIT")
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
    }

    func scalarInt(_ sql: String) throws -> Int {
        guard let handle else {
            throw EncryptedDatabaseError.sqlite(code: SQLITE_MISUSE, message: "Database is closed.")
        }
        var statement: OpaquePointer?
        let prepareResult = sqlite3_prepare_v2(handle, sql, -1, &statement, nil)
        guard prepareResult == SQLITE_OK else {
            throw Self.sqliteError(handle: handle, code: prepareResult)
        }
        defer { sqlite3_finalize(statement) }

        let stepResult = sqlite3_step(statement)
        guard stepResult == SQLITE_ROW else {
            throw Self.sqliteError(handle: handle, code: stepResult)
        }
        return Int(sqlite3_column_int(statement, 0))
    }

    func close() throws {
        guard let handle else { return }
        let result = sqlite3_close_v2(handle)
        guard result == SQLITE_OK else {
            throw Self.sqliteError(handle: handle, code: result)
        }
        self.handle = nil
    }

    private static func sqliteError(handle: OpaquePointer?, code: Int32) -> EncryptedDatabaseError {
        let message = handle.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "Unknown SQLite error."
        return .sqlite(code: code, message: message)
    }

    private static func bind(_ values: [DatabaseValue], to statement: OpaquePointer?, handle: OpaquePointer) throws {
        for (offset, value) in values.enumerated() {
            let index = Int32(offset + 1)
            let result: Int32
            switch value {
            case .null:
                result = sqlite3_bind_null(statement, index)
            case let .integer(number):
                result = sqlite3_bind_int64(statement, index, number)
            case let .real(number):
                result = sqlite3_bind_double(statement, index, number)
            case let .text(text):
                result = text.withCString { sqlite3_bind_text(statement, index, $0, -1, sqliteTransient) }
            }
            guard result == SQLITE_OK else {
                throw sqliteError(handle: handle, code: result)
            }
        }
    }
}

enum DatabaseValue: Equatable {
    case null
    case integer(Int64)
    case real(Double)
    case text(String)
}
