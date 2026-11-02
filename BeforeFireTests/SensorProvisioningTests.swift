import Foundation
import Testing
@testable import BeforeFire

// MARK: - Fixtures

private enum Fixture {
    static let kitchenSensor = DiscoveredSensor(id: UUID(uuidString: "00000000-0000-4000-8000-000000000001")!, name: "DAPUR_000001")
    static let pantrySensor = DiscoveredSensor(id: UUID(uuidString: "00000000-0000-4000-8000-000000000002")!, name: "DAPUR_000002")
    static let validSetupCode = "ab3d5fgh"
    static let securedNetwork = SensorWiFiNetwork(ssid: "Home", signalStrength: -50, isSecured: true)
    static let openNetwork = SensorWiFiNetwork(ssid: "Guest", signalStrength: -70, isSecured: false)
    static let validPassword = "password1"
}

// MARK: - Models

struct SensorSetupCodeTests {
    @Test func normalizesCaseAndWhitespace() throws {
        #expect(try SensorSetupCode(" AB3D5FGH \n").value == "ab3d5fgh")
    }

    @Test(arguments: ["", "abc", "ab3d5fgh9", "        "])
    func rejectsWrongLength(rawValue: String) {
        #expect(throws: SensorWiFiCredentialsIssue.invalidSetupCode) {
            try SensorSetupCode(rawValue)
        }
    }
}

struct SensorWiFiCredentialsTests {
    @Test func keepsSpacesInWiFiName() throws {
        let credentials = try SensorWiFiCredentials(wiFiName: " Kitchen WiFi ", password: "password1", requiresPassword: true)

        #expect(credentials.wiFiName == " Kitchen WiFi ")
        #expect(credentials.password == "password1")
    }

    @Test func acceptsEmptyPasswordWhenNotRequired() throws {
        let credentials = try SensorWiFiCredentials(wiFiName: "Guest", password: "", requiresPassword: false)

        #expect(credentials.password.isEmpty)
    }

    @Test func rejectsEmptyPasswordWhenRequired() {
        #expect(throws: SensorWiFiCredentialsIssue.missingPassword) {
            try SensorWiFiCredentials(wiFiName: "Home", password: "", requiresPassword: true)
        }
    }

    @Test func rejectsMissingWiFiName() {
        #expect(throws: SensorWiFiCredentialsIssue.missingWiFiName) {
            try SensorWiFiCredentials(wiFiName: "", password: "password1", requiresPassword: true)
        }
    }

    @Test func limitsWiFiNameByBytes() throws {
        // 16 two-byte characters fill the 32-byte limit. One more character is too long.
        _ = try SensorWiFiCredentials(wiFiName: String(repeating: "é", count: 16), password: "", requiresPassword: false)

        #expect(throws: SensorWiFiCredentialsIssue.wiFiNameTooLong) {
            try SensorWiFiCredentials(wiFiName: String(repeating: "é", count: 17), password: "", requiresPassword: false)
        }
    }

    @Test func rejectsPasswordOutsideWPALimits() throws {
        _ = try SensorWiFiCredentials(wiFiName: "Home", password: "12345678", requiresPassword: true)
        _ = try SensorWiFiCredentials(wiFiName: "Home", password: String(repeating: "a", count: 64), requiresPassword: true)

        #expect(throws: SensorWiFiCredentialsIssue.passwordTooShort) {
            try SensorWiFiCredentials(wiFiName: "Home", password: "1234567", requiresPassword: true)
        }
        #expect(throws: SensorWiFiCredentialsIssue.passwordTooLong) {
            try SensorWiFiCredentials(wiFiName: "Home", password: String(repeating: "a", count: 65), requiresPassword: true)
        }
    }

    @Test func limitsPasswordByBytes() {
        // 33 two-byte characters are 66 bytes, which is more than the 64-byte limit.
        #expect(throws: SensorWiFiCredentialsIssue.passwordTooLong) {
            try SensorWiFiCredentials(wiFiName: "Home", password: String(repeating: "é", count: 33), requiresPassword: true)
        }
    }
}

