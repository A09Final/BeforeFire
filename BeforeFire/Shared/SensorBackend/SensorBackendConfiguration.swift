import Foundation

/// Values that must agree with BeforeFire-Backend and the sensor firmware (`Sensor/KirimBackend.cpp`).
nonisolated enum SensorBackendConfiguration {
    /// The first line of the read key message. Must match `readKeyVersion` in `internal/telemetry/readkey.go`.
    static let readKeyVersion = "beforefire-read-v1"

    /// The backend HTTP port in `docker-compose.yml`. The app adds it when the user types an address without a port.
    static let defaultPort = 8080
    static let defaultScheme = "http"
    static let allowedSchemes: Set<String> = ["http", "https"]

    /// The firmware adds 6 hexadecimal MAC digits to the Bluetooth prefix. See `susunNamaBLE()`.
    static let sensorSerialDigitCount = 6

    /// The firmware sends telemetry every 5 seconds, so a shorter interval gives no new values.
    static let refreshInterval: Duration = .seconds(5)
    /// Shorter than `refreshInterval`, so a slow request does not delay the next refresh.
    static let requestTimeout: TimeInterval = 4

    /// Sensor names in `unavailableSensors`. Must match `backendKirimTelemetri()` in the firmware.
    static let environmentSensorName = "bme"
    static let presenceSensorName = "radar"
    static let thermalSensorName = "thermal"

    /// The error code in a 404 response when the sensor has not sent readings yet.
    static let noReadingsErrorCode = "no_readings"

    static func readingsPath(deviceID: String) -> String {
        "v1/devices/\(deviceID)/readings"
    }
}
