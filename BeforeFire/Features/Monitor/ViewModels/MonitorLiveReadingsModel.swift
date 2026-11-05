import Foundation
import Observation

/// Reads the sensor values from the backend again and again while the Monitor screen is active.
@MainActor
@Observable
final class MonitorLiveReadingsModel {
    enum Status: Equatable {
        /// No sensor is linked. The Monitor screen shows the example values.
        case notConfigured
        case loading
        case updated(SensorReadingsSnapshot)
        case failed(SensorReadingsFetchError)
    }

    private(set) var status: Status = .notConfigured
    /// The time of the last successful response. It stays after a failure, so the settings screen can show it.
    private(set) var lastUpdatedAt: Date?

    @ObservationIgnored private let client: any SensorReadingsFetching
    @ObservationIgnored private let refreshInterval: Duration
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private var currentLink: SensorBackendLink?

    init(
        client: any SensorReadingsFetching,
        refreshInterval: Duration = SensorBackendConfiguration.refreshInterval,
        now: @escaping () -> Date = Date.init
    ) {
        self.client = client
        self.refreshInterval = refreshInterval
        self.now = now
    }

    static func live() -> MonitorLiveReadingsModel {
        MonitorLiveReadingsModel(client: URLSessionSensorReadingsClient())
    }

    /// Runs until the calling task is cancelled. Start it again when the link changes.
    func refreshRepeatedly(for link: SensorBackendLink?) async {
        guard let link else {
            currentLink = nil
            status = .notConfigured
            lastUpdatedAt = nil
            return
        }
        if link != currentLink {
            // Values of a different sensor or server must not stay on the screen.
            currentLink = link
            status = .loading
            lastUpdatedAt = nil
        }

        while !Task.isCancelled {
            await refresh(link)
            do {
                try await Task.sleep(for: refreshInterval)
            } catch {
                return
            }
        }
    }

    func refresh(_ link: SensorBackendLink) async {
        do {
            let snapshot = try await client.fetchReadings(for: link)
            guard !Task.isCancelled, link == currentLink else { return }
            status = .updated(snapshot)
            lastUpdatedAt = now()
        } catch {
            guard !Task.isCancelled, link == currentLink, !(error is CancellationError) else { return }
            status = .failed(error as? SensorReadingsFetchError ?? .unexpectedResponse)
        }
    }
}