struct SensorWiFiNetworkTests {
    @Test func displayListRemovesHiddenAndDuplicateNetworks() {
        let networks = [
            SensorWiFiNetwork(ssid: "", signalStrength: -40, isSecured: true),
            SensorWiFiNetwork(ssid: "Home", signalStrength: -75, isSecured: true),
            SensorWiFiNetwork(ssid: "Home", signalStrength: -50, isSecured: true),
            SensorWiFiNetwork(ssid: "Guest", signalStrength: -60, isSecured: false)
        ]

        let displayList = SensorWiFiNetwork.displayList(from: networks)

        #expect(displayList.map(\.ssid) == ["Home", "Guest"])
        #expect(displayList.first?.signalStrength == -50)
    }

    @Test func displayListSortsEqualSignalsByName() {
        let networks = [
            SensorWiFiNetwork(ssid: "Network 10", signalStrength: -60, isSecured: true),
            SensorWiFiNetwork(ssid: "Network 2", signalStrength: -60, isSecured: true)
        ]

        #expect(SensorWiFiNetwork.displayList(from: networks).map(\.ssid) == ["Network 2", "Network 10"])
    }

    @Test func displayListOfEmptyInputIsEmpty() {
        #expect(SensorWiFiNetwork.displayList(from: []).isEmpty)
    }

    @Test(arguments: [(-55, 1.0), (-56, 0.66), (-67, 0.66), (-68, 0.33), (-80, 0.33), (-81, 0.0)])
    func signalLevelUsesDisplayLimits(signalStrength: Int, expectedLevel: Double) {
        let network = SensorWiFiNetwork(ssid: "Home", signalStrength: signalStrength, isSecured: true)

        #expect(network.signalLevel == expectedLevel)
    }
}

// MARK: - Sensor search

@MainActor
struct SensorConnectionModelTests {
    private func makeModel(scanner: ControlledSensorScanner, scanDuration: Duration = .seconds(60)) -> SensorConnectionModel {
        SensorConnectionModel(
            scanner: scanner,
            connector: RecordingConnector(),
            scanDuration: scanDuration
        )
    }

    @Test func showsEachDiscoveredSensorOnce() async throws {
        let scanner = ControlledSensorScanner()
        let model = makeModel(scanner: scanner)

        model.startScan()
        #expect(model.isScanning)
        scanner.continuation?.yield(Fixture.kitchenSensor)
        scanner.continuation?.yield(Fixture.kitchenSensor)
        scanner.continuation?.yield(Fixture.pantrySensor)
        try await waitUntil { model.discoveredSensors.count == 2 }

        #expect(model.discoveredSensors == [Fixture.kitchenSensor, Fixture.pantrySensor])
        #expect(model.isScanning)
    }

    @Test func showsBluetoothFailure() async throws {
        let scanner = ControlledSensorScanner()
        let model = makeModel(scanner: scanner)

        model.startScan()
        scanner.continuation?.finish(throwing: SensorProvisioningError.bluetoothPoweredOff)
        try await waitUntil { model.scanStatus != .scanning }

        #expect(model.scanStatus == .failed(.bluetoothPoweredOff))
    }

    @Test func mapsUnexpectedScanErrorToUnavailableBluetooth() async throws {
        let scanner = ControlledSensorScanner()
        let model = makeModel(scanner: scanner)

        model.startScan()
        scanner.continuation?.finish(throwing: URLError(.unknown))
        try await waitUntil { model.scanStatus != .scanning }

        #expect(model.scanStatus == .failed(.bluetoothUnavailable))
    }

