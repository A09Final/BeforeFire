import Foundation
import Observation

@MainActor
@Observable
final class SensorConnectionModel {
    enum ScanStatus: Equatable {
        case idle
        case scanning
        case finished
        case failed(SensorProvisioningError)
    }

    private(set) var scanStatus: ScanStatus = .idle
    private(set) var discoveredSensors: [DiscoveredSensor] = []
    /// Kept in memory only. The app does not yet read the sensor connection from HomeKit.
    private(set) var connectedSensorName: String?
    var selectedSensor: DiscoveredSensor?
    let isSimulated: Bool
    @ObservationIgnored let connector: any SensorProvisioningConnecting
    @ObservationIgnored let homeSetup: any SensorHomeSetupPerforming

    @ObservationIgnored private let scanner: any SensorScanning
    @ObservationIgnored private let scanDuration: Duration
    @ObservationIgnored private var scanTask: Task<Void, Never>?
    @ObservationIgnored private var scanTimeoutTask: Task<Void, Never>?

    init(
        scanner: any SensorScanning,
        connector: any SensorProvisioningConnecting,
        homeSetup: any SensorHomeSetupPerforming,
        scanDuration: Duration = SensorProvisioningConfiguration.scanDuration,
        isSimulated: Bool = false
    ) {
        self.scanner = scanner
        self.connector = connector
        self.homeSetup = homeSetup
        self.scanDuration = scanDuration
        self.isSimulated = isSimulated
    }

    static func live() -> SensorConnectionModel {
        SensorConnectionModel(
            scanner: BluetoothSensorScanner(),
            connector: ESPProvisionConnector(),
            homeSetup: HomeKitSensorHomeSetup()
        )
    }

    static func simulated() -> SensorConnectionModel {
        SensorConnectionModel(
            scanner: SimulatedSensorScanner(),
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
        discoveredSensors = []
        scanStatus = .scanning

        let sensorStream = scanner.discoverSensors()
        scanTask = Task { [weak self] in
            do {
                for try await sensor in sensorStream {
                    self?.add(sensor)
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

    func select(_ sensor: DiscoveredSensor) {
        // Bluetooth provisioning is more reliable when the phone does not scan at the same time.
        stopScan()
        selectedSensor = sensor
    }

    func markConnected(_ sensor: DiscoveredSensor) {
        connectedSensorName = sensor.name
        selectedSensor = nil
    }

    private func add(_ sensor: DiscoveredSensor) {
        guard !discoveredSensors.contains(where: { $0.id == sensor.id }) else { return }
        discoveredSensors.append(sensor)
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
