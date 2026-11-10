import Foundation
import HomeKit
import Testing
@testable import BeforeFire

// MARK: - Fixtures

private enum Fixture {
    static let kitchenSensor = DiscoveredDevice(id: UUID(uuidString: "00000000-0000-4000-8000-000000000001")!, name: "DAPUR_000001")
    static let pantrySensor = DiscoveredDevice(id: UUID(uuidString: "00000000-0000-4000-8000-000000000002")!, name: "DAPUR_000002")
    static let validSetupCode = "ab3d5fgh"
    static let securedNetwork = DeviceWiFiNetwork(ssid: "Home", signalStrength: -50, isSecured: true)
    static let openNetwork = DeviceWiFiNetwork(ssid: "Guest", signalStrength: -70, isSecured: false)
    static let validPassword = "password1"
}

// MARK: - Models

struct DeviceSetupCodeTests {
    @Test func normalizesCaseAndWhitespace() throws {
        #expect(try DeviceSetupCode(" AB3D5FGH \n").value == "ab3d5fgh")
    }

    @Test(arguments: ["", "abc", "ab3d5fgh9", "        "])
    func rejectsWrongLength(rawValue: String) {
        #expect(throws: DeviceWiFiCredentialsIssue.invalidSetupCode) {
            try DeviceSetupCode(rawValue)
        }
    }
}

struct DeviceWiFiCredentialsTests {
    @Test func keepsSpacesInWiFiName() throws {
        let credentials = try DeviceWiFiCredentials(wiFiName: " Kitchen WiFi ", password: "password1", requiresPassword: true)

        #expect(credentials.wiFiName == " Kitchen WiFi ")
        #expect(credentials.password == "password1")
    }

    @Test func acceptsEmptyPasswordWhenNotRequired() throws {
        let credentials = try DeviceWiFiCredentials(wiFiName: "Guest", password: "", requiresPassword: false)

        #expect(credentials.password.isEmpty)
    }

    @Test func rejectsEmptyPasswordWhenRequired() {
        #expect(throws: DeviceWiFiCredentialsIssue.missingPassword) {
            try DeviceWiFiCredentials(wiFiName: "Home", password: "", requiresPassword: true)
        }
    }

    @Test func rejectsMissingWiFiName() {
        #expect(throws: DeviceWiFiCredentialsIssue.missingWiFiName) {
            try DeviceWiFiCredentials(wiFiName: "", password: "password1", requiresPassword: true)
        }
    }

    @Test func limitsWiFiNameByBytes() throws {
        // 16 two-byte characters fill the 32-byte limit. One more character is too long.
        _ = try DeviceWiFiCredentials(wiFiName: String(repeating: "é", count: 16), password: "", requiresPassword: false)

        #expect(throws: DeviceWiFiCredentialsIssue.wiFiNameTooLong) {
            try DeviceWiFiCredentials(wiFiName: String(repeating: "é", count: 17), password: "", requiresPassword: false)
        }
    }

    @Test func rejectsPasswordOutsideWPALimits() throws {
        _ = try DeviceWiFiCredentials(wiFiName: "Home", password: "12345678", requiresPassword: true)
        _ = try DeviceWiFiCredentials(wiFiName: "Home", password: String(repeating: "a", count: 64), requiresPassword: true)

        #expect(throws: DeviceWiFiCredentialsIssue.passwordTooShort) {
            try DeviceWiFiCredentials(wiFiName: "Home", password: "1234567", requiresPassword: true)
        }
        #expect(throws: DeviceWiFiCredentialsIssue.passwordTooLong) {
            try DeviceWiFiCredentials(wiFiName: "Home", password: String(repeating: "a", count: 65), requiresPassword: true)
        }
    }

    @Test func limitsPasswordByBytes() {
        // 33 two-byte characters are 66 bytes, which is more than the 64-byte limit.
        #expect(throws: DeviceWiFiCredentialsIssue.passwordTooLong) {
            try DeviceWiFiCredentials(wiFiName: "Home", password: String(repeating: "é", count: 33), requiresPassword: true)
        }
    }
}

struct DeviceWiFiNetworkTests {
    @Test func displayListRemovesHiddenAndDuplicateNetworks() {
        let networks = [
            DeviceWiFiNetwork(ssid: "", signalStrength: -40, isSecured: true),
            DeviceWiFiNetwork(ssid: "Home", signalStrength: -75, isSecured: true),
            DeviceWiFiNetwork(ssid: "Home", signalStrength: -50, isSecured: true),
            DeviceWiFiNetwork(ssid: "Guest", signalStrength: -60, isSecured: false)
        ]

        let displayList = DeviceWiFiNetwork.displayList(from: networks)

        #expect(displayList.map(\.ssid) == ["Home", "Guest"])
        #expect(displayList.first?.signalStrength == -50)
    }

    @Test func displayListSortsEqualSignalsByName() {
        let networks = [
            DeviceWiFiNetwork(ssid: "Network 10", signalStrength: -60, isSecured: true),
            DeviceWiFiNetwork(ssid: "Network 2", signalStrength: -60, isSecured: true)
        ]

        #expect(DeviceWiFiNetwork.displayList(from: networks).map(\.ssid) == ["Network 2", "Network 10"])
    }

    @Test func displayListOfEmptyInputIsEmpty() {
        #expect(DeviceWiFiNetwork.displayList(from: []).isEmpty)
    }

    @Test(arguments: [(-55, 1.0), (-56, 0.66), (-67, 0.66), (-68, 0.33), (-80, 0.33), (-81, 0.0)])
    func signalLevelUsesDisplayLimits(signalStrength: Int, expectedLevel: Double) {
        let network = DeviceWiFiNetwork(ssid: "Home", signalStrength: signalStrength, isSecured: true)

        #expect(network.signalLevel == expectedLevel)
    }
}

// MARK: - Sensor search

@MainActor
struct DeviceConnectionModelTests {
    private func makeModel(scanner: ControlledDeviceScanner, scanDuration: Duration = .seconds(60)) -> DeviceConnectionModel {
        DeviceConnectionModel(
            kind: .sensor,
            scanner: scanner,
            connector: RecordingConnector(),
            homeSetup: RecordingHomeSetup(),
            scanDuration: scanDuration
        )
    }

