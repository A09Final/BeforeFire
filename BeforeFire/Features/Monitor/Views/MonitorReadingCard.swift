import SwiftUI

struct MonitorReadingCard: View {
    let reading: MonitorReading
    var alertCondition: MonitorPreviewCondition? = nil
    // The normal grid supplies an equal row height; scrolling layouts use the minimum height.
    var height: CGFloat? = nil

    // DESIGN: Ubah ukuran dasar label, nilai umum, Presence, dan Area Pressure di sini.
    // ScaledMetric menjaga ukuran teks agar mengikuti pengaturan Dynamic Type pengguna.
    @ScaledMetric(relativeTo: .body) private var labelSize = MonitorStyle.sensorLabelSize
    // DESIGN: Change the icon size, column width, and gap independently from the label.
    @ScaledMetric(relativeTo: .body) private var iconSize = MonitorStyle.sensorIconSize
    @ScaledMetric(relativeTo: .body) private var iconColumnWidth = MonitorStyle.sensorIconColumnWidth
    @ScaledMetric(relativeTo: .body) private var labelRowHeight = MonitorStyle.sensorLabelRowHeight
    private let iconSpacing: CGFloat = 8
    @ScaledMetric(relativeTo: .title) private var standardValueSize = 40.0
    @ScaledMetric(relativeTo: .title2) private var presenceValueSize = 40.0
    @ScaledMetric(relativeTo: .title2) private var pressureValueSize = 40.0
    // DESIGN: Ukuran satuan terpisah dari angka. Ubah unitSize untuk °C, %, dan hPa.
    @ScaledMetric(relativeTo: .body) private var unitSize = 25.0
    @ScaledMetric(relativeTo: .body) private var cardHeight = MonitorStyle.cardHeight
    @ScaledMetric(relativeTo: .body) private var statusDotSize = MonitorStyle.sensorStatusDotSize

    var body: some View {
        // DESIGN: alignment dan spacing mengatur posisi serta jarak label terhadap area nilai.
        VStack(alignment: .leading, spacing: 12) {
            readingLabel

            readingValue
                .foregroundStyle(MonitorStyle.primaryText)
                .fixedSize(horizontal: false, vertical: true)
                // DESIGN: Area selebar kartu membuat alignment kiri, tengah, dan kanan berlaku untuk nilai beserta satuannya.
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: MonitorStyle.readingValueAlignment
                )
        }
        // DESIGN: Padding mengatur jarak isi ke tepi kartu; tinggi dan radius dasarnya ada di MonitorStyle.
        .padding(.horizontal, MonitorStyle.spacing)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: cardHeight)
        .frame(height: height)
        .background(MonitorStyle.card, in: RoundedRectangle(cornerRadius: MonitorStyle.cardCornerRadius))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(reading.title)
        .accessibilityValue(accessibilityReadingValue)
    }

    private var statusDotColor: Color? {
        switch alertCondition {
        case .unsafe:
            MonitorStyle.warningIndicator
        case .dangerous:
            MonitorStyle.alarmText
        case nil:
            nil
        }
    }

    private var readingLabel: some View {
        HStack(alignment: .center, spacing: iconSpacing) {
            Image(systemName: symbolName)
                .font(.system(size: iconSize, weight: .regular))
                .symbolRenderingMode(.monochrome)
                .frame(width: iconColumnWidth)
                .accessibilityHidden(true)

            Text(reading.title)
                .font(.system(size: labelSize, weight: .regular))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let statusDotColor {
                Circle()
                    .fill(statusDotColor)
                    .frame(width: statusDotSize, height: statusDotSize)
                    .accessibilityHidden(true)
            }
        }
        .foregroundStyle(.secondary)
        // DESIGN: Reserve two label lines so long titles do not shift the values between cards.
        .frame(minHeight: labelRowHeight, alignment: .leading)
    }

    private var accessibilityReadingValue: String {
        guard let alertCondition else { return reading.spokenValue }
        return "\(reading.spokenValue), \(alertCondition.rawValue)"
    }

    private var symbolName: String {
        // DESIGN: Change the SF Symbol for each reading here.
        switch reading.id {
        case .stoveHeat:
            "cooktop"
        case .airQuality:
            "wind"
        case .presence:
            "figure.stand"
        case .roomTemperature:
            "thermometer.medium"
        case .roomHumidity:
            "humidity"
        case .areaPressure:
            "barometer"
        }
    }

    private var readingValue: some View {
        HStack(alignment: MonitorStyle.readingUnitAlignment, spacing: MonitorStyle.readingUnitSpacing) {
            Text(reading.value)
                .font(.system(size: valueSize, weight: .heavy))
                .fontWidth(.condensed)

            if let unit = reading.unit {
                Text(unit)
                    // DESIGN: Keep unit size and weight separate from the reading value.
                    .font(.system(size: unitSize, weight: .semibold))
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(MonitorStyle.readingMinimumScaleFactor)
    }

    private var valueSize: CGFloat {
        // DESIGN: Tentukan jenis kartu yang memakai ukuran khusus melalui switch ini.
        switch reading.id {
        case .presence:
            presenceValueSize
        case .areaPressure:
            pressureValueSize
        default:
            standardValueSize
        }
    }
}
