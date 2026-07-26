import Foundation
import Security

protocol WorkspaceKeyStore: AnyObject {
    func readWorkspaceKey() throws -> Data?
    func writeWorkspaceKey(_ key: Data) throws
    func deleteWorkspaceKey() throws
    func readPendingWorkspaceKey() throws -> Data?
    func writePendingWorkspaceKey(_ key: Data) throws
    func promotePendingWorkspaceKey() throws
    func deletePendingWorkspaceKey() throws
}

/// This namespace is compiled with the application. It is deliberately not read
/// from preferences, arguments, or environment variables, which prevents a
/// launch configuration from redirecting production key material.
nonisolated enum WorkspaceKeychainConfiguration {
    static let service: String = {
        let productionBundleID = "com.rekonlabs.RekonPursuit"
        let compiledBundleID = Bundle.main.bundleIdentifier ?? productionBundleID
        return "\(compiledBundleID).workspace"
    }()
}

enum WorkspaceKeyStoreError: Error {
    case locked
    case denied
    case unavailable(OSStatus)
}

nonisolated final class KeychainWorkspaceKeyStore: WorkspaceKeyStore {
    private let service = WorkspaceKeychainConfiguration.service
    static let primaryAccount = "primary-workspace-key"
    private let account = KeychainWorkspaceKeyStore.primaryAccount
    private let pendingAccount = "pending-workspace-key"

    func readWorkspaceKey() throws -> Data? {
        try readKey(account: account)
    }

    func readPendingWorkspaceKey() throws -> Data? {
        try readKey(account: pendingAccount)
    }

    func writeWorkspaceKey(_ key: Data) throws {
        try writeKey(key, account: account)
    }

    func writePendingWorkspaceKey(_ key: Data) throws {
        try writeKey(key, account: pendingAccount)
    }

    func promotePendingWorkspaceKey() throws {
        guard let key = try readPendingWorkspaceKey() else { throw WorkspaceKeyStoreError.unavailable(errSecItemNotFound) }
        try writeWorkspaceKey(key)
        try? deletePendingWorkspaceKey()
    }

    func deleteWorkspaceKey() throws {
        try deleteKey(account: account)
    }

    func deletePendingWorkspaceKey() throws {
        try deleteKey(account: pendingAccount)
    }

    private func readKey(account: String) throws -> Data? {
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
        guard status == errSecSuccess, let data = result as? Data else { throw map(status) }
        return data
    }

    private func writeKey(_ key: Data, account: String) throws {
        let attributes: [CFString: Any] = [
            kSecValueData: key,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecUseDataProtectionKeychain: true
        ]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var add = query
            attributes.forEach { add[$0.key] = $0.value }
            let addStatus = SecItemAdd(add as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw map(addStatus) }
        } else if updateStatus != errSecSuccess {
            throw map(updateStatus)
        }
    }

    private func deleteKey(account: String) throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecUseDataProtectionKeychain: true
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw map(status) }
    }

    private func map(_ status: OSStatus) -> WorkspaceKeyStoreError {
        switch status {
        case errSecInteractionNotAllowed: .locked
        case errSecAuthFailed: .denied
        default: .unavailable(status)
        }
    }
}
