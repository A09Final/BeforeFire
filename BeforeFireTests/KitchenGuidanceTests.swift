import Foundation
import Testing
import UserNotifications
@testable import BeforeFire

@MainActor
struct KitchenGuidanceTests {
    @Test(arguments: [(KitchenCondition.normal, "Normal"), (.warning1, "Unsafe"),
                      (.warning2, "Dangerous"), (.alarm, "Alarm")])
    func labelsFollowTheSensorCondition(_ condition: KitchenCondition, _ label: String) {
        #expect(condition.displayName == label)
    }

    @Test func normalHasNoCTAOrNotificationBody() {
        let assessment = KitchenAssessment(condition: .normal, isValid: true, reasons: [.highHeat], ruleID: 18)
        #expect(KitchenGuidance.monitorMessage(for: assessment) == nil)
        #expect(KitchenGuidance.notificationBody(for: assessment) == nil)
    }

    @Test func invalidNormalIsUnknown() {
        let snapshot = SensorReadingsSnapshot(deviceID: "DAPUR_A1B2C3", condition: .normal, conditionIsValid: false)
        let content = MonitorReadingsFormatter().content(for: snapshot)
        #expect(content.statusValue == "Unknown")
        #expect(content.assessment?.validCondition == nil)
        #expect(MonitorViewModel(content: content).actionGuidance == nil)
    }

