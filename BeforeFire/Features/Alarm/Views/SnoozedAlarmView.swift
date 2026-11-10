import SwiftUI

struct SnoozedAlarmView: View {
    let state: AlarmActivityAttributes.ContentState
    var guidance: AlarmGuidance = .mock
    let onResume: () -> Void

    @Environment(\.dismiss) private var dismiss
    @ScaledMetric(relativeTo: .largeTitle) private var countdownSize = AlarmStyle.countdownTextSize
    @ScaledMetric(relativeTo: .title) private var headingSize = AlarmStyle.snoozedTitleSize
    @ScaledMetric(relativeTo: .title2) private var instructionSize = AlarmStyle.titleSize
    @ScaledMetric(relativeTo: .body) private var buttonSize = AlarmStyle.resumeButtonTextSize

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    countdown
                        .frame(width: min(AlarmStyle.countdownDiameter, geometry.size.width - AlarmStyle.horizontalInset * 2),
                               height: min(AlarmStyle.countdownDiameter, geometry.size.width - AlarmStyle.horizontalInset * 2))

                    Text(KitchenGuidance.snoozedAlarmStatus)
                        .font(.system(size: headingSize, weight: .bold))
                        .foregroundStyle(AlarmStyle.snoozedAccent)
                        .padding(.top, AlarmStyle.snoozedTitleSpacing)
                        .accessibilityAddTraits(.isHeader)

                    Text(guidance.snoozedInstruction)
                        .font(.system(size: instructionSize, weight: .bold))
                        .foregroundStyle(AlarmStyle.foreground)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, AlarmStyle.snoozedInstructionSpacing)
                        .accessibilityIdentifier("alarm.snoozedInstruction")
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, AlarmStyle.horizontalInset)
                .padding(.top, AlarmStyle.topInset)
                .frame(maxWidth: AlarmStyle.maximumContentWidth)
                .frame(minHeight: geometry.size.height, alignment: .top)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
            .accessibilityIdentifier("alarm.snoozed")
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            resumeButton
                .padding(.horizontal, AlarmStyle.horizontalInset)
                .frame(maxWidth: AlarmStyle.maximumContentWidth)
                .padding(.top, AlarmStyle.minimumSliderSpacing)
                .padding(.bottom, AlarmStyle.bottomInset)
                .frame(maxWidth: .infinity)
                .accessibilitySortPriority(-1)
        }
        .background(AlarmStyle.snoozedBackground.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .accessibilityAction(.escape) { dismiss() }
    }

    private var resumeButton: some View {
        Button(action: onResume) {
            Text("Resume Alarm")
                .font(.system(size: buttonSize, weight: .medium))
                .foregroundStyle(AlarmStyle.foreground)
                .frame(maxWidth: .infinity, minHeight: AlarmStyle.resumeButtonHeight)
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
