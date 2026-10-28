import SwiftUI

enum AlarmLiveActivityStyle {
    // DESIGN: These assets are shared with the app. Keep the Dynamic Island background native.
    static let foreground = Color("AlarmForeground")
    static let alarm = Color("DangerRed")
    static let gradient = LinearGradient(
        colors: [Color("AlarmBackgroundTop"), Color("AlarmBackgroundBottom")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let inset: CGFloat = 16
    static let spacing: CGFloat = 8
    // DESIGN: Keep space above and below the expanded content without growing the header.
    static let expandedContentInset: CGFloat = 4
    static let minimumTextScale: CGFloat = 0.75
    static let titleSize: CGFloat = 20
    static let messageSize: CGFloat = 13
    static let statusSize: CGFloat = 12
    static let iconSize: CGFloat = 22
    static let actionHeight: CGFloat = 36
    static let actionTextSize: CGFloat = 15
    static let actionOpacity: Double = 0.16
    static let actionBorderOpacity: Double = 0.25
}
