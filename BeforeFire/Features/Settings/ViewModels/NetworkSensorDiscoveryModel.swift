import Foundation
import Observation

/// A sensor that already has Wi-Fi and reports to the server.
struct NetworkSensor: Identifiable, Hashable {
    /// The sensor serial, for example `DAPUR_020F3C`.
    let id: String
}

/// Finds sensors that already have Wi-Fi. Such a sensor does not advertise over Bluetooth, so the app asks the
/// server which sensors are online.
@MainActor
@Observable
final class NetworkSensorDiscoveryModel {
    enum Status: Equatable {
        case idle
        case searching
        case finished
        case failed(SensorReadingsFetchError)
    }

    private(set) var status: Status = .idle
    private(set) var sensors: [NetworkSensor] = []

    @ObservationIgnored private let client: any SensorDiscovering

    init(client: any SensorDiscovering) {
        self.client = client
    }

    static func live() -> NetworkSensorDiscoveryModel {
        NetworkSensorDiscoveryModel(client: URLSessionSensorDiscoveryClient())
    }

    /// Shows only online sensors. Alarm units do not report to the server.
    func search(serverAddress: String) async {
        sensors = []
        guard let serverURL = try? SensorBackendLink.serverURL(from: serverAddress) else {
            status = .failed(.backendUnreachable)
            return
        }
        status = .searching
        do {
            let devices = try await client.fetchDevices(serverURL: serverURL)
            guard !Task.isCancelled else { return }
            sensors = devices
                .filter { $0.isOnline && ProvisioningDeviceKind.sensor.matches(advertisedName: $0.deviceID) }
                .map { NetworkSensor(id: $0.deviceID) }
            status = .finished
        } catch {
            guard !Task.isCancelled, !(error is CancellationError) else { return }
            status = .failed(error as? SensorReadingsFetchError ?? .unexpectedResponse)
        }
    }
}
