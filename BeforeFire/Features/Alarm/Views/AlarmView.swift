import SwiftUI

struct AlarmView: View {
    var isHubDisconnected = false
    let onSnooze: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var isDismissing = false
    @ScaledMetric(relativeTo: .title2) private var titleSize = AlarmStyle.titleSize
    @ScaledMetric(relativeTo: .body) private var messageSize = AlarmStyle.messageSize
    @ScaledMetric(relativeTo: .body) private var offlineTextSize = AlarmStyle.hubOfflineTextSize
    @ScaledMetric(relativeTo: .body) private var offlineIconSize = AlarmStyle.hubOfflineIconSize

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    if isHubDisconnected {
                        hubOfflineBadge
                            .padding(.bottom, AlarmStyle.hubOfflineBottomSpacing)
                    }

                    AlarmEmblem()
                        .frame(width: emblemSize, height: emblemSize)
                        .accessibilityHidden(true)

                    Text("CHECK YOUR KITCHEN NOW!")
                        .font(.system(size: titleSize, weight: .bold))
                        .accessibilityAddTraits(.isHeader)
                        .padding(.top, AlarmStyle.emblemTextSpacing)

                    alarmMessage
                        .padding(.top, AlarmStyle.messageSpacing)

                    Spacer(minLength: AlarmStyle.minimumSliderSpacing)

                    // The preview starts a local countdown. It sends no alarm command.
                    AlarmSnoozeSlider { snoozePreview() }
                }
                .multilineTextAlignment(.center)
                .foregroundStyle(AlarmStyle.foreground)
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
        .background {
            LinearGradient(
                colors: [AlarmStyle.backgroundTop, AlarmStyle.backgroundBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
        .opacity(isDismissing ? 0 : 1)
        .allowsHitTesting(!isDismissing)
        .preferredColorScheme(.dark)
        .accessibilityIdentifier("alarm.preview")
        .accessibilityAction(.escape) { dismiss() }
    }

    private var emblemSize: CGFloat {
        isHubDisconnected ? AlarmStyle.offlineEmblemSize : AlarmStyle.emblemSize
    }

    private var hubOfflineBadge: some View {
        HStack(spacing: AlarmStyle.hubOfflineContentSpacing) {
            Image(systemName: "wifi.slash")
                .font(.system(size: offlineIconSize, weight: .semibold))
                .symbolRenderingMode(.palette)
                .foregroundStyle(AlarmStyle.symbol, AlarmStyle.foreground)
                .accessibilityHidden(true)
            Text(AlarmStyle.hubOfflineLabel)
                .font(.system(size: offlineTextSize, weight: .semibold))
        }
        .foregroundStyle(AlarmStyle.foreground)
        .padding(.horizontal, AlarmStyle.hubOfflineHorizontalInset)
        .padding(.vertical, AlarmStyle.hubOfflineVerticalInset)
        .glassEffect(.regular.tint(AlarmStyle.hubOfflineBackground), in: .capsule)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(AlarmStyle.hubOfflineLabel)
        .accessibilityIdentifier("alarm.hubOffline")
    }

    private var alarmMessage: some View {
        VStack(spacing: AlarmStyle.offlineMessageSpacing) {
            if isHubDisconnected {
                Text(AlarmStyle.lastKnownAlarmStatus)
                Text(AlarmStyle.liveStatusUnavailableMessage)
            } else {
                Text("Check the stove and surrounding area.")
            }
        }
        .font(.system(size: messageSize))
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier("alarm.statusMessage")
    }

    private func snoozePreview() {
        guard !isDismissing else { return }
        withAnimation(.easeOut(duration: AlarmStyle.dismissalFadeDuration)) {
            isDismissing = true
        } completion: {
            onSnooze()
        }
    }
}

private struct AlarmEmblem: View {
    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size.width
            ZStack {
                Circle().fill(AlarmStyle.foreground.opacity(0.06))
                Circle().fill(AlarmStyle.foreground.opacity(0.1))
                    .padding(size * 0.08)
                Circle().fill(AlarmStyle.foreground)
                    .padding(size * 0.14)
                SirenOutline()
                    .stroke(AlarmStyle.symbol, style: StrokeStyle(lineWidth: size * 0.036, lineCap: .round, lineJoin: .round))
                    .padding(size * 0.23)
            }
        }
    }
}

// Normalized points keep the siren outline proportional to its circle.
private struct SirenOutline: Shape {
    func path(in rect: CGRect) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
        }
        var path = Path()
        path.move(to: point(0.18, 0.88))
        path.addLine(to: point(0.82, 0.88))
        path.move(to: point(0.26, 0.88))
        path.addLine(to: point(0.26, 0.58))
        path.addCurve(to: point(0.74, 0.58), control1: point(0.26, 0.16), control2: point(0.74, 0.16))
        path.addLine(to: point(0.74, 0.88))
        path.move(to: point(0.5, 0.88))
        path.addLine(to: point(0.5, 0.58))
        for (start, end) in [
            (point(0.5, 0.1), point(0.5, 0.19)),
            (point(0.18, 0.23), point(0.23, 0.29)),
            (point(0.82, 0.23), point(0.77, 0.29)),
            (point(0.04, 0.56), point(0.12, 0.56)),
            (point(0.88, 0.56), point(0.96, 0.56))
        ] {
            path.move(to: start)
            path.addLine(to: end)
        }
        return path
    }
}

#Preview {
    AlarmView(onSnooze: {})
}

#Preview("Large Text") {
    AlarmView(onSnooze: {})
        .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Hub offline") {
    AlarmView(isHubDisconnected: true, onSnooze: {})
}

#Preview("Hub offline · Large Text") {
    AlarmView(isHubDisconnected: true, onSnooze: {})
        .environment(\.dynamicTypeSize, .accessibility3)
}
