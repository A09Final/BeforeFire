import Foundation

/// Values that must agree with BeforeFire-Backend and the sensor firmware (`Sensor/KirimBackend.cpp`).
nonisolated enum SensorBackendConfiguration {
    /// The first line of the read key message. Must match `readKeyVersion` in `internal/telemetry/readkey.go`.
    static let readKeyVersion = "beforefire-read-v1"

    /// The first line of the signed command text. Must match `signingVersion` in
    /// `internal/command/request.go` and `hitungTanda()` in the firmware (`Sensor/KirimBackend.cpp`).
    static let commandSigningVersion = "beforefire-cmd-v1"

    /// The `.local` name that `scripts/start-server.sh` in BeforeFire-Backend publishes for the Mac that runs the
    /// server. Any Mac can run the server, and the name moves with the Mac to a new Wi-Fi network or IP address,
    /// so the app needs no new address. Must match `LOCAL_NAME` in `scripts/start-server.sh` and the host of
    /// `BACKEND_MQTT_URI` in the firmware (`Sensor/KirimBackend.cpp`).
    static let defaultHost = "beforefire-server.local"

    /// The server that the app uses when the user did not type an address.
    static let defaultBackendAddress = "http://beforefire-server.local:8080"

    /// Hosts of earlier default addresses, in lowercase. Earlier versions used the `.local` name of one Mac.
    /// The app moves a saved link with such a host to `defaultHost`, so the user does not link the sensor again.
    static let legacyDefaultHosts: Set<String> = ["dericks-macbook-pro.local"]

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

    /// Lists each device that sent a status. The app uses it to find sensors that already have Wi-Fi.
    static let devicesPath = "v1/devices"

    static func readingsPath(deviceID: String) -> String {
        "v1/devices/\(deviceID)/readings"
    }

    /// Sends a signed command to the sensor through the backend.
    static func commandsPath(deviceID: String) -> String {
        "v1/devices/\(deviceID)/commands"
    }

    /// The backend waits for the sensor's ack (up to `COMMAND_ANSWER_TIMEOUT`, default 8s),
    /// so the app must allow more than that before it gives up.
    static let commandTimeout: TimeInterval = 12
}
