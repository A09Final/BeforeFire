import Foundation

/// Converts the backend response to the text on the Monitor screen.
struct MonitorReadingsFormatter {
    enum StatusText {
        static let safe = "Safe"
        static let unsafe = "Unsafe"
        static let dangerous = "Dangerous"
        /// The sensor sends readings, but no fuzzy result yet.
        static let unknown = "Unknown"
        /// The app cannot get current values from the sensor.
        static let offline = "Offline"
    }

    enum ConnectionText {
        static let loading = "Connecting to sensor"
        static let online = "Sensor connected"
        static let offline = "Sensor offline"
        static let unreachable = "Server not reachable"
    }

    enum ReadingText {
        static let unavailable = "—"
        static let unavailableSpoken = "Not available"
        static let detected = "Detected"
        static let notDetected = "Not Detected"
        /// BSEC reports accuracy 0 until the gas sensor has a baseline.
        static let calibrating = "Calibrating"
    }

    private enum Unit {
        static let celsius = "°C"
        static let percent = "%"
        static let hectopascal = "hPa"
    }

    /// The Bosch BSEC IAQ classes. Each limit is the highest index of the class.
    private static let airQualityClasses: [(upperLimit: Double, label: String)] = [
        (50, "Excellent"),
        (100, "Good"),
        (150, "Lightly Polluted"),
        (200, "Moderately Polluted"),
        (250, "Heavily Polluted"),
        (350, "Severely Polluted"),
        (.infinity, "Extremely Polluted")
    ]

    /// The card order of the Monitor screen.
    static let cardOrder: [MonitorReading.Kind] = [
        .stoveHeat, .airQuality, .presence, .roomTemperature, .roomHumidity, .areaPressure
    ]

    var locale: Locale = .current

    /// Returns `nil` when no sensor is linked. The screen then shows the example values.
    func content(for status: MonitorLiveReadingsModel.Status) -> MonitorContent? {
        switch status {
        case .notConfigured:
            return nil
        case .loading:
            return unavailableContent(status: StatusText.unknown, connection: ConnectionText.loading)
        case .failed:
            return unavailableContent(status: StatusText.offline, connection: ConnectionText.unreachable)
        case .updated(let snapshot):
            return content(for: snapshot)
        }
    }

    func content(for snapshot: SensorReadingsSnapshot) -> MonitorContent {
        // Old values can show a safe kitchen that is not safe now, so they are not shown.
        guard !snapshot.isStale, snapshot.connection != .offline else {
            return unavailableContent(status: StatusText.offline, connection: ConnectionText.offline)
        }
        return MonitorContent(
            connectionTitle: ConnectionText.online,
            statusValue: statusText(for: snapshot.condition),
            isDangerous: snapshot.condition == .alarm,
            readings: Self.cardOrder.map { reading(for: $0, in: snapshot) }
        )
    }

    private func unavailableContent(status: String, connection: String) -> MonitorContent {
        MonitorContent(
            connectionTitle: connection,
            statusValue: status,
            isDangerous: false,
            readings: Self.cardOrder.map(unavailableReading)
        )
    }

    private func statusText(for condition: SensorReadingsSnapshot.Condition?) -> String {
        switch condition {
        case .normal: StatusText.safe
        case .warning1, .warning2: StatusText.unsafe
        case .alarm: StatusText.dangerous
        case nil: StatusText.unknown
        }
    }

    private func reading(for kind: MonitorReading.Kind, in snapshot: SensorReadingsSnapshot) -> MonitorReading {
        guard !snapshot.unavailableSensors.contains(Self.sensorName(for: kind)) else {
            return unavailableReading(kind)
        }
        let values = snapshot.readings
        switch kind {
        case .stoveHeat:
            return measuredReading(kind, value: values.stoveTemperatureC, unit: Unit.celsius, spokenUnit: "degrees Celsius")
        case .roomTemperature:
            return measuredReading(kind, value: values.roomTemperatureC, unit: Unit.celsius, spokenUnit: "degrees Celsius")
        case .roomHumidity:
            return measuredReading(kind, value: values.roomHumidityRH, unit: Unit.percent, spokenUnit: "percent")
        case .areaPressure:
            return measuredReading(kind, value: values.pressureHPa, unit: Unit.hectopascal, spokenUnit: "hectopascals")
        case .presence:
            guard let isPresent = values.presence else { return unavailableReading(kind) }
            return textReading(kind, text: isPresent ? ReadingText.detected : ReadingText.notDetected)
        case .airQuality:
            guard let index = values.iaq, index.isFinite else { return unavailableReading(kind) }
            return textReading(kind, text: airQualityText(index: index, accuracy: values.iaqAccuracy))
        }
    }

    private func airQualityText(index: Double, accuracy: Int?) -> String {
        if accuracy == 0 { return ReadingText.calibrating }
        return Self.airQualityClasses.first { index <= $0.upperLimit }?.label ?? ReadingText.unavailable
    }

    private func measuredReading(_ kind: MonitorReading.Kind, value: Double?, unit: String, spokenUnit: String) -> MonitorReading {
        guard let value, value.isFinite else { return unavailableReading(kind) }
        // No grouping separator: "1.005 hPa" in some regions looks like a decimal value in this English interface.
        let text = value.formatted(.number.precision(.fractionLength(0)).grouping(.never).locale(locale))
        return MonitorReading(id: kind, title: Self.title(for: kind), value: text, unit: unit,
                              spokenValue: "\(text) \(spokenUnit)")
    }

    private func textReading(_ kind: MonitorReading.Kind, text: String) -> MonitorReading {
        MonitorReading(id: kind, title: Self.title(for: kind), value: text, unit: nil, spokenValue: text)
    }

    private func unavailableReading(_ kind: MonitorReading.Kind) -> MonitorReading {
        MonitorReading(id: kind, title: Self.title(for: kind), value: ReadingText.unavailable, unit: nil,
                       spokenValue: ReadingText.unavailableSpoken)
    }

    static func title(for kind: MonitorReading.Kind) -> String {
        switch kind {
        case .stoveHeat: "Stove Heat"
        case .airQuality: "Air Quality"
        case .presence: "Presence"
        case .roomTemperature: "Room Temperature"
        case .roomHumidity: "Room Humidity"
        case .areaPressure: "Area Pressure"
        }
    }

    /// The sensor that measures each card value.
    private static func sensorName(for kind: MonitorReading.Kind) -> String {
        switch kind {
        case .stoveHeat: SensorBackendConfiguration.thermalSensorName
        case .presence: SensorBackendConfiguration.presenceSensorName
        case .airQuality, .roomTemperature, .roomHumidity, .areaPressure:
            SensorBackendConfiguration.environmentSensorName
        }
    }
}
