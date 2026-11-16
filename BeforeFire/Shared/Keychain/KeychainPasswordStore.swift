import Foundation
import Security

nonisolated enum KeychainPasswordStoreError: Error, Equatable {
    case keychain(OSStatus)
}

/// Reads and writes the generic passwords of one Keychain service. Each value has an account name.
struct KeychainPasswordStore {
    let service: String

    func read(account: String) -> String? {
        try? readValue(account: account)
    }

    func readValue(account: String) throws -> String? {
        var query = baseQuery()
        query[kSecAttrAccount as String] = account
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw KeychainPasswordStoreError.keychain(status)
        }
        return String(data: data, encoding: .utf8)
    }

    /// Replaces the value of the account.
    func write(_ value: String, account: String) throws {
        var item = baseQuery()
        item[kSecAttrAccount as String] = account
        let data = Data(value.utf8)
        let attributes = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(item as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else {
            throw KeychainPasswordStoreError.keychain(updateStatus)
        }
        item[kSecValueData as String] = data
        // The values are not necessary while the phone is locked before the first unlock.
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainPasswordStoreError.keychain(status)
        }
    }

    func delete(account: String) throws {
        var query = baseQuery()
        query[kSecAttrAccount as String] = account
        try delete(matching: query)
    }

    /// Deletes all values of the service.
    func deleteAll() throws {
        try delete(matching: baseQuery())
    }

    private func baseQuery() -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service]
    }

    private func delete(matching query: [String: Any]) throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainPasswordStoreError.keychain(status)
        }
    }
}