    @Test func finishesWhenScannerEndsStream() async throws {
        let scanner = ControlledSensorScanner()
        let model = makeModel(scanner: scanner)

        model.startScan()
        scanner.continuation?.finish()
        try await waitUntil { model.scanStatus == .finished }

        #expect(model.discoveredSensors.isEmpty)
    }

    @Test func stopsScanAfterScanDuration() async throws {
        let scanner = ControlledSensorScanner()
        let model = makeModel(scanner: scanner, scanDuration: .milliseconds(20))

        model.startScan()
        try await waitUntil { model.scanStatus == .finished }

        #expect(model.discoveredSensors.isEmpty)
        try await waitUntil { scanner.terminationCount == 1 }
    }

    @Test func userCanStopScan() async throws {
        let scanner = ControlledSensorScanner()
        let model = makeModel(scanner: scanner)

        model.startScan()
        model.stopScan()

        #expect(model.scanStatus == .finished)
        try await waitUntil { scanner.terminationCount == 1 }
    }

    @Test func stopWithoutScanKeepsIdleStatus() {
        let model = makeModel(scanner: ControlledSensorScanner())

        model.stopScan()

        #expect(model.scanStatus == .idle)
    }

    @Test func selectingSensorStopsScan() async throws {
        let scanner = ControlledSensorScanner()
        let model = makeModel(scanner: scanner)

        model.startScan()
        scanner.continuation?.yield(Fixture.kitchenSensor)
        try await waitUntil { !model.discoveredSensors.isEmpty }
        model.select(Fixture.kitchenSensor)

        #expect(model.selectedSensor == Fixture.kitchenSensor)
        #expect(model.scanStatus == .finished)
        try await waitUntil { scanner.terminationCount == 1 }
    }

    @Test func restartingScanClearsPreviousResults() async throws {
        let scanner = ControlledSensorScanner()
        let model = makeModel(scanner: scanner)

        model.startScan()
        scanner.continuation?.yield(Fixture.kitchenSensor)
        try await waitUntil { !model.discoveredSensors.isEmpty }
        model.startScan()

        #expect(model.discoveredSensors.isEmpty)
        #expect(model.isScanning)
    }

    @Test func markingSensorConnectedUpdatesStatus() {
        let model = makeModel(scanner: ControlledSensorScanner())
        model.select(Fixture.kitchenSensor)

        model.markConnected(Fixture.kitchenSensor)

        #expect(model.connectedSensorName == "DAPUR_000001")
        #expect(model.selectedSensor == nil)
    }

    @Test func simulatedModelUsesSimulationMode() {
        #expect(SensorConnectionModel.simulated().isSimulated)
    }
}

// MARK: - Wi-Fi setup

@MainActor
struct SensorWiFiSetupModelTests {
    // Default arguments run outside the main actor, so the doubles are created in the body.
    private func makeModel(connector: RecordingConnector? = nil) -> SensorWiFiSetupModel {
        SensorWiFiSetupModel(sensor: Fixture.kitchenSensor, connector: connector ?? RecordingConnector())
    }

    /// Connects with a valid setup code and waits until the network list shows.
    private func makeModelOnNetworksStep(session: FakeProvisioningSession? = nil) async throws -> SensorWiFiSetupModel {
        let model = makeModel(connector: RecordingConnector(session: session))
        model.setupCode = Fixture.validSetupCode
        model.connect()
        try await waitUntil { model.step == .networks && !model.isBusy }
        return model
    }

    // MARK: Setup code

    @Test func cannotConnectWithoutSetupCode() {
        let model = makeModel()

        #expect(!model.canConnect)
        model.setupCode = Fixture.validSetupCode
        #expect(model.canConnect)
    }

    @Test func invalidSetupCodeShowsMessageWithoutConnecting() {
        let connector = RecordingConnector()
        let model = makeModel(connector: connector)
        model.setupCode = "abc"

        model.connect()

        #expect(model.errorMessage == "The setup code must have 8 characters.")
        #expect(model.step == .setupCode)
        #expect(connector.setupCodes.isEmpty)
    }

