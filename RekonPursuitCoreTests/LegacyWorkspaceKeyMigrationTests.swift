import Foundation
import SQLCipher
import XCTest
@testable import RekonPursuit

final class LegacyWorkspaceKeyMigrationTests: XCTestCase {
    private var root: URL!
    private let key = Data(repeating: 0x5A, count: 32)

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("rekon-pursuit-synthetic-migration-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: root)
    }

    func testReadOnlyVerifierUsesImmutableEncodedURIAndOneSchemaRead() throws {
        let databaseURL = root.appendingPathComponent("fixture ? # %.sqlite")
        let calls = SQLiteCallCapture()
        let verifier = ReadOnlySQLCipherVerifier(driver: calls.driver)

        try verifier.verify(url: databaseURL, key: key)

        XCTAssertEqual(calls.openFlags, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX | SQLITE_OPEN_URI | SQLITE_OPEN_NOFOLLOW)
        let allowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "?#%"))
        let encodedPath = databaseURL.standardizedFileURL.path.addingPercentEncoding(withAllowedCharacters: allowed)!
        XCTAssertEqual(calls.openURI, "file://\(encodedPath)?mode=ro&immutable=1")
        XCTAssertEqual(calls.keyByteCounts, [32])
        XCTAssertEqual(calls.preparedSQL, ["SELECT count(*) FROM sqlite_master"])
        XCTAssertEqual(calls.stepResults, [SQLITE_ROW])
        XCTAssertEqual(calls.finalizeCount, 1)
        XCTAssertEqual(calls.closeCount, 1)
    }

    func testReadOnlyVerifierRejectsWrongKeyAndLeavesFixtureManifestUnchanged() throws {
        let databaseURL = try makeEncryptedFixture()
        let before = try WorkspaceArtifactManifest.capture(for: databaseURL)

        XCTAssertThrowsError(try EncryptedDatabase.verifyReadOnly(url: databaseURL, key: Data(repeating: 0xA5, count: 32)))

        XCTAssertEqual(try WorkspaceArtifactManifest.capture(for: databaseURL), before)
    }

    func testReadOnlyVerifierAcceptsValidKeyAndLeavesFixtureManifestUnchanged() throws {
        let databaseURL = try makeEncryptedFixture()
        let before = try WorkspaceArtifactManifest.capture(for: databaseURL)

        XCTAssertNoThrow(try EncryptedDatabase.verifyReadOnly(url: databaseURL, key: key))

        XCTAssertEqual(try WorkspaceArtifactManifest.capture(for: databaseURL), before)
    }

    func testReadOnlyVerifierRejectsMissingFixture() throws {
        let missingURL = root.appendingPathComponent("missing.sqlite")

        XCTAssertThrowsError(try EncryptedDatabase.verifyReadOnly(url: missingURL, key: key))
    }

    func testReadOnlyVerifierPreservesOpenFailureAfterManifestComparison() throws {
        let databaseURL = try makeEncryptedFixture()
        let verifier = ReadOnlySQLCipherVerifier(driver: .init(
            open: { _, _ in .init(status: SQLITE_CANTOPEN, handle: nil) },
            key: { _, _ in XCTFail("must not key"); return SQLITE_ERROR },
            prepare: { _, _ in XCTFail("must not prepare"); return nil },
            step: { _ in XCTFail("must not step"); return SQLITE_ERROR },
            finalize: { _ in XCTFail("must not finalize"); return SQLITE_ERROR },
            close: { _ in XCTFail("must not close"); return SQLITE_ERROR },
            errorMessage: { _ in "unused" }
        ))

        XCTAssertThrowsError(try verifier.verify(url: databaseURL, key: key)) { error in
            XCTAssertEqual(error as? ReadOnlySQLCipherVerifierError, .openFailed)
        }
    }

    func testReadOnlyVerifierReportsArtifactChangeWhenOpenFailureMutatesFixture() throws {
        let databaseURL = try makeEncryptedFixture()
        let verifier = ReadOnlySQLCipherVerifier(driver: .init(
            open: { _, _ in
                let original = try! Data(contentsOf: databaseURL)
                try! (original + Data([0x00])).write(to: databaseURL, options: .atomic)
                return .init(status: SQLITE_CANTOPEN, handle: nil)
            },
            key: { _, _ in XCTFail("must not key"); return SQLITE_ERROR },
            prepare: { _, _ in XCTFail("must not prepare"); return nil },
            step: { _ in XCTFail("must not step"); return SQLITE_ERROR },
            finalize: { _ in XCTFail("must not finalize"); return SQLITE_ERROR },
            close: { _ in XCTFail("must not close"); return SQLITE_ERROR },
            errorMessage: { _ in "unused" }
        ))

        XCTAssertThrowsError(try verifier.verify(url: databaseURL, key: key)) { error in
            XCTAssertEqual(error as? ReadOnlySQLCipherVerifierError, .artifactChanged)
        }
    }

    func testReadOnlyVerifierClosesHandleReturnedFromFailedOpen() throws {
        let databaseURL = try makeEncryptedFixture()
        var closeCount = 0
        let verifier = ReadOnlySQLCipherVerifier(driver: .init(
            open: { _, _ in .init(status: SQLITE_CANTOPEN, handle: OpaquePointer(bitPattern: 11)!) },
            key: { _, _ in XCTFail("must not key"); return SQLITE_ERROR },
            prepare: { _, _ in XCTFail("must not prepare"); return nil },
            step: { _ in XCTFail("must not step"); return SQLITE_ERROR },
            finalize: { _ in XCTFail("must not finalize"); return SQLITE_ERROR },
            close: { _ in closeCount += 1; return SQLITE_OK },
            errorMessage: { _ in "unused" }
        ))

        XCTAssertThrowsError(try verifier.verify(url: databaseURL, key: key)) { error in
            XCTAssertEqual(error as? ReadOnlySQLCipherVerifierError, .openFailed)
        }
        XCTAssertEqual(closeCount, 1)
    }

    func testReadOnlyVerifierPreservesKeyFailureAfterManifestComparison() throws {
        let databaseURL = try makeEncryptedFixture()
        let verifier = ReadOnlySQLCipherVerifier(driver: .init(
            open: { _, _ in .init(status: SQLITE_OK, handle: OpaquePointer(bitPattern: 12)!) },
            key: { _, _ in SQLITE_NOTADB },
            prepare: { _, _ in XCTFail("must not prepare"); return nil },
            step: { _ in XCTFail("must not step"); return SQLITE_ERROR },
            finalize: { _ in XCTFail("must not finalize"); return SQLITE_ERROR },
            close: { _ in SQLITE_OK },
            errorMessage: { _ in "unused" }
        ))

        XCTAssertThrowsError(try verifier.verify(url: databaseURL, key: key)) { error in
            XCTAssertEqual(error as? ReadOnlySQLCipherVerifierError, .keyFailed)
        }
    }

    func testReadOnlyVerifierPreservesSchemaReadFailureAfterManifestComparison() throws {
        let databaseURL = try makeEncryptedFixture()
        let verifier = ReadOnlySQLCipherVerifier(driver: .init(
            open: { _, _ in .init(status: SQLITE_OK, handle: OpaquePointer(bitPattern: 13)!) },
            key: { _, _ in SQLITE_OK },
            prepare: { _, _ in OpaquePointer(bitPattern: 14)! },
            step: { _ in SQLITE_ERROR },
            finalize: { _ in SQLITE_OK },
            close: { _ in SQLITE_OK },
            errorMessage: { _ in "unused" }
        ))

        XCTAssertThrowsError(try verifier.verify(url: databaseURL, key: key)) { error in
            XCTAssertEqual(error as? ReadOnlySQLCipherVerifierError, .schemaReadFailed)
        }
    }

    func testReadOnlyVerifierRejectsSymlinkWithoutChangingFixture() throws {
        let databaseURL = try makeEncryptedFixture()
        let aliasURL = root.appendingPathComponent("workspace-alias.sqlite")
        try FileManager.default.createSymbolicLink(at: aliasURL, withDestinationURL: databaseURL)
        let before = try WorkspaceArtifactManifest.capture(for: databaseURL)

        XCTAssertThrowsError(try EncryptedDatabase.verifyReadOnly(url: aliasURL, key: key))

        XCTAssertEqual(try WorkspaceArtifactManifest.capture(for: databaseURL), before)
    }

    func testSyntheticConfigurationRejectsProductionValuesBeforeAnyAdapterCall() throws {
        let source = CountingLegacySource()
        let destination = CountingDestination()
        let configuration = SyntheticMigrationConfiguration(
            service: WorkspaceKeychainConfiguration.service,
            account: "synthetic-account",
            bookmarkPreferenceKey: "synthetic-bookmark",
            fixtureRoot: syntheticFixtureRoot()
        )
        let migration = LegacyWorkspaceKeyMigration(
            source: source,
            destination: destination,
            fixture: staticFixture(),
            verifyReadOnly: { _, _ in }
        )

        XCTAssertThrowsError(try migration.migrate(configuration: configuration))
        XCTAssertEqual(source.readCount, 0)
        XCTAssertEqual(destination.operationCount, 0)
    }

    func testSyntheticConfigurationRejectsEveryProductionOrDefaultInputBeforeAdapterCall() throws {
        let configurations = [
            SyntheticMigrationConfiguration(
                service: "com.rekonlabs.RekonPursuit.synthetic.\(UUID().uuidString)",
                account: KeychainWorkspaceKeyStore.primaryAccount,
                bookmarkPreferenceKey: "synthetic-bookmark-\(UUID().uuidString)",
                fixtureRoot: syntheticFixtureRoot()
            ),
            SyntheticMigrationConfiguration(
                service: "com.rekonlabs.RekonPursuit.synthetic.\(UUID().uuidString)",
                account: "synthetic-account-\(UUID().uuidString)",
                bookmarkPreferenceKey: WorkspaceLocationBookmarkConfiguration.preferenceKey,
                fixtureRoot: syntheticFixtureRoot()
            ),
            SyntheticMigrationConfiguration(
                service: "com.rekonlabs.RekonPursuit.synthetic.\(UUID().uuidString)",
                account: "synthetic-account-\(UUID().uuidString)",
                bookmarkPreferenceKey: "synthetic-bookmark-\(UUID().uuidString)",
                fixtureRoot: SyntheticMigrationConfiguration.defaultWorkspaceRoot
            )
        ]

        for configuration in configurations {
            let source = CountingLegacySource()
            let destination = CountingDestination()
            let migration = LegacyWorkspaceKeyMigration(source: source, destination: destination, fixture: staticFixture(), verifyReadOnly: { _, _ in })

            XCTAssertThrowsError(try migration.migrate(configuration: configuration))
            XCTAssertEqual(source.readCount, 0)
            XCTAssertEqual(destination.operationCount, 0)
        }
    }

    func testSyntheticConfigurationRejectsUnsafeLexicalPathsBeforeResolverAccess() throws {
        var resolverCalls = 0
        let configuration = SyntheticMigrationConfiguration(
            service: "com.rekonlabs.RekonPursuit.synthetic.\(UUID().uuidString)",
            account: "synthetic-account-\(UUID().uuidString)",
            bookmarkPreferenceKey: "synthetic-bookmark-\(UUID().uuidString)",
            fixtureRoot: SyntheticMigrationConfiguration.defaultWorkspaceRoot.appendingPathComponent("fixture"),
            resolveSymlinks: {
                resolverCalls += 1
                return $0
            }
        )

        XCTAssertThrowsError(try configuration.validate()) { error in
            XCTAssertEqual(error as? SyntheticMigrationConfigurationError, .defaultWorkspaceRoot)
        }
        XCTAssertEqual(resolverCalls, 0)
    }

    func testSyntheticConfigurationRejectsFixtureOutsideBaseBeforeResolverAccess() throws {
        var resolverCalls = 0
        let configuration = SyntheticMigrationConfiguration(
            service: "com.rekonlabs.RekonPursuit.synthetic.\(UUID().uuidString)",
            account: "synthetic-account-\(UUID().uuidString)",
            bookmarkPreferenceKey: "synthetic-bookmark-\(UUID().uuidString)",
            fixtureRoot: URL(fileURLWithPath: "/synthetic-other/fixture"),
            resolveSymlinks: {
                resolverCalls += 1
                return $0
            }
        )

        XCTAssertThrowsError(try configuration.validate()) { error in
            XCTAssertEqual(error as? SyntheticMigrationConfigurationError, .invalidSyntheticRoot)
        }
        XCTAssertEqual(resolverCalls, 0)
    }

    func testMigrationAddsDataProtectionKeyWithoutUpdatingOrDeletingSource() throws {
        let source = CountingLegacySource(key: key)
        let destination = CountingDestination()
        let configuration = syntheticConfiguration()
        var verificationKeys: [Data] = []
        let migration = LegacyWorkspaceKeyMigration(
            source: source,
            destination: destination,
            fixture: staticFixture(),
            verifyReadOnly: { _, candidate in verificationKeys.append(candidate) }
        )

        try migration.migrate(configuration: configuration)

        XCTAssertEqual(source.readCount, 1)
        XCTAssertEqual(destination.addedKeys, [key])
        XCTAssertEqual(destination.readCount, 2)
        XCTAssertEqual(verificationKeys, [key, key])
        XCTAssertEqual(destination.updateCount, 0)
        XCTAssertEqual(destination.deleteCount, 0)
    }

    func testMigrationDestinationConflictDoesNotVerifyOrMutate() throws {
        let source = CountingLegacySource(key: key)
        let destination = CountingDestination(existing: key)
        let migration = LegacyWorkspaceKeyMigration(source: source, destination: destination, fixture: staticFixture(), verifyReadOnly: { _, _ in XCTFail("must not verify") })

        XCTAssertThrowsError(try migration.migrate(configuration: syntheticConfiguration())) { error in
            XCTAssertEqual(error as? LegacyWorkspaceKeyMigrationError, .destinationAlreadyExists)
        }
        XCTAssertEqual(destination.addedKeys, [])
        XCTAssertEqual(destination.updateCount, 0)
        XCTAssertEqual(destination.deleteCount, 0)
    }

    func testMigrationMissingSourceDoesNotCallDestination() throws {
        let source = CountingLegacySource()
        let destination = CountingDestination()
        let migration = LegacyWorkspaceKeyMigration(source: source, destination: destination, fixture: staticFixture(), verifyReadOnly: { _, _ in XCTFail("must not verify") })

        XCTAssertThrowsError(try migration.migrate(configuration: syntheticConfiguration())) { error in
            XCTAssertEqual(error as? LegacyWorkspaceKeyMigrationError, .sourceMissing)
        }
        XCTAssertEqual(destination.operationCount, 0)
    }

    func testMigrationFixtureValidationFailureDoesNotReadLegacyKey() throws {
        let source = CountingLegacySource(key: key)
        let destination = CountingDestination()
        let migration = LegacyWorkspaceKeyMigration(
            source: source,
            destination: destination,
            fixture: FailingNonceFixture(),
            verifyReadOnly: { _, _ in XCTFail("must not verify") }
        )

        XCTAssertThrowsError(try migration.migrate(configuration: syntheticConfiguration()))
        XCTAssertEqual(source.readCount, 0)
        XCTAssertEqual(destination.operationCount, 0)
    }

    func testDataProtectionAddMapsDuplicateToTerminalDestinationConflict() throws {
        XCTAssertThrowsError(
            try DataProtectionKeychainWorkspaceKeyDestination.validateAddStatus(errSecDuplicateItem)
        ) { error in
            XCTAssertEqual(error as? LegacyWorkspaceKeyMigrationError, .destinationAlreadyExists)
        }
    }

    func testMigrationSourceVerificationFailureDoesNotAddDestination() throws {
        let source = CountingLegacySource(key: key)
        let destination = CountingDestination()
        let migration = LegacyWorkspaceKeyMigration(source: source, destination: destination, fixture: staticFixture(), verifyReadOnly: { _, _ in throw SyntheticTestError.sourceMismatch })

        XCTAssertThrowsError(try migration.migrate(configuration: syntheticConfiguration()))
        XCTAssertEqual(destination.addedKeys, [])
        XCTAssertEqual(destination.updateCount, 0)
        XCTAssertEqual(destination.deleteCount, 0)
    }

    func testMigrationDestinationAddFailureDoesNotUpdateOrDeleteEitherKey() throws {
        let source = CountingLegacySource(key: key)
        let destination = CountingDestination(addError: SyntheticTestError.destinationAddFailed)
        let migration = LegacyWorkspaceKeyMigration(source: source, destination: destination, fixture: staticFixture(), verifyReadOnly: { _, _ in })

        XCTAssertThrowsError(try migration.migrate(configuration: syntheticConfiguration()))
        XCTAssertEqual(source.key, key)
        XCTAssertNil(destination.current)
        XCTAssertEqual(destination.updateCount, 0)
        XCTAssertEqual(destination.deleteCount, 0)
    }

    func testMigrationReverificationFailureRetainsBothKeysWithoutRollback() throws {
        let source = CountingLegacySource(key: key)
        let destination = CountingDestination()
        var verificationCalls = 0
        let migration = LegacyWorkspaceKeyMigration(
            source: source,
            destination: destination,
            fixture: staticFixture(),
            verifyReadOnly: { _, _ in
                verificationCalls += 1
                if verificationCalls == 2 { throw SyntheticTestError.reverificationFailed }
            }
        )

        XCTAssertThrowsError(try migration.migrate(configuration: syntheticConfiguration()))
        XCTAssertEqual(source.key, key)
        XCTAssertEqual(destination.current, key)
        XCTAssertEqual(destination.updateCount, 0)
        XCTAssertEqual(destination.deleteCount, 0)
    }

    private func makeEncryptedFixture() throws -> URL {
        let databaseURL = root.appendingPathComponent("workspace.sqlite")
        let database = try EncryptedDatabase.open(url: databaseURL, key: key)
        try database.execute("CREATE TABLE records (value TEXT NOT NULL)")
        try database.close()
        return databaseURL
    }

    private func syntheticConfiguration() -> SyntheticMigrationConfiguration {
        SyntheticMigrationConfiguration(
            service: "com.rekonlabs.RekonPursuit.synthetic.\(UUID().uuidString)",
            account: "synthetic-account-\(UUID().uuidString)",
            bookmarkPreferenceKey: "synthetic-bookmark-\(UUID().uuidString)",
            fixtureRoot: syntheticFixtureRoot()
        )
    }

    private func syntheticFixtureRoot() -> URL {
        SyntheticMigrationConfiguration.trustedSyntheticBaseRoot
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    private func staticFixture() -> StaticNonceFixture {
        StaticNonceFixture()
    }
}

