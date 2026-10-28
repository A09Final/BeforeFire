import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

@main
struct BeforeFireWidgets: WidgetBundle {
    var body: some Widget {
        AlarmLiveActivity()
    }
}

struct AlarmLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmActivityAttributes.self) { context in
            AlarmLockScreenView(context: context)
                .activityBackgroundTint(Color("AlarmBackgroundTop"))
                .activitySystemActionForegroundColor(AlarmLiveActivityStyle.foreground)
                .widgetURL(AlarmActivityAttributes.previewURL)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: AlarmLiveActivityStyle.spacing) {
                        Image(systemName: context.state.symbol)
                            .font(.system(size: AlarmLiveActivityStyle.iconSize))
                            .foregroundStyle(AlarmLiveActivityStyle.alarm)
                            .accessibilityHidden(true)
                        Text(context.state.status)
                            .font(.system(size: AlarmLiveActivityStyle.statusSize, weight: .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(AlarmLiveActivityStyle.minimumTextScale)
                            .foregroundStyle(AlarmLiveActivityStyle.alarm)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: AlarmLiveActivityStyle.spacing) {
                        AlarmActivityMessage(state: context.state)
                        AlarmActivityActions(context: context)
                            .fixedSize(horizontal: false, vertical: true)
                            .layoutPriority(1)
                    }
                    .padding(.vertical, AlarmLiveActivityStyle.expandedContentInset)
                }
            } compactLeading: {
                Image(systemName: context.state.symbol)
                    .foregroundStyle(AlarmLiveActivityStyle.alarm)
                    .accessibilityLabel(context.state.status)
            } compactTrailing: {
                Image(systemName: context.state.isSnoozed ? "bell.slash.fill" : "exclamationmark.circle")
                    .foregroundStyle(AlarmLiveActivityStyle.alarm)
                    .accessibilityLabel(context.state.status)
            } minimal: {
                Image(systemName: context.state.symbol)
                    .foregroundStyle(AlarmLiveActivityStyle.alarm)
                    .accessibilityLabel(context.state.status)
            }
            .widgetURL(AlarmActivityAttributes.previewURL)
            .keylineTint(AlarmLiveActivityStyle.alarm)
        }
    }
}

private struct AlarmLockScreenView: View {
    let context: ActivityViewContext<AlarmActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: AlarmLiveActivityStyle.spacing) {
            Label(context.state.status, systemImage: context.state.symbol)
                .font(.system(size: AlarmLiveActivityStyle.statusSize, weight: .medium))

            AlarmActivityMessage(state: context.state)
            AlarmActivityActions(context: context)
        }
        .foregroundStyle(AlarmLiveActivityStyle.foreground)
        .padding(AlarmLiveActivityStyle.inset)
        .background(AlarmLiveActivityStyle.gradient)
    }
}

private struct AlarmActivityMessage: View {
    let state: AlarmActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(state.title)
                .font(.system(size: AlarmLiveActivityStyle.titleSize, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(AlarmLiveActivityStyle.minimumTextScale)
            Text(state.message)
                .font(.system(size: AlarmLiveActivityStyle.messageSize))
                .lineLimit(2)
        }
        .foregroundStyle(AlarmLiveActivityStyle.foreground)
        .accessibilityElement(children: .combine)
    }
}

private struct AlarmActivityActions: View {
    let context: ActivityViewContext<AlarmActivityAttributes>

    var body: some View {
        Button(intent: SnoozeAlarmPreviewIntent(activityID: context.activityID)) {
            Label(context.state.isSnoozed ? "Snoozed" : "Snooze", systemImage: "bell.slash")
                .modifier(AlarmActivityActionStyle())
        }
        .buttonStyle(.plain)
        .disabled(context.state.isSnoozed)
        .accessibilityHint("Changes the preview only. No alarm command is sent.")
    }
}

private struct AlarmActivityActionStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            // Bound control height because the system limits the expanded Live Activity height.
            .font(.system(size: AlarmLiveActivityStyle.actionTextSize, weight: .medium))
            .lineLimit(1)
            .minimumScaleFactor(AlarmLiveActivityStyle.minimumTextScale)
            .foregroundStyle(AlarmLiveActivityStyle.foreground)
            .frame(maxWidth: .infinity, minHeight: AlarmLiveActivityStyle.actionHeight)
            // Widget controls use simple translucent surfaces; no custom drag or glow animations.
            .background(AlarmLiveActivityStyle.foreground.opacity(AlarmLiveActivityStyle.actionOpacity), in: Capsule())
            .overlay {
                Capsule().strokeBorder(
                    AlarmLiveActivityStyle.foreground.opacity(AlarmLiveActivityStyle.actionBorderOpacity),
                    lineWidth: 0.5
                )
            }
    }
}

#Preview("Lock Screen", as: .content, using: AlarmActivityAttributes(previewID: UUID())) {
    AlarmLiveActivity()
} contentStates: {
    AlarmActivityAttributes.ContentState()
    AlarmActivityAttributes.ContentState(isSnoozed: true)
}

#Preview("Expanded", as: .dynamicIsland(.expanded), using: AlarmActivityAttributes(previewID: UUID())) {
    AlarmLiveActivity()
} contentStates: {
    AlarmActivityAttributes.ContentState()
}

#Preview("Compact", as: .dynamicIsland(.compact), using: AlarmActivityAttributes(previewID: UUID())) {
    AlarmLiveActivity()
} contentStates: {
    AlarmActivityAttributes.ContentState()
}

#Preview("Minimal", as: .dynamicIsland(.minimal), using: AlarmActivityAttributes(previewID: UUID())) {
    AlarmLiveActivity()
} contentStates: {
    AlarmActivityAttributes.ContentState()
}