    @Test func showsEachDiscoveredSensorOnce() async throws {
        let scanner = ControlledDeviceScanner()
        let model = makeModel(scanner: scanner)

        model.startScan()
        #expect(model.isScanning)
        scanner.continuation?.yield(Fixture.kitchenSensor)
        scanner.continuation?.yield(Fixture.kitchenSensor)
        scanner.continuation?.yield(Fixture.pantrySensor)
        try await waitUntil { model.discoveredDevices.count == 2 }

        #expect(model.discoveredDevices == [Fixture.kitchenSensor, Fixture.pantrySensor])
        #expect(model.isScanning)
    }

    @Test func showsBluetoothFailure() async throws {
        let scanner = ControlledDeviceScanner()
        let model = makeModel(scanner: scanner)

        model.startScan()
        scanner.continuation?.finish(throwing: DeviceProvisioningError.bluetoothPoweredOff)
        try await waitUntil { model.scanStatus != .scanning }

        #expect(model.scanStatus == .failed(.bluetoothPoweredOff))
    }

    @Test func mapsUnexpectedScanErrorToUnavailableBluetooth() async throws {
        let scanner = ControlledDeviceScanner()
        let model = makeModel(scanner: scanner)

        model.startScan()
        scanner.continuation?.finish(throwing: URLError(.unknown))
        try await waitUntil { model.scanStatus != .scanning }

        #expect(model.scanStatus == .failed(.bluetoothUnavailable))
    }

    @Test func finishesWhenScannerEndsStream() async throws {
        let scanner = ControlledDeviceScanner()
        let model = makeModel(scanner: scanner)

        model.startScan()
        scanner.continuation?.finish()
        try await waitUntil { model.scanStatus == .finished }

        #expect(model.discoveredDevices.isEmpty)
    }

    @Test func stopsScanAfterScanDuration() async throws {
        let scanner = ControlledDeviceScanner()
        let model = makeModel(scanner: scanner, scanDuration: .milliseconds(20))

        model.startScan()
        try await waitUntil { model.scanStatus == .finished }

        #expect(model.discoveredDevices.isEmpty)
        try await waitUntil { scanner.terminationCount == 1 }
    }

    @Test func userCanStopScan() async throws {
        let scanner = ControlledDeviceScanner()
        let model = makeModel(scanner: scanner)

        model.startScan()
        model.stopScan()

        #expect(model.scanStatus == .finished)
        try await waitUntil { scanner.terminationCount == 1 }
    }

    @Test func stopWithoutScanKeepsIdleStatus() {
        let model = makeModel(scanner: ControlledDeviceScanner())

        model.stopScan()

        #expect(model.scanStatus == .idle)
    }

    @Test func selectingSensorStopsScan() async throws {
        let scanner = ControlledDeviceScanner()
        let model = makeModel(scanner: scanner)

        model.startScan()
        scanner.continuation?.yield(Fixture.kitchenSensor)
        try await waitUntil { !model.discoveredDevices.isEmpty }
        model.select(Fixture.kitchenSensor)

        #expect(model.selectedDevice == Fixture.kitchenSensor)
        #expect(model.scanStatus == .finished)
        try await waitUntil { scanner.terminationCount == 1 }
    }

    @Test func restartingScanClearsPreviousResults() async throws {
        let scanner = ControlledDeviceScanner()
        let model = makeModel(scanner: scanner)

        model.startScan()
        scanner.continuation?.yield(Fixture.kitchenSensor)
        try await waitUntil { !model.discoveredDevices.isEmpty }
        model.startScan()

        #expect(model.discoveredDevices.isEmpty)
        #expect(model.isScanning)
    }

    @Test func markingSensorConnectedUpdatesStatus() {
        let model = makeModel(scanner: ControlledDeviceScanner())
        model.select(Fixture.kitchenSensor)

        model.markConnected(Fixture.kitchenSensor)

        #expect(model.connectedDeviceName == "DAPUR_000001")
        #expect(model.selectedDevice == nil)
    }

    @Test func simulatedModelUsesSimulationMode() {
        #expect(DeviceConnectionModel.simulated(kind: .sensor).isSimulated)
    }

    // MARK: Saved connection

    private func makeModel(
        kind: ProvisioningDeviceKind,
        store: InMemoryConnectedDeviceStore,
        setupCodeStore: InMemoryDeviceSetupCodeStore? = nil
    ) -> DeviceConnectionModel {
        DeviceConnectionModel(
            kind: kind,
            scanner: ControlledDeviceScanner(),
            connector: RecordingConnector(),
            homeSetup: RecordingHomeSetup(),
            connectedDeviceStore: store,
            setupCodeStore: setupCodeStore
        )
    }

    @Test func wiFiJoinSavesTheSetupCodeForTheNextSetup() throws {
        let setupCodes = InMemoryDeviceSetupCodeStore()
        let setupCode = try DeviceSetupCode(Fixture.validSetupCode)
        makeModel(kind: .sensor, store: InMemoryConnectedDeviceStore(), setupCodeStore: setupCodes)
            .rememberJoined(Fixture.kitchenSensor, setupCode: setupCode)

        let reopenedModel = makeModel(kind: .sensor, store: InMemoryConnectedDeviceStore(), setupCodeStore: setupCodes)

        #expect(reopenedModel.savedSetupCode(for: Fixture.kitchenSensor) == setupCode)
        #expect(reopenedModel.savedSetupCode(for: Fixture.pantrySensor) == nil)
    }

    @Test func disconnectForgetsTheUnitAndItsSetupCode() throws {
        let store = InMemoryConnectedDeviceStore()
        let setupCodes = InMemoryDeviceSetupCodeStore()
        let model = makeModel(kind: .sensor, store: store, setupCodeStore: setupCodes)
        model.rememberJoined(Fixture.kitchenSensor, setupCode: try DeviceSetupCode(Fixture.validSetupCode))

        model.disconnect()

        #expect(model.connectedDeviceName == nil)
        #expect(store.connectedDeviceName(for: .sensor) == nil)
        #expect(model.savedSetupCode(for: Fixture.kitchenSensor) == nil)
        #expect(makeModel(kind: .sensor, store: store, setupCodeStore: setupCodes).connectedDeviceName == nil)
    }

