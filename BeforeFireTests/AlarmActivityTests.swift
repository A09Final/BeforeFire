import Foundation
import Testing
@testable import BeforeFire

@MainActor
struct AlarmActivityTests {
    @Test func alarmStatesRoundTripWithoutLosingPreviewStatus() throws {
        for isSnoozed in [false, true] {
            let original = AlarmActivityAttributes.ContentState(isSnoozed: isSnoozed)
            let encoded = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(AlarmActivityAttributes.ContentState.self, from: encoded)
            #expect(decoded == original)
            #expect(decoded.status == (isSnoozed ? "Snoozed" : "Alarm active"))
        }
    }

    @Test func snoozedPreviewDoesNotClaimThatTheKitchenIsSafe() {
        let snoozed = AlarmActivityAttributes.ContentState(isSnoozed: true)
        #expect(snoozed.title == "Alarm snoozed")
        #expect(snoozed.message == "Preview only. No alarm command was sent.")
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
}
