// Message catalog from the supplied 32-rule CTA table. No fuzzy inference runs here.
nonisolated enum KitchenRuleMessages {
    struct Rule {
        let condition: KitchenCondition
        let notificationTemplate: String?
    }

    static let rules: [Int: Rule] = [
        1: Rule(condition: .normal, notificationTemplate: nil),
        2: Rule(condition: .normal, notificationTemplate: nil),
        3: Rule(condition: .warning1, notificationTemplate: "Lightly Polluted Air. No one has been detected for {duration}. Check the kitchen for sources of pollution."),
        4: Rule(condition: .normal, notificationTemplate: nil),
        5: Rule(condition: .warning1, notificationTemplate: "Moderately Polluted Air. No one has been detected for {duration}. Check the stove and the area around it."),
        6: Rule(condition: .normal, notificationTemplate: nil),
        7: Rule(condition: .warning1, notificationTemplate: "Poor Air Quality. No Presence Detected. Check your kitchen."),
        8: Rule(condition: .normal, notificationTemplate: nil),
        9: Rule(condition: .warning1, notificationTemplate: "High Heat Detected. No one has been detected for {duration}. Check the stove and stay nearby."),
        10: Rule(condition: .warning2, notificationTemplate: "High Heat Detected. No one has been detected for {duration}. Check the stove now. Turn it off if you can do so safely."),
        11: Rule(condition: .normal, notificationTemplate: nil),
        12: Rule(condition: .warning1, notificationTemplate: "High Heat Detected. Lightly Polluted Air. No Presence Detected. Check the stove and stay nearby."),
        13: Rule(condition: .warning2, notificationTemplate: "High Heat Detected. Lightly Polluted Air. No one has been detected for {duration}. Check the stove now. Turn it off if you can do so safely."),
        14: Rule(condition: .warning1, notificationTemplate: "High Heat Detected. Moderately Polluted Air. Check the stove and look for sources of pollution."),
        15: Rule(condition: .warning2, notificationTemplate: "High Heat Detected. Moderately Polluted Air. No one has been detected for {duration}. Check the stove now. Turn it off if you can do so safely."),
        16: Rule(condition: .warning1, notificationTemplate: "High Heat Detected. Poor Air Quality. Check the stove. If you see smoke, turn it off if you can do so safely."),
        17: Rule(condition: .warning2, notificationTemplate: "High Heat Detected. Concerning Air Quality Detected. No Presence Detected. Check the stove now. Turn it off if you can do so safely."),
        18: Rule(condition: .normal, notificationTemplate: nil),
        19: Rule(condition: .warning1, notificationTemplate: "High Heat Detected. No Presence Detected. Check the stove and stay nearby."),
        20: Rule(condition: .warning2, notificationTemplate: "High Heat Detected. No one has been detected for {duration}. Check the stove now. Turn it off if you can do so safely."),
        21: Rule(condition: .warning1, notificationTemplate: "High Heat Detected. Lightly Polluted Air. Check the stove and keep watching your food."),
        22: Rule(condition: .warning2, notificationTemplate: "High Heat Detected. Lightly Polluted Air. No one has been detected for {duration}. Check the stove now. Turn it off if you can do so safely."),
        23: Rule(condition: .warning1, notificationTemplate: "High Heat Detected. Moderately Polluted Air. Check your food. If you see smoke, turn off the stove if you can do so safely."),
        24: Rule(condition: .warning2, notificationTemplate: "High Heat Detected. Moderately Polluted Air. No Presence Detected. Check the stove now. Turn it off if you can do so safely."),
        25: Rule(condition: .warning2, notificationTemplate: "High Heat Detected. Concerning Air Quality Detected. Turn off the stove now if you can do so safely. Watch the area from a safe distance."),
        26: Rule(condition: .warning2, notificationTemplate: "Abnormally High Heat Detected. Turn off the stove now if you can do so safely. Keep clear of hot cookware."),
        27: Rule(condition: .alarm, notificationTemplate: "Turn off the stove now if you can safely reach it. The stove area temperature is very high, and no one has been detected for {duration}."),
        28: Rule(condition: .warning2, notificationTemplate: "Abnormally High Heat Detected. Lightly Polluted Air. Turn off the stove now if you can do so safely. Keep clear of hot cookware."),
        29: Rule(condition: .alarm, notificationTemplate: "Turn off the stove now if you can safely reach it. The stove area temperature is very high, the air is lightly polluted, and no one has been detected for {duration}."),
        30: Rule(condition: .warning2, notificationTemplate: "Abnormally High Heat Detected. Moderately Polluted Air. Turn off the stove now if you can do so safely. Keep clear of hot cookware."),
        31: Rule(condition: .alarm, notificationTemplate: "Turn off the stove now if you can safely reach it. The stove area temperature is very high, the air is moderately polluted, and no one is detected."),
        32: Rule(condition: .alarm, notificationTemplate: "Turn off the stove now if you can safely reach it. The stove area temperature is very high, and air quality is poor."),
    ]
}