    @Test func connectSendsNormalizedSetupCodeAndShowsNetworks() async throws {
        let session = FakeProvisioningSession(scanResults: [.success([Fixture.openNetwork, Fixture.securedNetwork])])
        let connector = RecordingConnector(session: session)
        let model = makeModel(connector: connector)
        model.setupCode = " AB3D5FGH "

        model.connect()
        #expect(model.activity == .connecting)
        try await waitUntil { model.step == .networks && !model.isBusy }

        #expect(connector.setupCodes == ["ab3d5fgh"])
        #expect(connector.sensors == [Fixture.kitchenSensor])
        #expect(model.networks == [Fixture.securedNetwork, Fixture.openNetwork])
        #expect(model.errorMessage == nil)
    }

    @Test func rejectedSetupCodeStaysOnSetupCodeStep() async throws {
        let connector = RecordingConnector(error: SensorProvisioningError.setupCodeRejected)
        let model = makeModel(connector: connector)
        model.setupCode = Fixture.validSetupCode

        model.connect()
        try await waitUntil { !model.isBusy }

        #expect(model.step == .setupCode)
        #expect(model.errorMessage == "The app could not make a secure connection to the sensor. Check the setup code on the sensor label.")
    }

    // MARK: Network list

    @Test func scanFailureKeepsNetworksStepForOtherNetwork() async throws {
        let session = FakeProvisioningSession(scanResults: [.failure(SensorProvisioningError.wiFiScanUnavailable)])
        let model = try await makeModelOnNetworksStep(session: session)

        #expect(model.networks.isEmpty)
        #expect(model.errorMessage == "The sensor could not search for Wi-Fi networks. Search again, or select Other Network and type the name.")
    }

    @Test func refreshLoadsNetworksAgain() async throws {
        let session = FakeProvisioningSession(scanResults: [
            .failure(SensorProvisioningError.wiFiScanUnavailable),
            .success([Fixture.securedNetwork])
        ])
        let model = try await makeModelOnNetworksStep(session: session)

        model.refreshNetworks()
        #expect(model.activity == .scanning)
        try await waitUntil { !model.isBusy }

        #expect(session.scanCount == 2)
        #expect(model.networks == [Fixture.securedNetwork])
        #expect(model.errorMessage == nil)
    }

    @Test func selectionIsIgnoredDuringScan() async throws {
        let model = try await makeModelOnNetworksStep()
        model.refreshNetworks()
        #expect(model.activity == .scanning)

        model.select(Fixture.securedNetwork)
        model.chooseOtherNetwork()

        #expect(model.step == .networks)
        try await waitUntil { !model.isBusy }
        model.chooseOtherNetwork()
        #expect(model.isOtherNetwork)
    }

    @Test func refreshIsIgnoredBeforeConnection() {
        let model = makeModel()

        model.refreshNetworks()

        #expect(model.activity == nil)
    }

    // MARK: Password step

    @Test func securedNetworkNeedsPassword() async throws {
        let model = try await makeModelOnNetworksStep()

        model.select(Fixture.securedNetwork)

        #expect(model.step == .password)
        #expect(model.requiresPassword)
        #expect(model.showsPasswordField)
        #expect(!model.isOtherNetwork)
        #expect(!model.canJoin)
        model.password = Fixture.validPassword
        #expect(model.canJoin)
    }

    @Test func openNetworkNeedsNoPassword() async throws {
        let model = try await makeModelOnNetworksStep()

        model.select(Fixture.openNetwork)

        #expect(!model.requiresPassword)
        #expect(!model.showsPasswordField)
        #expect(model.canJoin)
    }

    @Test func otherNetworkNeedsName() async throws {
        let model = try await makeModelOnNetworksStep()

        model.chooseOtherNetwork()

        #expect(model.isOtherNetwork)
        #expect(model.showsPasswordField)
        #expect(!model.canJoin)
        model.manualWiFiName = "Hidden"
        #expect(model.canJoin)
    }

