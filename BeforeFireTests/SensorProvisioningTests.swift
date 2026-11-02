import Foundation
import Testing
@testable import BeforeFire

@MainActor
struct SensorWiFiCredentialsTests {
    @Test func acceptsValidValuesAndNormalizesSetupCode() throws {
        let credentials = try SensorWiFiCredentials(wiFiName: " Kitchen WiFi", password: "password1", setupCode: " AB3D5FGH \n")

        #expect(credentials.wiFiName == " Kitchen WiFi")
        #expect(credentials.password == "password1")
        #expect(credentials.setupCode == "ab3d5fgh")
    }

    @Test func acceptsEmptyPasswordForOpenNetwork() throws {
        let credentials = try SensorWiFiCredentials(wiFiName: "Guest", password: "", setupCode: "ab3d5fgh")

        #expect(credentials.password.isEmpty)
    }

    @Test func rejectsMissingWiFiName() {
        #expect(throws: SensorWiFiCredentialsIssue.missingWiFiName) {
            try SensorWiFiCredentials(wiFiName: "", password: "password1", setupCode: "ab3d5fgh")
        }
    }

    @Test func limitsWiFiNameByBytes() throws {
        // 16 two-byte characters fill the 32-byte limit. One more character is too long.
        _ = try SensorWiFiCredentials(wiFiName: String(repeating: "é", count: 16), password: "", setupCode: "ab3d5fgh")

        #expect(throws: SensorWiFiCredentialsIssue.wiFiNameTooLong) {
            try SensorWiFiCredentials(wiFiName: String(repeating: "é", count: 17), password: "", setupCode: "ab3d5fgh")
        }
    }

    @Test func rejectsPasswordOutsideWPALimits() {
        #expect(throws: SensorWiFiCredentialsIssue.passwordTooShort) {
            try SensorWiFiCredentials(wiFiName: "Home", password: "1234567", setupCode: "ab3d5fgh")
        }
        #expect(throws: SensorWiFiCredentialsIssue.passwordTooLong) {
            try SensorWiFiCredentials(wiFiName: "Home", password: String(repeating: "a", count: 65), setupCode: "ab3d5fgh")
        }
    }

    @Test(arguments: ["", "abc", "ab3d5fgh9"])
    func rejectsSetupCodeWithWrongLength(setupCode: String) {
        #expect(throws: SensorWiFiCredentialsIssue.invalidSetupCode) {
            try SensorWiFiCredentials(wiFiName: "Home", password: "password1", setupCode: setupCode)
        }
    }
}

@MainActor
struct SensorConnectionModelTests {
    private let kitchenSensor = DiscoveredSensor(id: UUID(uuidString: "00000000-0000-4000-8000-000000000001")!, name: "DAPUR_000001")
    private let pantrySensor = DiscoveredSensor(id: UUID(uuidString: "00000000-0000-4000-8000-000000000002")!, name: "DAPUR_000002")

    @Test func showsEachDiscoveredSensorOnce() async throws {
        let scanner = ControlledSensorScanner()
        let model = SensorConnectionModel(scanner: scanner, wiFiSender: RecordingWiFiSender())

        model.startScan()
        #expect(model.isScanning)
        scanner.continuation?.yield(kitchenSensor)
        scanner.continuation?.yield(kitchenSensor)
        scanner.continuation?.yield(pantrySensor)
        try await waitUntil { model.discoveredSensors.count == 2 }

        #expect(model.discoveredSensors == [kitchenSensor, pantrySensor])
        #expect(model.isScanning)
    }

    @Test func showsBluetoothFailure() async throws {
        let scanner = ControlledSensorScanner()
        let model = SensorConnectionModel(scanner: scanner, wiFiSender: RecordingWiFiSender())

        model.startScan()
        scanner.continuation?.finish(throwing: SensorProvisioningError.bluetoothPoweredOff)
        try await waitUntil { model.scanStatus != .scanning }

        #expect(model.scanStatus == .failed(.bluetoothPoweredOff))
    }

