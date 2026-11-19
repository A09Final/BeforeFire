import Foundation

/// Presentation rules only. The sensor supplies the condition, validity, and optional reason metadata.
nonisolated enum KitchenGuidance {
    static let activeAlarmStatus = "Active Alarm"
    static let snoozedAlarmStatus = "Snoozed Alarm"
    static let alarmInstruction = "Turn stove off NOW"
    static let alarmSupportingInstruction = "Call closest available person if you are not able to reach the stove"
    static let snoozedInstruction = "Turn stove off or call the closest available person"
    static let alarmActivityInstruction = "Turn stove off NOW if safe."
    static let alarmActivitySupportingInstruction = "If not, call someone nearby."
    static let unknownStatus = "Unknown"

    static func monitorMessage(for assessment: KitchenAssessment) -> String? {
        guard let condition = assessment.validCondition, condition != .normal else { return nil }
        if condition == .warning1 || condition == .warning2,
           let message = ruleMessage(for: assessment, condition: condition) {
            return message
        }
        let reasons = assessment.reasons.map { reason in
            switch (condition, reason) {
            case (.warning2, .poorAirQuality): "Concerning Air Quality Detected"
            case (.warning2, .highHeat): "Abnormally High Heat Detected"
            default: reason.displayName
            }
        }.joined(separator: ", ")
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
        // The banner uses short general guidance. Full rule details stay in Monitor.
        switch condition {
        case .normal: return nil
        case .warning1: return "Check your kitchen.\nCheck the stove and nearby area."
        case .warning2: return "Check the stove NOW.\nTurn it off if safe."
        case .alarm: return "\(alarmActivityInstruction)\n\(alarmActivitySupportingInstruction)"
        }
    }

    private static func ruleMessage(for assessment: KitchenAssessment, condition: KitchenCondition) -> String? {
        guard let ruleID = assessment.ruleID, let rule = KitchenRuleMessages.rules[ruleID],
              rule.condition == condition, let template = rule.notificationTemplate else { return nil }
        return render(template, duration: assessment.absenceDurationSeconds)
    }

    private static func render(_ template: String, duration: Int?) -> String {
        guard let duration else {
            return template.replacingOccurrences(of: "no one has been detected for {duration}",
                                                 with: "no one is detected")
                .replacingOccurrences(of: "No one has been detected for {duration}",
                                      with: "No Presence Detected")
        }
        let minutes = duration / 60
        let seconds = duration % 60
        var parts: [String] = []
        if minutes > 0 { parts.append("\(minutes) \(minutes == 1 ? "minute" : "minutes")") }
        if seconds > 0 || parts.isEmpty { parts.append("\(seconds) \(seconds == 1 ? "second" : "seconds")") }
        return template.replacingOccurrences(of: "{duration}", with: parts.joined(separator: " "))
    }
}
