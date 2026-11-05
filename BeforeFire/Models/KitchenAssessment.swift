import Foundation

nonisolated enum KitchenCondition: String, Codable, CaseIterable, Sendable {
    case normal, warning1, warning2, alarm

    var displayName: String {
        switch self {
        case .normal: "Normal"
        case .warning1: "Unsafe"
        case .warning2: "Dangerous"
        case .alarm: "Alarm"
        }
    }
}

nonisolated enum KitchenConditionReason: String, Codable, CaseIterable, Sendable {
    case poorAirQuality = "poor_air_quality"
    case noPresence = "no_presence"
    case highHeat = "high_heat"

    var displayName: String {
        switch self {
        case .poorAirQuality: "Poor Air Quality"
        case .noPresence: "No Presence Detected"
        case .highHeat: "High Heat Detected"
        }
    }
}

/// A decision reported by the sensor. This type does not evaluate sensor values or fuzzy scores.
nonisolated struct KitchenAssessment: Decodable, Equatable, Sendable {
    let condition: KitchenCondition?
    let isValid: Bool
    let reasons: [KitchenConditionReason]
    let ruleID: Int?
    let absenceDurationSeconds: Int?

    var validCondition: KitchenCondition? { isValid ? condition : nil }

    init(condition: KitchenCondition?, isValid: Bool, reasons: [KitchenConditionReason] = [],
         ruleID: Int? = nil, absenceDurationSeconds: Int? = nil) {
        self.condition = condition
        self.isValid = isValid
        self.reasons = KitchenConditionReason.allCases.filter { reasons.contains($0) }
        self.ruleID = ruleID
        self.absenceDurationSeconds = absenceDurationSeconds.flatMap { $0 >= 0 ? $0 : nil }
    }

    private enum CodingKeys: String, CodingKey {
        case condition, valid, reasons
        case ruleID = "rule_id"
        case absenceDurationSeconds = "absence_duration_seconds"
    }

    init(from decoder: Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            condition: try fields.decodeIfPresent(String.self, forKey: .condition).flatMap(KitchenCondition.init(rawValue:)),
            isValid: try fields.decodeIfPresent(Bool.self, forKey: .valid) ?? false,
            reasons: try fields.decodeIfPresent([String].self, forKey: .reasons)?.compactMap(KitchenConditionReason.init(rawValue:)) ?? [],
            ruleID: try fields.decodeIfPresent(Int.self, forKey: .ruleID),
            absenceDurationSeconds: try fields.decodeIfPresent(Int.self, forKey: .absenceDurationSeconds)
        )
    }
}
