import Foundation
import Testing
@testable import BeforeFire

@MainActor
struct CompactAlertCopyTests {
    @Test(arguments: [KitchenCondition.warning1, .warning2, .alarm])
    func bannersUseTwoShortGeneralLines(_ condition: KitchenCondition) throws {
        let assessment = KitchenAssessment(condition: condition, isValid: true,
                                          reasons: [.highHeat, .poorAirQuality, .noPresence],
                                          ruleID: condition == .warning1 ? 9 : 27, absenceDurationSeconds: 3599)
        let body = try #require(KitchenGuidance.notificationBody(for: assessment))
        let lines = body.split(separator: "\n")
        #expect(lines.count == 2)
        #expect(lines.allSatisfy { $0.count <= 34 })
        #expect(!body.contains("minutes"))
        #expect(!body.contains("High Heat"))
    }

    @Test func activityUsesCompactCopyWhileTheAppKeepsDetailedGuidance() {
        let state = AlarmActivityAttributes.ContentState()
        #expect(state.activityTitle == "Turn stove off NOW if safe.")
        #expect(state.activityMessage == "If not, call someone nearby.")
        #expect(state.activityTitle.count <= 34)
        #expect(state.activityMessage.count <= 34)
        #expect(state.message == KitchenGuidance.alarmSupportingInstruction)
        #expect(KitchenGuidance.monitorMessage(for: KitchenAssessment(condition: .alarm, isValid: true))?.contains("Call closest available person") == true)
    }
}
