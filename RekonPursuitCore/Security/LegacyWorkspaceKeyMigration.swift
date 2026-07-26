import Foundation
import Security

nonisolated enum SyntheticMigrationConfigurationError: Error, Equatable {
    case productionService
    case productionAccount
    case defaultBookmarkPreference
    case defaultWorkspaceRoot
    case invalidSyntheticRoot
    case invalidSyntheticNamespace
}

/// This configuration is deliberately explicit and fixture-bound. It is never
/// derived from application preferences, launch arguments, or user selections.
nonisolated struct SyntheticMigrationConfiguration {
    /// The synthetic proof root is a compiled, container-derived sibling of the
    /// production workspace root. Callers cannot nominate an alternate base.
    static let defaultWorkspaceRoot: URL = {
        let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? URL(fileURLWithPath: "/Library/Application Support", isDirectory: true)
        return applicationSupport
            .appendingPathComponent("RekonLabs", isDirectory: true)
            .appendingPathComponent("RekonPursuit", isDirectory: true)
    }()

    static let trustedSyntheticBaseRoot: URL = defaultWorkspaceRoot
        .deletingLastPathComponent()
        .appendingPathComponent(".rekon-pursuit-synthetic-proof", isDirectory: true)

    let service: String
    let account: String
    let bookmarkPreferenceKey: String
    let fixtureRoot: URL
    private let resolveSymlinks: (URL) -> URL

    init(
        service: String,
        account: String,
        bookmarkPreferenceKey: String,
        fixtureRoot: URL,
        resolveSymlinks: @escaping (URL) -> URL = { $0.resolvingSymlinksInPath() }
    ) {
        self.service = service
        self.account = account
        self.bookmarkPreferenceKey = bookmarkPreferenceKey
        self.fixtureRoot = fixtureRoot
        self.resolveSymlinks = resolveSymlinks
    }

    func validate() throws {
        guard service != WorkspaceKeychainConfiguration.service else {
            throw SyntheticMigrationConfigurationError.productionService
        }
        guard account != KeychainWorkspaceKeyStore.primaryAccount else {
            throw SyntheticMigrationConfigurationError.productionAccount
        }
        guard bookmarkPreferenceKey != WorkspaceLocationBookmarkConfiguration.preferenceKey else {
            throw SyntheticMigrationConfigurationError.defaultBookmarkPreference
        }
        let lexicalFixture = fixtureRoot.standardizedFileURL
        let lexicalDefaultRoot = Self.defaultWorkspaceRoot.standardizedFileURL
        let lexicalSyntheticBase = Self.trustedSyntheticBaseRoot.standardizedFileURL
        guard !Self.isContained(lexicalFixture, in: lexicalDefaultRoot),
              !Self.isContained(lexicalSyntheticBase, in: lexicalDefaultRoot) else {
            throw SyntheticMigrationConfigurationError.defaultWorkspaceRoot
        }
        guard lexicalFixture.deletingLastPathComponent() == lexicalSyntheticBase else {
            throw SyntheticMigrationConfigurationError.invalidSyntheticRoot
        }
        let namespace = "com.rekonlabs.RekonPursuit.synthetic."
        guard service.hasPrefix(namespace), account.hasPrefix("synthetic-account-"), bookmarkPreferenceKey.hasPrefix("synthetic-bookmark-") else {
            throw SyntheticMigrationConfigurationError.invalidSyntheticNamespace
        }

        let canonicalBase = resolveSymlinks(Self.trustedSyntheticBaseRoot).standardizedFileURL
        let canonicalFixture = resolveSymlinks(fixtureRoot).standardizedFileURL
        let canonicalDefaultRoot = resolveSymlinks(Self.defaultWorkspaceRoot).standardizedFileURL
        guard !Self.isContained(canonicalBase, in: canonicalDefaultRoot),
              !Self.isContained(canonicalFixture, in: canonicalDefaultRoot),
              canonicalFixture.deletingLastPathComponent() == canonicalBase else {
            throw SyntheticMigrationConfigurationError.invalidSyntheticRoot
        }
    }

    private static func isContained(_ candidate: URL, in root: URL) -> Bool {
        let candidatePath = candidate.standardizedFileURL.path
        let rootPath = root.standardizedFileURL.path
        return candidatePath == rootPath || candidatePath.hasPrefix(rootPath + "/")
    }
}