    @Test func shortPasswordShowsMessageWithoutSending() async throws {
        let session = FakeProvisioningSession()
        let model = try await makeModelOnNetworksStep(session: session)
        model.select(Fixture.securedNetwork)
        model.password = "1234567"

        model.join()

        #expect(model.errorMessage == "The password must have a minimum of 8 characters.")
        #expect(session.sentCredentials.isEmpty)
    }

    @Test func goBackFromPasswordClearsPassword() async throws {
        let model = try await makeModelOnNetworksStep()
        model.select(Fixture.securedNetwork)
        model.password = Fixture.validPassword

        model.goBack()

        #expect(model.step == .networks)
        #expect(model.password.isEmpty)
    }

    @Test func goBackFromNetworksEndsSession() async throws {
        let session = FakeProvisioningSession(scanResults: [.success([Fixture.securedNetwork])])
        let model = try await makeModelOnNetworksStep(session: session)

        model.goBack()

        #expect(model.step == .setupCode)
        #expect(model.networks.isEmpty)
        #expect(session.disconnectCount == 1)
    }

    // MARK: Join

    @Test func joinSuccessShowsConnectedStep() async throws {
        let session = FakeProvisioningSession()
        let model = try await makeModelOnNetworksStep(session: session)
        model.select(Fixture.securedNetwork)
        model.password = Fixture.validPassword

        model.join()
        #expect(model.activity == .joining)
        try await waitUntil { !model.isBusy }

        #expect(model.step == .connected(wiFiName: "Home"))
        #expect(session.sentCredentials == [try SensorWiFiCredentials(wiFiName: "Home", password: "password1", requiresPassword: true)])
        #expect(session.disconnectCount == 1)
        #expect(model.password.isEmpty)
        #expect(model.errorMessage == nil)
        #expect(!model.canGoBack)
    }

    @Test func joinOpenNetworkSendsEmptyPassword() async throws {
        let session = FakeProvisioningSession()
        let model = try await makeModelOnNetworksStep(session: session)
        model.select(Fixture.openNetwork)

        model.join()
        try await waitUntil { !model.isBusy }

        #expect(model.step == .connected(wiFiName: "Guest"))
        #expect(session.sentCredentials.first?.password == "")
    }

    @Test func joinOtherNetworkSendsTypedName() async throws {
        let session = FakeProvisioningSession()
        let model = try await makeModelOnNetworksStep(session: session)
        model.chooseOtherNetwork()
        model.manualWiFiName = "Hidden"

        model.join()
        try await waitUntil { !model.isBusy }

        #expect(model.step == .connected(wiFiName: "Hidden"))
        #expect(session.sentCredentials.first?.wiFiName == "Hidden")
    }

    @Test func joinFailureKeepsPassword() async throws {
        let session = FakeProvisioningSession(sendError: SensorProvisioningError.wiFiPasswordRejected)
        let model = try await makeModelOnNetworksStep(session: session)
        model.select(Fixture.securedNetwork)
        model.password = Fixture.validPassword

        model.join()
        try await waitUntil { !model.isBusy }

        #expect(model.step == .password)
        #expect(model.password == "password1")
        #expect(model.errorMessage == "The Wi-Fi password is not correct.")
        #expect(session.disconnectCount == 0)
    }

    @Test func unexpectedJoinErrorShowsGenericMessage() async throws {
        let model = try await makeModelOnNetworksStep(session: FakeProvisioningSession(sendError: URLError(.unknown)))
        model.select(Fixture.openNetwork)

        model.join()
        try await waitUntil { !model.isBusy }

        #expect(model.errorMessage == "The operation did not complete. Try again.")
    }

    // MARK: Close

