import SwiftUI

struct AlarmSnoozeSlider: View {
    let onSlideComplete: () -> Void

    @GestureState private var dragOffset: CGFloat = 0
    @State private var hasCompletedSlide = false
    @ScaledMetric(relativeTo: .body) private var textSize = AlarmStyle.sliderTextSize
    private static let trackCoordinateSpace = "alarm.snoozeTrack"

    var body: some View {
        GeometryReader { geometry in
            let travel = max(0, geometry.size.width - AlarmStyle.thumbSize - AlarmStyle.thumbInset * 2)
            let offset = hasCompletedSlide ? travel : min(max(0, dragOffset), travel)
            let progress = travel > 0 ? offset / travel : 0

            ZStack(alignment: .leading) {
                Capsule().fill(AlarmStyle.foreground.opacity(AlarmStyle.sliderFillOpacity))
                Capsule().strokeBorder(
                    AlarmStyle.foreground.opacity(AlarmStyle.sliderBorderOpacity),
                    lineWidth: AlarmStyle.sliderBorderWidth
                )

                Text("Slide to Snooze")
                    .font(.system(size: textSize, weight: .medium))
                    .foregroundStyle(AlarmStyle.foreground)
                    .lineLimit(1)
                    .minimumScaleFactor(AlarmStyle.sliderLabelMinimumScale)
                    .padding(.leading, AlarmStyle.thumbInset + AlarmStyle.thumbSize + AlarmStyle.sliderLabelSpacing)
                    .padding(.trailing, AlarmStyle.sliderLabelTrailingInset)
                    .frame(maxWidth: .infinity)
                    .opacity(1 - progress)
                    .allowsHitTesting(false)

                Image(systemName: "bell.slash.fill")
                    .font(.system(size: AlarmStyle.snoozeIconSize, weight: .regular))
                    .foregroundStyle(AlarmStyle.sliderIcon)
                    .frame(width: AlarmStyle.thumbSize, height: AlarmStyle.thumbSize)
                    .glassEffect(.regular.tint(AlarmStyle.foreground).interactive(), in: .circle)
                    .contentShape(Circle())
                    .gesture(
                        DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.trackCoordinateSpace))
                            .updating($dragOffset) { value, state, _ in
                                state = value.translation.width
                            }
                            .onEnded { value in
                                if travel > 0 && value.translation.width >= travel * AlarmStyle.slideCompletionFraction {
                                    completeSlide()
                                }
                            }
                    )
                    // Move through layout so drag translation does not add an offset transform to the glass.
                    .padding(.leading, AlarmStyle.thumbInset + offset)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .coordinateSpace(name: Self.trackCoordinateSpace)
        }
        .frame(height: AlarmStyle.sliderHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Slide to Snooze")
        .accessibilityHint("Closes the alarm preview. No alarm command is sent.")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { completeSlide() }
        .accessibilityIdentifier("alarm.snoozeSlider")
    }

    private func completeSlide() {
        guard !hasCompletedSlide else { return }
        // Keep the handle at the end while the alarm fades out.
        hasCompletedSlide = true
        onSlideComplete()
    }
}
