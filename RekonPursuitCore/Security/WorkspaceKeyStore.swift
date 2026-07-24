import Foundation
import Security

protocol WorkspaceKeyStore: AnyObject {
    func readWorkspaceKey() throws -> Data?
    func writeWorkspaceKey(_ key: Data) throws
}

enum WorkspaceKeyStoreError: Error {
    case locked
    case denied
    case unavailable(OSStatus)
}

final class KeychainWorkspaceKeyStore: WorkspaceKeyStore {
    private let service = "com.rekonlabs.RekonPursuit.workspace"
    private let account = "primary-workspace-key"

    func readWorkspaceKey() throws -> Data? {
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
        guard status == errSecSuccess, let data = result as? Data else { throw map(status) }
        return data
    }

    func writeWorkspaceKey(_ key: Data) throws {
        let attributes: [CFString: Any] = [
            kSecValueData: key,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
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

    private func map(_ status: OSStatus) -> WorkspaceKeyStoreError {
        switch status {
        case errSecInteractionNotAllowed: .locked
        case errSecAuthFailed: .denied
        default: .unavailable(status)
        }
    }
}
