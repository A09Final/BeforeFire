import Foundation
import Testing
@testable import BeforeFire

// Reference values from BeforeFire-Backend README, "Kunci baca data sensor".
private let exampleSetupCode = "abcd2345"
private let exampleSerial = "DAPUR_A1B2C3"
private let exampleReadKey = "6055c941c040745007ad78c6cad28078f0e92dd4aaf06598a5e8a7446fb2b876"

@MainActor
private func exampleLink(address: String = "http://192.168.1.10:8080") throws -> SensorBackendLink {
    try SensorBackendLink(backendAddress: address, deviceID: exampleSerial, setupCode: exampleSetupCode)
}

// MARK: - Read key and link

@MainActor
struct SensorBackendLinkTests {
    @Test func readKeyMatchesBackendReference() throws {
        #expect(SensorReadKey.make(setupCode: exampleSetupCode, deviceID: exampleSerial) == exampleReadKey)
        #expect(try exampleLink().readKey == exampleReadKey)
    }

    @Test(arguments: [
        ("192.168.1.10", "http://192.168.1.10:8080"),
        ("192.168.1.10:8081", "http://192.168.1.10:8081"),
        (" http://192.168.1.10:8080/ ", "http://192.168.1.10:8080"),
        ("HTTPS://server.local", "https://server.local:8080")
    ])
    func normalizesBackendAddress(typed: String, expected: String) throws {
        #expect(try exampleLink(address: typed).backendAddress == expected)
    }

    @Test(arguments: ["", "ftp://192.168.1.10", "http://", "http://192.168.1.10:8080/api", "http://a b"])
    func rejectsBadBackendAddress(typed: String) {
        #expect(throws: SensorBackendLinkIssue.invalidBackendAddress) {
            try exampleLink(address: typed)
        }
    }

    @Test func normalizesSerialAndSetupCode() throws {
        let link = try SensorBackendLink(backendAddress: "192.168.1.10", deviceID: " dapur_a1b2c3 ",
                                         setupCode: " ABCD2345 ")
        #expect(link.deviceID == exampleSerial)
        #expect(link.setupCode == exampleSetupCode)
        #expect(link.readingsURL.absoluteString == "http://192.168.1.10:8080/v1/devices/DAPUR_A1B2C3/readings")
    }

    @Test(arguments: ["DAPUR_ALM_A1B2C3", "DAPUR_A1B2C", "DAPUR_A1B2C3D", "DAPUR_A1B2CG", "SENSOR_A1B2C3", ""])
    func rejectsSerialThatIsNotASensor(serial: String) {
        #expect(throws: SensorBackendLinkIssue.invalidSensorSerial) {
            try SensorBackendLink(backendAddress: "192.168.1.10", deviceID: serial, setupCode: exampleSetupCode)
        }
    }

    @Test func rejectsShortSetupCode() {
        #expect(throws: SensorBackendLinkIssue.invalidSetupCode) {
            try SensorBackendLink(backendAddress: "192.168.1.10", deviceID: exampleSerial, setupCode: "abc")
        }
    }
}

// MARK: - Response decoding

struct SensorReadingsSnapshotTests {
    @Test func decodesBackendResponse() throws {
        // A response of the real backend, with a fractional measuredAt that the app does not read.
        let body = Data("""
        {"deviceId":"DAPUR_A1B2C3","condition":"warning2","score":61.5,
         "readings":{"stoveTemperatureC":231.6,"iaq":45,"iaqAccuracy":3,"eco2Ppm":613,"presence":false,
                     "roomTemperatureC":30.1,"roomHumidityRH":55.5,"pressureHPa":1005.3},
         "unavailableSensors":[],"measuredAt":"2026-11-05T06:39:31.123456789Z",
         "ageSeconds":3,"isStale":false,"connection":"online"}
        """.utf8)

        let snapshot = try JSONDecoder().decode(SensorReadingsSnapshot.self, from: body)

        #expect(snapshot.deviceID == "DAPUR_A1B2C3")
        #expect(snapshot.condition == .warning2)
        #expect(snapshot.readings.stoveTemperatureC == 231.6)
        #expect(snapshot.readings.presence == false)
        #expect(snapshot.readings.iaqAccuracy == 3)
        #expect(snapshot.ageSeconds == 3)
        #expect(!snapshot.isStale)
        #expect(snapshot.connection == .online)
    }

