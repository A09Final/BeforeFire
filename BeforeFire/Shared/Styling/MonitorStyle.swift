import SwiftUI

enum MonitorStyle {
    // DESIGN: All typography uses SF Pro. Change width and weight here.
    static let fontWidth: Font.Width = .compressed
    static let valueWeight: Font.Weight = .black
    static let statusHeadingSize: CGFloat = 19
    static let statusHeadingTracking: CGFloat = 2
    static let statusValueSize: CGFloat = 132
    static let statusHeadingSpacing: CGFloat = -8
    static let statusBottomInset: CGFloat = -14
    static let statusTracking: CGFloat = -3
    static let statusMinimumScaleFactor: CGFloat = 0.38
    static let connectionSize: CGFloat = 14
    static let connectionDotSize: CGFloat = 16
    static let connectionSpacing: CGFloat = 8
    static let settingsIconSize: CGFloat = 21
    static let settingsButtonSize: CGFloat = 48

    // DESIGN: Card labels, illustrations, values, and units have independent sizes.
    static let sensorLabelSize: CGFloat = 18
    static let sensorLabelTracking: CGFloat = 0.3
    static let sensorLabelTopInset: CGFloat = 4
    static let readingTracking: CGFloat = -1.5
    static let sensorIconSize: CGFloat = 40
    static let sensorLabelRowHeight: CGFloat = 28
    static let sensorLabelIconSpacing: CGFloat = 4
    static let numericValueSize: CGFloat = 116
    static let textValueSize: CGFloat = 72
    static let pressureValueSize: CGFloat = 86
    static let unitSize: CGFloat = 38
    static let readingMinimumScaleFactor: CGFloat = 0.45
    // DESIGN: Use .leading, .center, or .trailing; add .top or .bottom for vertical placement.
    static let readingValueAlignment: Alignment = .leading
    static let readingUnitAlignment: VerticalAlignment = .firstTextBaseline
    static let readingUnitSpacing: CGFloat = 3
    static let sensorStatusDotSize: CGFloat = 12
    static let cardContentSpacing: CGFloat = 0
    static let cardHorizontalInset: CGFloat = 16
    static let cardVerticalInset: CGFloat = 16

    // DESIGN: Monitor colors are native color assets. Alarm assets remain separate.
    static let background = Color("MonitorBackground")
    static let darkCard = Color("MonitorCardDark")
    static let lightCard = Color("MonitorCardLight")
    static let primaryText = Color("AlarmForeground")
    static let secondaryText = Color("MonitorSecondaryOnDark")
    static let lightCardText = Color("Onyx")
    static let lightCardSecondaryText = Color("MonitorSecondaryOnLight")
    static let cyan = Color("MonitorCyan")
    static let flame = Color("MonitorFlame")
    static let connected = Color("ConnectionGreen")
    static let alarmText = Color("DangerRed")
    static let warningIndicator = Color("WarningYellow")

    static let actionGuidanceTextSize: CGFloat = 18
    static let actionGuidanceLineSpacing: CGFloat = 4
    static let actionGuidanceTopSpacing: CGFloat = 8
    static let actionGuidanceBottomSpacing: CGFloat = 12

    // DESIGN: The grid fills the available height. Large text can use the scrolling fallback.
    static let spacing: CGFloat = 12
    static let pageHorizontalInset: CGFloat = 16
    static let pageTopInset: CGFloat = 8
    static let normalStatusSensorSpacing: CGFloat = 2
    static let normalGridBottomInset: CGFloat = 20
    static let cardCornerRadius: CGFloat = 24
    static let cardHeight: CGFloat = 148
    static let maximumContentWidth: CGFloat = 600

    static func usesDarkCard(for kind: MonitorReading.Kind) -> Bool {
        switch kind {
        case .stoveHeat, .roomTemperature, .roomHumidity: true
        case .airQuality, .presence, .areaPressure: false
        }
    }
}
