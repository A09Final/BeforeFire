import SwiftUI
import WidgetKit

struct KitchenStatusWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: KitchenStatusWidgetConnection.kind, provider: KitchenStatusTimelineProvider()) { entry in
            KitchenStatusWidgetView(entry: entry)
        }
        .configurationDisplayName("Kitchen Status")
        .description("See your kitchen status from the linked BeforeFire sensor.")
        .supportedFamilies([.systemMedium])
    }
}

private struct KitchenStatusWidgetView: View {
    let entry: KitchenStatusEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(MonitorStyle.statusHeading.uppercased())
                .font(.system(size: 13, weight: .semibold).width(MonitorStyle.fontWidth))
                .tracking(MonitorStyle.statusHeadingTracking)
                .foregroundStyle(MonitorStyle.secondaryText)
                .accessibilityHidden(true)

            Text(entry.status.title.uppercased())
                .font(.system(size: statusTitleSize, weight: MonitorStyle.valueWeight).width(MonitorStyle.fontWidth))
                .tracking(MonitorStyle.statusTracking / 2)
                .foregroundStyle(entry.status.condition?.usesAlarmColor == true ? MonitorStyle.alarmText : MonitorStyle.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(MonitorStyle.statusMinimumScaleFactor)
                .padding(.vertical, -9)
                .accessibilityLabel("\(MonitorStyle.statusHeading) \(entry.status.title)")
                .accessibilityAddTraits(.isHeader)

            if let message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(MonitorStyle.primaryText)
                    .lineLimit(5)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(MonitorStyle.background, for: .widget)
        .widgetURL(KitchenStatusWidgetConnection.monitorURL)
    }

    private var statusTitleSize: CGFloat {
        entry.status.condition == .normal ? MonitorStyle.statusValueSize : 68
    }

    private var message: String? {
        if entry.needsSensor { return "Connect a sensor in BeforeFire." }
        if entry.status == .offline { return "No current sensor readings." }
        return entry.status.guidance
    }
}
