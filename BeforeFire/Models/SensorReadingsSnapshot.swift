import Foundation

/// The latest sensor values from `GET /v1/devices/{deviceId}/readings`.
/// The field names must match `readingsResponse` in BeforeFire-Backend `internal/httpapi/server.go`.
nonisolated struct SensorReadingsSnapshot: Decodable, Equatable, Sendable {
    /// The result of the fuzzy evaluation in the firmware. It is `nil` until the firmware sends it.
    enum Condition: String, Sendable {
        case normal
        case warning1
        case warning2
        case alarm
    }

    enum Connection: String, Sendable {
        case online
        case offline
        case unknown
    }

    /// All values are optional, because a sensor can be unavailable.
    struct Readings: Decodable, Equatable, Sendable {
        var stoveTemperatureC: Double?
        var iaq: Double?
        /// The BSEC accuracy, from 0 (not stable) to 3 (calibrated).
        var iaqAccuracy: Int?
        var eco2Ppm: Double?
        var presence: Bool?
        var roomTemperatureC: Double?
        var roomHumidityRH: Double?
        var pressureHPa: Double?
    }

    var deviceID: String
    var condition: Condition?
    var readings: Readings
    var unavailableSensors: [String]
    var ageSeconds: Int
    /// `true` when the sensor sent no new values for some time. Do not show old values as current values.
    var isStale: Bool
    var connection: Connection

    private enum CodingKeys: String, CodingKey {
        case deviceID = "deviceId"
        case condition
        case readings
        case unavailableSensors
        case ageSeconds
        case isStale
        case connection
    }

    init(
        deviceID: String,
        condition: Condition? = nil,
        readings: Readings = Readings(),
        unavailableSensors: [String] = [],
        ageSeconds: Int = 0,
        isStale: Bool = false,
        connection: Connection = .online
    ) {
        self.deviceID = deviceID
        self.condition = condition
        self.readings = readings
        self.unavailableSensors = unavailableSensors
        self.ageSeconds = ageSeconds
        self.isStale = isStale
        self.connection = connection
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        deviceID = try container.decode(String.self, forKey: .deviceID)
        readings = try container.decode(Readings.self, forKey: .readings)
        unavailableSensors = try container.decodeIfPresent([String].self, forKey: .unavailableSensors) ?? []
        ageSeconds = try container.decodeIfPresent(Int.self, forKey: .ageSeconds) ?? 0
        isStale = try container.decodeIfPresent(Bool.self, forKey: .isStale) ?? true
        // A new value from a newer backend must not make the whole response unreadable.
        condition = try container.decodeIfPresent(String.self, forKey: .condition).flatMap(Condition.init(rawValue:))
        connection = try container.decodeIfPresent(String.self, forKey: .connection)
            .flatMap(Connection.init(rawValue:)) ?? .unknown
    }
}
