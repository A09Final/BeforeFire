/// Fetches readings for the linked sensor in the app.
protocol SensorReadingsFetching {
    func fetchReadings(for link: SensorBackendLink) async throws -> SensorReadingsSnapshot
}

extension URLSessionSensorReadingsClient: SensorReadingsFetching {
    func fetchReadings(for link: SensorBackendLink) async throws -> SensorReadingsSnapshot {
        try await fetchReadings(using: link.readingsAccess)
    }
}
