enum MonitorPreviewCondition: String, CaseIterable, Identifiable {
    case normal = "Normal"
    case unsafe = "Unsafe"
    case dangerous = "Dangerous"
    case alarm = "Alarm"

    var id: Self { self }

    var condition: KitchenCondition {
        switch self {
        case .normal: .normal
        case .unsafe: .warning1
        case .dangerous: .warning2
        case .alarm: .alarm
        }
    }

    var assessment: KitchenAssessment {
        KitchenAssessment(condition: condition, isValid: true,
                          reasons: self == .normal ? [] : [.poorAirQuality, .noPresence, .highHeat])
    }

    var actionGuidance: String? { KitchenGuidance.monitorMessage(for: assessment) }
}
