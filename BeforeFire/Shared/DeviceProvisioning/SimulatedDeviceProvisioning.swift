import Foundation

// Developer simulation for previews, UI tests, and the Simulator, which has no Bluetooth.
// These types make no Bluetooth connection, send no Wi-Fi values, and change no home.

struct SimulatedDeviceScanner: DeviceScanning {
    static let sensors = [
        DiscoveredDevice(id: UUID(uuidString: "A09F0000-0000-4000-8000-0000000A1B2C")!, name: "DAPUR_A1B2C3"),
        DiscoveredDevice(id: UUID(uuidString: "A09F0000-0000-4000-8000-0000000D4E5F")!, name: "DAPUR_D4E5F6")
    ]
    static let alarms = [
        DiscoveredDevice(id: UUID(uuidString: "A09F0000-0000-4000-8000-0000000A1A2B")!, name: "DAPUR_ALM_A1A2B3")
    ]
    static let discoveryInterval: Duration = .milliseconds(600)

    let kind: ProvisioningDeviceKind

    static func devices(for kind: ProvisioningDeviceKind) -> [DiscoveredDevice] {
        switch kind {
        case .sensor: sensors
        case .alarm: alarms
        }
    }

    func discoverDevices() -> AsyncThrowingStream<DiscoveredDevice, Error> {
        let devices = Self.devices(for: kind)
        return AsyncThrowingStream { continuation in
            let discoveryTask = Task {
                for device in devices {
                    do {
                        try await Task.sleep(for: Self.discoveryInterval)
                    } catch {
                        return
                    }
                    continuation.yield(device)
                }
                // The stream stays open like a real scan. The scan timeout or the user ends it.
            }
            continuation.onTermination = { _ in discoveryTask.cancel() }
        }
    }
}

struct SimulatedDeviceConnector: DeviceProvisioningConnecting {
    static let connectDuration: Duration = .milliseconds(800)

    func connect(to device: DiscoveredDevice, setupCode: DeviceSetupCode) async throws -> any DeviceProvisioningSession {
        try await Task.sleep(for: Self.connectDuration)
        return SimulatedDeviceSession()
    }
}

final class SimulatedDeviceSession: DeviceProvisioningSession {
    static let networks = [
        DeviceWiFiNetwork(ssid: "Kitchen WiFi", signalStrength: -48, isSecured: true),
        DeviceWiFiNetwork(ssid: "Guest", signalStrength: -71, isSecured: false),
        DeviceWiFiNetwork(ssid: "Neighbor 2.4G", signalStrength: -83, isSecured: true)
    ]
    static let scanDuration: Duration = .milliseconds(800)
    static let sendDuration: Duration = .milliseconds(1500)

    func scanWiFiNetworks() async throws -> [DeviceWiFiNetwork] {
        try await Task.sleep(for: Self.scanDuration)
        return Self.networks
    }

    func sendWiFi(_ credentials: DeviceWiFiCredentials) async throws {
        try await Task.sleep(for: Self.sendDuration)
    }

    func disconnect() {}
}

/// Shows no system UI and adds no accessory to a home.
struct SimulatedDeviceHomeSetup: DeviceHomeSetupPerforming {
    static let setupDuration: Duration = .milliseconds(1000)

    func addDeviceToHome() async throws {
        try await Task.sleep(for: Self.setupDuration)
    }
}