    @Test func toleratesMissingAndNewValues() throws {
        let body = Data("""
        {"deviceId":"DAPUR_A1B2C3","condition":"smoke","readings":{},"connection":"sleeping"}
        """.utf8)

        let snapshot = try JSONDecoder().decode(SensorReadingsSnapshot.self, from: body)

        #expect(snapshot.condition == nil)
        #expect(snapshot.connection == .unknown)
        #expect(snapshot.unavailableSensors.isEmpty)
        // Without isStale the app cannot know that the values are current.
        #expect(snapshot.isStale)
    }
}

// MARK: - Monitor text

@MainActor
struct MonitorReadingsFormatterTests {
    private let formatter = MonitorReadingsFormatter(locale: Locale(identifier: "en_US"))

    private func snapshot(
        condition: SensorReadingsSnapshot.Condition? = nil,
        unavailableSensors: [String] = [],
        iaqAccuracy: Int = 3,
        isStale: Bool = false,
        connection: SensorReadingsSnapshot.Connection = .online
    ) -> SensorReadingsSnapshot {
        SensorReadingsSnapshot(
            deviceID: exampleSerial,
            condition: condition,
            readings: .init(stoveTemperatureC: 231.6, iaq: 120, iaqAccuracy: iaqAccuracy, eco2Ppm: 613,
                            presence: true, roomTemperatureC: 30.4, roomHumidityRH: 55.5, pressureHPa: 1005.3),
            unavailableSensors: unavailableSensors,
            isStale: isStale,
            connection: connection
        )
    }

    @Test func showsExampleValuesWhenNoSensorIsLinked() {
        #expect(formatter.content(for: .notConfigured) == nil)
    }

    @Test func formatsAllCardsInScreenOrder() {
        let content = formatter.content(for: snapshot())

        #expect(content.readings.map(\.id) == MonitorReadingsFormatter.cardOrder)
        #expect(content.readings.map(\.value) == ["232", "Lightly Polluted", "Detected", "30", "56", "1005"])
        #expect(content.readings.map(\.unit) == ["°C", nil, nil, "°C", "%", "hPa"])
        #expect(content.readings.first?.spokenValue == "232 degrees Celsius")
    }

    @Test func cardTitlesMatchExampleCards() {
        let liveTitles = formatter.content(for: snapshot()).readings.map(\.title)
        #expect(liveTitles == MonitorViewModel.mockContent.readings.map(\.title))
    }

    @Test(arguments: [
        (nil, "Unknown", false),
        (SensorReadingsSnapshot.Condition.normal, "Normal", false),
        (.warning1, "Unsafe", false),
        (.warning2, "Dangerous", false),
        (.alarm, "Alarm", true)
    ])
    func mapsConditionToStatus(condition: SensorReadingsSnapshot.Condition?, status: String, isDangerous: Bool) {
        let content = formatter.content(for: snapshot(condition: condition))
        #expect(content.statusValue == status)
        #expect(content.isDangerous == isDangerous)
    }

    @Test func hidesValuesOfUnavailableSensors() {
        let content = formatter.content(for: snapshot(unavailableSensors: ["bme", "thermal"]))
        #expect(content.readings.map(\.value) == ["—", "—", "Detected", "—", "—", "—"])
        #expect(content.readings[0].spokenValue == "Not available")
        #expect(content.readings[0].unit == nil)
    }

    @Test func hidesMissingValues() {
        var partial = snapshot()
        partial.readings = .init(presence: false)
        let content = formatter.content(for: partial)
        #expect(content.readings.map(\.value) == ["—", "—", "Not Detected", "—", "—", "—"])
    }

    @Test func pressureHasNoGroupingSeparatorInAnyRegion() {
        let content = MonitorReadingsFormatter(locale: Locale(identifier: "id_ID")).content(for: snapshot())
        #expect(content.readings.last?.value == "1005")
    }

