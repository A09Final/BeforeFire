import Foundation

/// One step result from the provisioning SDK, already converted to app types.
typealias ProvisioningCompletion<Value> = @Sendable (Result<Value, SensorProvisioningError>) -> Void

// These boundaries keep the ESPProvision SDK in one adapter file, so tests can check the steps without hardware.
protocol ProvisioningDeviceFinding {
    func findDevice(named name: String, setupCode: String, completion: @escaping ProvisioningCompletion<any ProvisioningDevice>)
    func stopFinding()
}

protocol ProvisioningDevice: AnyObject, Sendable {
    func openSecureSession(completion: @escaping ProvisioningCompletion<Void>)
    func scanWiFiNetworks(completion: @escaping ProvisioningCompletion<[SensorWiFiNetwork]>)
    func sendWiFi(name: String, password: String, completion: @escaping ProvisioningCompletion<Void>)
    func resetWiFiStatus(completion: @escaping ProvisioningCompletion<Void>)
    func disconnect()
}

/// Opens Espressif BLE provisioning sessions, as `bme688_ld2410b.ino` expects.
struct ESPProvisionConnector: SensorProvisioningConnecting {
    private let finder: any ProvisioningDeviceFinding

    init(finder: any ProvisioningDeviceFinding = ESPProvisionDeviceFinder()) {
        self.finder = finder
    }

    func connect(to sensor: DiscoveredSensor, setupCode: SensorSetupCode) async throws -> any SensorProvisioningSession {
        let finder = finder
        let device = try await awaitProvisioningStep(onCancel: { finder.stopFinding() }) { completion in
            finder.findDevice(named: sensor.name, setupCode: setupCode.value, completion: completion)
        }
        do {
            try await awaitProvisioningStep(onCancel: { device.disconnect() }) { completion in
                device.openSecureSession(completion: completion)
            }
        } catch {
            device.disconnect()
            throw error
        }
        return ESPProvisionSensorSession(device: device)
    }
}

final class ESPProvisionSensorSession: SensorProvisioningSession {
    private let device: any ProvisioningDevice
    // After a failed join, the firmware accepts new Wi-Fi values only after a reset of its Wi-Fi state.
    private var needsWiFiStatusReset = false

    init(device: any ProvisioningDevice) {
        self.device = device
    }

    func scanWiFiNetworks() async throws -> [SensorWiFiNetwork] {
        let device = device
        return try await awaitProvisioningStep(onCancel: { device.disconnect() }) { completion in
            device.scanWiFiNetworks(completion: completion)
        }
    }

    func sendWiFi(_ credentials: SensorWiFiCredentials) async throws {
        let device = device
        if needsWiFiStatusReset {
            try await awaitProvisioningStep(onCancel: { device.disconnect() }) { completion in
                device.resetWiFiStatus(completion: completion)
            }
            needsWiFiStatusReset = false
        }

        do {
            try await awaitProvisioningStep(onCancel: { device.disconnect() }) { completion in
                device.sendWiFi(name: credentials.wiFiName, password: credentials.password, completion: completion)
            }
        } catch let error as SensorProvisioningError where Self.isWiFiJoinFailure(error) {
            needsWiFiStatusReset = true
            throw error
        }
    }

    func disconnect() {
        device.disconnect()
    }

    private static func isWiFiJoinFailure(_ error: SensorProvisioningError) -> Bool {
        [.wiFiPasswordRejected, .wiFiNetworkNotFound, .sensorCouldNotJoinWiFi].contains(error)
    }
}

/// Converts one callback step to async. Only the first result counts, because the SDK can send more than one status.
func awaitProvisioningStep<Value: Sendable>(
    onCancel: @escaping @MainActor () -> Void,
    start: (@escaping ProvisioningCompletion<Value>) -> Void
) async throws -> Value {
    let gate = ProvisioningResultGate<Value>()
    return try await withTaskCancellationHandler {
        try await withCheckedThrowingContinuation { continuation in
            guard gate.install(continuation) else {
                continuation.resume(throwing: CancellationError())
                return
            }
            start { result in gate.complete(with: result.mapError { $0 as Error }) }
        }
    } onCancel: {
        gate.complete(with: .failure(CancellationError()))
        // The SDK uses Core Bluetooth objects that must stay on the main thread.
        Task { @MainActor in onCancel() }
    }
}

/// Resumes a continuation one time. The SDK can call back from other threads, so a lock protects the state.
nonisolated final class ProvisioningResultGate<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Value, Error>?
    private var isCompleted = false

    /// Returns `false` when cancellation completed the gate before the step started.
    func install(_ continuation: CheckedContinuation<Value, Error>) -> Bool {
        lock.withLock {
            guard !isCompleted else { return false }
            self.continuation = continuation
            return true
        }
    }

    func complete(with result: Result<Value, Error>) {
        let pendingContinuation: CheckedContinuation<Value, Error>? = lock.withLock {
            guard !isCompleted else { return nil }
            isCompleted = true
            defer { continuation = nil }
            return continuation
        }
        pendingContinuation?.resume(with: result)
    }
}
