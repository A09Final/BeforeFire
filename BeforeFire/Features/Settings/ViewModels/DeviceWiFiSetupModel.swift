import Foundation
import Observation

/// Runs the Wi-Fi and Home setup steps for one unit. The sensor and the alarm use the same steps.
@MainActor
@Observable
final class DeviceWiFiSetupModel {
    enum Step: Equatable {
        case setupCode
        case networks
        case password
        /// The unit joined Wi-Fi. The Home setup is not complete yet.
        case connected(wiFiName: String)
        case addedToHome
    }

    enum Activity: Equatable {
        case connecting
        case scanning
        case joining
        case addingToHome
    }

    let device: DiscoveredDevice
    let copy: DeviceConnectionCopy
    var setupCode = ""
    var manualWiFiName = ""
    var password = ""
    private(set) var step: Step = .setupCode
    private(set) var activity: Activity?
    private(set) var errorMessage: String?
    private(set) var networks: [DeviceWiFiNetwork] = []
    /// `nil` on the password step means that the user types the network name.
    private(set) var selectedNetwork: DeviceWiFiNetwork?

    @ObservationIgnored private let connector: any DeviceProvisioningConnecting
    @ObservationIgnored private let homeSetup: any DeviceHomeSetupPerforming
    @ObservationIgnored private var session: (any DeviceProvisioningSession)?
    @ObservationIgnored private var activityTask: Task<Void, Never>?
    /// The setup code that opened the secure session. The unit accepts only its own code, so this code is correct.
    @ObservationIgnored private var acceptedSetupCode: DeviceSetupCode?
    /// Called one time when the unit joins Wi-Fi, with the setup code that the unit accepted.
    @ObservationIgnored private let onWiFiJoined: ((DiscoveredDevice, DeviceSetupCode) -> Void)?

    init(
        device: DiscoveredDevice,
        kind: ProvisioningDeviceKind,
        connector: any DeviceProvisioningConnecting,
        homeSetup: any DeviceHomeSetupPerforming,
        onWiFiJoined: ((DiscoveredDevice, DeviceSetupCode) -> Void)? = nil
    ) {
        self.device = device
        self.copy = DeviceConnectionCopy(kind: kind)
        self.connector = connector
        self.homeSetup = homeSetup
        self.onWiFiJoined = onWiFiJoined
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

    var isWiFiConnected: Bool {
        if case .connected = step { return true }
        return false
    }

    var canAddToHome: Bool {
        !isBusy && isWiFiConnected
    }

    var canGoBack: Bool {
        !isBusy && (step == .networks || step == .password)
    }

    func connect() {
        guard canConnect else { return }
        let validSetupCode: DeviceSetupCode
        do {
            validSetupCode = try DeviceSetupCode(setupCode)
        } catch {
            errorMessage = copy.message(for: error)
            return
        }

        perform(.connecting) { [weak self, connector, device] in
            let session = try await connector.connect(to: device, setupCode: validSetupCode)
            guard let self, !Task.isCancelled else {
                session.disconnect()
                return
            }
            self.session = session
            self.acceptedSetupCode = validSetupCode
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

    func select(_ network: DeviceWiFiNetwork) {
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
        let credentials: DeviceWiFiCredentials
        do {
            credentials = try DeviceWiFiCredentials(
                wiFiName: selectedNetwork?.ssid ?? manualWiFiName,
                password: password,
                requiresPassword: requiresPassword
            )
        } catch {
            errorMessage = copy.message(for: error)
            return
        }

        perform(.joining) { [weak self] in
            try await session.sendWiFi(credentials)
            guard let self, !Task.isCancelled else { return }
            // The firmware restarts after it saves the Wi-Fi values, so the session ends here.
            self.endSession()
            self.password = ""
            self.step = .connected(wiFiName: credentials.wiFiName)
            if let acceptedSetupCode = self.acceptedSetupCode {
                self.onWiFiJoined?(self.device, acceptedSetupCode)
            }
            // The Home setup starts at once. The firmware restarts while the user scans the HomeKit code.
            try await self.addDeviceToHome()
        }
    }

    func addToHome() {
        guard canAddToHome else { return }
        perform(.addingToHome) { [weak self] in
            try await self?.addDeviceToHome()
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
        case .setupCode, .connected, .addedToHome:
            break
        }
    }

    /// Stops the current work and ends the Bluetooth session, for example when the sheet closes.
    func close() {
        cancelActivity()
        endSession()
        password = ""
    }

    private func showPasswordStep(for network: DeviceWiFiNetwork?) {
        selectedNetwork = network
        password = ""
        errorMessage = nil
        step = .password
    }

    private func loadNetworks(using session: any DeviceProvisioningSession) async throws {
        activity = .scanning
        do {
            networks = DeviceWiFiNetwork.displayList(from: try await session.scanWiFiNetworks())
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            // The user can still type a network name, so a scan failure does not end the setup.
            networks = []
            errorMessage = copy.message(for: error)
        }
    }

    private func addDeviceToHome() async throws {
        activity = .addingToHome
        // A cancelled setup throws to `perform`, which shows a message. The unit keeps its Wi-Fi values,
        // so the user can start the Home setup again.
        try await homeSetup.addDeviceToHome()
        guard !Task.isCancelled else { return }
        step = .addedToHome
    }

    private func perform(_ newActivity: Activity, operation: @escaping @MainActor () async throws -> Void) {
        cancelActivity()
        activity = newActivity
        errorMessage = nil
        activityTask = Task { [weak self, copy] in
            do {
                try await operation()
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                self?.errorMessage = copy.message(for: error)
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
