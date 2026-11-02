import Foundation
import Observation

@MainActor
@Observable
final class SensorWiFiSetupModel {
    enum Step: Equatable {
        case setupCode
        case networks
        case password
        case connected(wiFiName: String)
    }

    enum Activity: Equatable {
        case connecting
        case scanning
        case joining
    }

    let sensor: DiscoveredSensor
    var setupCode = ""
    var manualWiFiName = ""
    var password = ""
    private(set) var step: Step = .setupCode
    private(set) var activity: Activity?
    private(set) var errorMessage: String?
    private(set) var networks: [SensorWiFiNetwork] = []
    /// `nil` on the password step means that the user types the network name.
    private(set) var selectedNetwork: SensorWiFiNetwork?

    @ObservationIgnored private let connector: any SensorProvisioningConnecting
    @ObservationIgnored private var session: (any SensorProvisioningSession)?
    @ObservationIgnored private var activityTask: Task<Void, Never>?

    init(sensor: DiscoveredSensor, connector: any SensorProvisioningConnecting) {
        self.sensor = sensor
        self.connector = connector
    }

    var isBusy: Bool {
        activity != nil
    }

    var isOtherNetwork: Bool {
        step == .password && selectedNetwork == nil
    }

    var requiresPassword: Bool {
        selectedNetwork?.isSecured ?? false
    }

    /// Open networks need no password. For a typed name the app cannot know, so it shows the field.
    var showsPasswordField: Bool {
        selectedNetwork?.isSecured ?? true
    }

    var canConnect: Bool {
        !isBusy && !setupCode.isEmpty
    }

    var canJoin: Bool {
        guard !isBusy else { return false }
        if isOtherNetwork, manualWiFiName.isEmpty { return false }
        return !(requiresPassword && password.isEmpty)
    }

    var canGoBack: Bool {
        !isBusy && (step == .networks || step == .password)
    }

    func connect() {
        guard canConnect else { return }
        let validSetupCode: SensorSetupCode
        do {
            validSetupCode = try SensorSetupCode(setupCode)
        } catch {
            errorMessage = SensorConnectionCopy.message(for: error)
            return
        }

        perform(.connecting) { [weak self, connector, sensor] in
            let session = try await connector.connect(to: sensor, setupCode: validSetupCode)
            guard let self, !Task.isCancelled else {
                session.disconnect()
                return
            }
            self.session = session
            self.step = .networks
            try await self.loadNetworks(using: session)
        }
    }

    func refreshNetworks() {
        guard !isBusy, step == .networks, let session else { return }
        perform(.scanning) { [weak self] in
            try await self?.loadNetworks(using: session)
        }
    }

    func select(_ network: SensorWiFiNetwork) {
        guard !isBusy else { return }
        showPasswordStep(for: network)
    }

    func chooseOtherNetwork() {
        guard !isBusy else { return }
        manualWiFiName = ""
        showPasswordStep(for: nil)
    }

    func join() {
        guard canJoin, let session else { return }
        let credentials: SensorWiFiCredentials
        do {
            credentials = try SensorWiFiCredentials(
                wiFiName: selectedNetwork?.ssid ?? manualWiFiName,
                password: password,
                requiresPassword: requiresPassword
            )
        } catch {
            errorMessage = SensorConnectionCopy.message(for: error)
            return
        }

        perform(.joining) { [weak self] in
            try await session.sendWiFi(credentials)
            guard let self, !Task.isCancelled else { return }
            // The firmware restarts after it saves the Wi-Fi values, so the session ends here.
            self.endSession()
            self.password = ""
            self.step = .connected(wiFiName: credentials.wiFiName)
        }
    }

    func goBack() {
        guard canGoBack else { return }
        errorMessage = nil
        switch step {
        case .password:
            password = ""
            step = .networks
        case .networks:
            endSession()
            networks = []
            step = .setupCode
        case .setupCode, .connected:
            break
        }
    }

    /// Stops the current work and ends the Bluetooth session, for example when the sheet closes.
    func close() {
        cancelActivity()
        endSession()
        password = ""
    }

    private func showPasswordStep(for network: SensorWiFiNetwork?) {
        selectedNetwork = network
        password = ""
        errorMessage = nil
        step = .password
    }

    private func loadNetworks(using session: any SensorProvisioningSession) async throws {
        activity = .scanning
        do {
            networks = SensorWiFiNetwork.displayList(from: try await session.scanWiFiNetworks())
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            // The user can still type a network name, so a scan failure does not end the setup.
            networks = []
            errorMessage = SensorConnectionCopy.message(for: error)
        }
    }

    private func perform(_ newActivity: Activity, operation: @escaping @MainActor () async throws -> Void) {
        cancelActivity()
        activity = newActivity
        errorMessage = nil
        activityTask = Task { [weak self] in
            do {
                try await operation()
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                self?.errorMessage = SensorConnectionCopy.message(for: error)
            }
            guard !Task.isCancelled else { return }
            self?.activity = nil
        }
    }

    private func cancelActivity() {
        activityTask?.cancel()
        activityTask = nil
        activity = nil
    }

    private func endSession() {
        session?.disconnect()
        session = nil
    }
}
