import Foundation

protocol SensorBackendLinkStoring {
    /// Returns `nil` when no complete link is saved.
    func load() -> SensorBackendLink?
    func save(_ link: SensorBackendLink) throws
    func remove() throws
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
    private let setupCodes: KeychainPasswordStore

    init(defaults: UserDefaults = .standard, keychainService: String = Key.setupCodeService) {
        self.defaults = defaults
        self.setupCodes = KeychainPasswordStore(service: keychainService)
    }

    func load() -> SensorBackendLink? {
        guard let backendAddress = defaults.string(forKey: Key.backendAddress),
              let deviceID = defaults.string(forKey: Key.deviceID),
              let setupCode = setupCodes.read(account: deviceID)
        else {
            return nil
        }
        // Saved values were valid when they were saved. A failure here means that the format rules changed.
        return try? SensorBackendLink(backendAddress: backendAddress, deviceID: deviceID, setupCode: setupCode)
    }

    func save(_ link: SensorBackendLink) throws {
        // Remove the code of a different sensor, so only one linked sensor stays on the phone.
        try setupCodes.deleteAll()
        try setupCodes.write(link.setupCode, account: link.deviceID)
        defaults.set(link.backendAddress, forKey: Key.backendAddress)
        defaults.set(link.deviceID, forKey: Key.deviceID)
    }

    func remove() throws {
        try setupCodes.deleteAll()
        defaults.removeObject(forKey: Key.backendAddress)
        defaults.removeObject(forKey: Key.deviceID)
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
