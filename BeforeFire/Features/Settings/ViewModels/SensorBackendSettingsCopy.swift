import Foundation

/// User-facing text for the screen that links the sensor to the backend.
enum SensorBackendSettingsCopy {
    static let screenTitle = "Sensor Data"

    static let serverHeader = "Server"
    static let backendAddressLabel = "Server address"
    static let backendAddressPlaceholder = SensorBackendConfiguration.defaultBackendAddress
    static let serverFooter = "Leave the address empty to use the default BeforeFire server. Your phone must be on the same Wi-Fi network as the server."

    static let sensorHeader = "Sensor"
    static let serialLabel = "Serial"
    static let serialPlaceholder = "DAPUR_A1B2C3"
    static let setupCodeLabel = "Setup code"
    static let setupCodePlaceholder = "8 characters"
    static let savedSetupCodePlaceholder = "Saved"
    static let sensorFooter = "The app fills in these values when you connect the sensor in Sensor Connection. You can also find them on the sensor label."

    static let saveButton = "Save"
    static let removeButton = "Remove Sensor Link"
    static let savedMessage = "Saved. The Monitor screen now shows the sensor values."

    static let statusHeader = "Status"
    static let readingsLabel = "Sensor values"
    static let lastUpdateLabel = "Last update"
    static let notLinked = "Not linked. The Monitor screen shows example values."
    static let loading = "Connecting…"
    static let receiving = "Receiving"
    static let sensorOffline = "The sensor sends no new values. Make sure that it is on and connected to Wi-Fi."
    static let monitorPausedNote = "The app gets new values only while the Monitor screen is open."

    static func message(for issue: SensorBackendLinkIssue) -> String {
        switch issue {
        case .invalidBackendAddress:
            "Enter a server address, for example http://192.168.1.10:8080, or leave it empty."
        case .invalidSensorSerial:
            "Enter the sensor serial from the label, for example \(serialPlaceholder)."
        case .invalidSetupCode:
            "Enter the 8-character setup code from the sensor label."
        case .storageFailed:
            "The app could not save the sensor link. Try again."
        }
    }

    /// Messages when the app links a sensor that already has Wi-Fi.
    static func linkMessage(for error: SensorReadingsFetchError) -> String {
        switch error {
        case .invalidReadKey:
            "The setup code is not correct. Check the setup code on the sensor label."
        case .noReadings:
            "The sensor has sent no values yet. Wait a few seconds, then try again."
        case .backendUnreachable, .unknownDevice, .unexpectedResponse:
            message(for: error)
        }
    }

    static func message(for error: SensorReadingsFetchError) -> String {
        switch error {
        case .backendUnreachable:
            "The app cannot reach the server. Make sure that the server is on and that your phone is on the home Wi-Fi."
        case .invalidReadKey:
            "The server did not accept the setup code. Check the setup code on the sensor label."
        case .noReadings:
            "The server has no values from this sensor yet. Make sure that the sensor is connected to the server."
        case .unknownDevice:
            "The server does not know this serial. Check the serial on the sensor label."
        case .unexpectedResponse:
            "The server sent an answer that the app cannot read. Make sure that the app and the server are up to date."
        }
    }
}
