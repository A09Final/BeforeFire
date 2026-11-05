import Foundation

/// A device in the backend list. The backend knows only devices that sent a status since it started.
nonisolated struct BackendDevice: Equatable, Sendable {
    let deviceID: String
    let isOnline: Bool
}

protocol SensorDiscovering {
    /// Throws `SensorReadingsFetchError`, or `CancellationError` when the task is cancelled.
    func fetchDevices(serverURL: URL) async throws -> [BackendDevice]
}

/// Reads the device list with `GET /v1/devices`.
struct URLSessionSensorDiscoveryClient: SensorDiscovering {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchDevices(serverURL: URL) async throws -> [BackendDevice] {
        let request = URLRequest(
            url: serverURL.appending(path: SensorBackendConfiguration.devicesPath),
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: SensorBackendConfiguration.requestTimeout
        )

        let body: Data
        let response: URLResponse
        do {
            (body, response) = try await session.data(for: request)
        } catch {
            if Task.isCancelled || (error as? URLError)?.code == .cancelled {
                throw CancellationError()
            }
            throw SensorReadingsFetchError.backendUnreachable
        }

        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let list = try? JSONDecoder().decode(DeviceListResponse.self, from: body)
        else {
            throw SensorReadingsFetchError.unexpectedResponse
        }
        return list.devices.map { BackendDevice(deviceID: $0.deviceId, isOnline: $0.connection == "online") }
    }
}

/// The body of `GET /v1/devices` in BeforeFire-Backend `internal/httpapi/server.go`.
private nonisolated struct DeviceListResponse: Decodable {
    struct Device: Decodable {
        let deviceId: String
        let connection: String
    }

    let devices: [Device]
}
