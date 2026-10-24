enum MonitorPreviewCondition: String, CaseIterable, Identifiable {
    case unsafe = "Unsafe"
    case dangerous = "Dangerous"

    var id: Self { self }

    var statusTitle: String {
        "Your Kitchen Is\n\(rawValue)"
    }

    // DESIGN: Edit the action text for each developer preview here.
    var actionGuidance: String {
        switch self {
        case .unsafe:
            "Check your kitchen now.\nStay nearby while the stove is hot."
        case .dangerous:
            "Check your kitchen now.\nCheck the stove and surrounding area."
        }
    }
}