    @Test func closeDuringJoinCancelsAndEndsSession() async throws {
        let session = FakeProvisioningSession(sendDelay: .seconds(60))
        let model = try await makeModelOnNetworksStep(session: session)
        model.select(Fixture.securedNetwork)
        model.password = Fixture.validPassword
        model.join()
        try await waitUntil { session.sentCredentials.count == 1 }

        model.close()

        #expect(model.activity == nil)
        #expect(model.password.isEmpty)
        #expect(session.disconnectCount == 1)
        try await Task.sleep(for: .milliseconds(20))
        #expect(model.step == .password)
        #expect(model.errorMessage == nil)
    }
}

// MARK: - ESPProvision adapter

@MainActor
struct ESPProvisionConnectorTests {
    @Test func opensSecureSessionWithSensorNameAndSetupCode() async throws {
        let device = FakeProvisioningDevice()
        let finder = FakeDeviceFinder(result: .success(device))
        let connector = ESPProvisionConnector(finder: finder)

        _ = try await connector.connect(to: Fixture.kitchenSensor, setupCode: try SensorSetupCode(Fixture.validSetupCode))

        #expect(finder.requestedNames == ["DAPUR_000001"])
        #expect(finder.requestedSetupCodes == ["ab3d5fgh"])
        #expect(device.openSessionCount == 1)
        #expect(device.disconnectCount == 0)
    }

    @Test func missingSensorThrowsNotFound() async throws {
        let connector = ESPProvisionConnector(finder: FakeDeviceFinder(result: .failure(.sensorNotFound)))

        await #expect(throws: SensorProvisioningError.sensorNotFound) {
            _ = try await connector.connect(to: Fixture.kitchenSensor, setupCode: try SensorSetupCode(Fixture.validSetupCode))
        }
    }

    @Test func failedSecureSessionDisconnectsDevice() async throws {
        let device = FakeProvisioningDevice(openSessionResult: .failure(.setupCodeRejected))
        let connector = ESPProvisionConnector(finder: FakeDeviceFinder(result: .success(device)))

        await #expect(throws: SensorProvisioningError.setupCodeRejected) {
            _ = try await connector.connect(to: Fixture.kitchenSensor, setupCode: try SensorSetupCode(Fixture.validSetupCode))
        }
        #expect(device.disconnectCount == 1)
    }
}

@MainActor
struct ESPProvisionSensorSessionTests {
    private let credentials = try! SensorWiFiCredentials(wiFiName: "Home", password: "password1", requiresPassword: true)

    @Test func firstSendNeedsNoWiFiReset() async throws {
        let device = FakeProvisioningDevice()
        let session = ESPProvisionSensorSession(device: device)

        try await session.sendWiFi(credentials)

        #expect(device.sentWiFiNames == ["Home"])
        #expect(device.sentPasswords == ["password1"])
        #expect(device.resetCount == 0)
    }

    @Test func retryAfterFailedJoinResetsWiFiStatus() async throws {
        let device = FakeProvisioningDevice(sendResults: [.failure(.wiFiPasswordRejected), .success(())])
        let session = ESPProvisionSensorSession(device: device)

        await #expect(throws: SensorProvisioningError.wiFiPasswordRejected) {
            try await session.sendWiFi(credentials)
        }
        try await session.sendWiFi(credentials)

