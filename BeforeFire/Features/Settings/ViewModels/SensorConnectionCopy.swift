import Foundation

/// User-facing text for the Sensor Connection flow.
enum SensorConnectionCopy {
    static let screenTitle = "Sensor Connection"
    static let statusHeader = "Status"
    static let sensorLabel = "Sensor"
    static let notConnected = "Not connected"
    static let connectButton = "Connect Sensor"
    static let stopSearchButton = "Stop Searching"
    static let simulationFooter = "Simulated sensors. The app makes no Bluetooth connection."
    static let connectFooter = "Turn on the sensor and keep your phone near it."

    static let sensorsFoundHeader = "Sensors Found"
    static let sensorsFoundFooter = "Tap a sensor to connect it to your Wi-Fi network."
    static let searching = "Searching for sensors…"
    static let noSensorsFound = "No sensors found. Make sure that the sensor light is purple, then try again."
    static let openSettingsButton = "Open Settings"

    static let setupCodeHeader = "Sensor Setup Code"
    static let setupCodePlaceholder = "Setup code"
    static let setupCodeFooter = "Find the 8-character setup code on the sensor label. The app uses it to make a secure Bluetooth connection. It is not the HomeKit code."
    static let connectToSensorButton = "Connect"
    static let connectingToSensor = "Connecting to the sensor…"

    static let networksHeader = "Choose a Wi-Fi Network"
    static let networksFooter = "The sensor can connect only to 2.4 GHz networks. This list shows the networks that the sensor found."
    static let scanningNetworks = "Searching for Wi-Fi networks…"
    static let noNetworksFound = "The sensor found no Wi-Fi networks."
    static let refreshNetworksButton = "Search Again"
    static let otherNetworkButton = "Other Network…"
    static let securedNetworkLabel = "Secured"

    static let otherNetworkHeader = "Other Network"
    static let wiFiNamePlaceholder = "Wi-Fi name"
    static let passwordPlaceholder = "Password"
    static let passwordFooter = "The sensor stores this password and uses it to connect to the network."
    static let openNetworkFooter = "This network has no password."
    static let joinButton = "Join"
    static let joining = "Sending Wi-Fi to the sensor…"

    static let cancelButton = "Cancel"
    static let backButton = "Back"
    static let doneButton = "Done"
    static let successTitle = "Sensor Connected"

    static func successDescription(sensorName: String, wiFiName: String) -> String {
        "\(sensorName) is connected to \(wiFiName). The sensor restarts now. Then add it in the Home app with the HomeKit code on the sensor label."
    }

    static func networkAccessibilityLabel(for network: SensorWiFiNetwork) -> String {
        network.isSecured ? "\(network.ssid), \(securedNetworkLabel)" : network.ssid
    }

    static func message(for error: Error) -> String {
        switch error {
        case let issue as SensorWiFiCredentialsIssue:
            message(for: issue)
        case let provisioningError as SensorProvisioningError:
            message(for: provisioningError)
        default:
            "The operation did not complete. Try again."
        }
    }

    private static func message(for issue: SensorWiFiCredentialsIssue) -> String {
        switch issue {
        case .invalidSetupCode:
            "The setup code must have \(SensorProvisioningConfiguration.setupCodeLength) characters."
        case .missingWiFiName:
            "Enter the Wi-Fi name."
        case .wiFiNameTooLong:
            "The Wi-Fi name is too long. Use a maximum of \(SensorProvisioningConfiguration.maximumWiFiNameBytes) characters."
        case .missingPassword:
            "Enter the Wi-Fi password."
        case .passwordTooShort:
            "The password must have a minimum of \(SensorProvisioningConfiguration.minimumWiFiPasswordLength) characters."
        case .passwordTooLong:
            "The password is too long. Use a maximum of \(SensorProvisioningConfiguration.maximumWiFiPasswordBytes) characters."
        }
    }

    private static func message(for error: SensorProvisioningError) -> String {
        switch error {
        case .bluetoothPoweredOff:
            "Bluetooth is off. Turn on Bluetooth and try again."
        case .bluetoothUnauthorized:
            "BeforeFire cannot use Bluetooth. Allow Bluetooth access in Settings."
        case .bluetoothUnsupported:
            "This device does not support Bluetooth Low Energy."
        case .bluetoothUnavailable:
            "Bluetooth is not available. Try again."
        case .sensorNotFound:
            "The sensor was not found. Move near the sensor and make sure that the sensor light is purple."
        case .sensorConnectionFailed:
            "The connection to the sensor stopped. Move near the sensor and try again."
        case .setupCodeRejected:
            "The app could not make a secure connection to the sensor. Check the setup code on the sensor label."
        case .wiFiScanUnavailable:
            "The sensor could not search for Wi-Fi networks. Search again, or select Other Network and type the name."
        case .wiFiPasswordRejected:
            "The Wi-Fi password is not correct."
        case .wiFiNetworkNotFound:
            "The sensor cannot find this Wi-Fi network. Check the name and use a 2.4 GHz network."
        case .sensorCouldNotJoinWiFi:
            "The sensor could not connect to the Wi-Fi network. Check the Wi-Fi name and password."
        }
    }
}
