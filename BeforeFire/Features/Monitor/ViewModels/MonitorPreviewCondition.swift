enum MonitorPreviewCondition: String, CaseIterable, Identifiable {
    case unsafe = "Unsafe"
    case dangerous = "Dangerous"

    var id: Self { self }

    // DESIGN: Edit the action text for each developer preview here.
    var actionGuidance: String {
        switch self {
        case .unsafe:
            "Check your stove. The stove area is hot, the air is lightly polluted, and no one is detected. Check your food, then stay nearby while the stove is on."
        case .dangerous:
            "Check your kitchen now. The stove area is hot, air quality is poor, and no one is detected. Turn off the stove if you can do so safely."
        }
    }
}