        #expect(device.resetCount == 1)
        #expect(device.sentWiFiNames.count == 2)
    }

    @Test func connectionFailureNeedsNoWiFiReset() async throws {
        let device = FakeProvisioningDevice(sendResults: [.failure(.sensorConnectionFailed), .success(())])
        let session = ESPProvisionSensorSession(device: device)

        await #expect(throws: SensorProvisioningError.sensorConnectionFailed) {
            try await session.sendWiFi(credentials)
        }
        try await session.sendWiFi(credentials)

        #expect(device.resetCount == 0)
    }

    @Test func failedResetStopsSend() async throws {
        let device = FakeProvisioningDevice(
            sendResults: [.failure(.wiFiNetworkNotFound)],
            resetResult: .failure(.sensorConnectionFailed)
        )
        let session = ESPProvisionSensorSession(device: device)

        await #expect(throws: SensorProvisioningError.wiFiNetworkNotFound) {
            try await session.sendWiFi(credentials)
        }
        await #expect(throws: SensorProvisioningError.sensorConnectionFailed) {
            try await session.sendWiFi(credentials)
        }

        #expect(device.sentWiFiNames.count == 1)
    }

    @Test func scanReturnsDeviceNetworks() async throws {
        let device = FakeProvisioningDevice(scanResult: .success([Fixture.securedNetwork]))
        let session = ESPProvisionSensorSession(device: device)

        #expect(try await session.scanWiFiNetworks() == [Fixture.securedNetwork])
    }

    @Test func disconnectDisconnectsDevice() {
        let device = FakeProvisioningDevice()

        ESPProvisionSensorSession(device: device).disconnect()

        #expect(device.disconnectCount == 1)
    }
}

@MainActor
struct ProvisioningStepTests {
    @Test func usesOnlyFirstResult() async throws {
        let value: Int = try await awaitProvisioningStep(onCancel: {}) { completion in
            completion(.success(1))
            completion(.failure(.sensorConnectionFailed))
            completion(.success(2))
        }

        #expect(value == 1)
    }

    @Test func mapsFailureToThrownError() async {
        await #expect(throws: SensorProvisioningError.sensorConnectionFailed) {
            let _: Int = try await awaitProvisioningStep(onCancel: {}) { completion in
                completion(.failure(.sensorConnectionFailed))
            }
        }
    }

    @Test func cancellationThrowsAndRunsCancelHandler() async throws {
        let cancelCounter = CallCounter()
        let task = Task {
            let _: Int = try await awaitProvisioningStep(onCancel: { cancelCounter.count += 1 }) { _ in
                // The step never completes, so only cancellation can end it.
            }
        }

        task.cancel()

        await #expect(throws: CancellationError.self) {
            try await task.value
        }
        try await waitUntil { cancelCounter.count == 1 }
    }
}

struct SensorConnectionCopyTests {
    @Test func credentialIssueHasUserMessage() {
        #expect(SensorConnectionCopy.message(for: SensorWiFiCredentialsIssue.missingWiFiName) == "Enter the Wi-Fi name.")
    }

    @Test func unknownErrorHasGenericMessage() {
        #expect(SensorConnectionCopy.message(for: URLError(.unknown)) == "The operation did not complete. Try again.")
    }

