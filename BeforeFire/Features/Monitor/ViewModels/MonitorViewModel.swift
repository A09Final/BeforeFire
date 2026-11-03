import Foundation

struct MonitorViewModel {
    let connectionTitle: String
    let statusValue: String
    let statusHeading = "Your Kitchen Is"

    private let originalReadings: [MonitorReading]
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

    private var previewAirQualityDescription: String {
        switch previewCondition {
        case .unsafe: "Lightly Polluted"
        case .dangerous: "Heavily Polluted"
        }
    }

    var readings: [MonitorReading] {
        guard isActionGuidanceVisible else {
            return originalReadings
        }

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
        isActionGuidanceVisible ? previewCondition.actionGuidance : nil
    }

    var isAlarmPreview: Bool {
        isActionGuidanceVisible && previewCondition == .dangerous
    }

    var readingAlertCondition: MonitorPreviewCondition? {
        // The indicator shows the preview condition, not a sensor threshold.
        isActionGuidanceVisible ? previewCondition : nil
    }

    static let mock = MonitorViewModel(
        connectionTitle: "Hub connected",
        statusValue: "Safe",
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
