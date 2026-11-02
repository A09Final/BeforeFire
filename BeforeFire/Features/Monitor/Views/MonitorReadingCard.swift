import SwiftUI

struct MonitorReadingCard: View {
    let reading: MonitorReading
    var alertCondition: MonitorPreviewCondition? = nil
    var height: CGFloat? = nil

    @ScaledMetric(relativeTo: .caption) private var labelSize = MonitorStyle.sensorLabelSize
    @ScaledMetric(relativeTo: .body) private var iconSize = MonitorStyle.sensorIconSize
    @ScaledMetric(relativeTo: .body) private var labelRowHeight = MonitorStyle.sensorLabelRowHeight
    @ScaledMetric(relativeTo: .largeTitle) private var numericValueSize = MonitorStyle.numericValueSize
    @ScaledMetric(relativeTo: .title) private var textValueSize = MonitorStyle.textValueSize
    @ScaledMetric(relativeTo: .title) private var pressureValueSize = MonitorStyle.pressureValueSize
    @ScaledMetric(relativeTo: .title2) private var unitSize = MonitorStyle.unitSize
    @ScaledMetric(relativeTo: .body) private var cardHeight = MonitorStyle.cardHeight

    private var isDark: Bool { MonitorStyle.usesDarkCard(for: reading.id) }
    private var foreground: Color { isDark ? MonitorStyle.primaryText : MonitorStyle.lightCardText }
    private var secondaryForeground: Color {
        isDark ? MonitorStyle.secondaryText : MonitorStyle.lightCardSecondaryText
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MonitorStyle.cardContentSpacing) {
            readingLabel
            readingValue
                .foregroundStyle(foreground)
                .frame(maxWidth: .infinity, maxHeight: .infinity,
                       alignment: MonitorStyle.readingValueAlignment)
        }
        .padding(.horizontal, MonitorStyle.cardHorizontalInset)
        .padding(.vertical, MonitorStyle.cardVerticalInset)
        .frame(maxWidth: .infinity)
        .frame(height: height ?? cardHeight)
        .background(isDark ? MonitorStyle.darkCard : MonitorStyle.lightCard,
                    in: RoundedRectangle(cornerRadius: MonitorStyle.cardCornerRadius))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(reading.title)
        .accessibilityValue(accessibilityReadingValue)
        .accessibilityIdentifier("monitor.card.\(reading.id)")
    }

    private var readingLabel: some View {
        Text(reading.title.uppercased())
            .font(.system(size: labelSize, weight: .semibold))
            .fontWidth(MonitorStyle.fontWidth)
            .tracking(MonitorStyle.sensorLabelTracking)
            .foregroundStyle(secondaryForeground)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.trailing, iconSize + MonitorStyle.sensorLabelIconSpacing)
            .padding(.top, MonitorStyle.sensorLabelTopInset)
            .frame(maxWidth: .infinity, minHeight: labelRowHeight, alignment: .topLeading)
            // The illustration does not reserve space above the large value.
            .overlay(alignment: .topTrailing) {
                MonitorSensorIllustration(kind: reading.id, foreground: foreground,
                                          secondaryForeground: secondaryForeground)
                    .frame(width: iconSize, height: iconSize)
                    .overlay(alignment: .topTrailing) {
                        if let statusDotColor {
                            Circle()
                                .fill(statusDotColor)
                                .frame(width: MonitorStyle.sensorStatusDotSize,
                                       height: MonitorStyle.sensorStatusDotSize)
                        }
                    }
                    .accessibilityHidden(true)
            }
    }

    private var readingValue: some View {
        HStack(alignment: MonitorStyle.readingUnitAlignment, spacing: MonitorStyle.readingUnitSpacing) {
            Text(reading.value.uppercased())
                .font(.system(size: valueSize, weight: MonitorStyle.valueWeight))
                .fontWidth(MonitorStyle.fontWidth)
                .tracking(MonitorStyle.readingTracking)

            if let unit = reading.unit {
                Text(unit)
                    .font(.system(size: unitSize, weight: .bold))
                    .fontWidth(MonitorStyle.fontWidth)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(MonitorStyle.readingMinimumScaleFactor)
    }

    private var statusDotColor: Color? {
        switch alertCondition {
        case .unsafe: MonitorStyle.warningIndicator
        case .dangerous: MonitorStyle.alarmText
        case nil: reading.id == .airQuality ? MonitorStyle.cyan : nil
        }
    }

    private var accessibilityReadingValue: String {
        guard let alertCondition else { return reading.spokenValue }
        return "\(reading.spokenValue), \(alertCondition.rawValue)"
    }

    private var valueSize: CGFloat {
        if reading.id == .areaPressure { return pressureValueSize }
        return reading.unit == nil ? textValueSize : numericValueSize
    }
}
