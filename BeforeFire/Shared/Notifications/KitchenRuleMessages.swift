// Message catalog from the supplied 32-rule CTA table. No fuzzy inference runs here.
nonisolated enum KitchenRuleMessages {
    struct Rule {
        let condition: KitchenCondition
        let notificationTemplate: String?
    }

    static let rules: [Int: Rule] = [
        1: Rule(condition: .normal, notificationTemplate: nil),
        2: Rule(condition: .normal, notificationTemplate: nil),
        3: Rule(condition: .warning1, notificationTemplate: "Check your kitchen. The air is lightly polluted, and no one has been detected for {duration}. Check for sources that may affect the air."),
        4: Rule(condition: .normal, notificationTemplate: nil),
        5: Rule(condition: .warning1, notificationTemplate: "Check your kitchen. The air is moderately polluted, and no one has been detected for {duration}. Check the stove and the surrounding area."),
        6: Rule(condition: .normal, notificationTemplate: nil),
        7: Rule(condition: .warning1, notificationTemplate: "Check your kitchen. Air quality is poor, and no one is detected. Check the stove and other possible sources of air pollution."),
        8: Rule(condition: .normal, notificationTemplate: nil),
        9: Rule(condition: .warning1, notificationTemplate: "Check your stove. The stove area is hot, and no one has been detected for {duration}. Check your food, then stay nearby while the stove is on."),
        10: Rule(condition: .warning2, notificationTemplate: "Check your stove now. The stove area is hot, and no one has been detected for {duration}. Check your food. Turn off the stove if you cannot stay nearby."),
        11: Rule(condition: .normal, notificationTemplate: nil),
        12: Rule(condition: .warning1, notificationTemplate: "Check your stove. The stove area is hot, the air is lightly polluted, and no one is detected. Check your food, then stay nearby while the stove is on."),
        13: Rule(condition: .warning2, notificationTemplate: "Check your stove now. The stove area is hot, the air is lightly polluted, and no one has been detected for {duration}. Turn off the stove if you cannot stay nearby."),
        14: Rule(condition: .warning1, notificationTemplate: "Check your stove and food. The stove area is hot, and the air is moderately polluted. Check for other sources that may affect the kitchen air."),
        15: Rule(condition: .warning2, notificationTemplate: "Check your kitchen now. The stove area is hot, the air is moderately polluted, and no one has been detected for {duration}. Turn off the stove if you cannot stay nearby."),
        16: Rule(condition: .warning1, notificationTemplate: "Check your stove and kitchen air. The stove area is hot, and air quality is poor. If you see smoke from the oil or food, turn off the stove if you can do so safely."),
        17: Rule(condition: .warning2, notificationTemplate: "Check your kitchen now. The stove area is hot, air quality is poor, and no one is detected. Turn off the stove if you can do so safely."),
        18: Rule(condition: .normal, notificationTemplate: nil),
        19: Rule(condition: .warning1, notificationTemplate: "Check your stove. The stove area temperature is high, and no one is detected. Check your food, then stay nearby while the stove is on."),
        20: Rule(condition: .warning2, notificationTemplate: "Check your stove now. The stove area temperature is high, and no one has been detected for {duration}. Turn off the stove if you cannot stay nearby."),
        21: Rule(condition: .warning1, notificationTemplate: "Check your stove and food. The stove area temperature is high, and the air is lightly polluted. Keep watching your food after you check it."),
        22: Rule(condition: .warning2, notificationTemplate: "Check your stove now. The stove area temperature is high, the air is lightly polluted, and no one has been detected for {duration}. Turn off the stove if you cannot stay nearby."),
        23: Rule(condition: .warning1, notificationTemplate: "Check your food. The stove area temperature is high, and the air is moderately polluted. If you see smoke from the oil or food, turn off the stove if you can do so safely."),
        24: Rule(condition: .warning2, notificationTemplate: "Check your kitchen now. The stove area temperature is high, the air is moderately polluted, and no one is detected. Turn off the stove if you can do so safely."),
        25: Rule(condition: .warning2, notificationTemplate: "Take action now. The stove area temperature is high, and air quality is poor. Turn off the stove if you can do so safely. Then monitor conditions from a safe distance."),
        26: Rule(condition: .warning2, notificationTemplate: "Turn off the stove if you can do so safely. The stove area temperature is very high, even though air quality is good. Do not touch hot cookware after turning off the stove."),
        27: Rule(condition: .alarm, notificationTemplate: "Turn off the stove now if you can safely reach it. The stove area temperature is very high, and no one has been detected for {duration}."),
        28: Rule(condition: .warning2, notificationTemplate: "Turn off the stove if you can do so safely. The stove area temperature is very high, and the air is lightly polluted. Do not touch hot cookware after turning off the stove."),
        29: Rule(condition: .alarm, notificationTemplate: "Turn off the stove now if you can safely reach it. The stove area temperature is very high, the air is lightly polluted, and no one has been detected for {duration}."),
        30: Rule(condition: .warning2, notificationTemplate: "Turn off the stove if you can do so safely. The stove area temperature is very high, and the air is moderately polluted. Do not touch hot cookware after turning off the stove."),
        31: Rule(condition: .alarm, notificationTemplate: "Turn off the stove now if you can safely reach it. The stove area temperature is very high, the air is moderately polluted, and no one is detected."),
        32: Rule(condition: .alarm, notificationTemplate: "Turn off the stove now if you can safely reach it. The stove area temperature is very high, and air quality is poor."),
    ]
}