    /// The Bosch IAQ classes, with 7 levels.
    @Test(arguments: [
        (0.0, "Excellent"), (50, "Excellent"),
        (51, "Good"), (100, "Good"),
        (101, "Lightly Polluted"), (150, "Lightly Polluted"),
        (151, "Moderately Polluted"), (200, "Moderately Polluted"),
        (201, "Heavily Polluted"), (220, "Heavily Polluted"), (250, "Heavily Polluted"),
        (251, "Severely Polluted"), (350, "Severely Polluted"),
        (351, "Extremely Polluted"), (500, "Extremely Polluted")
    ])
    func airQualityUsesTheBoschClasses(index: Double, label: String) {
        var values = snapshot()
        values.readings.iaq = index
        #expect(formatter.content(for: values).readings[1].value == label)
    }

    @Test func showsCalibrationBeforeAirQualityIsStable() {
        let content = formatter.content(for: snapshot(iaqAccuracy: 0))
        #expect(content.readings[1].value == "Calibrating")
    }

    @Test(arguments: [(isStale: true, connection: SensorReadingsSnapshot.Connection.online),
                      (isStale: false, connection: .offline)])
    func doesNotShowOldValues(isStale: Bool, connection: SensorReadingsSnapshot.Connection) {
        let content = formatter.content(for: snapshot(condition: .normal, isStale: isStale, connection: connection))
        #expect(content.statusValue == "Offline")
        #expect(content.readings.allSatisfy { $0.value == "—" })
        #expect(!content.isDangerous)
    }

    @Test func showsOfflineWhenTheServerFails() throws {
        let content = try #require(formatter.content(for: .failed(.backendUnreachable)))
        #expect(content.statusValue == "Offline")
        #expect(content.readings.allSatisfy { $0.value == "—" })
    }

    @Test func monitorViewModelShowsLiveContent() {
        var model = MonitorViewModel.mock
        model.show(formatter.content(for: snapshot(condition: .alarm)))

        #expect(model.displayedStatusValue == "Alarm")
        #expect(model.showsAlarmStatus)
        #expect(model.readings.first?.value == "232")

        // The developer preview still replaces the live values.
        model.isActionGuidanceVisible = true
        #expect(model.displayedStatusValue == "Unsafe")
        #expect(!model.showsAlarmStatus)
    }
}

// MARK: - HTTP client

