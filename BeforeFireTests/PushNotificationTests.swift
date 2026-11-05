import Foundation
import Testing
import UserNotifications
@testable import BeforeFire

@MainActor
struct PushNotificationTests {
    private let bundleIdentifier = "com.ibnu.BeforeFire"

    @Test func firstLaunchDoesNotRequestPermissionWithoutUserAction() async {
        let client = StubPushNotificationClient()
        let manager = makeManager(client)
        await manager.refreshAuthorization()
        #expect(client.permissionRequests == 0)
        #expect(client.registrationRequests == 0)
        #expect(manager.authorizationStatus == .notDetermined)
    }

    @Test func permissionGrantStartsAPNsRegistration() async {
        let client = StubPushNotificationClient()
        let manager = makeManager(client)
        await manager.requestPermission()
        #expect(client.permissionRequests == 1)
        #expect(client.registrationRequests == 1)
        #expect(manager.registrationStatus == .registering)
        manager.didRegister(deviceToken: Data([0, 15, 128, 255]))
        #expect(manager.registrationStatus == .registered)
        #expect(manager.deviceRegistration?.token == "000f80ff")
        #expect(manager.deviceRegistration?.bundleIdentifier == bundleIdentifier)
    }

    @Test func deniedPermissionDoesNotRegisterOrAskAgain() async {
        let client = StubPushNotificationClient()
        client.statusAfterRequest = .denied
        let manager = makeManager(client)
        await manager.requestPermission()
        await manager.requestPermission()
        #expect(client.permissionRequests == 1)
        #expect(client.registrationRequests == 0)
        #expect(manager.authorizationStatus == .denied)
        #expect(manager.deviceRegistration == nil)
    }

    @Test(arguments: [UNAuthorizationStatus.authorized, .provisional, .ephemeral])
    func existingPermissionRegistersWithoutAnotherPrompt(_ status: UNAuthorizationStatus) async {
        let client = StubPushNotificationClient(status: status)
        let manager = makeManager(client)
        await manager.refreshAuthorization()
        #expect(client.permissionRequests == 0)
        #expect(client.registrationRequests == 1)
    }

    @Test func repeatedRefreshDoesNotStartDuplicateRegistration() async {
        let client = StubPushNotificationClient(status: .authorized)
        let manager = makeManager(client)
        await manager.refreshAuthorization()
        await manager.refreshAuthorization()
        manager.didRegister(deviceToken: Data([1, 2]))
        await manager.refreshAuthorization()
        #expect(client.registrationRequests == 1)
    }

    @Test func registrationFailureCanBeRetried() async {
        let client = StubPushNotificationClient(status: .authorized)
        let manager = makeManager(client)
        await manager.refreshAuthorization()
        manager.didFailToRegister(error: StubPushNotificationClient.Failure.unavailable)
        #expect(manager.registrationStatus == .failed)
        #expect(manager.errorMessage != nil)
        await manager.requestPermission()
        #expect(client.registrationRequests == 2)
        manager.didRegister(deviceToken: Data([42]))
        #expect(manager.errorMessage == nil)
        #expect(manager.registrationStatus == .registered)
    }

    @Test func permissionFailureCanBeRetried() async {
        let client = StubPushNotificationClient()
        client.shouldFailPermission = true
        let manager = makeManager(client)
        await manager.requestPermission()
        #expect(manager.errorMessage != nil)
        #expect(!manager.isUpdating)
        #expect(client.registrationRequests == 0)
        client.shouldFailPermission = false
        await manager.requestPermission()
        #expect(manager.errorMessage == nil)
        #expect(client.registrationRequests == 1)
    }

    @Test func cancellationPreventsRegistration() async {
        let client = StubPushNotificationClient(status: .authorized)
        let manager = makeManager(client)
        let request = Task { await manager.refreshAuthorization() }
        request.cancel()
        await request.value
        #expect(client.registrationRequests == 0)
        #expect(!manager.isUpdating)
        #expect(manager.errorMessage == nil)
    }

    @Test func revokedPermissionClearsRegistrationAndIgnoresLateToken() async {
        let client = StubPushNotificationClient(status: .authorized)
        let manager = makeManager(client)
        await manager.refreshAuthorization()
        manager.didRegister(deviceToken: Data([1]))
        client.status = .denied
        await manager.refreshAuthorization()
        manager.didRegister(deviceToken: Data([2]))
        #expect(manager.deviceRegistration == nil)
        #expect(manager.registrationStatus == .notRegistered)
    }

    @Test func tokenRotationReplacesTheCurrentRegistration() async {
        let manager = makeManager(StubPushNotificationClient(status: .authorized))
        await manager.refreshAuthorization()
        manager.didRegister(deviceToken: Data([0, 1]))
        manager.didRegister(deviceToken: Data([0, 2]))
        #expect(manager.deviceRegistration?.token == "0002")
    }

    @Test func missingTokenIsReportedAsFailure() async {
        let manager = makeManager(StubPushNotificationClient(status: .authorized))
        await manager.refreshAuthorization()
        manager.didRegister(deviceToken: Data())
        #expect(manager.registrationStatus == .failed)
        #expect(manager.deviceRegistration == nil)
        #expect(manager.errorMessage != nil)
    }

    @Test func registrationDoesNotAssumeAFixedTokenLength() {
        let token = Data(repeating: 15, count: 17)
        #expect(PushDeviceRegistration(deviceToken: token, bundleIdentifier: bundleIdentifier)?.token.count == 34)
        #expect(PushDeviceRegistration(deviceToken: token, bundleIdentifier: "") == nil)
    }

    @Test func validAlarmPayloadKeepsItsEventID() throws {
        let event = try alarmEvent(id: "alarm-001")
        #expect(event.id == "alarm-001")
    }

