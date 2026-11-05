import Foundation

/// Values that must agree with BeforeFire-Backend and the sensor firmware (`Sensor/KirimBackend.cpp`).
nonisolated enum SensorBackendConfiguration {
    /// The first line of the read key message. Must match `readKeyVersion` in `internal/telemetry/readkey.go`.
    static let readKeyVersion = "beforefire-read-v1"

    /// The server that the app uses when the user did not type an address. The `.local` name of the Mac that runs
    /// BeforeFire-Backend stays the same when the Mac changes its IP address or Wi-Fi network.
    /// Must use the same host as `BACKEND_MQTT_URI` in the firmware (`Sensor/KirimBackend.cpp`).
    /// TODO: Change this value when the server runs on a different Mac or moves to a server with a fixed domain.
    static let defaultBackendAddress = "http://Dericks-MacBook-Pro.local:8080"

    /// The backend HTTP port in `docker-compose.yml`. The app adds it when the user types an address without a port.
    static let defaultPort = 8080
    static let defaultScheme = "http"
    static let allowedSchemes: Set<String> = ["http", "https"]

    /// The firmware adds 6 hexadecimal MAC digits to the Bluetooth prefix. See `susunNamaBLE()`.
    static let sensorSerialDigitCount = 6

    /// The firmware sends a changed danger level or presence at once, so a short interval shows it in about
    /// 1 second. The requests are small and stay on the home network.
    static let refreshInterval: Duration = .seconds(1)
    /// A request that takes longer than this fails, and the next refresh starts. On the home network, an answer
    /// takes much less time.
    static let requestTimeout: TimeInterval = 2

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
