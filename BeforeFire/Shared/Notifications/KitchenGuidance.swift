import Foundation

/// Presentation rules only. The sensor supplies the condition, validity, and optional reason metadata.
nonisolated enum KitchenGuidance {
    static let activeAlarmStatus = "Active Alarm"
    static let snoozedAlarmStatus = "Snoozed Alarm"
    static let alarmInstruction = "Turn stove off NOW"
    static let alarmSupportingInstruction = "Call closest available person if you are not able to reach the stove"
    static let snoozedInstruction = "Turn stove off or call the closest available person"
    static let unknownStatus = "Unknown"

    static func monitorMessage(for assessment: KitchenAssessment) -> String? {
        guard let condition = assessment.validCondition, condition != .normal else { return nil }
        let reasons = assessment.reasons.map(\.displayName).joined(separator: ", ")
        switch condition {
        case .normal: return nil
        case .warning1:
            return reasons.isEmpty ? "Check your kitchen." : reasons
        case .warning2:
            let action = "Check your kitchen now. Turn off the stove if you can do so safely."
            return reasons.isEmpty ? action : "\(reasons). \(action)"
        case .alarm:
            return "\(alarmInstruction)\n\(alarmSupportingInstruction)"
        }
    }

    static func notificationBody(for assessment: KitchenAssessment) -> String? {
        guard let condition = assessment.validCondition, condition != .normal else { return nil }
        if let ruleID = assessment.ruleID, let rule = KitchenRuleMessages.rules[ruleID],
           rule.condition == condition, let template = rule.notificationTemplate {
            return render(template, duration: assessment.absenceDurationSeconds)
        }
        // Do not guess a rule or a temperature/IAQ class when the sender omitted metadata.
        let reasons = assessment.reasons.map(\.displayName).joined(separator: ", ")
        let reasonText = reasons.isEmpty ? "" : " \(reasons)."
        switch condition {
        case .normal: return nil
        case .warning1:
            return "Check your kitchen.\(reasonText) Check the stove and surrounding area."
        case .warning2:
            return "Check your kitchen now.\(reasonText) Turn off the stove if you can do so safely."
        case .alarm:
            return "Turn off the stove now if you can safely reach it.\(reasonText)"
        }
    }

    private static func render(_ template: String, duration: Int?) -> String {
        guard let duration else {
            return template.replacingOccurrences(of: "no one has been detected for {duration}",
                                                 with: "no one is detected")
        }
        let minutes = duration / 60
        let seconds = duration % 60
        var parts: [String] = []
        if minutes > 0 { parts.append("\(minutes) \(minutes == 1 ? "minute" : "minutes")") }
        if seconds > 0 || parts.isEmpty { parts.append("\(seconds) \(seconds == 1 ? "second" : "seconds")") }
        return template.replacingOccurrences(of: "{duration}", with: parts.joined(separator: " "))
    }
}
