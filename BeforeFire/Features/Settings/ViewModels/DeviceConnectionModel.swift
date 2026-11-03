import Foundation
import Observation

/// Finds units of one type over Bluetooth and keeps the connection status for the connection screen.
@MainActor
@Observable
final class DeviceConnectionModel {
    enum ScanStatus: Equatable {
        case idle
        case scanning
        case finished
        case failed(SensorProvisioningError)
    }

    let kind: ProvisioningDeviceKind
    let copy: DeviceConnectionCopy
    private(set) var scanStatus: ScanStatus = .idle
    private(set) var discoveredDevices: [DiscoveredSensor] = []
    /// Kept in memory only. The app does not yet read the unit connection from HomeKit.
    private(set) var connectedDeviceName: String?
    var selectedDevice: DiscoveredSensor?
    let isSimulated: Bool
    @ObservationIgnored let connector: any SensorProvisioningConnecting
    @ObservationIgnored let homeSetup: any SensorHomeSetupPerforming

    @ObservationIgnored private let scanner: any SensorScanning
    @ObservationIgnored private let scanDuration: Duration
    @ObservationIgnored private var scanTask: Task<Void, Never>?
    @ObservationIgnored private var scanTimeoutTask: Task<Void, Never>?

    init(
        kind: ProvisioningDeviceKind,
        scanner: any SensorScanning,
        connector: any SensorProvisioningConnecting,
        homeSetup: any SensorHomeSetupPerforming,
        scanDuration: Duration = SensorProvisioningConfiguration.scanDuration,
        isSimulated: Bool = false
    ) {
        self.kind = kind
        self.copy = DeviceConnectionCopy(kind: kind)
        self.scanner = scanner
        self.connector = connector
        self.homeSetup = homeSetup
        self.scanDuration = scanDuration
        self.isSimulated = isSimulated
    }

    static func live(kind: ProvisioningDeviceKind) -> DeviceConnectionModel {
        DeviceConnectionModel(
            kind: kind,
            scanner: BluetoothSensorScanner(kind: kind),
            connector: ESPProvisionConnector(),
            homeSetup: HomeKitSensorHomeSetup()
        )
    }

    static func simulated(kind: ProvisioningDeviceKind) -> DeviceConnectionModel {
        DeviceConnectionModel(
            kind: kind,
            scanner: SimulatedSensorScanner(kind: kind),
            connector: SimulatedSensorConnector(),
            homeSetup: SimulatedSensorHomeSetup(),
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

        let deviceStream = scanner.discoverSensors()
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

    func select(_ device: DiscoveredSensor) {
        // Bluetooth provisioning is more reliable when the phone does not scan at the same time.
        stopScan()
        selectedDevice = device
    }

    func markConnected(_ device: DiscoveredSensor) {
        connectedDeviceName = device.name
        selectedDevice = nil
    }

    private func add(_ device: DiscoveredSensor) {
        guard !discoveredDevices.contains(where: { $0.id == device.id }) else { return }
        discoveredDevices.append(device)
    }

    private func failScan(with error: Error) {
        cancelScanTasks()
        scanStatus = .failed(error as? SensorProvisioningError ?? .bluetoothUnavailable)
    }

    private func cancelScanTasks() {
        scanTask?.cancel()
        scanTask = nil
        scanTimeoutTask?.cancel()
        scanTimeoutTask = nil
    }
}
