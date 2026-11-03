import Foundation

nonisolated enum SensorProvisioningError: Error, Equatable {
    case bluetoothPoweredOff
    case bluetoothUnauthorized
    case bluetoothUnsupported
    case bluetoothUnavailable
    case sensorNotFound
    case sensorConnectionFailed
    /// The secure session failed. A wrong setup code (PoP) is the usual cause.
    case setupCodeRejected
    case wiFiScanUnavailable
    case wiFiPasswordRejected
    case wiFiNetworkNotFound
    /// The firmware reports `ARDUINO_EVENT_PROV_CRED_FAIL` for another reason.
    case sensorCouldNotJoinWiFi
}

protocol SensorScanning {
    /// Yields each matching sensor one time. Cancel the iterating task to stop the scan.
    func discoverSensors() -> AsyncThrowingStream<DiscoveredSensor, Error>
}

protocol SensorProvisioningConnecting {
    /// Opens a secure Bluetooth session with the sensor. The setup code must match the sensor label.
    func connect(to sensor: DiscoveredSensor, setupCode: SensorSetupCode) async throws -> any SensorProvisioningSession
}

protocol SensorProvisioningSession: AnyObject {
    /// Asks the sensor to scan. The sensor finds only the 2.4 GHz networks that it can use.
    func scanWiFiNetworks() async throws -> [SensorWiFiNetwork]
    /// Returns after the sensor confirms that it joined the Wi-Fi network.
    func sendWiFi(_ credentials: SensorWiFiCredentials) async throws
    func disconnect()
}
