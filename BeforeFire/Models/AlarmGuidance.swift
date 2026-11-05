struct AlarmGuidance {
    let alarmInstruction: String
    let alarmSupportingInstruction: String
    let snoozedInstruction: String

    static let mock = AlarmGuidance(
        alarmInstruction: "Turn your stove of NOW!",
        alarmSupportingInstruction: "Call closest available person if you are not able to reach the stove",
        snoozedInstruction: "Turn stove off or call the closest available person"
    )
}