nonisolated protocol LegacyWorkspaceKeyReading: AnyObject {
    func readLegacyKey(service: String, account: String) throws -> Data?
}

nonisolated protocol DataProtectionWorkspaceKeyAdding: AnyObject {
    func readDataProtectionKey(service: String, account: String) throws -> Data?
    func addDataProtectionKey(_ key: Data, service: String, account: String) throws
}

/// Task 2a can only operate on a fixture that a separate, nonce-sentinel
/// capability has validated. Task 2b supplies the signed helper and concrete
/// proof; this boundary ensures the legacy key is never read before that proof.
nonisolated protocol ValidatedSyntheticNonceFixture: AnyObject {
    func validatedDatabaseURL(for configuration: SyntheticMigrationConfiguration) throws -> URL
}

nonisolated enum LegacyWorkspaceKeyMigrationError: Error, Equatable {
    case sourceMissing
    case invalidKeyLength
    case destinationAlreadyExists
    case targetMismatch
}

/// An add-only state machine for a disposable synthetic fixture. It intentionally
/// has no update, delete, bookmark, or workspace creation capability.
nonisolated final class LegacyWorkspaceKeyMigration {
    private let source: LegacyWorkspaceKeyReading
    private let destination: DataProtectionWorkspaceKeyAdding
    private let fixture: ValidatedSyntheticNonceFixture
    private let verifyReadOnly: (URL, Data) throws -> Void

    init(
        source: LegacyWorkspaceKeyReading,
        destination: DataProtectionWorkspaceKeyAdding,
        fixture: ValidatedSyntheticNonceFixture,
        verifyReadOnly: @escaping (URL, Data) throws -> Void
    ) {
        self.source = source
        self.destination = destination
        self.fixture = fixture
        self.verifyReadOnly = verifyReadOnly
    }

    func migrate(configuration: SyntheticMigrationConfiguration) throws {
        try configuration.validate()
        let databaseURL = try fixture.validatedDatabaseURL(for: configuration)
        guard let sourceKey = try source.readLegacyKey(service: configuration.service, account: configuration.account) else {
            throw LegacyWorkspaceKeyMigrationError.sourceMissing
        }
        guard sourceKey.count == 32 else { throw LegacyWorkspaceKeyMigrationError.invalidKeyLength }
        guard try destination.readDataProtectionKey(service: configuration.service, account: configuration.account) == nil else {
            throw LegacyWorkspaceKeyMigrationError.destinationAlreadyExists
        }

        try verifyReadOnly(databaseURL, sourceKey)
        try destination.addDataProtectionKey(sourceKey, service: configuration.service, account: configuration.account)
        guard let targetKey = try destination.readDataProtectionKey(service: configuration.service, account: configuration.account), targetKey == sourceKey else {
            throw LegacyWorkspaceKeyMigrationError.targetMismatch
        }
        try verifyReadOnly(databaseURL, targetKey)
    }
}

nonisolated final class LegacyKeychainWorkspaceKeySource: LegacyWorkspaceKeyReading {
    func readLegacyKey(service: String, account: String) throws -> Data? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw WorkspaceKeyStoreError.unavailable(status) }
        return data
    }
}

nonisolated final class DataProtectionKeychainWorkspaceKeyDestination: DataProtectionWorkspaceKeyAdding {
    func readDataProtectionKey(service: String, account: String) throws -> Data? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecUseDataProtectionKeychain: true,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw WorkspaceKeyStoreError.unavailable(status) }
        return data
    }

    func addDataProtectionKey(_ key: Data, service: String, account: String) throws {
        let attributes: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecUseDataProtectionKeychain: true,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData: key
        ]
        let status = SecItemAdd(attributes as CFDictionary, nil)
        try Self.validateAddStatus(status)
    }

    static func validateAddStatus(_ status: OSStatus) throws {
        if status == errSecDuplicateItem {
            throw LegacyWorkspaceKeyMigrationError.destinationAlreadyExists
        }
        guard status == errSecSuccess else { throw WorkspaceKeyStoreError.unavailable(status) }
    }
}