    @Test func snapshotDecodesAnInvalidFuzzyResultWithoutCallingItNormal() throws {
        let bytes = Data(#"{"deviceId":"DAPUR_A1B2C3","condition":"normal","valid":false,"readings":{},"connection":"online","isStale":false}"#.utf8)
        let snapshot = try JSONDecoder().decode(SensorReadingsSnapshot.self, from: bytes)
        #expect(snapshot.assessment.validCondition == nil)
    }

    @Test func conflictingSensorLabelsAreUnavailable() {
        let snapshot = SensorReadingsSnapshot(deviceID: "DAPUR_A1B2C3", condition: .alarm,
                                              reportedAssessment: .init(condition: .normal, isValid: true))
        #expect(snapshot.assessment.validCondition == nil)
        #expect(MonitorReadingsFormatter().content(for: snapshot).statusValue == "Unknown")
    }

    @Test func scoreNeverChangesTheSensorLabel() throws {
        let bytes = Data(#"{"deviceId":"DAPUR_A1B2C3","condition":"normal","valid":true,"score":100,"readings":{"stoveTemperatureC":300,"iaq":500},"connection":"online","isStale":false}"#.utf8)
        let snapshot = try JSONDecoder().decode(SensorReadingsSnapshot.self, from: bytes)
        #expect(MonitorReadingsFormatter().content(for: snapshot).statusValue == "Normal")
        #expect(KitchenGuidance.monitorMessage(for: snapshot.assessment) == nil)
    }

    @Test func warningOneUsesOnlyReportedReasons() {
        let assessment = KitchenAssessment(condition: .warning1, isValid: true, reasons: [.noPresence])
        #expect(KitchenGuidance.monitorMessage(for: assessment) == "No Presence Detected")
        #expect(KitchenGuidance.notificationBody(for: assessment)?.contains("High Heat") == false)
        #expect(KitchenGuidance.notificationBody(for: assessment)?.contains("Poor Air Quality") == false)
    }

    @Test func warningTwoUsesItsOwnMonitorReasonLabels() {
        let assessment = KitchenAssessment(condition: .warning2, isValid: true,
                                            reasons: [.poorAirQuality, .noPresence, .highHeat])
        #expect(KitchenGuidance.monitorMessage(for: assessment) ==
                "Concerning Air Quality Detected, No Presence Detected, Abnormally High Heat Detected. " +
                "Check your kitchen now. Turn off the stove if you can do so safely.")
    }

    @Test func warningsBecomeMoreUrgentWithoutReclassifyingThem() {
        let first = KitchenAssessment(condition: .warning1, isValid: true)
        let second = KitchenAssessment(condition: .warning2, isValid: true)
        #expect(KitchenGuidance.notificationBody(for: first)?.hasPrefix("Check your kitchen.") == true)
        #expect(KitchenGuidance.notificationBody(for: second)?.hasPrefix("Check your kitchen now.") == true)
        #expect(KitchenGuidance.monitorMessage(for: second)?.contains("Turn off the stove") == true)
    }

    @Test func allThirtyTwoRulesHaveAMessagePolicy() {
        #expect(Set(KitchenRuleMessages.rules.keys) == Set(1...32))
        for rule in KitchenRuleMessages.rules.values {
            #expect((rule.notificationTemplate == nil) == (rule.condition == .normal))
        }
    }

    @Test func notificationDurationUsesOnlySuppliedDuration() throws {
        let timed = KitchenAssessment(condition: .warning1, isValid: true, ruleID: 3, absenceDurationSeconds: 245)
        let untimed = KitchenAssessment(condition: .warning1, isValid: true, ruleID: 3)
        #expect(KitchenGuidance.notificationBody(for: timed)?.contains("4 minutes 5 seconds") == true)
        let body = try #require(KitchenGuidance.notificationBody(for: untimed))
        #expect(body.contains("no one is detected"))
        #expect(!body.contains("{duration}"))
        #expect(!body.contains("minutes"))
    }

    @Test func mismatchedRuleDoesNotOverrideTheFinalCondition() {
        let assessment = KitchenAssessment(condition: .warning1, isValid: true, ruleID: 32)
        #expect(KitchenGuidance.notificationBody(for: assessment)?.hasPrefix("Check your kitchen.") == true)
        #expect(assessment.validCondition == .warning1)
    }

    @Test func missingMetadataDoesNotInventThreeSensorProblems() {
        let assessment = KitchenAssessment(condition: .warning1, isValid: true)
        #expect(KitchenGuidance.monitorMessage(for: assessment) == "Check your kitchen.")
        #expect(assessment.reasons.isEmpty)
    }

    @Test func staleAndOfflineSnapshotsHaveNoCTA() {
        for isStale in [false, true] {
            let snapshot = SensorReadingsSnapshot(deviceID: "DAPUR_A1B2C3", condition: .alarm,
                                                  isStale: isStale, connection: .offline)
            let model = MonitorViewModel(content: MonitorReadingsFormatter().content(for: snapshot))
            #expect(model.actionGuidance == nil)
            #expect(!model.showsAlarmStatus)
        }
    }

    @Test func unavailableSensorsDoNotKeepReasonClaims() {
        let assessment = KitchenAssessment(condition: .warning1, isValid: true,
                                            reasons: [.highHeat, .noPresence, .poorAirQuality], ruleID: 9,
                                            absenceDurationSeconds: 240)
        let snapshot = SensorReadingsSnapshot(deviceID: "DAPUR_A1B2C3", reportedAssessment: assessment,
                                              unavailableSensors: ["radar", "thermal"])
        #expect(snapshot.assessment.reasons == [.poorAirQuality])
        #expect(snapshot.assessment.ruleID == nil)
        #expect(snapshot.assessment.absenceDurationSeconds == nil)
    }

    @Test func liveCardIndicatorsUseOnlyTheirOwnReportedReason() {
        let assessment = KitchenAssessment(condition: .warning1, isValid: true, reasons: [.noPresence])
        let snapshot = SensorReadingsSnapshot(deviceID: "DAPUR_A1B2C3", reportedAssessment: assessment)
        let model = MonitorViewModel(content: MonitorReadingsFormatter().content(for: snapshot))
        #expect(model.readingAlertCondition(for: .presence) == .unsafe)
        #expect(model.readingAlertCondition(for: .stoveHeat) == nil)
        #expect(model.readingAlertCondition(for: .airQuality) == nil)
        #expect(model.readingAlertCondition(for: .roomHumidity) == nil)
    }

    @Test func snoozeChangesPresentationButNotRisk() {
        let state = AlarmActivityAttributes.ContentState().snoozed(at: Date(timeIntervalSince1970: 1000))
        #expect(state.status == "Snoozed Alarm")
        #expect(state.message == "Turn stove off or call the closest available person")
        #expect(state.resumed().status == "Active Alarm")
        #expect(AlarmGuidance.mock.alarmInstruction == "Turn stove off NOW")
    }

    @Test func serviceExtensionUsesTheSameWarningMessage() throws {
        let original = notification(condition: "warning2")
        let event = try KitchenPushEvent(userInfo: original.userInfo)
        let mapped = KitchenNotificationContent.mapped(original)
        #expect(mapped.title == "Dangerous")
        #expect(mapped.body == KitchenGuidance.notificationBody(for: event.assessment))
        #expect(mapped.sound != nil)
        #expect(KitchenNotificationContent.foregroundOptions(for: original.userInfo).contains(.sound))
    }

    @Test func normalIsSilentAndDoesNotHaveActionText() {
        let original = notification(condition: "normal")
        let mapped = KitchenNotificationContent.mapped(original)
        #expect(mapped.title == "Normal")
        #expect(mapped.body.isEmpty)
        #expect(mapped.sound == nil)
        #expect(KitchenNotificationContent.foregroundOptions(for: original.userInfo).isEmpty)
    }

    @Test(arguments: ["normal", "warning1", "warning2"])
    func onlyAnAlarmLabelCanOpenTheAlarmPopup(_ condition: String) throws {
        let event = try KitchenPushEvent(userInfo: notification(condition: condition).userInfo)
        let model = AlarmPreviewModel()
        model.openPushAlarm(event)
        #expect(!model.isAlarmPresented)
    }

    @Test func dangerousPreviewIsSeparateFromAlarmPreview() {
        var model = MonitorViewModel.mock
        model.isActionGuidanceVisible = true
        model.previewCondition = .dangerous
        #expect(model.displayedStatusValue == "Dangerous")
        #expect(!model.isAlarmPreview)
        model.previewCondition = .alarm
        #expect(model.displayedStatusValue == "Alarm")
        #expect(model.isAlarmPreview)
        model.previewCondition = .normal
        #expect(model.actionGuidance == nil)
        #expect(model.readingAlertCondition == nil)
    }

    @Test func invalidOrUnknownConditionDoesNotPresentAnAlarm() {
        for condition in ["", "future-level"] {
            let original = notification(condition: condition)
            let mapped = KitchenNotificationContent.mapped(original)
            #expect(mapped.title == "Status unavailable")
            #expect(mapped.sound == nil)
            #expect(KitchenNotificationContent.foregroundOptions(for: original.userInfo).isEmpty)
        }
    }

    @Test func unknownReasonIsIgnoredAndMissingValidityIsNotAssumed() throws {
        let assessment = try JSONDecoder().decode(KitchenAssessment.self,
            from: Data(#"{"condition":"normal","reasons":["future_reason"]}"#.utf8))
        #expect(assessment.validCondition == nil)
        #expect(assessment.reasons.isEmpty)
    }

    private func notification(condition: String) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "Fallback"
        content.body = "Fallback message"
        content.userInfo = ["beforefire": ["alertId": "event-001", "deviceId": "DAPUR_A1B2C3",
                                            "condition": condition, "issuedAt": 1730700000]]
        return content
    }
}