    @Test func forgetSetupCodeKeepsTheConnectedUnit() throws {
        let setupCodes = InMemoryDeviceSetupCodeStore()
        let model = makeModel(kind: .sensor, store: InMemoryConnectedDeviceStore(), setupCodeStore: setupCodes)
        model.rememberJoined(Fixture.kitchenSensor, setupCode: try DeviceSetupCode(Fixture.validSetupCode))

        model.forgetSetupCode(for: Fixture.kitchenSensor)

        #expect(model.savedSetupCode(for: Fixture.kitchenSensor) == nil)
        #expect(model.connectedDeviceName == Fixture.kitchenSensor.name)
    }

    @Test func keychainSetupCodeStoreKeepsOneCodePerUnit() throws {
        let store = KeychainDeviceSetupCodeStore(service: "DeviceSetupCodeTests.\(UUID().uuidString)")
        defer {
            try? store.removeSetupCode(for: Fixture.kitchenSensor.name)
            try? store.removeSetupCode(for: Fixture.pantrySensor.name)
        }
        let kitchenCode = try DeviceSetupCode(Fixture.validSetupCode)
        let pantryCode = try DeviceSetupCode("zz9y8x7w")

        try store.saveSetupCode(kitchenCode, for: Fixture.kitchenSensor.name)
        try store.saveSetupCode(pantryCode, for: Fixture.pantrySensor.name)
        // A second save replaces the code.
        try store.saveSetupCode(pantryCode, for: Fixture.kitchenSensor.name)

        #expect(store.setupCode(for: Fixture.kitchenSensor.name) == pantryCode)
        #expect(store.setupCode(for: Fixture.pantrySensor.name) == pantryCode)

        try store.removeSetupCode(for: Fixture.kitchenSensor.name)
        #expect(store.setupCode(for: Fixture.kitchenSensor.name) == nil)
        #expect(store.setupCode(for: Fixture.pantrySensor.name) == pantryCode)
    }

    @Test func showsTheSavedUnitWhenTheScreenOpensAgain() {
        let store = InMemoryConnectedDeviceStore()
        makeModel(kind: .sensor, store: store).markConnected(Fixture.kitchenSensor)

        let reopenedModel = makeModel(kind: .sensor, store: store)

        #expect(reopenedModel.connectedDeviceName == Fixture.kitchenSensor.name)
    }

    @Test func wiFiJoinSavesTheUnitAndKeepsTheSetupOpen() {
        let store = InMemoryConnectedDeviceStore()
        let model = makeModel(kind: .sensor, store: store)
        model.select(Fixture.kitchenSensor)

        model.rememberJoined(Fixture.kitchenSensor)

        #expect(model.connectedDeviceName == Fixture.kitchenSensor.name)
        #expect(store.connectedDeviceName(for: .sensor) == Fixture.kitchenSensor.name)
        // The Home setup step still needs the sheet.
        #expect(model.selectedDevice == Fixture.kitchenSensor)
    }

    @Test func sensorAndAlarmHaveSeparateSavedUnits() {
        let store = InMemoryConnectedDeviceStore()
        makeModel(kind: .sensor, store: store).markConnected(Fixture.kitchenSensor)

        #expect(makeModel(kind: .alarm, store: store).connectedDeviceName == nil)
    }

    @Test func simulatedUnitsAreNotSaved() {
        let model = DeviceConnectionModel.simulated(kind: .sensor)
        model.markConnected(Fixture.kitchenSensor)

        #expect(DeviceConnectionModel.simulated(kind: .sensor).connectedDeviceName == nil)
    }

    @Test func userDefaultsStoreKeepsTheNamePerUnitType() throws {
        let suiteName = "ConnectedDeviceStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = UserDefaultsConnectedDeviceStore(defaults: defaults)

        store.saveConnectedDeviceName("DAPUR_020F3C", for: .sensor)
        store.saveConnectedDeviceName("DAPUR_ALM_A1A2B3", for: .alarm)

        #expect(store.connectedDeviceName(for: .sensor) == "DAPUR_020F3C")
        #expect(store.connectedDeviceName(for: .alarm) == "DAPUR_ALM_A1A2B3")
    }
}

// MARK: - Wi-Fi and Home setup

@MainActor
struct DeviceWiFiSetupModelTests {
    // Default arguments run outside the main actor, so the doubles are created in the body.
    private func makeModel(
        connector: RecordingConnector? = nil,
        homeSetup: RecordingHomeSetup? = nil
    ) -> DeviceWiFiSetupModel {
        DeviceWiFiSetupModel(
            device: Fixture.kitchenSensor,
            kind: .sensor,
            connector: connector ?? RecordingConnector(),
            homeSetup: homeSetup ?? RecordingHomeSetup()
        )
    }

    /// Connects with a valid setup code and waits until the network list shows.
    private func makeModelOnNetworksStep(
        session: FakeProvisioningSession? = nil,
        homeSetup: RecordingHomeSetup? = nil
    ) async throws -> DeviceWiFiSetupModel {
        let model = makeModel(connector: RecordingConnector(session: session), homeSetup: homeSetup)
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
        #expect(connector.devices == [Fixture.kitchenSensor])
        #expect(model.networks == [Fixture.securedNetwork, Fixture.openNetwork])
        #expect(model.errorMessage == nil)
    }

    @Test func rejectedSetupCodeStaysOnSetupCodeStep() async throws {
        let connector = RecordingConnector(error: DeviceProvisioningError.setupCodeRejected)
        let model = makeModel(connector: connector)
        model.setupCode = Fixture.validSetupCode

        model.connect()
        try await waitUntil { !model.isBusy }

        #expect(model.step == .setupCode)
        #expect(model.errorMessage == "The app could not make a secure connection to the sensor. Check the setup code on the sensor label.")
    }

    // MARK: Network list

