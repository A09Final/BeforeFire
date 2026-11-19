import Foundation
import Testing
@testable import BeforeFire

private final class WidgetRequestLog: @unchecked Sendable {
    private let lock = NSLock()
    private var requests: [(URLRequest, [String: Any])] = []
    private var status = 204

    func respond(to request: URLRequest) -> Int {
        let data: Data
        if let body = request.httpBody { data = body }
        else if let stream = request.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var body = Data()
            var buffer = [UInt8](repeating: 0, count: 1024)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count <= 0 { break }
                body.append(contentsOf: buffer.prefix(count))
            }
            data = body
        } else { data = Data() }
        let body = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        lock.lock()
        defer { lock.unlock() }
        requests.append((request, body))
        return status
    }

    func setStatus(_ status: Int) { lock.lock(); self.status = status; lock.unlock() }
    var captured: [(URLRequest, [String: Any])] { lock.lock(); defer { lock.unlock() }; return requests }
}

private final class WidgetTokenURLProtocol: URLProtocol {
    nonisolated(unsafe) static var log = WidgetRequestLog()
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let status = Self.log.respond(to: request)
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@MainActor
@Suite(.serialized)
struct KitchenWidgetPushLifecycleTests {
    @Test func rotatesTokensRemovesOldSensorsAndStopsAfterWidgetRemoval() async throws {
        let fixture = try Fixture()
        defer { fixture.clean() }
        _ = try fixture.connection.update(fixture.first)
        fixture.registration.didChangeToken(Data([1, 2]), isInstalled: true)
        await fixture.registration.refresh().value
        #expect(fixture.log.captured.count == 1)
        let firstID = fixture.log.captured[0].1["installationId"] as? String

        fixture.registration.didChangeToken(Data([3, 4]), isInstalled: true)
        await fixture.registration.refresh().value
        #expect(fixture.log.captured.count == 2)
        #expect(fixture.log.captured.last?.1["pushToken"] as? String == "0304")
        #expect(fixture.log.captured.last?.1["installationId"] as? String == firstID)

        _ = try fixture.connection.update(fixture.second)
        await fixture.registration.refresh().value
        let switched = fixture.log.captured
        #expect(switched.count == 4)
        #expect(switched[2].0.url?.host == fixture.first.url.host)
        #expect(switched[2].1["remove"] as? Bool == true)
        #expect(switched[3].0.url?.host == fixture.second.url.host)

        fixture.registration.didChangeToken(Data([3, 4]), isInstalled: false)
        await fixture.registration.refresh().value
        #expect(fixture.log.captured.count == 5)
        #expect(fixture.log.captured.last?.1["remove"] as? Bool == true)
        await fixture.registration.refresh().value
        #expect(fixture.log.captured.count == 5)
    }

    @Test func failedUnlinkRemainsPendingUntilTheServerAcceptsIt() async throws {
        let fixture = try Fixture()
        defer { fixture.clean() }
        _ = try fixture.connection.update(fixture.first)
        fixture.registration.didChangeToken(Data([1, 2]), isInstalled: true)
        await fixture.registration.refresh().value
        fixture.log.setStatus(400)
        _ = try fixture.connection.update(nil)
        await fixture.registration.refresh().value
        #expect(fixture.log.captured.count == 2)
        fixture.log.setStatus(204)
        await fixture.registration.refresh().value
        #expect(fixture.log.captured.count == 3)
        #expect(fixture.log.captured.last?.1["remove"] as? Bool == true)
        await fixture.registration.refresh().value
        #expect(fixture.log.captured.count == 3)
    }

    @Test func unlinkAlsoRemovesAnUnconfirmedRegistration() async throws {
        let fixture = try Fixture()
        defer { fixture.clean() }
        fixture.log.setStatus(400)
        _ = try fixture.connection.update(fixture.first)
        fixture.registration.didChangeToken(Data([1, 2]), isInstalled: true)
        await fixture.registration.refresh().value
        let attempts = fixture.log.captured.count
        fixture.log.setStatus(204)
        _ = try fixture.connection.update(nil)
        await fixture.registration.refresh().value
        #expect(fixture.log.captured.count == attempts + 1)
        #expect(fixture.log.captured.last?.1["remove"] as? Bool == true)
    }

    @MainActor
    private struct Fixture {
        let connection: KitchenStatusWidgetConnection
        let registration: KitchenWidgetPushRegistration
        let log = WidgetRequestLog()
        let first = SensorReadingsAccess(url: URL(string: "https://first.example/v1/devices/DAPUR_A1B2C3/readings")!, deviceID: "DAPUR_A1B2C3", readKey: "first-key")
        let second = SensorReadingsAccess(url: URL(string: "https://second.example/v1/devices/DAPUR_A1B2C4/readings")!, deviceID: "DAPUR_A1B2C4", readKey: "second-key")
        private let stores: [KeychainPasswordStore]

        init() throws {
            let group = try #require(Bundle.main.object(forInfoDictionaryKey: "KitchenStatusKeychainGroup") as? String)
            let suffix = UUID().uuidString
            let connectionService = "BeforeFire.tests.widgetConnection.\(suffix)"
            let pushService = "BeforeFire.tests.widgetPush.\(suffix)"
            connection = try KitchenStatusWidgetConnection(service: connectionService)
            stores = [KeychainPasswordStore(service: connectionService, accessGroup: group), KeychainPasswordStore(service: pushService, accessGroup: group)]
            let config = URLSessionConfiguration.ephemeral
            config.protocolClasses = [WidgetTokenURLProtocol.self]
            WidgetTokenURLProtocol.log = log
            registration = KitchenWidgetPushRegistration(service: pushService, connection: connection, session: URLSession(configuration: config))
        }
        func clean() { for store in stores { try? store.deleteAll() } }
    }
}
