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
}
