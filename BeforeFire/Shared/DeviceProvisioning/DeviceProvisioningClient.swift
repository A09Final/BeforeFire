import Foundation

nonisolated enum DeviceProvisioningError: Error, Equatable {
    case bluetoothPoweredOff
    case bluetoothUnauthorized
    case bluetoothUnsupported
    case bluetoothUnavailable
    case deviceNotFound
    case deviceConnectionFailed
    /// The secure session failed. A wrong setup code (PoP) is the usual cause.
    case setupCodeRejected
    case wiFiScanUnavailable
    case wiFiPasswordRejected
    case wiFiNetworkNotFound
    /// The firmware reports `ARDUINO_EVENT_PROV_CRED_FAIL` for another reason.
    case deviceCouldNotJoinWiFi
}

protocol DeviceScanning {
    /// Yields each matching unit one time. Cancel the iterating task to stop the scan.
    func discoverDevices() -> AsyncThrowingStream<DiscoveredDevice, Error>
}

protocol DeviceProvisioningConnecting {
    /// Opens a secure Bluetooth session with the unit. The setup code must match the code that the unit shows.
    func connect(to device: DiscoveredDevice, setupCode: DeviceSetupCode) async throws -> any DeviceProvisioningSession
}

protocol DeviceProvisioningSession: AnyObject {
    /// Asks the unit to scan. The unit finds only the 2.4 GHz networks that it can use.
    func scanWiFiNetworks() async throws -> [DeviceWiFiNetwork]
    /// Returns after the unit confirms that it joined the Wi-Fi network.
    func sendWiFi(_ credentials: DeviceWiFiCredentials) async throws
    func disconnect()
}
