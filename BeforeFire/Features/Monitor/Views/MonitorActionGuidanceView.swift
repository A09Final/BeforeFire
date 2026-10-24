import SwiftUI

struct MonitorActionGuidanceView: View {
    let guidance: String

    // DESIGN: Change the action text size and line spacing here.
    @ScaledMetric(relativeTo: .body) private var textSize = 20.0
    private let lineSpacing: CGFloat = 4

    var body: some View {
        Text(guidance)
            .font(.system(size: textSize))
            .foregroundStyle(MonitorStyle.secondaryText)
            .lineSpacing(lineSpacing)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("monitor.actionGuidance")
    }
}
