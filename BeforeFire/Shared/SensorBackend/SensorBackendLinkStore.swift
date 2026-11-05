import Foundation
import Security

protocol SensorBackendLinkStoring {
    /// Returns `nil` when no complete link is saved.
    func load() -> SensorBackendLink?
    func save(_ link: SensorBackendLink) throws
    func remove() throws
}

nonisolated enum SensorBackendLinkStoreError: Error, Equatable {
    case keychain(OSStatus)
}

/// Keeps the backend address and the sensor serial in `UserDefaults`, and the setup code in the Keychain.
/// The setup code also opens the Bluetooth setup of the sensor, so it must not be in `UserDefaults`.
final class KeychainSensorBackendLinkStore: SensorBackendLinkStoring {
    private enum Key {
        static let backendAddress = "sensorBackend.backendAddress"
        static let deviceID = "sensorBackend.deviceID"
        static let setupCodeService = "BeforeFire.sensorBackend.setupCode"
    }

    private let defaults: UserDefaults
    private let keychainService: String

    init(defaults: UserDefaults = .standard, keychainService: String = Key.setupCodeService) {
        self.defaults = defaults
        self.keychainService = keychainService
    }

    func load() -> SensorBackendLink? {
        guard let backendAddress = defaults.string(forKey: Key.backendAddress),
              let deviceID = defaults.string(forKey: Key.deviceID),
              let setupCode = readSetupCode(deviceID: deviceID)
        else {
            return nil
        }
        // Saved values were valid when they were saved. A failure here means that the format rules changed.
        return try? SensorBackendLink(backendAddress: backendAddress, deviceID: deviceID, setupCode: setupCode)
    }

    func save(_ link: SensorBackendLink) throws {
        // Remove the code of a different sensor, so only one setup code stays on the phone.
        try deleteSetupCodes()
        try writeSetupCode(link.setupCode, deviceID: link.deviceID)
        defaults.set(link.backendAddress, forKey: Key.backendAddress)
        defaults.set(link.deviceID, forKey: Key.deviceID)
    }

    func remove() throws {
        defaults.removeObject(forKey: Key.backendAddress)
        defaults.removeObject(forKey: Key.deviceID)
        try deleteSetupCodes()
    }

    // MARK: Keychain

    private func baseQuery() -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: keychainService]
    }

    private func readSetupCode(deviceID: String) -> String? {
        var query = baseQuery()
        query[kSecAttrAccount as String] = deviceID
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data
        else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private func writeSetupCode(_ setupCode: String, deviceID: String) throws {
        var item = baseQuery()
        item[kSecAttrAccount as String] = deviceID
        item[kSecValueData as String] = Data(setupCode.utf8)
        // The sensor values are not needed while the phone is locked before the first unlock.
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw SensorBackendLinkStoreError.keychain(status)
        }
    }

    private func deleteSetupCodes() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SensorBackendLinkStoreError.keychain(status)
        }
    }
}

/// Keeps the link only in memory. For previews and tests.
final class InMemorySensorBackendLinkStore: SensorBackendLinkStoring {
    private var link: SensorBackendLink?

    init(link: SensorBackendLink? = nil) {
        self.link = link
    }

    func load() -> SensorBackendLink? { link }
    func save(_ link: SensorBackendLink) throws { self.link = link }
    func remove() throws { link = nil }
}
