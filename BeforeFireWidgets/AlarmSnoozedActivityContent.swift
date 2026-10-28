import SwiftUI

struct AlarmSnoozedActivityContent: View {
    let state: AlarmActivityAttributes.ContentState
    var isExpandedIsland = false

    private var diameter: CGFloat {
        isExpandedIsland ? AlarmLiveActivityStyle.expandedCountdownDiameter : AlarmLiveActivityStyle.countdownDiameter
    }

    private var ringScale: CGFloat { diameter / AlarmLiveActivityStyle.countdownDiameter }

    var body: some View {
        HStack(spacing: AlarmLiveActivityStyle.spacing) {
            ZStack {
                if let interval = state.snoozeInterval {
                    // System timer views continue updating without an app-driven per-second loop.
                    ProgressView(timerInterval: interval, countsDown: true) {
                        EmptyView()
                    } currentValueLabel: {
                        EmptyView()
                    }
                    .progressViewStyle(.circular)
                    .tint(AlarmLiveActivityStyle.snoozedAccent)
                    .accessibilityHidden(true)
                }

                VStack(spacing: AlarmLiveActivityStyle.countdownContentSpacing) {
                    Image(systemName: AlarmActivityAttributes.snoozeSymbol)
                        .font(.system(size: AlarmLiveActivityStyle.countdownIconSize * ringScale))
                        .accessibilityHidden(true)
                    AlarmActivityCountdown(state: state)
                        .font(.system(size: AlarmLiveActivityStyle.countdownTextSize * ringScale, weight: .bold))
                }
                .foregroundStyle(AlarmLiveActivityStyle.snoozedAccent)
            }
            .frame(width: diameter, height: diameter)

            VStack(alignment: .leading, spacing: AlarmLiveActivityStyle.expandedContentInset) {
                Text("Alarm snoozed")
                    .font(.system(size: AlarmLiveActivityStyle.titleSize, weight: .bold))
                    .foregroundStyle(AlarmLiveActivityStyle.snoozedAccent)
                    .lineLimit(1)
                    .minimumScaleFactor(AlarmLiveActivityStyle.minimumTextScale)
                Text("Check your kitchen now.")
                    .font(.system(size: AlarmLiveActivityStyle.messageSize))
                    .foregroundStyle(AlarmLiveActivityStyle.foreground.opacity(AlarmLiveActivityStyle.snoozedMessageOpacity))
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        // The camera cutout leaves less vertical space than the Lock Screen card.
        .frame(height: isExpandedIsland ? AlarmLiveActivityStyle.expandedCountdownDiameter : nil)
        .environment(\.colorScheme, .dark)
    }
}

struct AlarmActivityCountdown: View {
    let state: AlarmActivityAttributes.ContentState

    var body: some View {
        Group {
            if let interval = state.snoozeInterval {
                Text(timerInterval: interval, countsDown: true, showsHours: false)
            } else {
                Text("00:00")
            }
        }
        .monospacedDigit()
        .multilineTextAlignment(.center)
        .lineLimit(1)
        .minimumScaleFactor(AlarmLiveActivityStyle.minimumTextScale)
        .accessibilityLabel("Snooze time remaining")
    }
}
