import CryptoKit
import Foundation
import Security

protocol ArchiveSigningKeyStoring: Actor {
    func privateKeyRawRepresentation(for workspaceID: String, catalogueExists: Bool) async throws -> Data
}

actor ArchiveSigningKeyStore: ArchiveSigningKeyStoring {
    private let service = "com.rekonlabs.RekonPursuit.portable-archive-signing.v1"

    func privateKeyRawRepresentation(for workspaceID: String, catalogueExists: Bool) async throws -> Data {
        let account = Self.account(for: workspaceID)
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
        if status == errSecSuccess, let data = result as? Data, let key = try? Curve25519.Signing.PrivateKey(rawRepresentation: data) {
            return key.rawRepresentation
        }
        guard status == errSecItemNotFound, !catalogueExists else { throw PortableArchiveError.signingKeyUnavailable }
        let key = Curve25519.Signing.PrivateKey()
        let add: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecValueData: key.rawRepresentation,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecUseDataProtectionKeychain: true
        ]
        guard SecItemAdd(add as CFDictionary, nil) == errSecSuccess else { throw PortableArchiveError.signingKeyUnavailable }
        return key.rawRepresentation
    }

    static func account(for workspaceID: String) -> String {
        let domain = Data("RekonPursuit/portable-archive/signing-account/v1\0".utf8)
        return SHA256.hash(data: domain + Data(workspaceID.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

actor InMemoryArchiveSigningKeyStore: ArchiveSigningKeyStoring {
    private var keys: [String: Curve25519.Signing.PrivateKey] = [:]
    func privateKeyRawRepresentation(for workspaceID: String, catalogueExists: Bool) async throws -> Data {
        if let key = keys[workspaceID] { return key.rawRepresentation }
        guard !catalogueExists else { throw PortableArchiveError.signingKeyUnavailable }
        let key = Curve25519.Signing.PrivateKey()
        keys[workspaceID] = key
        return key.rawRepresentation
    }
}