    @Test func scanFailureKeepsNetworksStepForOtherNetwork() async throws {
        let session = FakeProvisioningSession(scanResults: [.failure(DeviceProvisioningError.wiFiScanUnavailable)])
        let model = try await makeModelOnNetworksStep(session: session)

        #expect(model.networks.isEmpty)
        #expect(model.errorMessage == "The sensor could not search for Wi-Fi networks. Search again, or select Other Network and type the name.")
    }

    @Test func refreshLoadsNetworksAgain() async throws {
        let session = FakeProvisioningSession(scanResults: [
            .failure(DeviceProvisioningError.wiFiScanUnavailable),
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

    // MARK: Join and Home setup

    @Test(arguments: [ProvisioningDeviceKind.sensor, .alarm])
    func onboardingJoinsWiFiWithoutStartingHome(kind: ProvisioningDeviceKind) async throws {
        let session = FakeProvisioningSession()
        let homeSetup = RecordingHomeSetup()
        var joinedCount = 0
        let model = DeviceWiFiSetupModel(
            device: Fixture.kitchenSensor, kind: kind,
            connector: RecordingConnector(session: session), homeSetup: homeSetup,
            onWiFiJoined: { _, _ in joinedCount += 1 }, startsHomeSetupAfterWiFi: false
        )
        model.setupCode = Fixture.validSetupCode
        model.connect()
        try await waitUntil { model.step == .networks && !model.isBusy }
        model.select(Fixture.securedNetwork)
        model.password = Fixture.validPassword
        model.join()
        try await waitUntil { model.isWiFiConnected && !model.isBusy }

        #expect(model.step == .connected(wiFiName: Fixture.securedNetwork.ssid))
        #expect(homeSetup.callCount == 0)
        #expect(joinedCount == 1)
        #expect(session.disconnectCount == 1)
        #expect(model.password.isEmpty)
        model.close()
        #expect(model.isWiFiConnected)
    }

    @Test func onboardingJoinFailureDoesNotCompleteSetup() async throws {
        let homeSetup = RecordingHomeSetup()
        var joinedCount = 0
        let session = FakeProvisioningSession(sendError: DeviceProvisioningError.wiFiPasswordRejected)
        let model = DeviceWiFiSetupModel(
            device: Fixture.kitchenSensor, kind: .sensor,
            connector: RecordingConnector(session: session), homeSetup: homeSetup,
            onWiFiJoined: { _, _ in joinedCount += 1 }, startsHomeSetupAfterWiFi: false
        )
        model.setupCode = Fixture.validSetupCode
        model.connect()
        try await waitUntil { model.step == .networks && !model.isBusy }
        model.select(Fixture.securedNetwork)
        model.password = Fixture.validPassword
        model.join()
        try await waitUntil { !model.isBusy }

        #expect(model.step == .password)
        #expect(model.errorMessage != nil)
        #expect(joinedCount == 0)
        #expect(homeSetup.callCount == 0)
        model.close()
    }

    @Test func joinSuccessStartsHomeSetupAtOnce() async throws {
        let session = FakeProvisioningSession()
        let homeSetup = RecordingHomeSetup()
        let model = try await makeModelOnNetworksStep(session: session, homeSetup: homeSetup)
        model.select(Fixture.securedNetwork)
        model.password = Fixture.validPassword

        model.join()
        #expect(model.activity == .joining)
        try await waitUntil { model.step == .addedToHome }

        #expect(session.sentCredentials == [try DeviceWiFiCredentials(wiFiName: "Home", password: "password1", requiresPassword: true)])
        #expect(session.disconnectCount == 1)
        #expect(model.password.isEmpty)
        #expect(homeSetup.callCount == 1)
        #expect(model.activity == nil)
        #expect(model.errorMessage == nil)
    }

    @Test func joinSuccessReportsTheAcceptedSetupCodeOneTime() async throws {
        var joinedDevices: [String] = []
        var joinedSetupCodes: [String] = []
        let model = DeviceWiFiSetupModel(
            device: Fixture.kitchenSensor,
            kind: .sensor,
            connector: RecordingConnector(),
            homeSetup: RecordingHomeSetup(),
            onWiFiJoined: { device, setupCode in
                joinedDevices.append(device.name)
                joinedSetupCodes.append(setupCode.value)
            }
        )
        // The setup code is normalized before the secure session opens.
        model.setupCode = " \(Fixture.validSetupCode.uppercased()) "
        model.connect()
        try await waitUntil { model.step == .networks && !model.isBusy }
        model.select(Fixture.openNetwork)

        model.join()
        try await waitUntil { model.step == .addedToHome }

        #expect(joinedDevices == [Fixture.kitchenSensor.name])
        #expect(joinedSetupCodes == [try DeviceSetupCode(Fixture.validSetupCode).value])
    }

    // MARK: Saved setup code

    private func makeModelWithSavedCode(
        connector: RecordingConnector,
        savedSetupCode: String = Fixture.validSetupCode,
        onRejected: @escaping (DiscoveredDevice) -> Void = { _ in }
    ) throws -> DeviceWiFiSetupModel {
        DeviceWiFiSetupModel(
            device: Fixture.kitchenSensor,
            kind: .sensor,
            connector: connector,
            homeSetup: RecordingHomeSetup(),
            savedSetupCode: try DeviceSetupCode(savedSetupCode),
            onSavedSetupCodeRejected: onRejected
        )
    }

    @Test func savedSetupCodeGoesToTheWiFiListWithNoTypedCode() async throws {
        let connector = RecordingConnector()
        let model = try makeModelWithSavedCode(connector: connector)

        model.connectWithSavedSetupCode()
        #expect(model.isUsingSavedSetupCode)
        try await waitUntil { model.step == .networks && !model.isBusy }

        #expect(connector.setupCodes == [try DeviceSetupCode(Fixture.validSetupCode).value])
        #expect(!model.isUsingSavedSetupCode)
        #expect(model.errorMessage == nil)
    }

    @Test func rejectedSavedSetupCodeAsksForTheCode() async throws {
        var rejectedDevices: [String] = []
        let connector = RecordingConnector(error: DeviceProvisioningError.setupCodeRejected)
        let model = try makeModelWithSavedCode(connector: connector) { rejectedDevices.append($0.name) }

        model.connectWithSavedSetupCode()
        try await waitUntil { !model.isBusy }

        #expect(model.step == .setupCode)
        #expect(!model.isUsingSavedSetupCode)
        #expect(model.setupCode.isEmpty)
        #expect(model.errorMessage != nil)
        #expect(rejectedDevices == [Fixture.kitchenSensor.name])

        // The rejected code is used only one time.
        model.connectWithSavedSetupCode()
        #expect(connector.setupCodes.count == 1)
    }

    @Test func otherFailureKeepsTheSavedCodeInTheField() async throws {
        var rejectionCount = 0
        let connector = RecordingConnector(error: DeviceProvisioningError.deviceConnectionFailed)
        let model = try makeModelWithSavedCode(connector: connector) { _ in rejectionCount += 1 }

        model.connectWithSavedSetupCode()
        try await waitUntil { !model.isBusy }

        // The code can still be correct, so the user can try again with one tap.
        #expect(model.step == .setupCode)
        #expect(!model.isUsingSavedSetupCode)
        #expect(model.setupCode == (try DeviceSetupCode(Fixture.validSetupCode).value))
        #expect(model.canConnect)
        #expect(rejectionCount == 0)
    }

    @Test func noSavedSetupCodeShowsTheField() {
        let connector = RecordingConnector()
        let model = makeModel(connector: connector)

        model.connectWithSavedSetupCode()

        #expect(!model.isUsingSavedSetupCode)
        #expect(!model.isBusy)
        #expect(connector.setupCodes.isEmpty)
    }

    @Test func joinFailureReportsNoJoinedUnit() async throws {
        var joinCount = 0
        let session = FakeProvisioningSession(sendError: DeviceProvisioningError.wiFiPasswordRejected)
        let model = DeviceWiFiSetupModel(
            device: Fixture.kitchenSensor,
            kind: .sensor,
            connector: RecordingConnector(session: session),
            homeSetup: RecordingHomeSetup(),
            onWiFiJoined: { _, _ in joinCount += 1 }
        )
        model.setupCode = Fixture.validSetupCode
        model.connect()
        try await waitUntil { model.step == .networks && !model.isBusy }
        model.select(Fixture.securedNetwork)
        model.password = Fixture.validPassword

        model.join()
        try await waitUntil { model.errorMessage != nil }

        #expect(joinCount == 0)
    }

    @Test func showsWiFiConnectedStepDuringHomeSetup() async throws {
        let homeSetup = RecordingHomeSetup(delay: .seconds(60))
        let model = try await makeModelOnNetworksStep(homeSetup: homeSetup)
        model.select(Fixture.openNetwork)

        model.join()
        try await waitUntil { model.activity == .addingToHome }

        #expect(model.step == .connected(wiFiName: "Guest"))
        #expect(model.isWiFiConnected)
        #expect(!model.canAddToHome)
        model.close()
    }

    @Test func joinFailureKeepsPasswordAndSkipsHomeSetup() async throws {
        let session = FakeProvisioningSession(sendError: DeviceProvisioningError.wiFiPasswordRejected)
        let homeSetup = RecordingHomeSetup()
        let model = try await makeModelOnNetworksStep(session: session, homeSetup: homeSetup)
        model.select(Fixture.securedNetwork)
        model.password = Fixture.validPassword

        model.join()
        try await waitUntil { !model.isBusy }

        #expect(model.step == .password)
        #expect(model.password == "password1")
        #expect(model.errorMessage == "The Wi-Fi password is not correct.")
        #expect(homeSetup.callCount == 0)
        #expect(session.disconnectCount == 0)
    }

    @Test func cancelledHomeSetupKeepsWiFiAndAllowsRetry() async throws {
        let homeSetup = RecordingHomeSetup(errors: [DeviceHomeSetupError.cancelled, nil])
        let model = try await makeModelOnNetworksStep(homeSetup: homeSetup)
        model.select(Fixture.openNetwork)

        model.join()
        try await waitUntil { model.isWiFiConnected && !model.isBusy }

        #expect(model.step == .connected(wiFiName: "Guest"))
        #expect(model.errorMessage == "The Home setup closed before the sensor was added. Tap Add to Home to try again.")
        #expect(model.canAddToHome)

        model.addToHome()
        #expect(model.activity == .addingToHome)
        try await waitUntil { model.step == .addedToHome }

        #expect(homeSetup.callCount == 2)
    }

    @Test func failedHomeSetupShowsMessageAndAllowsRetry() async throws {
        let homeSetup = RecordingHomeSetup(errors: [DeviceHomeSetupError.accessoryNotFound, nil])
        let model = try await makeModelOnNetworksStep(homeSetup: homeSetup)
        model.select(Fixture.openNetwork)

        model.join()
        try await waitUntil { model.isWiFiConnected && !model.isBusy }

        #expect(model.errorMessage == "Home cannot find the sensor. Make sure that the sensor and your phone use the same Wi-Fi network, then try again.")

        model.addToHome()
        #expect(model.errorMessage == nil)
        try await waitUntil { model.step == .addedToHome }
    }

    @Test func unexpectedHomeErrorShowsGenericMessage() async throws {
        let homeSetup = RecordingHomeSetup(errors: [URLError(.unknown)])
        let model = try await makeModelOnNetworksStep(homeSetup: homeSetup)
        model.select(Fixture.openNetwork)

        model.join()
        try await waitUntil { model.isWiFiConnected && !model.isBusy }

        #expect(model.errorMessage == "The operation did not complete. Try again.")
    }

    @Test func addToHomeIsIgnoredBeforeWiFiConnects() async throws {
        let homeSetup = RecordingHomeSetup()
        let model = try await makeModelOnNetworksStep(homeSetup: homeSetup)

        model.addToHome()

        #expect(!model.canAddToHome)
        #expect(model.activity == nil)
        #expect(homeSetup.callCount == 0)
    }

    @Test func goBackIsIgnoredAfterWiFiConnects() async throws {
        let homeSetup = RecordingHomeSetup(errors: [DeviceHomeSetupError.cancelled])
        let model = try await makeModelOnNetworksStep(homeSetup: homeSetup)
        model.select(Fixture.openNetwork)
        model.join()
        try await waitUntil { model.isWiFiConnected && !model.isBusy }

        model.goBack()

        #expect(!model.canGoBack)
        #expect(model.step == .connected(wiFiName: "Guest"))
    }

    // MARK: Close

    @Test func closeDuringJoinCancelsAndEndsSession() async throws {
        let session = FakeProvisioningSession(sendDelay: .seconds(60))
        let homeSetup = RecordingHomeSetup()
        let model = try await makeModelOnNetworksStep(session: session, homeSetup: homeSetup)
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
        #expect(homeSetup.callCount == 0)
    }

    @Test func closeDuringHomeSetupKeepsWiFiConnectedStep() async throws {
        let homeSetup = RecordingHomeSetup(delay: .seconds(60))
        let model = try await makeModelOnNetworksStep(homeSetup: homeSetup)
        model.select(Fixture.openNetwork)
        model.join()
        try await waitUntil { model.activity == .addingToHome }

        model.close()
        try await Task.sleep(for: .milliseconds(20))

        #expect(model.activity == nil)
        #expect(model.step == .connected(wiFiName: "Guest"))
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

        _ = try await connector.connect(to: Fixture.kitchenSensor, setupCode: try DeviceSetupCode(Fixture.validSetupCode))

        #expect(finder.requestedNames == ["DAPUR_000001"])
        #expect(finder.requestedSetupCodes == ["ab3d5fgh"])
        #expect(device.openSessionCount == 1)
        #expect(device.disconnectCount == 0)
    }

    @Test func missingSensorThrowsNotFound() async throws {
        let connector = ESPProvisionConnector(finder: FakeDeviceFinder(result: .failure(.deviceNotFound)))

        await #expect(throws: DeviceProvisioningError.deviceNotFound) {
            _ = try await connector.connect(to: Fixture.kitchenSensor, setupCode: try DeviceSetupCode(Fixture.validSetupCode))
        }
    }

    @Test func failedSecureSessionDisconnectsDevice() async throws {
        let device = FakeProvisioningDevice(openSessionResult: .failure(.setupCodeRejected))
        let connector = ESPProvisionConnector(finder: FakeDeviceFinder(result: .success(device)))

        await #expect(throws: DeviceProvisioningError.setupCodeRejected) {
            _ = try await connector.connect(to: Fixture.kitchenSensor, setupCode: try DeviceSetupCode(Fixture.validSetupCode))
        }
        #expect(device.disconnectCount == 1)
    }
}

@MainActor
struct ESPProvisionDeviceSessionTests {
    private let credentials = try! DeviceWiFiCredentials(wiFiName: "Home", password: "password1", requiresPassword: true)