/// Answers requests of the test URLSession without a network.
private final class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (Int, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            guard let handler = Self.handler else { throw URLError(.badServerResponse) }
            let (statusCode, body) = try handler(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: body)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

@MainActor
@Suite(.serialized)
struct SensorReadingsClientTests {
    private static let stubSession: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }()
    private let client = URLSessionSensorReadingsClient(session: stubSession)
    private let discoveryClient = URLSessionSensorDiscoveryClient(session: stubSession)

    @Test func sendsReadKeyAndDecodesResponse() async throws {
        var receivedRequest: URLRequest?
        StubURLProtocol.handler = { request in
            receivedRequest = request
            return (200, Data(#"{"deviceId":"DAPUR_A1B2C3","readings":{"presence":true},"isStale":false,"connection":"online","ageSeconds":2}"#.utf8))
        }

        let snapshot = try await client.fetchReadings(for: exampleLink())

        #expect(snapshot.readings.presence == true)
        #expect(receivedRequest?.url?.absoluteString == "http://192.168.1.10:8080/v1/devices/DAPUR_A1B2C3/readings")
        #expect(receivedRequest?.value(forHTTPHeaderField: "Authorization") == "Bearer \(exampleReadKey)")
    }

    @Test(arguments: [
        (401, #"{"error":"invalid_read_key"}"#, SensorReadingsFetchError.invalidReadKey),
        (404, #"{"error":"no_readings"}"#, .noReadings),
        (404, #"{"error":"unknown_device_id"}"#, .unknownDevice),
        (500, #"{"error":"internal_error"}"#, .unexpectedResponse),
        (200, "not json", .unexpectedResponse)
    ])
    func mapsErrorResponses(statusCode: Int, body: String, expected: SensorReadingsFetchError) async throws {
        StubURLProtocol.handler = { _ in (statusCode, Data(body.utf8)) }
        let link = try exampleLink()
        await #expect(throws: expected) {
            try await client.fetchReadings(for: link)
        }
    }

    @Test func readsTheDeviceList() async throws {
        var receivedURL: String?
        StubURLProtocol.handler = { request in
            receivedURL = request.url?.absoluteString
            return (200, Data(#"{"devices":[{"deviceId":"DAPUR_020F3C","connection":"online","updatedAt":"2026-11-05T08:54:20.5Z"},{"deviceId":"DAPUR_FFFFFF","connection":"offline"}]}"#.utf8))
        }

        let devices = try await discoveryClient.fetchDevices(serverURL: try exampleLink().backendURL)

        #expect(receivedURL == "http://192.168.1.10:8080/v1/devices")
        #expect(devices == [BackendDevice(deviceID: "DAPUR_020F3C", isOnline: true),
                            BackendDevice(deviceID: "DAPUR_FFFFFF", isOnline: false)])
    }

    @Test func deviceListErrors() async throws {
        let serverURL = try exampleLink().backendURL
        StubURLProtocol.handler = { _ in (500, Data()) }
        await #expect(throws: SensorReadingsFetchError.unexpectedResponse) {
            try await discoveryClient.fetchDevices(serverURL: serverURL)
        }
        StubURLProtocol.handler = { _ in throw URLError(.cannotConnectToHost) }
        await #expect(throws: SensorReadingsFetchError.backendUnreachable) {
            try await discoveryClient.fetchDevices(serverURL: serverURL)
        }
    }

    @Test func mapsNetworkFailure() async throws {
        StubURLProtocol.handler = { _ in throw URLError(.cannotConnectToHost) }
        let link = try exampleLink()
        await #expect(throws: SensorReadingsFetchError.backendUnreachable) {
            try await client.fetchReadings(for: link)
        }
    }
}

// MARK: - Refresh state

private final class ScriptedReadingsClient: SensorReadingsFetching {
    var results: [Result<SensorReadingsSnapshot, Error>]
    private(set) var requestCount = 0

    init(results: [Result<SensorReadingsSnapshot, Error>]) {
        self.results = results
    }

    func fetchReadings(for link: SensorBackendLink) async throws -> SensorReadingsSnapshot {
        requestCount += 1
        return try results.removeFirst().get()
    }
}

@MainActor
struct MonitorLiveReadingsModelTests {
    private let fixedDate = Date(timeIntervalSince1970: 1_793_000_000)

    @Test func keepsTheLastUpdateAfterAFailure() async throws {
        let snapshot = SensorReadingsSnapshot(deviceID: exampleSerial)
        let client = ScriptedReadingsClient(results: [.success(snapshot), .failure(SensorReadingsFetchError.invalidReadKey)])
        let model = MonitorLiveReadingsModel(client: client, now: { fixedDate })
        let link = try exampleLink()

        // One loop step: the loop sets the link, refreshes, then the cancelled sleep ends it.
        let task = Task { await model.refreshRepeatedly(for: link) }
        while client.requestCount == 0 { await Task.yield() }
        task.cancel()
        await task.value

        #expect(model.status == .updated(snapshot))
        #expect(model.lastUpdatedAt == fixedDate)

        await model.refresh(link)
        #expect(model.status == .failed(.invalidReadKey))
        #expect(model.lastUpdatedAt == fixedDate)
    }

    @Test func resetsWhenTheSensorLinkIsRemoved() async throws {
        let client = ScriptedReadingsClient(results: [.success(SensorReadingsSnapshot(deviceID: exampleSerial))])
        let model = MonitorLiveReadingsModel(client: client, now: { fixedDate })
        let link = try exampleLink()
        let task = Task { await model.refreshRepeatedly(for: link) }
        while client.requestCount == 0 { await Task.yield() }
        task.cancel()
        await task.value

        await model.refreshRepeatedly(for: nil)

        #expect(model.status == .notConfigured)
        #expect(model.lastUpdatedAt == nil)
    }

    @Test func ignoresAnAnswerForAnOldLink() async throws {
        let client = ScriptedReadingsClient(results: [.success(SensorReadingsSnapshot(deviceID: exampleSerial))])
        let model = MonitorLiveReadingsModel(client: client)

        // No refresh loop runs for this link, so its answer belongs to no current link.
        await model.refresh(try exampleLink())

        #expect(model.status == .notConfigured)
    }
}

// MARK: - Saved link

@MainActor
struct SensorBackendSettingsModelTests {
    @Test func savesAndRemovesTheLink() throws {
        let store = InMemorySensorBackendLinkStore()
        let model = SensorBackendSettingsModel(store: store)

        try model.save(backendAddress: "192.168.1.10", deviceID: exampleSerial, setupCode: exampleSetupCode)
        #expect(model.link == (try exampleLink()))
        #expect(store.load() == model.link)

        try model.remove()
        #expect(model.link == nil)
        #expect(store.load() == nil)
    }

    @Test func emptySetupCodeKeepsTheSavedCodeForTheSameSensor() throws {
        let model = SensorBackendSettingsModel(store: InMemorySensorBackendLinkStore(link: try exampleLink()))

        try model.save(backendAddress: "192.168.1.20", deviceID: exampleSerial.lowercased(), setupCode: "")

        #expect(model.link?.backendAddress == "http://192.168.1.20:8080")
        #expect(model.link?.setupCode == exampleSetupCode)
    }

    @Test func emptySetupCodeIsRejectedForADifferentSensor() throws {
        let model = SensorBackendSettingsModel(store: InMemorySensorBackendLinkStore(link: try exampleLink()))

        #expect(throws: SensorBackendLinkIssue.invalidSetupCode) {
            try model.save(backendAddress: "192.168.1.10", deviceID: "DAPUR_FFFFFF", setupCode: "")
        }
        #expect(model.link == (try exampleLink()))
    }

    @Test func emptyServerAddressUsesTheDefaultServer() throws {
        let model = SensorBackendSettingsModel(store: InMemorySensorBackendLinkStore())

        try model.save(backendAddress: "  ", deviceID: exampleSerial, setupCode: exampleSetupCode)

        #expect(model.link?.backendAddress == SensorBackendConfiguration.defaultBackendAddress)
    }

    @Test func connectedSensorIsLinkedToTheDefaultServer() {
        let store = InMemorySensorBackendLinkStore()
        let model = SensorBackendSettingsModel(store: store)

        model.linkSensor(deviceID: exampleSerial, setupCode: exampleSetupCode)

        #expect(model.link?.deviceID == exampleSerial)
        #expect(model.link?.readKey == exampleReadKey)
        #expect(model.link?.backendAddress == SensorBackendConfiguration.defaultBackendAddress)
        #expect(store.load() == model.link)
    }

    @Test func connectedSensorKeepsTheSavedServer() throws {
        let model = SensorBackendSettingsModel(store: InMemorySensorBackendLinkStore(
            link: try exampleLink(address: "192.168.1.20:8081")))

        model.linkSensor(deviceID: "DAPUR_D4E5F6", setupCode: "wxyz6789")

        #expect(model.link?.deviceID == "DAPUR_D4E5F6")
        #expect(model.link?.setupCode == "wxyz6789")
        #expect(model.link?.backendAddress == "http://192.168.1.20:8081")
    }

    @Test func invalidConnectedSensorKeepsTheOldLink() throws {
        let oldLink = try exampleLink()
        let model = SensorBackendSettingsModel(store: InMemorySensorBackendLinkStore(link: oldLink))

        model.linkSensor(deviceID: "DAPUR_ALM_A1B2C3", setupCode: exampleSetupCode)

        #expect(model.link == oldLink)
    }

    @Test func defaultServerAddressIsValid() throws {
        let link = try SensorBackendLink(backendAddress: SensorBackendConfiguration.defaultBackendAddress,
                                         deviceID: exampleSerial, setupCode: exampleSetupCode)
        #expect(link.backendAddress == SensorBackendConfiguration.defaultBackendAddress)
    }

    @Test func keychainStoreKeepsTheLink() throws {
        let suiteName = "SensorBackendTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = KeychainSensorBackendLinkStore(defaults: defaults, keychainService: suiteName)
        defer { try? store.remove() }

        try store.save(try exampleLink())
        #expect(store.load() == (try exampleLink()))

        try store.remove()
        #expect(store.load() == nil)
    }
}

// MARK: - Push token removal

@MainActor
struct SensorPushTokenRemovalTests {
    private let token = String(repeating: "a", count: 64)
    private let replacementToken = String(repeating: "b", count: 64)

    @Test func unlinkRevokesTheTokenForTheOldSensor() async throws {
        let oldLink = try exampleLink()
        let store = InMemorySensorBackendLinkStore(link: oldLink)
        let registrations = SensorPushRegistrationStore(keychainService: UUID().uuidString)
        defer { try? registrations.save([]) }
        let client = RecordingSensorCommandClient()
        let registrar = PushTokenRegistrar(store: store, registrations: registrations, client: client)
        let settings = SensorBackendSettingsModel(store: store, pushTokens: registrar)

        await registrar.updateToken(token).value
        try settings.remove()
        await registrar.retryRevocations().value

        #expect(settings.link == nil)
        #expect(client.requests.map(\.command.action) == [.registerPushToken, .unregisterPushToken])
        #expect(client.requests.last?.link == oldLink)
        #expect(client.requests.last?.command.pushToken == token)
        #expect(try registrations.load().isEmpty)
    }

    @Test func offlineRevocationSurvivesRelaunchAndUsesTheOldToken() async throws {
        let oldLink = try exampleLink()
        let store = InMemorySensorBackendLinkStore(link: oldLink)
        let service = UUID().uuidString
        let registrations = SensorPushRegistrationStore(keychainService: service)
        defer { try? registrations.save([]) }
        let client = RecordingSensorCommandClient()
        let registrar = PushTokenRegistrar(store: store, registrations: registrations, client: client)
        let settings = SensorBackendSettingsModel(store: store, pushTokens: registrar)

        await registrar.updateToken(token).value
        client.isOffline = true
        try settings.remove()
        await registrar.retryRevocations().value
        #expect(try registrations.load().map(\.token) == [token])

        let relaunchedClient = RecordingSensorCommandClient()
        let relaunched = PushTokenRegistrar(
            store: store, registrations: SensorPushRegistrationStore(keychainService: service),
            client: relaunchedClient
        )
        await relaunched.updateToken(replacementToken).value

        #expect(relaunchedClient.requests.count == 1)
        #expect(relaunchedClient.requests.first?.command.action == .unregisterPushToken)
        #expect(relaunchedClient.requests.first?.command.pushToken == token)
        #expect(relaunchedClient.requests.first?.link == oldLink)
        #expect(try registrations.load().isEmpty)
    }

    @Test func unlinkOfAnOlderInstallWaitsForAPNsToken() async throws {
        let oldLink = try exampleLink()
        let store = InMemorySensorBackendLinkStore(link: oldLink)
        let registrations = SensorPushRegistrationStore(keychainService: UUID().uuidString)
        defer { try? registrations.save([]) }
        let client = RecordingSensorCommandClient()
        let registrar = PushTokenRegistrar(store: store, registrations: registrations, client: client)
        let settings = SensorBackendSettingsModel(store: store, pushTokens: registrar)

        try settings.remove()
        await registrar.retryRevocations().value
        #expect(client.requests.isEmpty)
        #expect(try registrations.load() == [SensorPushRegistration(link: oldLink, token: nil)])

        await registrar.updateToken(token).value
        #expect(client.requests.map(\.command.action) == [.unregisterPushToken])
        #expect(try registrations.load().isEmpty)
    }

    @Test func switchingSensorsRegistersTheNewSensorAndRevokesTheOldOne() async throws {
        let oldLink = try exampleLink()
        let store = InMemorySensorBackendLinkStore(link: oldLink)
        let registrations = SensorPushRegistrationStore(keychainService: UUID().uuidString)
        defer { try? registrations.save([]) }
        let client = RecordingSensorCommandClient()
        let registrar = PushTokenRegistrar(store: store, registrations: registrations, client: client)
        let settings = SensorBackendSettingsModel(store: store, pushTokens: registrar)

        await registrar.updateToken(token).value
        settings.linkSensor(deviceID: "DAPUR_D4E5F6", setupCode: "wxyz6789")
        await registrar.retryRevocations().value

        #expect(client.requests.map(\.command.action) == [.registerPushToken, .registerPushToken, .unregisterPushToken])
        #expect(client.requests.map(\.link.deviceID) == [oldLink.deviceID, "DAPUR_D4E5F6", oldLink.deviceID])
        #expect(try registrations.load().map(\.deviceID) == ["DAPUR_D4E5F6"])
    }

    @Test func relinkingTheSameSensorKeepsItsToken() async throws {
        let link = try exampleLink()
        let store = InMemorySensorBackendLinkStore(link: link)
        let registrations = SensorPushRegistrationStore(keychainService: UUID().uuidString)
        defer { try? registrations.save([]) }
        let client = RecordingSensorCommandClient()
        let registrar = PushTokenRegistrar(store: store, registrations: registrations, client: client)
        let settings = SensorBackendSettingsModel(store: store, pushTokens: registrar)

        await registrar.updateToken(token).value
        client.isOffline = true
        try settings.remove()
        await registrar.retryRevocations().value

        client.isOffline = false
        client.requests.removeAll()
        settings.linkSensor(deviceID: link.deviceID, setupCode: link.setupCode)
        await registrar.retryRevocations().value

        #expect(client.requests.map(\.command.action) == [.registerPushToken])
        #expect(try registrations.load().map(\.token) == [token])
    }
}

private final class RecordingSensorCommandClient: SensorCommandSending {
    var isOffline = false
    var requests: [(command: SensorCommand, link: SensorBackendLink)] = []

    func send(_ command: SensorCommand, for link: SensorBackendLink) async throws -> SensorCommandAck {
        requests.append((command, link))
        if isOffline { throw SensorCommandError.deviceOffline }
        return SensorCommandAck(requestId: command.requestId, result: "done", reason: nil)
    }
}

// MARK: - Sensors that already have Wi-Fi

private final class FixedDiscoveryClient: SensorDiscovering {
    let result: Result<[BackendDevice], Error>
    private(set) var serverURLs: [URL] = []

    init(result: Result<[BackendDevice], Error>) {
        self.result = result
    }

    func fetchDevices(serverURL: URL) async throws -> [BackendDevice] {
        serverURLs.append(serverURL)
        return try result.get()
    }
}

@MainActor
struct NetworkSensorDiscoveryModelTests {
    @Test func showsOnlyOnlineSensors() async {
        let client = FixedDiscoveryClient(result: .success([
            BackendDevice(deviceID: "DAPUR_020F3C", isOnline: true),
            BackendDevice(deviceID: "DAPUR_FFFFFF", isOnline: false),
            BackendDevice(deviceID: "DAPUR_ALM_A1B2C3", isOnline: true)
        ]))
        let model = NetworkSensorDiscoveryModel(client: client)

        await model.search(serverAddress: "192.168.1.10")

        #expect(model.status == .finished)
        #expect(model.sensors == [NetworkSensor(id: "DAPUR_020F3C")])
        #expect(client.serverURLs.map(\.absoluteString) == ["http://192.168.1.10:8080"])
    }

    @Test func showsTheServerError() async {
        let model = NetworkSensorDiscoveryModel(
            client: FixedDiscoveryClient(result: .failure(SensorReadingsFetchError.backendUnreachable)))

        await model.search(serverAddress: "192.168.1.10")

        #expect(model.status == .failed(.backendUnreachable))
        #expect(model.sensors.isEmpty)
    }

    @Test func invalidServerAddressFailsWithoutARequest() async {
        let client = FixedDiscoveryClient(result: .success([]))
        let model = NetworkSensorDiscoveryModel(client: client)

        await model.search(serverAddress: "ftp://server")

        #expect(model.status == .failed(.backendUnreachable))
        #expect(client.serverURLs.isEmpty)
    }
}

@MainActor
struct NetworkSensorLinkModelTests {
    private let sensor = NetworkSensor(id: exampleSerial)

    private func makeModel(
        results: [Result<SensorReadingsSnapshot, Error>],
        savedSetupCode: String? = nil,
        onLinked: @escaping (SensorBackendLink) throws -> Void = { _ in },
        onRejected: @escaping () -> Void = {}
    ) throws -> (NetworkSensorLinkModel, ScriptedReadingsClient) {
        let client = ScriptedReadingsClient(results: results)
        let model = NetworkSensorLinkModel(
            sensor: sensor,
            serverAddress: "192.168.1.10",
            savedSetupCode: try savedSetupCode.map { try DeviceSetupCode($0) },
            client: client,
            onLinked: onLinked,
            onSavedSetupCodeRejected: onRejected
        )
        return (model, client)
    }

    @Test func correctSetupCodeLinksTheSensor() async throws {
        var linked: [SensorBackendLink] = []
        let (model, _) = try makeModel(results: [.success(SensorReadingsSnapshot(deviceID: exampleSerial))],
                                       onLinked: { linked.append($0) })
        model.setupCode = " ABCD2345 "

        model.link()
        try await waitUntilLinkEnds(model)

        #expect(model.isLinked)
        #expect(model.errorMessage == nil)
        #expect(linked == [try exampleLink()])
    }

    @Test func wrongSetupCodeShowsAMessage() async throws {
        var linkCount = 0
        let (model, _) = try makeModel(results: [.failure(SensorReadingsFetchError.invalidReadKey)],
                                       onLinked: { _ in linkCount += 1 })
        model.setupCode = "zzzz2345"

        model.link()
        try await waitUntilLinkEnds(model)

        #expect(!model.isLinked)
        #expect(model.errorMessage == SensorBackendSettingsCopy.linkMessage(for: .invalidReadKey))
        #expect(linkCount == 0)
        #expect(model.canLink)
    }

    @Test func shortSetupCodeFailsWithoutARequest() throws {
        let (model, client) = try makeModel(results: [])
        model.setupCode = "abc"

        model.link()

        #expect(model.errorMessage == SensorBackendSettingsCopy.message(for: .invalidSetupCode))
        #expect(client.requestCount == 0)
    }

    @Test func savedSetupCodeLinksWithNoTypedCode() async throws {
        var linked: [SensorBackendLink] = []
        let (model, _) = try makeModel(results: [.success(SensorReadingsSnapshot(deviceID: exampleSerial))],
                                       savedSetupCode: exampleSetupCode, onLinked: { linked.append($0) })

        model.linkWithSavedSetupCode()
        #expect(model.isUsingSavedSetupCode)
        try await waitUntilLinkEnds(model)

        #expect(model.isLinked)
        #expect(linked.first?.readKey == exampleReadKey)
    }

    @Test func rejectedSavedSetupCodeAsksForTheCode() async throws {
        var rejectionCount = 0
        let (model, _) = try makeModel(results: [.failure(SensorReadingsFetchError.invalidReadKey)],
                                       savedSetupCode: exampleSetupCode, onRejected: { rejectionCount += 1 })

        model.linkWithSavedSetupCode()
        try await waitUntilLinkEnds(model)

        #expect(!model.isUsingSavedSetupCode)
        #expect(model.setupCode.isEmpty)
        #expect(rejectionCount == 1)
        #expect(model.errorMessage != nil)
    }

    @Test func storageFailureShowsAMessage() async throws {
        let (model, _) = try makeModel(results: [.success(SensorReadingsSnapshot(deviceID: exampleSerial))],
                                       onLinked: { _ in throw SensorBackendLinkIssue.storageFailed })
        model.setupCode = exampleSetupCode

        model.link()
        try await waitUntilLinkEnds(model)

        #expect(!model.isLinked)
        #expect(model.errorMessage == SensorBackendSettingsCopy.message(for: .storageFailed))
    }

    private func waitUntilLinkEnds(_ model: NetworkSensorLinkModel) async throws {
        for _ in 0..<200 {
            if !model.isLinking { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        Issue.record("The link did not end")
    }
}