private enum SyntheticTestError: Error {
    case reverificationFailed
    case sourceMismatch
    case destinationAddFailed
}

private final class SQLiteCallCapture {
    private(set) var openURI: String?
    private(set) var openFlags: Int32?
    private(set) var keyByteCounts: [Int] = []
    private(set) var preparedSQL: [String] = []
    private(set) var stepResults: [Int32] = []
    private(set) var finalizeCount = 0
    private(set) var closeCount = 0

    var driver: ReadOnlySQLiteDriver {
        ReadOnlySQLiteDriver(
            open: { [weak self] uri, flags in
                self?.openURI = uri
                self?.openFlags = flags
                return .init(status: SQLITE_OK, handle: OpaquePointer(bitPattern: 1)!)
            },
            key: { [weak self] _, data in
                self?.keyByteCounts.append(data.count)
                return SQLITE_OK
            },
            prepare: { [weak self] _, sql in
                self?.preparedSQL.append(sql)
                return OpaquePointer(bitPattern: 2)!
            },
            step: { [weak self] _ in
                self?.stepResults.append(SQLITE_ROW)
                return SQLITE_ROW
            },
            finalize: { [weak self] _ in
                self?.finalizeCount += 1
                return SQLITE_OK
            },
            close: { [weak self] _ in
                self?.closeCount += 1
                return SQLITE_OK
            },
            errorMessage: { _ in "captured SQLite error" }
        )
    }
}