    @Test func firstSendNeedsNoWiFiReset() async throws {
        let device = FakeProvisioningDevice()
        let session = ESPProvisionDeviceSession(device: device)

        try await session.sendWiFi(credentials)

        #expect(device.sentWiFiNames == ["Home"])
        #expect(device.sentPasswords == ["password1"])
        #expect(device.resetCount == 0)
    }

    @Test func retryAfterFailedJoinResetsWiFiStatus() async throws {
        let device = FakeProvisioningDevice(sendResults: [.failure(.wiFiPasswordRejected), .success(())])
        let session = ESPProvisionDeviceSession(device: device)

        await #expect(throws: DeviceProvisioningError.wiFiPasswordRejected) {
            try await session.sendWiFi(credentials)
        }
        try await session.sendWiFi(credentials)

        #expect(device.resetCount == 1)
        #expect(device.sentWiFiNames.count == 2)
    }

    @Test func connectionFailureNeedsNoWiFiReset() async throws {
        let device = FakeProvisioningDevice(sendResults: [.failure(.deviceConnectionFailed), .success(())])
        let session = ESPProvisionDeviceSession(device: device)

        await #expect(throws: DeviceProvisioningError.deviceConnectionFailed) {
            try await session.sendWiFi(credentials)
        }
        try await session.sendWiFi(credentials)

