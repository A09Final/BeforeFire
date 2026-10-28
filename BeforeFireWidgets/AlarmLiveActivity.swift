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
                .activityBackgroundTint(context.state.isSnoozed ? AlarmLiveActivityStyle.snoozedBackground : Color("AlarmBackgroundTop"))
                .activitySystemActionForegroundColor(AlarmLiveActivityStyle.foreground)
                .widgetURL(AlarmActivityAttributes.previewURL)
                .environment(\.colorScheme, .dark)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    if !context.state.isSnoozed {
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
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: AlarmLiveActivityStyle.spacing) {
                        if context.state.isSnoozed {
                            AlarmSnoozedActivityContent(state: context.state, isExpandedIsland: true)
                        } else {
                            AlarmActivityMessage(state: context.state)
                        }
                        AlarmActivityActions(context: context)
                            .fixedSize(horizontal: false, vertical: true)
                            .layoutPriority(1)
                    }
                    .padding(.vertical, AlarmLiveActivityStyle.expandedContentInset)
                }
            } compactLeading: {
                Image(systemName: context.state.symbol)
                    .foregroundStyle(AlarmLiveActivityStyle.accent(for: context.state))
                    .accessibilityLabel(context.state.status)
            } compactTrailing: {
                if context.state.isSnoozed {
                    AlarmActivityCountdown(state: context.state)
                        .font(.system(size: AlarmLiveActivityStyle.compactCountdownTextSize, weight: .semibold))
                        .foregroundStyle(AlarmLiveActivityStyle.snoozedAccent)
                        .frame(width: AlarmLiveActivityStyle.compactCountdownWidth)
                } else {
                    Image(systemName: "exclamationmark.circle")
                        .foregroundStyle(AlarmLiveActivityStyle.alarm)
                        .accessibilityLabel(context.state.status)
                }
            } minimal: {
                Image(systemName: context.state.symbol)
                    .foregroundStyle(AlarmLiveActivityStyle.accent(for: context.state))
                    .accessibilityLabel(context.state.status)
            }
            .widgetURL(AlarmActivityAttributes.previewURL)
            .keylineTint(AlarmLiveActivityStyle.accent(for: context.state))
        }
    }
}

private struct AlarmLockScreenView: View {
    let context: ActivityViewContext<AlarmActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: AlarmLiveActivityStyle.spacing) {
            if context.state.isSnoozed {
                AlarmSnoozedActivityContent(state: context.state)
            } else {
                Label(context.state.status, systemImage: context.state.symbol)
                    .font(.system(size: AlarmLiveActivityStyle.statusSize, weight: .medium))
                AlarmActivityMessage(state: context.state)
            }
            AlarmActivityActions(context: context)
        }
        .foregroundStyle(AlarmLiveActivityStyle.foreground)
        .padding(AlarmLiveActivityStyle.inset)
        .background {
            if context.state.isSnoozed {
                AlarmLiveActivityStyle.snoozedBackground
            } else {
                AlarmLiveActivityStyle.gradient
            }
        }
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
        Group {
            if context.state.isSnoozed {
                Button(intent: ResumeAlarmPreviewIntent(activityID: context.activityID)) {
                    Text("Resume Alarm")
                        .modifier(AlarmActivityActionStyle())
                }
            } else {
                Button(intent: SnoozeAlarmPreviewIntent(activityID: context.activityID)) {
                    Label("Snooze", systemImage: "bell.slash")
                        .modifier(AlarmActivityActionStyle())
                }
            }
        }
        .buttonStyle(.plain)
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
    AlarmActivityAttributes.ContentState().snoozed(at: .now)
}

#Preview("Expanded", as: .dynamicIsland(.expanded), using: AlarmActivityAttributes(previewID: UUID())) {
    AlarmLiveActivity()
} contentStates: {
    AlarmActivityAttributes.ContentState()
    AlarmActivityAttributes.ContentState().snoozed(at: .now)
}

#Preview("Compact", as: .dynamicIsland(.compact), using: AlarmActivityAttributes(previewID: UUID())) {
    AlarmLiveActivity()
} contentStates: {
    AlarmActivityAttributes.ContentState()
    AlarmActivityAttributes.ContentState().snoozed(at: .now)
}

#Preview("Minimal", as: .dynamicIsland(.minimal), using: AlarmActivityAttributes(previewID: UUID())) {
    AlarmLiveActivity()
} contentStates: {
    AlarmActivityAttributes.ContentState()
    AlarmActivityAttributes.ContentState().snoozed(at: .now)
}