    @Test func unrelatedNotificationDoesNotBecomeAnAlarm() {
        #expect(throws: KitchenPushPayloadError.unrelatedNotification) {
            try KitchenPushEvent(userInfo: ["aps": ["alert": "Hello"]])
        }
    }

    @Test(arguments: [
        "{}",
        #"{"version":2,"type":"condition"}"#,
        #"{"version":true,"type":"condition","event_id":"alarm-001"}"#,
        #"{"version":2,"type":"condition","event_id":42}"#,
        #"{"version":2,"type":"condition","event_id":null}"#,
        #"{"version":2,"type":"condition","event_id":""}"#,
        #"{"version":2,"type":"condition","event_id":" alarm-001 "}"#
    ])
    func malformedAlarmPayloadIsRejected(_ json: String) throws {
        var fields = try #require(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
        fields["device_id"] = "DAPUR_A1B2C3"
        fields["assessment"] = ["condition": "alarm", "valid": true]
        #expect(throws: KitchenPushPayloadError.invalidPayload) {
            try KitchenPushEvent(userInfo: ["beforefire": fields])
        }
    }

    @Test func unsupportedVersionAndTypeAreRejected() {
        for fields in [
            ["version": 3, "type": "condition", "event_id": "alarm-001"],
            ["version": 2, "type": "unexpected", "event_id": "alarm-001"]
        ] as [[String: Any]] {
            #expect(throws: KitchenPushPayloadError.unsupportedEvent) {
                var payload = fields
                payload["device_id"] = "DAPUR_A1B2C3"
                payload["assessment"] = ["condition": "alarm", "valid": true]
                return try KitchenPushEvent(userInfo: ["beforefire": payload])
            }
        }
    }

    @Test func nonObjectAndOversizedEventIDAreRejected() {
        #expect(throws: KitchenPushPayloadError.invalidPayload) {
            try KitchenPushEvent(userInfo: ["beforefire": "alarm"])
        }
        #expect(throws: KitchenPushPayloadError.invalidPayload) {
            try alarmEvent(id: String(repeating: "a", count: 129))
        }
    }

    @Test func coldLaunchKeepsTappedAlarmUntilTheSceneConsumesIt() throws {
        let manager = makeManager(StubPushNotificationClient())
        let event = try alarmEvent(id: "alarm-001")
        manager.receiveTappedEvent(event)
        #expect(manager.pendingEvent == event)
        #expect(manager.takePendingEvent() == event)
        #expect(manager.takePendingEvent() == nil)
    }

    @Test func latestTappedAlarmReplacesAnUnconsumedTap() throws {
        let manager = makeManager(StubPushNotificationClient())
        manager.receiveTappedEvent(try alarmEvent(id: "alarm-001"))
        manager.receiveTappedEvent(try alarmEvent(id: "alarm-002"))
        #expect(manager.takePendingEvent()?.id == "alarm-002")
    }

    @Test func invalidPayloadDoesNotCreateAnAlarmAndValidPayloadClearsTheError() throws {
        let manager = makeManager(StubPushNotificationClient())
        manager.reportPayloadError(.invalidPayload)
        #expect(manager.payloadMessage != nil)
        #expect(manager.pendingEvent == nil)
        manager.receiveTappedEvent(try alarmEvent(id: "alarm-001"))
        #expect(manager.payloadMessage == nil)
        #expect(manager.pendingEvent?.id == "alarm-001")
    }

    @Test func unrelatedPayloadDoesNotReportAnAlarmError() {
        let manager = makeManager(StubPushNotificationClient())
        manager.reportPayloadError(.unrelatedNotification)
        #expect(manager.payloadMessage == nil)
        #expect(manager.pendingEvent == nil)
    }

    @Test func repeatedEventPreservesSnoozeButNewEventResumesAlarm() throws {
        let start = Date(timeIntervalSince1970: 1000)
        let active = AlarmActivityAttributes.ContentState().presentingPushEvent("alarm-001")
        let snoozed = active.snoozed(at: start)
        #expect(snoozed.presentingPushEvent("alarm-001") == snoozed)
        let next = snoozed.presentingPushEvent("alarm-002")
        #expect(!next.isSnoozed)
        #expect(next.snoozeEndsAt == nil)
        #expect(next.pushEventID == "alarm-002")
        let restored = try JSONDecoder().decode(AlarmActivityAttributes.ContentState.self,
                                                from: JSONEncoder().encode(snoozed))
        #expect(restored.presentingPushEvent("alarm-001") == snoozed)
    }

    private func makeManager(_ client: StubPushNotificationClient) -> PushNotificationManager {
        PushNotificationManager(client: client, bundleIdentifier: bundleIdentifier)
    }

    private func alarmEvent(id: String) throws -> KitchenPushEvent {
        try KitchenPushEvent(userInfo: ["beforefire": ["version": 2, "type": "condition", "event_id": id,
                                                       "device_id": "DAPUR_A1B2C3",
                                                       "assessment": ["condition": "alarm", "valid": true]]])
    }
}

@MainActor
private final class StubPushNotificationClient: PushNotificationClient {
    enum Failure: Error { case unavailable }
    var status: UNAuthorizationStatus
    var statusAfterRequest: UNAuthorizationStatus = .authorized
    var shouldFailPermission = false
    private(set) var permissionRequests = 0
    private(set) var registrationRequests = 0

    init(status: UNAuthorizationStatus = .notDetermined) {
        self.status = status
    }

    func authorizationStatus() async -> UNAuthorizationStatus { status }

    func requestAuthorization() async throws {
        permissionRequests += 1
        if shouldFailPermission { throw Failure.unavailable }
        status = statusAfterRequest
    }

    func registerForRemoteNotifications() {
        registrationRequests += 1
    }
}
