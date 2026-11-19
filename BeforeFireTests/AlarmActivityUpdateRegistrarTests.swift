import Foundation
import Testing
@testable import BeforeFire

private final class UpdateRequestLog: @unchecked Sendable {
    private let lock = NSLock()
    private var codes: [Int] = []
    private var events: [String] = []
    func use(_ codes: [Int]) { lock.lock(); self.codes = codes; events = []; lock.unlock() }
    func respond(_ request: URLRequest) -> Int {
        lock.lock()
        defer { lock.unlock() }
        events.append(request.url?.path ?? "")
        return codes.isEmpty ? 204 : codes.removeFirst()
    }
    var count: Int { lock.lock(); defer { lock.unlock() }; return events.count }
}
private final class UpdateTokenURLProtocol: URLProtocol {
    nonisolated(unsafe) static var log = UpdateRequestLog()
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let response = HTTPURLResponse(url: request.url!, statusCode: Self.log.respond(request), httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@MainActor
@Suite(.serialized)
struct AlarmActivityUpdateRegistrarTests {
    @Test func rejectedTokenSurvivesARestartAndRetriesWithoutNewTokenEmission() async throws {
        let fixture = try Fixture()
        defer { fixture.clean() }
        fixture.log.use([401, 204])
        await fixture.makeRegistrar().register(Data([1, 2]), installationID: "installation", eventID: "alarm-1", link: fixture.link).value
        #expect(fixture.log.count == 1)
        let relaunched = fixture.makeRegistrar()
        await relaunched.retryPending().value
        #expect(fixture.log.count == 2)
        await relaunched.retryPending().value
        #expect(fixture.log.count == 2)
    }

    @Test func pendingTokenIsDiscardedAfterUnlinking() async throws {
        let fixture = try Fixture()
        defer { fixture.clean() }
        fixture.log.use([401])
        let registrar = fixture.makeRegistrar()
        await registrar.register(Data([1, 2]), installationID: "installation", eventID: "alarm-1", link: fixture.link).value
        try fixture.links.remove()
        await registrar.retryPending().value
        #expect(fixture.log.count == 1)
        try fixture.links.save(fixture.link)
        await registrar.retryPending().value
        #expect(fixture.log.count == 1)
    }

    @Test func sensorAlarmDoesNotCreateAPushlessLocalFallback() {
        let model = AlarmPreviewModel(feedback: SilentFeedback())
        model.setApplicationActive(true)
        model.handleLiveReading(SensorReadingsSnapshot(deviceID: "DAPUR_A1B2C3", condition: .alarm, measuredAt: .now), linkedDeviceID: "DAPUR_A1B2C3")
        model.startLiveActivity(remoteDeviceID: nil)
        #expect(model.isAlarmPresented)
        #expect(model.activityMessage == "Waiting for the alarm Live Activity.")
    }

    @MainActor
    private final class SilentFeedback: AlarmFeedbackPlaying {
        var onFailure: ((AlarmFeedbackFailure?) -> Void)?
        func setPlaying(_ shouldPlay: Bool) {}
    }

    @MainActor
    private struct Fixture {
        let link: SensorBackendLink
        let links: InMemorySensorBackendLinkStore
        let log = UpdateRequestLog()
        let service = "BeforeFire.tests.activityUpdate.\(UUID().uuidString)"
        let session: URLSession
        init() throws {
            link = try SensorBackendLink(backendAddress: "https://example.com:443", deviceID: "DAPUR_A1B2C3", setupCode: "test1234")
            links = InMemorySensorBackendLinkStore(link: link)
            let config = URLSessionConfiguration.ephemeral
            config.protocolClasses = [UpdateTokenURLProtocol.self]
            session = URLSession(configuration: config)
            UpdateTokenURLProtocol.log = log
        }
        func makeRegistrar() -> AlarmActivityUpdateRegistrar {
            AlarmActivityUpdateRegistrar(links: links, session: session, keychainService: service)
        }
        func clean() { try? KeychainPasswordStore(service: service).deleteAll() }
    }
}
