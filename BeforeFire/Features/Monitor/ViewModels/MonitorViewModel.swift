import Foundation

struct MonitorViewModel {
    private(set) var connectionTitle: String
    private(set) var statusValue: String
    let statusHeading = "Your Kitchen Is"

    private var originalReadings: [MonitorReading]
    /// `true` when the live sensor values report the alarm condition.
    private var isLiveDangerous = false
    private var liveAssessment: KitchenAssessment?
    private let previewStoveTemperatureC = 180
    private let previewAbsenceDurationSeconds = 240

    // These values are fixed examples for the developer preview.
    var isActionGuidanceVisible = false
    var previewCondition: MonitorPreviewCondition = .unsafe

    init(connectionTitle: String, statusValue: String, readings: [MonitorReading]) {
        self.connectionTitle = connectionTitle
        self.statusValue = statusValue
        self.originalReadings = readings
    }

    init(content: MonitorContent) {
        self.init(connectionTitle: content.connectionTitle, statusValue: content.statusValue, readings: content.readings)
        isLiveDangerous = content.isDangerous
        liveAssessment = content.assessment
    }

    /// Shows new status and sensor values. The developer preview still replaces them while it is on.
    mutating func show(_ content: MonitorContent) {
        connectionTitle = content.connectionTitle
        statusValue = content.statusValue
        originalReadings = content.readings
        isLiveDangerous = content.isDangerous
        liveAssessment = content.assessment
    }

    private var previewAirQualityDescription: String {
        switch previewCondition {
        case .normal: "Good"
        case .unsafe: "Lightly Polluted"
        case .dangerous, .alarm: "Heavily Polluted"
        }
    }

    var readings: [MonitorReading] {
        guard isActionGuidanceVisible else {
            return originalReadings
        }
        if previewCondition == .normal { return Self.mockContent.readings }

        return originalReadings.map { reading in
            switch reading.id {
            case .stoveHeat:
                return MonitorReading(
                    id: reading.id,
                    title: reading.title,
                    value: String(previewStoveTemperatureC),
                    unit: "°C",
                    spokenValue: "\(previewStoveTemperatureC) degrees Celsius"
                )

            case .airQuality:
                return MonitorReading(
                    id: reading.id,
                    title: reading.title,
                    value: previewAirQualityDescription,
                    unit: nil,
                    spokenValue: previewAirQualityDescription
                )

            case .presence:
                return MonitorReading(
                    id: reading.id,
                    title: reading.title,
                    value: "Not Detected",
                    unit: nil,
                    spokenValue: "No person detected for \(previewAbsenceDurationSeconds) seconds."
                )

            case .roomTemperature, .roomHumidity, .areaPressure:
                return reading
            }
        }
    }

    var statusTitle: String {
        "\(statusHeading)\n\(statusValue)"
    }

    var displayedStatusValue: String {
        isActionGuidanceVisible ? previewCondition.rawValue : statusValue
    }

    var displayedStatusTitle: String {
        "\(statusHeading)\n\(displayedStatusValue)"
    }

    var actionGuidance: String? {
        isActionGuidanceVisible ? previewCondition.actionGuidance : liveAssessment.flatMap(KitchenGuidance.monitorMessage)
    }

    var isAlarmPreview: Bool {
        isActionGuidanceVisible && previewCondition == .alarm
    }

    /// Shows the status in the alarm color for the preview or for a live alarm condition.
    var showsAlarmStatus: Bool {
        if isActionGuidanceVisible { return previewCondition == .dangerous || previewCondition == .alarm }
        return liveAssessment?.validCondition == .warning2 || isLiveDangerous
    }

    var readingAlertCondition: MonitorPreviewCondition? {
        switch currentAssessment?.validCondition {
        case .warning1: .unsafe
        case .warning2: .dangerous
        case .alarm: .alarm
        case .normal, nil: nil
        }
    }

    func readingAlertCondition(for kind: MonitorReading.Kind) -> MonitorPreviewCondition? {
        let reason: KitchenConditionReason
        switch kind {
        case .stoveHeat: reason = .highHeat
        case .airQuality: reason = .poorAirQuality
        case .presence: reason = .noPresence
        default: return nil
        }
        guard currentAssessment?.reasons.contains(reason) == true else { return nil }
        return readingAlertCondition
    }

    private var currentAssessment: KitchenAssessment? {
        isActionGuidanceVisible ? previewCondition.assessment : liveAssessment
    }

    static let mock = MonitorViewModel(content: mockContent)

    /// Example values. The Monitor screen shows them when no sensor is linked.
    static let mockContent = MonitorContent(
        connectionTitle: "Hub connected",
        statusValue: "Normal",
        isDangerous: false,
        readings: [
            MonitorReading(
                id: .stoveHeat,
                title: "Stove Heat",
                value: "80",
                unit: "°C",
                spokenValue: "80 degrees Celsius"
            ),
            MonitorReading(
                id: .airQuality,
                title: "Air Quality",
                value: "Good",
                unit: nil,
                spokenValue: "Good"
            ),
            MonitorReading(
                id: .presence,
                title: "Presence",
                value: "Detected",
                unit: nil,
                spokenValue: "Detected"
            ),
            MonitorReading(
                id: .roomTemperature,
                title: "Room Temperature",
                value: "30",
                unit: "°C",
                spokenValue: "30 degrees Celsius"
            ),
            MonitorReading(
                id: .roomHumidity,
                title: "Room Humidity",
                value: "60",
                unit: "%",
                spokenValue: "60 percent"
            ),
            MonitorReading(
                id: .areaPressure,
                title: "Area Pressure",
                value: "1,013",
                unit: "hPa",
                spokenValue: "1,013 hectopascals"
            )
        ]
    )
}