        #expect(device.resetCount == 0)
    }

    @Test func failedResetStopsSend() async throws {
        let device = FakeProvisioningDevice(
            sendResults: [.failure(.wiFiNetworkNotFound)],
            resetResult: .failure(.deviceConnectionFailed)
        )
        let session = ESPProvisionDeviceSession(device: device)

        await #expect(throws: DeviceProvisioningError.wiFiNetworkNotFound) {
            try await session.sendWiFi(credentials)
        }
        await #expect(throws: DeviceProvisioningError.deviceConnectionFailed) {
            try await session.sendWiFi(credentials)
        }

        #expect(device.sentWiFiNames.count == 1)
    }

    @Test func scanReturnsDeviceNetworks() async throws {
        let device = FakeProvisioningDevice(scanResult: .success([Fixture.securedNetwork]))
        let session = ESPProvisionDeviceSession(device: device)

        #expect(try await session.scanWiFiNetworks() == [Fixture.securedNetwork])
    }

    @Test func disconnectDisconnectsDevice() {
        let device = FakeProvisioningDevice()

        ESPProvisionDeviceSession(device: device).disconnect()

        #expect(device.disconnectCount == 1)
    }
}

@MainActor
struct ProvisioningStepTests {
    @Test func usesOnlyFirstResult() async throws {
        let value: Int = try await awaitProvisioningStep(onCancel: {}) { completion in
            completion(.success(1))
            completion(.failure(.deviceConnectionFailed))
            completion(.success(2))
        }

        #expect(value == 1)
    }

