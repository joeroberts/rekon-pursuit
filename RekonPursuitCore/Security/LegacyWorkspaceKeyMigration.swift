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
nonisolated struct SyntheticMigrationConfiguration: Equatable {
    let service: String
    let account: String
    let bookmarkPreferenceKey: String
    let fixtureRoot: URL
    let syntheticBaseRoot: URL
    let defaultApplicationSupportRoot: URL

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
        guard fixtureRoot.standardizedFileURL != defaultApplicationSupportRoot.standardizedFileURL else {
            throw SyntheticMigrationConfigurationError.defaultWorkspaceRoot
        }
        let canonicalBase = syntheticBaseRoot.resolvingSymlinksInPath().standardizedFileURL
        let canonicalFixture = fixtureRoot.resolvingSymlinksInPath().standardizedFileURL
        guard canonicalBase != defaultApplicationSupportRoot.resolvingSymlinksInPath().standardizedFileURL,
              canonicalFixture.deletingLastPathComponent() == canonicalBase else {
            throw SyntheticMigrationConfigurationError.invalidSyntheticRoot
        }
        let namespace = "com.rekonlabs.RekonPursuit.synthetic."
        guard service.hasPrefix(namespace), account.hasPrefix("synthetic-account-"), bookmarkPreferenceKey.hasPrefix("synthetic-bookmark-") else {
            throw SyntheticMigrationConfigurationError.invalidSyntheticNamespace
        }
    }
}

nonisolated protocol LegacyWorkspaceKeyReading: AnyObject {
    func readLegacyKey(service: String, account: String) throws -> Data?
}

nonisolated protocol DataProtectionWorkspaceKeyAdding: AnyObject {
    func readDataProtectionKey(service: String, account: String) throws -> Data?
    func addDataProtectionKey(_ key: Data, service: String, account: String) throws
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
    private let verifyReadOnly: (URL, Data) throws -> Void

    init(
        source: LegacyWorkspaceKeyReading,
        destination: DataProtectionWorkspaceKeyAdding,
        verifyReadOnly: @escaping (URL, Data) throws -> Void
    ) {
        self.source = source
        self.destination = destination
        self.verifyReadOnly = verifyReadOnly
    }

    func migrate(configuration: SyntheticMigrationConfiguration) throws {
        try configuration.validate()
        guard let sourceKey = try source.readLegacyKey(service: configuration.service, account: configuration.account) else {
            throw LegacyWorkspaceKeyMigrationError.sourceMissing
        }
        guard sourceKey.count == 32 else { throw LegacyWorkspaceKeyMigrationError.invalidKeyLength }
        guard try destination.readDataProtectionKey(service: configuration.service, account: configuration.account) == nil else {
            throw LegacyWorkspaceKeyMigrationError.destinationAlreadyExists
        }

        let databaseURL = configuration.fixtureRoot.appendingPathComponent("workspace.sqlite", isDirectory: false)
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
        guard status == errSecSuccess else { throw WorkspaceKeyStoreError.unavailable(status) }
    }
}
