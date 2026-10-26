import SwiftUI

struct AlertBadge: View {
    enum Severity {
        case warning
        case alarm
    }

    let severity: Severity

    // DESIGN: Badge size is 40 pt at the default text size; card icons use 25 pt.
    @ScaledMetric(relativeTo: .body) private var badgeSize = 40.0

    var body: some View {
        Group {
            switch severity {
            case .warning:
                Image(systemName: "exclamationmark.triangle.fill")
                    .resizable()
                    .scaledToFit()
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(MonitorStyle.primaryText, MonitorStyle.warningBadge)
                    .overlay {
                        Image(systemName: "exclamationmark.triangle")
                            .resizable()
                            .scaledToFit()
                            .symbolRenderingMode(.monochrome)
                            .foregroundStyle(MonitorStyle.primaryText)
                    }
            case .alarm:
                Image(systemName: "exclamationmark.octagon.fill")
                    .resizable()
                    .scaledToFit()
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(MonitorStyle.alarmForeground, MonitorStyle.alarmText)
            }
        }
        .frame(width: badgeSize, height: badgeSize)
        .accessibilityHidden(true)
    }
}