    @Test func mapsFailureToThrownError() async {
        await #expect(throws: DeviceProvisioningError.deviceConnectionFailed) {
            let _: Int = try await awaitProvisioningStep(onCancel: {}) { completion in
                completion(.failure(.deviceConnectionFailed))
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

// MARK: - HomeKit adapter

struct HomeKitSetupErrorMappingTests {
    @Test(arguments: [
        (HMError.Code.operationCancelled, DeviceHomeSetupError.cancelled),
        (HMError.Code.missingEntitlement, DeviceHomeSetupError.missingEntitlement),
        (HMError.Code.accessoryNotReachable, DeviceHomeSetupError.accessoryNotFound),
        (HMError.Code.notFound, DeviceHomeSetupError.accessoryNotFound),
        (HMError.Code.communicationFailure, DeviceHomeSetupError.failed)
    ])
    func mapsHomeKitErrorCodes(code: HMError.Code, expectedError: DeviceHomeSetupError) {
        let error = NSError(domain: HMErrorDomain, code: code.rawValue)

        #expect(HomeKitSetupErrorMapping.error(for: error) == expectedError)
    }

    @Test func mapsClosedSystemSetupToCancelled() {
        let error = NSError(
            domain: HomeKitSetupErrorMapping.homeFoundationErrorDomain,
            code: HomeKitSetupErrorMapping.homeFoundationCancelledCode
        )

        #expect(HomeKitSetupErrorMapping.error(for: error) == .cancelled)
    }

    @Test func mapsOtherHomeFoundationCodeToFailure() {
        let error = NSError(domain: HomeKitSetupErrorMapping.homeFoundationErrorDomain, code: 1)

        #expect(HomeKitSetupErrorMapping.error(for: error) == .failed)
    }

    @Test func mapsOtherDomainToFailure() {
        let error = NSError(domain: NSURLErrorDomain, code: HMError.Code.operationCancelled.rawValue)

        #expect(HomeKitSetupErrorMapping.error(for: error) == .failed)
    }
}

struct DeviceConnectionCopyTests {
    private let sensorCopy = DeviceConnectionCopy(kind: .sensor)
    private let alarmCopy = DeviceConnectionCopy(kind: .alarm)

    @Test(arguments: [
        (DeviceHomeSetupError.unsupported, "This device cannot add accessories to Home."),
        (DeviceHomeSetupError.missingEntitlement, "BeforeFire does not have permission to add accessories to Home."),
        (DeviceHomeSetupError.failed, "The sensor was not added to Home. Try again.")
    ])
    func homeSetupErrorsHaveUserMessages(error: DeviceHomeSetupError, expectedMessage: String) {
        #expect(sensorCopy.message(for: error) == expectedMessage)
    }

    @Test func connectedDescriptionNamesSensorAndNetwork() {
        let description = sensorCopy.wiFiConnectedDescription(deviceName: "DAPUR_000001", wiFiName: "Home")

        #expect(description.contains("DAPUR_000001"))
        #expect(description.contains("Home"))
    }

    @Test func sensorTextIsUnchanged() {
        #expect(sensorCopy.screenTitle == "Sensor Connection")
        #expect(sensorCopy.connectButton == "Connect Sensor")
        #expect(sensorCopy.noDevicesFound == "No sensors found. Make sure that the sensor light is purple, then try again.")
        #expect(sensorCopy.message(for: DeviceProvisioningError.deviceNotFound)
            == "The sensor was not found. Move near the sensor and make sure that the sensor light is purple.")
    }

    @Test func alarmTextNamesTheAlarm() {
        #expect(alarmCopy.screenTitle == "Alarm Connection")
        #expect(alarmCopy.unitName == "Alarm")
        #expect(alarmCopy.connectButton == "Connect Alarm")
        #expect(alarmCopy.devicesFoundHeader == "Alarms Found")
        #expect(alarmCopy.devicesFoundFooter == "Tap an alarm to connect it to your Wi-Fi network.")
        #expect(alarmCopy.noDevicesFound == "No alarms found. Make sure that the alarm screen shows SETUP WIFI, then try again.")
        #expect(alarmCopy.networksFooter.hasPrefix("The alarm can connect only"))
    }

    @Test func alarmSetupCodeTextPointsToAlarmScreen() {
        #expect(alarmCopy.setupCodeFooter.contains("after PIN on the alarm screen"))
        #expect(alarmCopy.message(for: DeviceProvisioningError.setupCodeRejected)
            == "The app could not make a secure connection to the alarm. Check the setup code after PIN on the alarm screen.")
    }

    @Test(arguments: [
        DeviceProvisioningError.deviceNotFound, .deviceConnectionFailed, .setupCodeRejected,
        .wiFiScanUnavailable, .wiFiNetworkNotFound, .deviceCouldNotJoinWiFi
    ])
    func alarmProvisioningErrorsDoNotNameTheSensor(error: DeviceProvisioningError) {
        let message = alarmCopy.message(for: error)

        #expect(message.localizedCaseInsensitiveContains("alarm"))
        #expect(!message.localizedCaseInsensitiveContains("sensor"))
    }

    @Test(arguments: [DeviceHomeSetupError.cancelled, .accessoryNotFound, .failed])
    func alarmHomeSetupErrorsDoNotNameTheSensor(error: DeviceHomeSetupError) {
        let message = alarmCopy.message(for: error)

        #expect(message.localizedCaseInsensitiveContains("alarm"))
        #expect(!message.localizedCaseInsensitiveContains("sensor"))
    }
}

// MARK: - Unit types

struct ProvisioningDeviceKindTests {
    @Test(arguments: [
        ("DAPUR_A1B2C3", true),
        ("DAPUR_ALM_A1B2C3", false),
        ("DAPUR", false),
        ("Other_A1B2C3", false),
        ("", false)
    ])
    func sensorMatchesOnlySensorNames(name: String, isMatch: Bool) {
        #expect(ProvisioningDeviceKind.sensor.matches(advertisedName: name) == isMatch)
    }

    @Test(arguments: [
        ("DAPUR_ALM_A1B2C3", true),
        ("DAPUR_A1B2C3", false),
        ("DAPUR_ALM", false),
        ("", false)
    ])
    func alarmMatchesOnlyAlarmNames(name: String, isMatch: Bool) {
        #expect(ProvisioningDeviceKind.alarm.matches(advertisedName: name) == isMatch)
    }

    @Test func simulatedDevicesMatchTheirUnitType() {
        for kind in [ProvisioningDeviceKind.sensor, .alarm] {
            let devices = SimulatedDeviceScanner.devices(for: kind)

            #expect(!devices.isEmpty)
            #expect(devices.allSatisfy { kind.matches(advertisedName: $0.name) })
        }
    }

