import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

@main
struct BeforeFireWidgets: WidgetBundle {
    var body: some Widget {
        AlarmLiveActivity()
        KitchenStatusWidget()
    }
}

struct AlarmLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmActivityAttributes.self) { context in
            AlarmLockScreenView(context: context)
                .activityBackgroundTint(context.alarmDisplayState.isSnoozed ? AlarmLiveActivityStyle.snoozedBackground : Color("AlarmBackgroundTop"))
                .activitySystemActionForegroundColor(AlarmLiveActivityStyle.foreground)
                .widgetURL(context.attributes.openURL)
                .environment(\.colorScheme, .dark)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    if !context.alarmDisplayState.isSnoozed {
                        HStack(spacing: AlarmLiveActivityStyle.spacing) {
                            Image(systemName: context.alarmDisplayState.symbol)
                                .font(.system(size: AlarmLiveActivityStyle.iconSize))
                                .foregroundStyle(AlarmLiveActivityStyle.alarm)
                                .accessibilityHidden(true)
                            Text(context.alarmDisplayState.status)
                                .font(.system(size: AlarmLiveActivityStyle.statusSize, weight: .medium))
                                .lineLimit(1)
                                .minimumScaleFactor(AlarmLiveActivityStyle.minimumTextScale)
                                .foregroundStyle(AlarmLiveActivityStyle.alarm)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: AlarmLiveActivityStyle.spacing) {
                        if context.alarmDisplayState.isSnoozed {
                            AlarmSnoozedActivityContent(state: context.alarmDisplayState, isExpandedIsland: true)
                        } else {
                            AlarmActivityMessage(state: context.alarmDisplayState)
                        }
                        AlarmActivityActions(context: context)
                            .fixedSize(horizontal: false, vertical: true)
                            .layoutPriority(1)
                    }
                    .padding(.vertical, AlarmLiveActivityStyle.expandedContentInset)
                }
            } compactLeading: {
                Image(systemName: context.alarmDisplayState.symbol)
                    .foregroundStyle(AlarmLiveActivityStyle.accent(for: context.alarmDisplayState))
                    .accessibilityLabel(context.alarmDisplayState.status)
            } compactTrailing: {
                if context.alarmDisplayState.isSnoozed {
                    AlarmActivityCountdown(state: context.alarmDisplayState)
                        .font(.system(size: AlarmLiveActivityStyle.compactCountdownTextSize, weight: .semibold))
                        .foregroundStyle(AlarmLiveActivityStyle.snoozedAccent)
                        .frame(width: AlarmLiveActivityStyle.compactCountdownWidth)
                } else {
                    Image(systemName: "exclamationmark.circle")
                        .foregroundStyle(AlarmLiveActivityStyle.alarm)
                        .accessibilityLabel(context.alarmDisplayState.status)
                }
            } minimal: {
                Image(systemName: context.alarmDisplayState.symbol)
                    .foregroundStyle(AlarmLiveActivityStyle.accent(for: context.alarmDisplayState))
                    .accessibilityLabel(context.alarmDisplayState.status)
            }
            .widgetURL(context.attributes.openURL)
            .keylineTint(AlarmLiveActivityStyle.accent(for: context.alarmDisplayState))
        }
    }
}

private extension ActivityViewContext where Attributes == AlarmActivityAttributes {
    var alarmDisplayState: AlarmActivityAttributes.ContentState {
        state.displayState(isStale: isStale, at: .now)
    }
}

private struct AlarmLockScreenView: View {
    let context: ActivityViewContext<AlarmActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: AlarmLiveActivityStyle.spacing) {
            if context.alarmDisplayState.isSnoozed {
                AlarmSnoozedActivityContent(state: context.alarmDisplayState)
            } else {
                Label(context.alarmDisplayState.status, systemImage: context.alarmDisplayState.symbol)
                    .font(.system(size: AlarmLiveActivityStyle.statusSize, weight: .medium))
                AlarmActivityMessage(state: context.alarmDisplayState)
            }
            AlarmActivityActions(context: context)
        }
        .foregroundStyle(AlarmLiveActivityStyle.foreground)
        .padding(AlarmLiveActivityStyle.inset)
        .background {
            if context.alarmDisplayState.isSnoozed {
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
            Text(state.activityTitle)
                .font(.system(size: AlarmLiveActivityStyle.titleSize, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(AlarmLiveActivityStyle.minimumTextScale)
            Text(state.activityMessage)
                .font(.system(size: AlarmLiveActivityStyle.messageSize))
                .lineLimit(1)
                .minimumScaleFactor(AlarmLiveActivityStyle.minimumTextScale)
        }
        .foregroundStyle(AlarmLiveActivityStyle.foreground)
        .accessibilityElement(children: .combine)
    }
}

private struct AlarmActivityActions: View {
    let context: ActivityViewContext<AlarmActivityAttributes>

    var body: some View {
        Group {
            if context.alarmDisplayState.isSnoozed {
                Button(intent: ResumeAlarmPreviewIntent(activityID: context.activityID)) {
                    Text("Resume Alarm")
                        .modifier(AlarmActivityActionStyle())
                }
            } else {
                Button(intent: SnoozeAlarmPreviewIntent(activityID: context.activityID)) {
                    Label("Silence", systemImage: "bell.slash")
                        .modifier(AlarmActivityActionStyle())
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint("Silences or resumes alarm alerts on this iPhone only.")
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
