import Foundation

/// Keeps the setup code (PoP) of each unit that joined Wi-Fi, so the user does not type it again when the unit
/// loses Wi-Fi and needs a new Wi-Fi network.
protocol DeviceSetupCodeStoring {
    func setupCode(for deviceName: String) -> DeviceSetupCode?
    func saveSetupCode(_ setupCode: DeviceSetupCode, for deviceName: String) throws
    func removeSetupCode(for deviceName: String) throws
}

/// The setup code also opens the secure Bluetooth session of the unit, so it stays in the Keychain.
struct KeychainDeviceSetupCodeStore: DeviceSetupCodeStoring {
    static let defaultService = "BeforeFire.deviceSetupCode"

    private let keychain: KeychainPasswordStore

    init(service: String = Self.defaultService) {
        keychain = KeychainPasswordStore(service: service)
    }

    func setupCode(for deviceName: String) -> DeviceSetupCode? {
        keychain.read(account: deviceName).flatMap { try? DeviceSetupCode($0) }
    }

    func saveSetupCode(_ setupCode: DeviceSetupCode, for deviceName: String) throws {
        try keychain.write(setupCode.value, account: deviceName)
    }

    func removeSetupCode(for deviceName: String) throws {
        try keychain.delete(account: deviceName)
    }
}
