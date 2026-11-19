import Foundation
import Observation

/// Adds the sensor and the alarm to the Home app. Each unit must have Wi-Fi before the user adds it.
@MainActor
@Observable
final class HomeConnectionModel {
    enum Status: Equatable {
        case idle
        case adding
        /// The system Home setup finished. The app does not read the Home app, so this status stays only
        /// while the screen is open.
        case added
        case failed(message: String)
    }

    /// The order of the units on the Home Connection screen.
    static let units: [ProvisioningDeviceKind] = [.sensor, .alarm]

    let isSimulated: Bool
    private(set) var statuses: [ProvisioningDeviceKind: Status] = [:]

    @ObservationIgnored private let homeSetup: any DeviceHomeSetupPerforming
    @ObservationIgnored private var setupTask: Task<Void, Never>?

    init(homeSetup: any DeviceHomeSetupPerforming, isSimulated: Bool = false) {
        self.homeSetup = homeSetup
        self.isSimulated = isSimulated
    }

    static func live() -> HomeConnectionModel {
        HomeConnectionModel(homeSetup: HomeKitDeviceHomeSetup())
    }

    static func simulated() -> HomeConnectionModel {
        HomeConnectionModel(homeSetup: SimulatedDeviceHomeSetup(), isSimulated: true)
    }

    func status(for kind: ProvisioningDeviceKind) -> Status {
        statuses[kind] ?? .idle
    }

    /// The system shows one Home setup at a time, so the screen allows only one unit at a time.
    var isBusy: Bool {
        statuses.values.contains(.adding)
    }

    func addToHome(_ kind: ProvisioningDeviceKind) {
        guard !isBusy, status(for: kind) != .added else { return }
        statuses[kind] = .adding
        setupTask = Task { [weak self, homeSetup] in
            let result: Status
            do {
                try await homeSetup.addDeviceToHome()
                result = .added
            } catch is CancellationError {
                result = .idle
            } catch DeviceHomeSetupError.cancelled {
                // The user closed the system Home setup. This is not an error.
                result = .idle
            } catch {
                result = .failed(message: DeviceConnectionCopy(kind: kind).message(for: error))
            }
            guard !Task.isCancelled else { return }
            self?.statuses[kind] = result
        }
    }

    /// Stops waiting for the Home setup. The system setup UI can stay open, because the app cannot close it.
    func cancel() {
        setupTask?.cancel()
        setupTask = nil
        for (kind, status) in statuses where status == .adding {
            statuses[kind] = .idle
        }
    }
}
