import Foundation

/// The latest sensor values from `GET /v1/devices/{deviceId}/readings`.
/// The field names must match `readingsResponse` in BeforeFire-Backend `internal/httpapi/server.go`.
nonisolated struct SensorReadingsSnapshot: Decodable, Equatable, Sendable {
    /// The result of the fuzzy evaluation in the firmware. It is `nil` until the firmware sends it.
    typealias Condition = KitchenCondition

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
    var conditionIsValid: Bool?
    var reportedAssessment: KitchenAssessment?
    var readings: Readings
    var unavailableSensors: [String]
    var ageSeconds: Int
    var measuredAt: Date?
    var recoveryConfirmed: Bool?
    /// `true` when the sensor sent no new values for some time. Do not show old values as current values.
    var isStale: Bool
    var connection: Connection

    private enum CodingKeys: String, CodingKey {
        case deviceID = "deviceId"
        case condition
        case conditionIsValid = "valid"
        case reportedAssessment = "assessment"
        case readings
        case unavailableSensors
        case ageSeconds
        case measuredAt
        case recoveryConfirmed
        case isStale
        case connection
    }

    init(
        deviceID: String,
        condition: Condition? = nil,
        conditionIsValid: Bool? = nil,
        reportedAssessment: KitchenAssessment? = nil,
        readings: Readings = Readings(),
        unavailableSensors: [String] = [],
        ageSeconds: Int = 0,
        measuredAt: Date? = nil,
        recoveryConfirmed: Bool? = nil,
        isStale: Bool = false,
        connection: Connection = .online
    ) {
        self.deviceID = deviceID
        self.condition = condition
        self.conditionIsValid = conditionIsValid
        self.reportedAssessment = reportedAssessment
        self.readings = readings
        self.unavailableSensors = unavailableSensors
        self.ageSeconds = ageSeconds
        self.measuredAt = measuredAt
        self.recoveryConfirmed = recoveryConfirmed
        self.isStale = isStale
        self.connection = connection
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        deviceID = try container.decode(String.self, forKey: .deviceID)
        readings = try container.decode(Readings.self, forKey: .readings)
        unavailableSensors = try container.decodeIfPresent([String].self, forKey: .unavailableSensors) ?? []
        ageSeconds = try container.decodeIfPresent(Int.self, forKey: .ageSeconds) ?? 0
        if let value = try container.decodeIfPresent(String.self, forKey: .measuredAt) {
            measuredAt = (try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(value)) ??
                (try? Date.ISO8601FormatStyle().parse(value))
        }
        recoveryConfirmed = try container.decodeIfPresent(Bool.self, forKey: .recoveryConfirmed)
        isStale = try container.decodeIfPresent(Bool.self, forKey: .isStale) ?? true
        // A new value from a newer backend must not make the whole response unreadable.
        condition = try container.decodeIfPresent(String.self, forKey: .condition).flatMap(Condition.init(rawValue:))
        conditionIsValid = try container.decodeIfPresent(Bool.self, forKey: .conditionIsValid)
        reportedAssessment = try container.decodeIfPresent(KitchenAssessment.self, forKey: .reportedAssessment)
        connection = try container.decodeIfPresent(String.self, forKey: .connection)
            .flatMap(Connection.init(rawValue:)) ?? .unknown
    }

    var confirmsNormal: Bool {
        recoveryConfirmed != false && connection == .online && !isStale && assessment.validCondition == .normal &&
            unavailableSensors.isEmpty && readings.stoveTemperatureC != nil &&
            readings.iaq != nil && readings.presence != nil
    }

    var assessment: KitchenAssessment {
        if let reportedAssessment, let condition, reportedAssessment.condition != condition {
            return KitchenAssessment(condition: nil, isValid: false)
        }
        // The existing endpoint exposes a nullable, sensor-supplied condition. Keep that legacy contract.
        // TODO: The backend must forward fuzzy `valid`, and the optional assessment metadata, without
        // replacing invalid results with Normal. Confirm the new field names with the backend owner.
        let result = reportedAssessment ?? KitchenAssessment(condition: condition,
                                                             isValid: condition != nil && conditionIsValid != false)
        let blockedReasons: [KitchenConditionReason] = unavailableSensors.compactMap { sensor in
            switch sensor {
            case SensorBackendConfiguration.thermalSensorName: .highHeat
            case SensorBackendConfiguration.environmentSensorName: .poorAirQuality
            case SensorBackendConfiguration.presenceSensorName: .noPresence
            default: nil
            }
        }
        return KitchenAssessment(condition: result.condition, isValid: result.isValid && conditionIsValid != false,
                                 reasons: result.reasons.filter { !blockedReasons.contains($0) },
                                 ruleID: blockedReasons.isEmpty ? result.ruleID : nil,
                                 absenceDurationSeconds: blockedReasons.contains(.noPresence) ? nil : result.absenceDurationSeconds)
    }
}