    @Test func mapsUnexpectedScanErrorToUnavailableBluetooth() async throws {
        let scanner = ControlledSensorScanner()
        let model = SensorConnectionModel(scanner: scanner, wiFiSender: RecordingWiFiSender())

        model.startScan()
        scanner.continuation?.finish(throwing: URLError(.unknown))
        try await waitUntil { model.scanStatus != .scanning }

        #expect(model.scanStatus == .failed(.bluetoothUnavailable))
    }

    @Test func stopsScanAfterScanDuration() async throws {
        let scanner = ControlledSensorScanner()
        let model = SensorConnectionModel(scanner: scanner, wiFiSender: RecordingWiFiSender(), scanDuration: .milliseconds(20))

        model.startScan()
        try await waitUntil { model.scanStatus == .finished }

        #expect(model.discoveredSensors.isEmpty)
        try await waitUntil { scanner.terminationCount == 1 }
    }

    @Test func selectingSensorStopsScan() async throws {
        let scanner = ControlledSensorScanner()
        let model = SensorConnectionModel(scanner: scanner, wiFiSender: RecordingWiFiSender())

        model.startScan()
        scanner.continuation?.yield(kitchenSensor)
        try await waitUntil { !model.discoveredSensors.isEmpty }
        model.select(kitchenSensor)

        #expect(model.selectedSensor == kitchenSensor)
        #expect(model.scanStatus == .finished)
        try await waitUntil { scanner.terminationCount == 1 }
    }

    @Test func restartingScanClearsPreviousResults() async throws {
        let scanner = ControlledSensorScanner()
        let model = SensorConnectionModel(scanner: scanner, wiFiSender: RecordingWiFiSender())

        model.startScan()
        scanner.continuation?.yield(kitchenSensor)
        try await waitUntil { !model.discoveredSensors.isEmpty }
        model.startScan()

        #expect(model.discoveredSensors.isEmpty)
        #expect(model.isScanning)
    }

    @Test func markingSensorConnectedUpdatesStatus() {
        let model = SensorConnectionModel(scanner: ControlledSensorScanner(), wiFiSender: RecordingWiFiSender())
        model.select(kitchenSensor)

        model.markConnected(kitchenSensor)

        #expect(model.connectedSensorName == "DAPUR_000001")
        #expect(model.selectedSensor == nil)
    }
}

@MainActor
struct SensorWiFiSetupModelTests {
    private let sensor = DiscoveredSensor(id: UUID(uuidString: "00000000-0000-4000-8000-000000000001")!, name: "DAPUR_000001")

    @Test func cannotSendWithoutRequiredValues() {
        let model = SensorWiFiSetupModel(sensor: sensor, wiFiSender: RecordingWiFiSender())
        #expect(!model.canSend)

        model.wiFiName = "Home"
        #expect(!model.canSend)

        model.setupCode = "ab3d5fgh"
        #expect(model.canSend)
    }

    @Test func invalidValuesShowMessageWithoutSending() {
        let sender = RecordingWiFiSender()
        let model = SensorWiFiSetupModel(sensor: sensor, wiFiSender: sender)
        model.wiFiName = "Home"
        model.setupCode = "abc"

        model.send()

        #expect(model.sendStatus == .failed(message: "The setup code must have 8 characters."))
        #expect(sender.sentCredentials.isEmpty)
    }

    @Test func successfulSendClearsPassword() async throws {
        let sender = RecordingWiFiSender()
        let model = SensorWiFiSetupModel(sensor: sensor, wiFiSender: sender)
        model.wiFiName = "Home"
        model.password = "password1"
        model.setupCode = "AB3D5FGH"

        model.send()
        #expect(model.isSending)
        try await waitUntil { !model.isSending }

        #expect(model.sendStatus == .succeeded(wiFiName: "Home"))
        #expect(model.password.isEmpty)
        #expect(sender.sentCredentials == [try SensorWiFiCredentials(wiFiName: "Home", password: "password1", setupCode: "ab3d5fgh")])
        #expect(sender.sensors == [sensor])
    }

