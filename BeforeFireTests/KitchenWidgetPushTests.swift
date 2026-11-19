import Foundation
import Testing
@testable import BeforeFire

@MainActor
struct KitchenWidgetPushTests {
    @Test func registrationUsesTheReadKeyWithoutTheSetupCode() throws {
        let access = SensorReadingsAccess(url: URL(string: "http://example.local:8080/v1/devices/DAPUR_A1B2C3/readings")!,
                                          deviceID: "DAPUR_A1B2C3", readKey: "read-key")
        let request = try KitchenWidgetPushRegistration.request(access: access, installationID: "phone-1", token: "token-1")
        #expect(request.url?.absoluteString == "http://example.local:8080/v1/devices/DAPUR_A1B2C3/widget-token")
        #expect(request.httpMethod == "PUT")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer read-key")
        let data = try #require(request.httpBody)
        let body = try #require(JSONSerialization.jsonObject(with: data) as? [String: String])
        #expect(body == ["installationId": "phone-1", "pushToken": "token-1"])
    }

    @Test func removalDoesNotSendAnAPNsOrActivityToken() throws {
        let access = SensorReadingsAccess(url: URL(string: "https://example.com/v1/devices/DAPUR_A1B2C3/readings")!,
                                          deviceID: "DAPUR_A1B2C3", readKey: "read-key")
        let request = try KitchenWidgetPushRegistration.request(access: access, installationID: "phone-1", token: nil)
        let data = try #require(request.httpBody)
        let body = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(body["remove"] as? Bool == true)
        #expect(body["pushToken"] == nil)
    }

    @Test func delayedRefreshRetainsTheTimestampWithoutClaimingTheSensorIsOffline() {
        let measured = Date(timeIntervalSince1970: 1_000)
        let entry = KitchenStatusEntry(date: measured, status: .reported(KitchenAssessment(condition: .warning1, isValid: true)), measuredAt: measured)
        let outdated = entry.outdated(at: measured.addingTimeInterval(900))
        #expect(outdated.isOutdated)
        #expect(outdated.status.condition == .warning1)
        #expect(outdated.measuredAt == measured)
        #expect(outdated.status != .offline)
    }
}
