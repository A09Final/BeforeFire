import CoreBluetooth
import Foundation

/// Finds units of one type that advertise Wi-Fi provisioning over Bluetooth Low Energy.
final class BluetoothSensorScanner: NSObject, SensorScanning {
    private let kind: ProvisioningDeviceKind
    // The manager is created on the first scan, so iOS asks for Bluetooth access only when the user starts a search.
    private var centralManager: CBCentralManager?
    private var continuation: AsyncThrowingStream<DiscoveredSensor, Error>.Continuation?
    private var activeScanID: UUID?
    private var reportedSensorIDs: Set<UUID> = []

    init(kind: ProvisioningDeviceKind) {
        self.kind = kind
        super.init()
    }

    func discoverSensors() -> AsyncThrowingStream<DiscoveredSensor, Error> {
        stopScan()

        let (stream, continuation) = AsyncThrowingStream<DiscoveredSensor, Error>.makeStream()
        let scanID = UUID()
        activeScanID = scanID
        reportedSensorIDs = []
        self.continuation = continuation
        continuation.onTermination = { [weak self] _ in
            let scanner = self
            Task { @MainActor in
                // A late termination of an earlier scan must not stop the current scan.
                guard let scanner, scanner.activeScanID == scanID else { return }
                scanner.stopScan()
            }
        }

        if let centralManager {
            handle(centralManager.state)
        } else {
            // The delegate receives the first state update and then starts the scan.
            centralManager = CBCentralManager(delegate: self, queue: nil)
        }
        return stream
    }

    private func handle(_ state: CBManagerState) {
        guard continuation != nil else { return }

        switch state {
        case .poweredOn:
            // The firmware sets no custom service UUID, so the scan filters by advertised name.
            centralManager?.scanForPeripherals(withServices: nil)
        case .poweredOff:
            finishScan(throwing: .bluetoothPoweredOff)
        case .unauthorized:
            finishScan(throwing: .bluetoothUnauthorized)
        case .unsupported:
            finishScan(throwing: .bluetoothUnsupported)
        case .unknown, .resetting:
            // Core Bluetooth sends another state update when the state is known.
            break
        @unknown default:
            finishScan(throwing: .bluetoothUnavailable)
        }
    }

    private func finishScan(throwing error: SensorProvisioningError) {
        let continuation = self.continuation
        stopScan()
        continuation?.finish(throwing: error)
    }

    private func stopScan() {
        if centralManager?.isScanning == true {
            centralManager?.stopScan()
        }
        activeScanID = nil
        continuation = nil
    }
}

extension BluetoothSensorScanner: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        handle(central.state)
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let advertisedName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        guard let name = advertisedName ?? peripheral.name,
              kind.matches(advertisedName: name),
              reportedSensorIDs.insert(peripheral.identifier).inserted
        else { return }

        continuation?.yield(DiscoveredSensor(id: peripheral.identifier, name: name))
    }
}
