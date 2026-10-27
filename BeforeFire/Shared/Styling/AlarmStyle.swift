import SwiftUI

enum AlarmStyle {
    // DESIGN: Edit the alarm colors in Assets.xcassets/Colors.
    static let backgroundTop = Color("AlarmBackgroundTop")
    static let backgroundBottom = Color("AlarmBackgroundBottom")
    static let foreground = Color("AlarmForeground")
    static let symbol = Color("DangerRed")
    static let sliderIcon = Color("Onyx")

    // DESIGN: The symbol and rings scale together. Text follows Dynamic Type.
    static let emblemSize: CGFloat = 252
    static let titleSize: CGFloat = 25
    static let messageSize: CGFloat = 17
    static let sliderTextSize: CGFloat = 24
    static let horizontalInset: CGFloat = 24
    static let topInset: CGFloat = 32
    static let bottomInset: CGFloat = 76
    static let emblemTextSpacing: CGFloat = 24
    static let messageSpacing: CGFloat = 32
    static let minimumSliderSpacing: CGFloat = 40
    static let maximumContentWidth: CGFloat = 440

    // DESIGN: Keep the large Clock-style proportions with the sketch's red and white colors.
    static let sliderHeight: CGFloat = 104
    static let thumbInset: CGFloat = 3
    static let thumbSize: CGFloat = 98
    static let snoozeIconSize: CGFloat = 35
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
