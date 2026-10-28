import SwiftUI

struct SnoozedAlarmView: View {
    let state: AlarmActivityAttributes.ContentState
    let onResume: () -> Void

    @Environment(\.dismiss) private var dismiss
    @ScaledMetric(relativeTo: .largeTitle) private var countdownSize = AlarmStyle.countdownTextSize
    @ScaledMetric(relativeTo: .title) private var headingSize = AlarmStyle.snoozedTitleSize
    @ScaledMetric(relativeTo: .body) private var messageSize = AlarmStyle.snoozedMessageSize
    @ScaledMetric(relativeTo: .body) private var buttonSize = AlarmStyle.sliderTextSize

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    countdown
                        .frame(width: min(AlarmStyle.countdownDiameter, geometry.size.width - AlarmStyle.horizontalInset * 2),
                               height: min(AlarmStyle.countdownDiameter, geometry.size.width - AlarmStyle.horizontalInset * 2))

                    Text("Alarm snoozed")
                        .font(.system(size: headingSize, weight: .bold))
                        .foregroundStyle(AlarmStyle.snoozedAccent)
                        .padding(.top, AlarmStyle.snoozedTitleSpacing)
                        .accessibilityAddTraits(.isHeader)

                    Text("Check your kitchen now.")
                        .font(.system(size: messageSize))
                        .foregroundStyle(AlarmStyle.foreground.opacity(AlarmStyle.snoozedMessageOpacity))
                        .padding(.top, AlarmStyle.snoozedMessageSpacing)

                    Spacer(minLength: AlarmStyle.minimumSliderSpacing)

                    Button(action: onResume) {
                        Text("Resume Alarm")
                            .font(.system(size: buttonSize, weight: .medium))
                            .foregroundStyle(AlarmStyle.foreground)
                            .frame(maxWidth: .infinity, minHeight: AlarmStyle.sliderHeight)
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .capsule)
                    .overlay {
                        Capsule().strokeBorder(
                            AlarmStyle.foreground.opacity(AlarmStyle.sliderBorderOpacity),
                            lineWidth: AlarmStyle.sliderBorderWidth
                        )
                        .allowsHitTesting(false)
                    }
                    .accessibilityIdentifier("alarm.resume")
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, AlarmStyle.horizontalInset)
                .padding(.top, AlarmStyle.topInset)
                .padding(.bottom, AlarmStyle.bottomInset)
                .frame(maxWidth: AlarmStyle.maximumContentWidth)
                .frame(minHeight: geometry.size.height)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
        }
        .background(AlarmStyle.snoozedBackground.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .accessibilityIdentifier("alarm.snoozed")
        .accessibilityAction(.escape) { dismiss() }
    }

    private var countdown: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            ZStack {
                Circle().stroke(AlarmStyle.foreground.opacity(AlarmStyle.countdownTrackOpacity),
                                lineWidth: AlarmStyle.countdownLineWidth)
                Circle()
                    .trim(from: 0, to: state.remainingFraction(at: timeline.date))
                    .stroke(AlarmStyle.snoozedAccent,
                            style: StrokeStyle(lineWidth: AlarmStyle.countdownLineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack(spacing: AlarmStyle.countdownContentSpacing) {
                    Image(systemName: AlarmActivityAttributes.snoozeSymbol)
                        .font(.system(size: AlarmStyle.countdownIconSize))
                        .accessibilityHidden(true)
                    Text(state.remainingText(at: timeline.date))
                        .font(.system(size: countdownSize, weight: .bold))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(AlarmStyle.sliderLabelMinimumScale)
                        .accessibilityLabel("Snooze time remaining")
                        .accessibilityValue(state.remainingText(at: timeline.date))
                        .accessibilityIdentifier("alarm.snoozeCountdown")
                }
                .foregroundStyle(AlarmStyle.snoozedAccent)
                .padding(AlarmStyle.countdownContentInset)
            }
            .padding(AlarmStyle.countdownLineWidth / 2)
        }
    }
}

#Preview {
    SnoozedAlarmView(state: AlarmActivityAttributes.ContentState().snoozed(at: .now), onResume: {})
}

#Preview("Large Text") {
    SnoozedAlarmView(state: AlarmActivityAttributes.ContentState().snoozed(at: .now), onResume: {})
        .environment(\.dynamicTypeSize, .accessibility3)
}