    @Test func sendFailureShowsUserMessageAndKeepsValues() async throws {
        let sender = RecordingWiFiSender(error: SensorProvisioningError.sensorCouldNotJoinWiFi)
        let model = SensorWiFiSetupModel(sensor: sensor, wiFiSender: sender)
        model.wiFiName = "Home"
        model.password = "password1"
        model.setupCode = "ab3d5fgh"

        model.send()
        try await waitUntil { !model.isSending }

        #expect(model.sendStatus == .failed(message: "The sensor could not connect to the Wi-Fi network. Check the Wi-Fi name and password."))
        #expect(model.password == "password1")
    }

    @Test func wrongPasswordShowsPasswordMessage() async throws {
        let model = SensorWiFiSetupModel(sensor: sensor, wiFiSender: RecordingWiFiSender(error: SensorProvisioningError.wiFiPasswordRejected))
        model.wiFiName = "Home"
        model.password = "password1"
        model.setupCode = "ab3d5fgh"

        model.send()
        try await waitUntil { !model.isSending }

        #expect(model.sendStatus == .failed(message: "The Wi-Fi password is not correct."))
    }

    @Test func unexpectedErrorShowsGenericMessage() async throws {
        let model = SensorWiFiSetupModel(sensor: sensor, wiFiSender: RecordingWiFiSender(error: URLError(.unknown)))
        model.wiFiName = "Home"
        model.setupCode = "ab3d5fgh"

        model.send()
        try await waitUntil { !model.isSending }

        #expect(model.sendStatus == .failed(message: "The operation did not complete. Try again."))
    }

    @Test func cancelReturnsToEditing() async throws {
        let sender = RecordingWiFiSender(delay: .seconds(60))
        let model = SensorWiFiSetupModel(sensor: sensor, wiFiSender: sender)
        model.wiFiName = "Home"
        model.setupCode = "ab3d5fgh"

        model.send()
        model.cancelSend()

        #expect(model.sendStatus == .editing)
        try await Task.sleep(for: .milliseconds(20))
        #expect(model.sendStatus == .editing)
    }
}

// MARK: - Test doubles

@MainActor
private final class ControlledSensorScanner: SensorScanning {
    private(set) var continuation: AsyncThrowingStream<DiscoveredSensor, Error>.Continuation?
    private(set) var terminationCount = 0

    func discoverSensors() -> AsyncThrowingStream<DiscoveredSensor, Error> {
        let (stream, continuation) = AsyncThrowingStream<DiscoveredSensor, Error>.makeStream()
        continuation.onTermination = { [weak self] _ in
            let scanner = self
            Task { @MainActor in scanner?.terminationCount += 1 }
        }
        self.continuation = continuation
        return stream
    }
}

@MainActor
private final class RecordingWiFiSender: SensorWiFiSending {
    private let error: Error?
    private let delay: Duration?
    private(set) var sentCredentials: [SensorWiFiCredentials] = []
    private(set) var sensors: [DiscoveredSensor] = []

    init(error: Error? = nil, delay: Duration? = nil) {
        self.error = error
        self.delay = delay
    }

    func sendWiFiCredentials(_ credentials: SensorWiFiCredentials, to sensor: DiscoveredSensor) async throws {
        sentCredentials.append(credentials)
        sensors.append(sensor)
        if let delay {
            try await Task.sleep(for: delay)
        }
        if let error {
            throw error
        }
    }
}

struct ConditionTimeout: Error {}

@MainActor
func waitUntil(timeout: Duration = .seconds(2), _ condition: () -> Bool) async throws {
    let deadline = ContinuousClock.now + timeout
    while !condition() {
        guard ContinuousClock.now < deadline else { throw ConditionTimeout() }
        try await Task.sleep(for: .milliseconds(5))
    }
}