    @MainActor
    @Test func simulatedAlarmModelFindsOnlyAlarms() async throws {
        let model = DeviceConnectionModel.simulated(kind: .alarm)

        model.startScan()
        try await waitUntil { model.discoveredDevices.count == SimulatedDeviceScanner.alarms.count }
        model.stopScan()

        #expect(model.kind == .alarm)
        #expect(model.copy.kind == .alarm)
        #expect(model.discoveredDevices == SimulatedDeviceScanner.alarms)
    }
}

// MARK: - Test doubles

@MainActor
private final class ControlledDeviceScanner: DeviceScanning {
    private(set) var continuation: AsyncThrowingStream<DiscoveredDevice, Error>.Continuation?
    private(set) var terminationCount = 0

    func discoverDevices() -> AsyncThrowingStream<DiscoveredDevice, Error> {
        let (stream, continuation) = AsyncThrowingStream<DiscoveredDevice, Error>.makeStream()
        continuation.onTermination = { [weak self] _ in
            let scanner = self
            Task { @MainActor in scanner?.terminationCount += 1 }
        }
        self.continuation = continuation
        return stream
    }
}

@MainActor
private final class RecordingConnector: DeviceProvisioningConnecting {
    private let session: FakeProvisioningSession
    private let error: Error?
    private(set) var setupCodes: [String] = []
    private(set) var devices: [DiscoveredDevice] = []

    init(session: FakeProvisioningSession? = nil, error: Error? = nil) {
        self.session = session ?? FakeProvisioningSession()
        self.error = error
    }

    func connect(to device: DiscoveredDevice, setupCode: DeviceSetupCode) async throws -> any DeviceProvisioningSession {
        setupCodes.append(setupCode.value)
        devices.append(device)
        if let error {
            throw error
        }
        return session
    }
}

@MainActor
private final class FakeProvisioningSession: DeviceProvisioningSession {
    /// Each scan uses the next result. The last result repeats.
    private var scanResults: [Result<[DeviceWiFiNetwork], Error>]
    private let sendError: Error?
    private let sendDelay: Duration?
    private(set) var scanCount = 0
    private(set) var sentCredentials: [DeviceWiFiCredentials] = []
    private(set) var disconnectCount = 0

    init(
        scanResults: [Result<[DeviceWiFiNetwork], Error>] = [.success([Fixture.securedNetwork, Fixture.openNetwork])],
        sendError: Error? = nil,
        sendDelay: Duration? = nil
    ) {
        self.scanResults = scanResults
        self.sendError = sendError
        self.sendDelay = sendDelay
    }

    func scanWiFiNetworks() async throws -> [DeviceWiFiNetwork] {
        scanCount += 1
        let result = scanResults.count > 1 ? scanResults.removeFirst() : scanResults[0]
        return try result.get()
    }

    func sendWiFi(_ credentials: DeviceWiFiCredentials) async throws {
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
private final class RecordingHomeSetup: DeviceHomeSetupPerforming {
    /// Each call uses the next value. `nil` means success. After the list ends, calls succeed.
    private var errors: [Error?]
    private let delay: Duration?
    private(set) var callCount = 0

    init(errors: [Error?] = [], delay: Duration? = nil) {
        self.errors = errors
        self.delay = delay
    }

    func addDeviceToHome() async throws {
        callCount += 1
        if let delay {
            try await Task.sleep(for: delay)
        }
        if !errors.isEmpty, let error = errors.removeFirst() {
            throw error
        }
    }
}

@MainActor
private final class FakeDeviceFinder: ProvisioningDeviceFinding {
    private let result: Result<any ProvisioningDevice, DeviceProvisioningError>
    private(set) var requestedNames: [String] = []
    private(set) var requestedSetupCodes: [String] = []

    init(result: Result<any ProvisioningDevice, DeviceProvisioningError>) {
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
    private let openSessionResult: Result<Void, DeviceProvisioningError>
    private let scanResult: Result<[DeviceWiFiNetwork], DeviceProvisioningError>
    /// Each send uses the next result. After the list ends, sends succeed.
    private var sendResults: [Result<Void, DeviceProvisioningError>]
    private let resetResult: Result<Void, DeviceProvisioningError>
    private(set) var openSessionCount = 0
    private(set) var sentWiFiNames: [String] = []
    private(set) var sentPasswords: [String] = []
    private(set) var resetCount = 0
    private(set) var disconnectCount = 0

    init(
        openSessionResult: Result<Void, DeviceProvisioningError> = .success(()),
        scanResult: Result<[DeviceWiFiNetwork], DeviceProvisioningError> = .success([]),
        sendResults: [Result<Void, DeviceProvisioningError>] = [],
        resetResult: Result<Void, DeviceProvisioningError> = .success(())
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

    func scanWiFiNetworks(completion: @escaping ProvisioningCompletion<[DeviceWiFiNetwork]>) {
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

/// Keeps saved unit names in memory, so the tests do not change the app settings.
private final class InMemoryConnectedDeviceStore: ConnectedDeviceStoring {
    private var names: [ProvisioningDeviceKind: String] = [:]

    func connectedDeviceName(for kind: ProvisioningDeviceKind) -> String? { names[kind] }
    func saveConnectedDeviceName(_ name: String, for kind: ProvisioningDeviceKind) { names[kind] = name }
    func removeConnectedDeviceName(for kind: ProvisioningDeviceKind) { names[kind] = nil }
}

/// Keeps setup codes in memory, so the tests do not change the Keychain of the app.
private final class InMemoryDeviceSetupCodeStore: DeviceSetupCodeStoring {
    private(set) var codes: [String: DeviceSetupCode] = [:]

    func setupCode(for deviceName: String) -> DeviceSetupCode? { codes[deviceName] }
    func saveSetupCode(_ setupCode: DeviceSetupCode, for deviceName: String) throws { codes[deviceName] = setupCode }
    func removeSetupCode(for deviceName: String) throws { codes[deviceName] = nil }
}
