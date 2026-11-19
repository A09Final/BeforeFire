import SwiftUI
import WidgetKit

struct KitchenStatusWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: KitchenStatusWidgetConnection.kind, provider: KitchenStatusTimelineProvider()) { entry in
            KitchenStatusWidgetView(entry: entry)
        }
        .configurationDisplayName("Kitchen Status")
        .pushHandler(KitchenStatusWidgetPushHandler.self)
        .description("See your kitchen status from the linked BeforeFire sensor.")
        .supportedFamilies([.systemMedium])
    }
}

private struct KitchenStatusWidgetView: View {
    let entry: KitchenStatusEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(entry.isOutdated ? "LAST KNOWN STATUS" : MonitorStyle.statusHeading.uppercased())
                    .font(.system(size: 13, weight: .semibold).width(MonitorStyle.fontWidth))
                    .tracking(MonitorStyle.statusHeadingTracking)
                    .foregroundStyle(MonitorStyle.secondaryText)
                    .accessibilityHidden(true)
                Spacer(minLength: 0)
                if let measuredAt = entry.measuredAt {
                    HStack(spacing: 3) {
                        Text("Updated")
                        Text(measuredAt, style: .time)
                    }
                    .font(.caption2)
                    .foregroundStyle(MonitorStyle.secondaryText)
                    .lineLimit(1)
                    .accessibilityElement(children: .combine)
                }
            }

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
        if entry.isOutdated { return "Open BeforeFire to check the current status." }
        if entry.needsSensor { return "Connect a sensor in BeforeFire." }
        if entry.status == .offline { return "No current sensor readings." }
        return entry.status.guidance
    }
}
