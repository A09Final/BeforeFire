import Foundation
import Observation
import os

/// Finds units of one type over Bluetooth and keeps the connection status for the connection screen.
@MainActor
@Observable
final class DeviceConnectionModel {
    enum ScanStatus: Equatable {
        case idle
        case scanning
        case finished
        case failed(DeviceProvisioningError)
    }

    let kind: ProvisioningDeviceKind
    let copy: DeviceConnectionCopy
    private(set) var scanStatus: ScanStatus = .idle
    private(set) var discoveredDevices: [DiscoveredDevice] = []
    /// The last unit that joined Wi-Fi. The live model keeps it on the phone. It does not tell whether the unit is online now.
    private(set) var connectedDeviceName: String?
    var selectedDevice: DiscoveredDevice?
    let isSimulated: Bool
    @ObservationIgnored let connector: any DeviceProvisioningConnecting
    @ObservationIgnored let homeSetup: any DeviceHomeSetupPerforming
    /// `nil` keeps the name only in memory, for simulated units and tests.
    @ObservationIgnored private let connectedDeviceStore: (any ConnectedDeviceStoring)?
    /// `nil` saves no setup codes, for simulated units and tests.
    @ObservationIgnored private let setupCodeStore: (any DeviceSetupCodeStoring)?
    @ObservationIgnored private let logger = Logger(subsystem: "BeforeFire", category: "DeviceConnection")

    @ObservationIgnored private let scanner: any DeviceScanning
    @ObservationIgnored private let scanDuration: Duration
    @ObservationIgnored private var scanTask: Task<Void, Never>?
    @ObservationIgnored private var scanTimeoutTask: Task<Void, Never>?

    init(
        kind: ProvisioningDeviceKind,
        scanner: any DeviceScanning,
        connector: any DeviceProvisioningConnecting,
        homeSetup: any DeviceHomeSetupPerforming,
        scanDuration: Duration = DeviceProvisioningConfiguration.scanDuration,
        isSimulated: Bool = false,
        connectedDeviceStore: (any ConnectedDeviceStoring)? = nil,
        setupCodeStore: (any DeviceSetupCodeStoring)? = nil
    ) {
        self.kind = kind
        self.copy = DeviceConnectionCopy(kind: kind)
        self.scanner = scanner
        self.connector = connector
        self.homeSetup = homeSetup
        self.scanDuration = scanDuration
        self.isSimulated = isSimulated
        self.connectedDeviceStore = connectedDeviceStore
        self.setupCodeStore = setupCodeStore
        connectedDeviceName = connectedDeviceStore?.connectedDeviceName(for: kind)
    }

    static func live(kind: ProvisioningDeviceKind) -> DeviceConnectionModel {
        DeviceConnectionModel(
            kind: kind,
            scanner: BluetoothDeviceScanner(kind: kind),
            connector: ESPProvisionConnector(),
            homeSetup: HomeKitDeviceHomeSetup(),
            connectedDeviceStore: UserDefaultsConnectedDeviceStore(),
            setupCodeStore: KeychainDeviceSetupCodeStore()
        )
    }

    static func simulated(kind: ProvisioningDeviceKind) -> DeviceConnectionModel {
        DeviceConnectionModel(
            kind: kind,
            scanner: SimulatedDeviceScanner(kind: kind),
            connector: SimulatedDeviceConnector(),
            homeSetup: SimulatedDeviceHomeSetup(),
            isSimulated: true
        )
    }

    var isScanning: Bool {
        scanStatus == .scanning
    }

    func startScan() {
        cancelScanTasks()
        discoveredDevices = []
        scanStatus = .scanning

        let deviceStream = scanner.discoverDevices()
        scanTask = Task { [weak self] in
            do {
                for try await device in deviceStream {
                    self?.add(device)
                }
                guard !Task.isCancelled else { return }
                self?.stopScan()
            } catch {
                guard !Task.isCancelled else { return }
                self?.failScan(with: error)
            }
        }
        scanTimeoutTask = Task { [weak self, scanDuration] in
            do {
                try await Task.sleep(for: scanDuration)
            } catch {
                return
            }
            self?.stopScan()
        }
    }

    func stopScan() {
        cancelScanTasks()
        if scanStatus == .scanning {
            scanStatus = .finished
        }
    }

    func select(_ device: DiscoveredDevice) {
        // Bluetooth provisioning is more reliable when the phone does not scan at the same time.
        stopScan()
        selectedDevice = device
    }

    /// Records a unit that joined Wi-Fi. The setup sheet stays open, because the Home setup starts next.
    /// The setup code is saved, so the next Wi-Fi setup of this unit needs no typed code.
    func rememberJoined(_ device: DiscoveredDevice, setupCode: DeviceSetupCode? = nil) {
        connectedDeviceName = device.name
        connectedDeviceStore?.saveConnectedDeviceName(device.name, for: kind)
        guard let setupCode else { return }
        do {
            try setupCodeStore?.saveSetupCode(setupCode, for: device.name)
        } catch {
            // The setup still works. The user only types the code again next time.
            logger.error("Saving the setup code failed: \(String(describing: error), privacy: .public)")
        }
    }

    func savedSetupCode(for device: DiscoveredDevice) -> DeviceSetupCode? {
        setupCodeStore?.setupCode(for: device.name)
    }

    /// Removes a saved code that the unit did not accept, for example after the unit made a new setup code.
    func forgetSetupCode(for device: DiscoveredDevice) {
        removeSetupCode(for: device.name)
    }

    /// Forgets the connected unit and its setup code. The unit keeps its Wi-Fi network.
    func disconnect() {
        if let connectedDeviceName {
            removeSetupCode(for: connectedDeviceName)
        }
        connectedDeviceName = nil
        connectedDeviceStore?.removeConnectedDeviceName(for: kind)
    }

    private func removeSetupCode(for deviceName: String) {
        do {
            try setupCodeStore?.removeSetupCode(for: deviceName)
        } catch {
            logger.error("Removing the setup code failed: \(String(describing: error), privacy: .public)")
        }
    }

    /// Records the unit and closes the setup sheet.
    func markConnected(_ device: DiscoveredDevice) {
        rememberJoined(device)
        selectedDevice = nil
    }

    private func add(_ device: DiscoveredDevice) {
        guard !discoveredDevices.contains(where: { $0.id == device.id }) else { return }
        discoveredDevices.append(device)
    }

    private func failScan(with error: Error) {
        cancelScanTasks()
        scanStatus = .failed(error as? DeviceProvisioningError ?? .bluetoothUnavailable)
    }

    private func cancelScanTasks() {
        scanTask?.cancel()
        scanTask = nil
        scanTimeoutTask?.cancel()
        scanTimeoutTask = nil
    }
}
