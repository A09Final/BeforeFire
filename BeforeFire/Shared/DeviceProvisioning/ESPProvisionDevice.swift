@preconcurrency import ESPProvision
import Foundation

// The only file that uses the ESPProvision SDK. Verified against ESPProvision 3.2.0.
// Do not call `ESPProvisionManager.shared.enableLogs(true)`: the SDK logs the Wi-Fi password and the PoP.

final class ESPProvisionDeviceFinder: ProvisioningDeviceFinding {
    func findDevice(named name: String, setupCode: String, completion: @escaping ProvisioningCompletion<any ProvisioningDevice>) {
        // The SDK scans for 5 seconds and matches the name as a prefix. Unit names are unique per board.
        ESPProvisionManager.shared.createESPDevice(
            deviceName: name,
            transport: .ble,
            security: .secure,
            proofOfPossession: setupCode
        ) { @Sendable device, _ in
            guard let device else {
                completion(.failure(.deviceNotFound))
                return
            }
            Task { @MainActor in
                completion(.success(ESPProvisionDevice(device: device)))
            }
        }
    }

    func stopFinding() {
        ESPProvisionManager.shared.stopESPDevicesSearch()
    }
}

final class ESPProvisionDevice: ProvisioningDevice {
    private let device: ESPDevice

    init(device: ESPDevice) {
        self.device = device
    }

    func openSecureSession(completion: @escaping ProvisioningCompletion<Void>) {
        device.connect { @Sendable status in
            completion(ESPProvisionResultMapping.result(for: status))
        }
    }

    func scanWiFiNetworks(completion: @escaping ProvisioningCompletion<[DeviceWiFiNetwork]>) {
        device.scanWifiList { @Sendable networks, error in
            let foundNetworks = networks?.map {
                ESPProvisionResultMapping.network(ssid: $0.ssid, rssi: $0.rssi, auth: $0.auth)
            }
            completion(ESPProvisionResultMapping.scanResult(networks: foundNetworks, error: error))
        }
    }

    func sendWiFi(name: String, password: String, completion: @escaping ProvisioningCompletion<Void>) {
        device.provision(ssid: name, passPhrase: password) { @Sendable status in
            guard let result = ESPProvisionResultMapping.result(for: status) else { return }
            completion(result)
        }
    }

    func resetWiFiStatus(completion: @escaping ProvisioningCompletion<Void>) {
        device.resetWifiStatus { @Sendable isReset, _ in
            completion(isReset ? .success(()) : .failure(.deviceConnectionFailed))
        }
    }

    func disconnect() {
        device.disconnect()
    }
}

nonisolated enum ESPProvisionResultMapping {
    static func network(ssid: String, rssi: Int32, auth: WifiAuthMode) -> DeviceWiFiNetwork {
        DeviceWiFiNetwork(ssid: ssid, signalStrength: Int(rssi), isSecured: auth != .open)
    }

    static func scanResult(networks: [DeviceWiFiNetwork]?, error: ESPWiFiScanError?) -> Result<[DeviceWiFiNetwork], DeviceProvisioningError> {
        if let networks {
            return .success(networks)
        }
        // The SDK also reports an empty result when the firmware does not offer the `wifi_scan` capability.
        // The user can then type the network name.
        if case .emptyResultCount = error {
            return .success([])
        }
        return .failure(.wiFiScanUnavailable)
    }

    static func result(for status: ESPSessionStatus) -> Result<Void, DeviceProvisioningError> {
        switch status {
        case .connected:
            .success(())
        case .failedToConnect(.sessionInitError), .failedToConnect(.noPOP):
            // With Security 1, the unit ends the session when the PoP does not match.
            .failure(.setupCodeRejected)
        case .failedToConnect, .disconnected:
            .failure(.deviceConnectionFailed)
        }
    }

    /// Returns `nil` for intermediate statuses. The SDK sends `.configApplied` before the final status.
    static func result(for status: ESPProvisionStatus) -> Result<Void, DeviceProvisioningError>? {
        switch status {
        case .configApplied:
            nil
        case .success:
            .success(())
        case .failure(.wifiStatusAuthenticationError):
            .failure(.wiFiPasswordRejected)
        case .failure(.wifiStatusNetworkNotFound):
            .failure(.wiFiNetworkNotFound)
        case .failure(.sessionError):
            .failure(.deviceConnectionFailed)
        case .failure:
            .failure(.deviceCouldNotJoinWiFi)
        }
    }
}
