struct AlarmGuidance {
    let alarmInstruction: String
    let alarmSupportingInstruction: String
    let snoozedInstruction: String

    static let mock = AlarmGuidance(
        alarmInstruction: KitchenGuidance.alarmInstruction,
        alarmSupportingInstruction: KitchenGuidance.alarmSupportingInstruction,
        snoozedInstruction: KitchenGuidance.snoozedInstruction
    )
}
