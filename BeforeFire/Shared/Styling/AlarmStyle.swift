import SwiftUI

enum AlarmStyle {
    // DESIGN: Edit the alarm colors in Assets.xcassets/Colors.
    static let backgroundTop = Color("AlarmBackgroundTop")
    static let backgroundBottom = Color("AlarmBackgroundBottom")
    static let foreground = Color("AlarmForeground")
    static let symbol = Color("DangerRed")
    static let sliderIcon = Color("Onyx")
    static let hubOfflineLabel = AlarmActivityAttributes.hubOfflineLabel
    static let lastKnownAlarmStatus = AlarmActivityAttributes.lastKnownAlarmStatus
    static let liveStatusUnavailableMessage = AlarmActivityAttributes.liveStatusUnavailableMessage
    static let hubOfflineBackground = Color("Onyx")
    static let hubOfflineTextSize: CGFloat = 16
    static let hubOfflineIconSize: CGFloat = 22
    static let hubOfflineContentSpacing: CGFloat = 10
    static let hubOfflineHorizontalInset: CGFloat = 18
    static let hubOfflineVerticalInset: CGFloat = 10
    static let hubOfflineBottomSpacing: CGFloat = 20
    static let offlineMessageSpacing: CGFloat = 8
    // DESIGN: Leave room for the offline badge and both status lines above the snooze control.
    static let offlineEmblemSize: CGFloat = 120
    static let snoozedBackground = Color("Onyx")
    // DESIGN: The view uses dark appearance, so this resolves to Apple's dark system orange.
    static let snoozedAccent = Color(uiColor: .systemOrange)
    static let countdownDiameter: CGFloat = 300
    static let countdownLineWidth: CGFloat = 18
    static let countdownTrackOpacity: Double = 0.2
    static let countdownTextSize: CGFloat = 64
    static let countdownIconSize: CGFloat = 56
    static let countdownContentSpacing: CGFloat = 24
    static let countdownContentInset: CGFloat = 36
    static let snoozedTitleSize: CGFloat = 32
    static let snoozedTitleSpacing: CGFloat = 24
    static let snoozedInstructionSpacing: CGFloat = 32
    static let resumeButtonHeight: CGFloat = 64
    static let resumeButtonTextSize: CGFloat = 20

    // DESIGN: The symbol and rings scale together. Text follows Dynamic Type.
    static let emblemSize: CGFloat = 140
    static let titleSize: CGFloat = 30
    static let alarmHeadingSize: CGFloat = 48
    static let messageSize: CGFloat = 21
    static let horizontalInset: CGFloat = 24
    static let topInset: CGFloat = 32
    static let bottomInset: CGFloat = 76
    static let emblemTextSpacing: CGFloat = 24
    static let messageSpacing: CGFloat = 32
    static let minimumSliderSpacing: CGFloat = 40
    static let maximumContentWidth: CGFloat = 440

    static let snoozeSliderHeight: CGFloat = 64
    static let snoozeSliderTextSize: CGFloat = 20
    static let thumbInset: CGFloat = 3
    static let thumbSize: CGFloat = 58
    static let snoozeIconSize: CGFloat = 24
    static let sliderLabelSpacing: CGFloat = 10
    static let sliderLabelTrailingInset: CGFloat = 20
    static let sliderLabelMinimumScale: CGFloat = 0.7
    static let sliderFillOpacity: Double = 0.12
    static let sliderBorderOpacity: Double = 0.5
    static let sliderBorderWidth: CGFloat = 1.5
    static let slideCompletionFraction: CGFloat = 0.85
    // DESIGN: Fade the complete alarm screen before removing its presentation.
    static let dismissalFadeDuration: Double = 0.3
}