    @Test func successDescriptionNamesSensorAndNetwork() {
        let description = SensorConnectionCopy.successDescription(sensorName: "DAPUR_000001", wiFiName: "Home")

        #expect(description.contains("DAPUR_000001"))
        #expect(description.contains("Home"))
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
private final class RecordingConnector: SensorProvisioningConnecting {
    private let session: FakeProvisioningSession
    private let error: Error?
    private(set) var setupCodes: [String] = []
    private(set) var sensors: [DiscoveredSensor] = []

    init(session: FakeProvisioningSession? = nil, error: Error? = nil) {
        self.session = session ?? FakeProvisioningSession()
        self.error = error
    }

    func connect(to sensor: DiscoveredSensor, setupCode: SensorSetupCode) async throws -> any SensorProvisioningSession {
        setupCodes.append(setupCode.value)
        sensors.append(sensor)
        if let error {
            throw error
        }
        return session
    }
}

@MainActor
private final class FakeProvisioningSession: SensorProvisioningSession {
    /// Each scan uses the next result. The last result repeats.
    private var scanResults: [Result<[SensorWiFiNetwork], Error>]
    private let sendError: Error?
    private let sendDelay: Duration?
    private(set) var scanCount = 0
    private(set) var sentCredentials: [SensorWiFiCredentials] = []
    private(set) var disconnectCount = 0

    init(
        scanResults: [Result<[SensorWiFiNetwork], Error>] = [.success([Fixture.securedNetwork, Fixture.openNetwork])],
        sendError: Error? = nil,
        sendDelay: Duration? = nil
    ) {
        self.scanResults = scanResults
        self.sendError = sendError
        self.sendDelay = sendDelay
    }

    func scanWiFiNetworks() async throws -> [SensorWiFiNetwork] {
        scanCount += 1
        let result = scanResults.count > 1 ? scanResults.removeFirst() : scanResults[0]
        return try result.get()
    }

    func sendWiFi(_ credentials: SensorWiFiCredentials) async throws {
        sentCredentials.append(credentials)
        if let sendDelay {
            try await Task.sleep(for: sendDelay)
        }
        if let sendError {
            throw sendError
        }
    }

    func disconnect() {
        disconnectCount += 1
    }
}

@MainActor
private final class FakeDeviceFinder: ProvisioningDeviceFinding {
    private let result: Result<any ProvisioningDevice, SensorProvisioningError>
    private(set) var requestedNames: [String] = []
    private(set) var requestedSetupCodes: [String] = []

    init(result: Result<any ProvisioningDevice, SensorProvisioningError>) {
        self.result = result
    }

    func findDevice(named name: String, setupCode: String, completion: @escaping ProvisioningCompletion<any ProvisioningDevice>) {
        requestedNames.append(name)
        requestedSetupCodes.append(setupCode)
        completion(result)
    }

    func stopFinding() {}
}

@MainActor
private final class FakeProvisioningDevice: ProvisioningDevice {
    private let openSessionResult: Result<Void, SensorProvisioningError>
    private let scanResult: Result<[SensorWiFiNetwork], SensorProvisioningError>
    /// Each send uses the next result. After the list ends, sends succeed.
    private var sendResults: [Result<Void, SensorProvisioningError>]
    private let resetResult: Result<Void, SensorProvisioningError>
    private(set) var openSessionCount = 0
    private(set) var sentWiFiNames: [String] = []
    private(set) var sentPasswords: [String] = []
    private(set) var resetCount = 0
    private(set) var disconnectCount = 0

    init(
        openSessionResult: Result<Void, SensorProvisioningError> = .success(()),
        scanResult: Result<[SensorWiFiNetwork], SensorProvisioningError> = .success([]),
        sendResults: [Result<Void, SensorProvisioningError>] = [],
        resetResult: Result<Void, SensorProvisioningError> = .success(())
    ) {
        self.openSessionResult = openSessionResult
        self.scanResult = scanResult
        self.sendResults = sendResults
        self.resetResult = resetResult
    }

    func openSecureSession(completion: @escaping ProvisioningCompletion<Void>) {
        openSessionCount += 1
        completion(openSessionResult)
    }

    func scanWiFiNetworks(completion: @escaping ProvisioningCompletion<[SensorWiFiNetwork]>) {
        completion(scanResult)
    }

    func sendWiFi(name: String, password: String, completion: @escaping ProvisioningCompletion<Void>) {
        sentWiFiNames.append(name)
        sentPasswords.append(password)
        completion(sendResults.isEmpty ? .success(()) : sendResults.removeFirst())
    }

    func resetWiFiStatus(completion: @escaping ProvisioningCompletion<Void>) {
        resetCount += 1
        completion(resetResult)
    }

    func disconnect() {
        disconnectCount += 1
    }
}

@MainActor
private final class CallCounter {
    var count = 0
}

private struct ConditionTimeout: Error {}

@MainActor
private func waitUntil(timeout: Duration = .seconds(2), _ condition: () -> Bool) async throws {
    let deadline = ContinuousClock.now + timeout
    while !condition() {
        guard ContinuousClock.now < deadline else { throw ConditionTimeout() }
        try await Task.sleep(for: .milliseconds(5))
    }
}
