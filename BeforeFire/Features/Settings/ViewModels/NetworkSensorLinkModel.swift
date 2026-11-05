import Foundation
import Observation

/// Links a sensor that already has Wi-Fi. The app checks the setup code with the server: the server accepts only
/// the read key that the correct setup code makes. No Wi-Fi setup is necessary.
@MainActor
@Observable
final class NetworkSensorLinkModel {
    let sensor: NetworkSensor
    var setupCode = ""
    private(set) var isLinking = false
    /// `true` while the app checks the saved setup code. The screen then shows no setup code field.
    private(set) var isUsingSavedSetupCode = false
    private(set) var isLinked = false
    private(set) var errorMessage: String?

    @ObservationIgnored private let serverAddress: String
    @ObservationIgnored private let client: any SensorReadingsFetching
    @ObservationIgnored private var savedSetupCode: DeviceSetupCode?
    /// Saves the checked link. It can throw when the phone cannot save it.
    @ObservationIgnored private let onLinked: (SensorBackendLink) throws -> Void
    @ObservationIgnored private let onSavedSetupCodeRejected: () -> Void
    @ObservationIgnored private var linkTask: Task<Void, Never>?

    init(
        sensor: NetworkSensor,
        serverAddress: String,
        savedSetupCode: DeviceSetupCode?,
        client: any SensorReadingsFetching,
        onLinked: @escaping (SensorBackendLink) throws -> Void,
        onSavedSetupCodeRejected: @escaping () -> Void = {}
    ) {
        self.sensor = sensor
        self.serverAddress = serverAddress
        self.savedSetupCode = savedSetupCode
        self.client = client
        self.onLinked = onLinked
        self.onSavedSetupCodeRejected = onSavedSetupCodeRejected
    }

    var canLink: Bool {
        !isLinking && !isLinked && !setupCode.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Links at once with the saved setup code. It does nothing when no code is saved.
    func linkWithSavedSetupCode() {
        guard !isLinking, !isLinked, let savedSetupCode else { return }
        isUsingSavedSetupCode = true
        setupCode = savedSetupCode.value
        link()
    }

    func link() {
        guard canLink else { return }
        let link: SensorBackendLink
        do {
            link = try SensorBackendLink(backendAddress: serverAddress, deviceID: sensor.id, setupCode: setupCode)
        } catch let issue as SensorBackendLinkIssue {
            show(SensorBackendSettingsCopy.message(for: issue))
            return
        } catch {
            show(SensorBackendSettingsCopy.message(for: .invalidSetupCode))
            return
        }

        isLinking = true
        errorMessage = nil
        linkTask = Task { [weak self, client] in
            do {
                // A successful read proves that the setup code is correct.
                _ = try await client.fetchReadings(for: link)
                guard let self, !Task.isCancelled else { return }
                try self.onLinked(link)
                self.isLinked = true
                self.isUsingSavedSetupCode = false
            } catch {
                guard let self, !Task.isCancelled, !(error is CancellationError) else { return }
                self.handleFailure(error)
            }
            self?.isLinking = false
        }
    }

    func cancel() {
        linkTask?.cancel()
        linkTask = nil
        isLinking = false
    }

    private func handleFailure(_ error: Error) {
        let fetchError = error as? SensorReadingsFetchError
        if isUsingSavedSetupCode {
            isUsingSavedSetupCode = false
            savedSetupCode = nil
            if fetchError == .invalidReadKey {
                // The sensor has a new setup code, for example after @R in the firmware.
                setupCode = ""
                onSavedSetupCodeRejected()
            }
        }
        if let fetchError {
            show(SensorBackendSettingsCopy.linkMessage(for: fetchError))
        } else {
            show(SensorBackendSettingsCopy.message(for: .storageFailed))
        }
    }

    private func show(_ message: String) {
        errorMessage = message
    }
}
