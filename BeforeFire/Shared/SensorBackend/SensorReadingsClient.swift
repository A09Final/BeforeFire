import Foundation

nonisolated enum SensorReadingsFetchError: Error, Equatable {
    /// No response, for example because the phone is not on the home Wi-Fi or the server is off.
    case backendUnreachable
    /// The setup code is wrong, or the sensor made a new setup code.
    case invalidReadKey
    /// The sensor is not connected to the backend yet, or it sent no readings yet.
    case noReadings
    /// The backend does not accept the sensor serial.
    case unknownDevice
    case unexpectedResponse
}

protocol SensorReadingsFetching {
    /// Throws `SensorReadingsFetchError`, or `CancellationError` when the task is cancelled.
    func fetchReadings(for link: SensorBackendLink) async throws -> SensorReadingsSnapshot
}

/// Reads the sensor values with `GET /v1/devices/{deviceId}/readings`.
struct URLSessionSensorReadingsClient: SensorReadingsFetching {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchReadings(for link: SensorBackendLink) async throws -> SensorReadingsSnapshot {
        var request = URLRequest(
            url: link.readingsURL,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: SensorBackendConfiguration.requestTimeout
        )
        request.setValue("Bearer \(link.readKey)", forHTTPHeaderField: "Authorization")

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

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SensorReadingsFetchError.unexpectedResponse
        }
        switch httpResponse.statusCode {
        case 200:
            do {
                return try JSONDecoder().decode(SensorReadingsSnapshot.self, from: body)
            } catch {
                throw SensorReadingsFetchError.unexpectedResponse
            }
        case 401:
            throw SensorReadingsFetchError.invalidReadKey
        case 404:
            let errorCode = try? JSONDecoder().decode(BackendErrorResponse.self, from: body).error
            throw errorCode == SensorBackendConfiguration.noReadingsErrorCode
                ? SensorReadingsFetchError.noReadings
                : SensorReadingsFetchError.unknownDevice
        default:
            throw SensorReadingsFetchError.unexpectedResponse
        }
    }
}

/// The error body of the backend, for example `{"error":"no_readings"}`.
private nonisolated struct BackendErrorResponse: Decodable {
    let error: String
}