private final class CountingLegacySource: LegacyWorkspaceKeyReading {
    var key: Data?
    private(set) var readCount = 0

    init(key: Data? = nil) { self.key = key }

    func readLegacyKey(service: String, account: String) throws -> Data? {
        readCount += 1
        return key
    }
}

private final class CountingDestination: DataProtectionWorkspaceKeyAdding {
    var current: Data?
    var addError: Error?
    private(set) var readCount = 0
    private(set) var addedKeys: [Data] = []
    private(set) var updateCount = 0
    private(set) var deleteCount = 0

    init(existing: Data? = nil, addError: Error? = nil) {
        current = existing
        self.addError = addError
    }

    var operationCount: Int { readCount + addedKeys.count + updateCount + deleteCount }

    func readDataProtectionKey(service: String, account: String) throws -> Data? {
        readCount += 1
        return current
    }

    func addDataProtectionKey(_ key: Data, service: String, account: String) throws {
        if let addError { throw addError }
        addedKeys.append(key)
        current = key
    }
}

private final class StaticNonceFixture: ValidatedSyntheticNonceFixture {
    func validatedDatabaseURL(for configuration: SyntheticMigrationConfiguration) throws -> URL {
        configuration.fixtureRoot.appendingPathComponent("workspace.sqlite", isDirectory: false)
    }
}

private final class FailingNonceFixture: ValidatedSyntheticNonceFixture {
    func validatedDatabaseURL(for configuration: SyntheticMigrationConfiguration) throws -> URL {
        throw SyntheticTestError.sourceMismatch
    }
}
