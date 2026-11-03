import Foundation

// Developer simulation for previews, UI tests, and the Simulator, which has no Bluetooth.
// These types make no Bluetooth connection, send no Wi-Fi values, and change no home.

struct SimulatedSensorScanner: SensorScanning {
    static let sensors = [
        DiscoveredSensor(id: UUID(uuidString: "A09F0000-0000-4000-8000-0000000A1B2C")!, name: "DAPUR_A1B2C3"),
        DiscoveredSensor(id: UUID(uuidString: "A09F0000-0000-4000-8000-0000000D4E5F")!, name: "DAPUR_D4E5F6")
    ]
    static let alarms = [
        DiscoveredSensor(id: UUID(uuidString: "A09F0000-0000-4000-8000-0000000A1A2B")!, name: "DAPUR_ALM_A1A2B3")
    ]
    static let discoveryInterval: Duration = .milliseconds(600)

    let kind: ProvisioningDeviceKind

    static func devices(for kind: ProvisioningDeviceKind) -> [DiscoveredSensor] {
        switch kind {
        case .sensor: sensors
        case .alarm: alarms
        }
    }

    func discoverSensors() -> AsyncThrowingStream<DiscoveredSensor, Error> {
        let devices = Self.devices(for: kind)
        return AsyncThrowingStream { continuation in
            let discoveryTask = Task {
                for sensor in devices {
                    do {
                        try await Task.sleep(for: Self.discoveryInterval)
                    } catch {
                        return
                    }
                    continuation.yield(sensor)
                }
                // The stream stays open like a real scan. The scan timeout or the user ends it.
            }
            continuation.onTermination = { _ in discoveryTask.cancel() }
        }
    }
}

struct SimulatedSensorConnector: SensorProvisioningConnecting {
    static let connectDuration: Duration = .milliseconds(800)

    func connect(to sensor: DiscoveredSensor, setupCode: SensorSetupCode) async throws -> any SensorProvisioningSession {
        try await Task.sleep(for: Self.connectDuration)
        return SimulatedSensorSession()
    }
}

final class SimulatedSensorSession: SensorProvisioningSession {
    static let networks = [
        SensorWiFiNetwork(ssid: "Kitchen WiFi", signalStrength: -48, isSecured: true),
        SensorWiFiNetwork(ssid: "Guest", signalStrength: -71, isSecured: false),
        SensorWiFiNetwork(ssid: "Neighbor 2.4G", signalStrength: -83, isSecured: true)
    ]
    static let scanDuration: Duration = .milliseconds(800)
    static let sendDuration: Duration = .milliseconds(1500)

    func scanWiFiNetworks() async throws -> [SensorWiFiNetwork] {
        try await Task.sleep(for: Self.scanDuration)
        return Self.networks
    }

    func sendWiFi(_ credentials: SensorWiFiCredentials) async throws {
        try await Task.sleep(for: Self.sendDuration)
    }

    func disconnect() {}
}

/// Shows no system UI and adds no accessory to a home.
struct SimulatedSensorHomeSetup: SensorHomeSetupPerforming {
    static let setupDuration: Duration = .milliseconds(1000)

    func addSensorToHome() async throws {
        try await Task.sleep(for: Self.setupDuration)
    }
}
