import Foundation
import Testing
@testable import BeforeFire

@MainActor
struct AlarmActivityTests {
    @Test func backendStartPayloadDecodesAndUsesAnAlarmLink() throws {
        let attributes = try JSONDecoder().decode(AlarmActivityAttributes.self, from: Data(
            #"{"previewID":"01234567-89ab-cdef-0123-456789abcdef","sensorDeviceID":"DAPUR_A1B2C3","remoteEventID":"alarm-1","alarmIssuedAt":1794272400}"#.utf8
        ))
        let state = try JSONDecoder().decode(AlarmActivityAttributes.ContentState.self, from: Data(
            #"{"isSnoozed":false,"pushEventID":"alarm-1"}"#.utf8
        ))
        #expect(attributes.sensorDeviceID == "DAPUR_A1B2C3")
        #expect(attributes.remoteEventID == state.pushEventID)
        #expect(attributes.alarmDate == Date(timeIntervalSince1970: 1794272400))
        #expect(!state.isSnoozed)
        #expect(attributes.openURL.query?.contains("deviceId=DAPUR_A1B2C3") == true)
    }

    @Test func alarmStatesRoundTripWithoutLosingPreviewStatus() throws {
        for isSnoozed in [false, true] {
            let original = AlarmActivityAttributes.ContentState(isSnoozed: isSnoozed)
            let encoded = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(AlarmActivityAttributes.ContentState.self, from: encoded)
            #expect(decoded == original)
            #expect(decoded.status == (isSnoozed ? "Snoozed Alarm" : "Active Alarm"))
        }
    }

    @Test func snoozedPreviewDoesNotClaimThatTheKitchenIsSafe() {
        let snoozed = AlarmActivityAttributes.ContentState(isSnoozed: true)
        #expect(snoozed.title == "Snoozed Alarm")
        #expect(snoozed.message == "Turn stove off or call the closest available person")
    }

    @Test func previewLinkRoutesOnlyTheSupportedURL() {
        let model = AlarmPreviewModel()
        for address in ["https://alarm-preview", "beforefire://other", "beforefire://alarm-preview/other", "beforefire://alarm-preview?command=snooze"] {
            model.open(URL(string: address)!)
            #expect(!model.isAlarmPresented)
        }
        model.open(AlarmActivityAttributes.previewURL)
        #expect(model.isAlarmPresented)
    }

    @Test func defaultSnoozeCountsDownFromOneMinute() {
        let start = Date(timeIntervalSince1970: 1000)
        let state = AlarmActivityAttributes.ContentState().snoozed(at: start)
        #expect(state.snoozeEndsAt == start.addingTimeInterval(60))
        #expect(state.remainingText(at: start) == "01:00")
        #expect(state.remainingText(at: start.addingTimeInterval(30)) == "00:30")
        #expect(state.remainingFraction(at: start.addingTimeInterval(30)) == 0.5)
    }

    @Test func countdownClampsAtBothEndsAndNeverBecomesNegative() {
        let start = Date(timeIntervalSince1970: 1000)
        let state = AlarmActivityAttributes.ContentState().snoozed(at: start)
        #expect(state.remainingSeconds(at: start.addingTimeInterval(-20)) == 60)
        #expect(state.remainingFraction(at: start.addingTimeInterval(-20)) == 1)
        #expect(state.remainingText(at: start.addingTimeInterval(60)) == "00:00")
        #expect(state.remainingFraction(at: start.addingTimeInterval(100)) == 0)
        #expect(state.remainingSeconds(at: start.addingTimeInterval(100)) == 0)
    }

    @Test func durationChangesAndResumeUseFreshDeadlines() {
        let start = Date(timeIntervalSince1970: 1000)
        var state = AlarmActivityAttributes.ContentState(snoozeDurationSeconds: 90).snoozed(at: start)
        #expect(state.remainingText(at: start) == "01:30")
        state = state.resumed()
        #expect(!state.isSnoozed)
        #expect(state.snoozeEndsAt == nil)
        #expect(state.remainingSeconds(at: start) == 0)
        state = state.snoozed(at: start.addingTimeInterval(200))
        #expect(state.snoozeEndsAt == start.addingTimeInterval(290))
    }

    @Test func invalidDurationsUseSupportedBounds() {
        #expect(AlarmActivityAttributes.ContentState(snoozeDurationSeconds: -1).durationSeconds == 5)
        #expect(AlarmActivityAttributes.ContentState(snoozeDurationSeconds: 0).durationSeconds == 5)
        #expect(AlarmActivityAttributes.ContentState(snoozeDurationSeconds: 9999).durationSeconds == 3600)
    }

    @Test func oldActivityStateStillDecodes() throws {
        let encoded = Data(#"{"isSnoozed":true}"#.utf8)
        let state = try JSONDecoder().decode(AlarmActivityAttributes.ContentState.self, from: encoded)
        #expect(state.isSnoozed)
        #expect(state.snoozeEndsAt == nil)
        #expect(state.durationSeconds == 60)
    }

    @Test func snoozeDeadlineSurvivesActivityEncoding() throws {
        let original = AlarmActivityAttributes.ContentState(snoozeDurationSeconds: 120)
            .snoozed(at: Date(timeIntervalSince1970: 1000))
        let decoded = try JSONDecoder().decode(AlarmActivityAttributes.ContentState.self,
                                               from: JSONEncoder().encode(original))
        #expect(decoded == original)
    }

    @Test func widgetTimerUsesTheSameSnoozeInterval() {
        let start = Date(timeIntervalSince1970: 1000)
        let state = AlarmActivityAttributes.ContentState(snoozeDurationSeconds: 90).snoozed(at: start)
        #expect(state.snoozeInterval?.lowerBound == start)
        #expect(state.snoozeInterval?.upperBound == start.addingTimeInterval(90))
        #expect(state.resumed().snoozeInterval == nil)
        #expect(AlarmActivityAttributes.ContentState(isSnoozed: true).snoozeInterval == nil)
    }

    @Test func hubOfflineStateSurvivesSnoozeResumeAndEncoding() throws {
        let offline = AlarmActivityAttributes.ContentState(isHubDisconnected: true)
        #expect(offline.status == "Hub offline")
        #expect(offline.message == "Last known status: Alarm active\nLive status unavailable")
        let snoozed = offline.snoozed(at: Date(timeIntervalSince1970: 1000))
        #expect(snoozed.isHubOffline)
        #expect(snoozed.resumed().isHubOffline)
        let decoded = try JSONDecoder().decode(AlarmActivityAttributes.ContentState.self,
                                               from: JSONEncoder().encode(snoozed))
        #expect(decoded == snoozed)
        #expect(AlarmActivityAttributes.ContentState().isHubOffline == false)
    }

    @Test func oldPreviewDefaultsToConnectedHub() throws {
        let state = try JSONDecoder().decode(AlarmActivityAttributes.ContentState.self,
                                             from: Data(#"{"isSnoozed":false}"#.utf8))
        #expect(!state.isHubOffline)
        #expect(state.status == "Active Alarm")
    }
}
