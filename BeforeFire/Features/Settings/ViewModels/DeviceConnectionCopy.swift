import Foundation

/// User-facing text for the connection flow of one unit type.
struct DeviceConnectionCopy {
    let kind: ProvisioningDeviceKind

    init(kind: ProvisioningDeviceKind) {
        self.kind = kind
    }

    // MARK: Unit names

    /// The unit name as a label, for example "Sensor".
    var unitName: String {
        switch kind {
        case .sensor: "Sensor"
        case .alarm: "Alarm"
        }
    }

    /// The unit name in a sentence, for example "the sensor".
    private var theUnit: String { "the \(unitName.lowercased())" }
    private var pluralUnits: String { "\(unitName.lowercased())s" }
    private var aUnit: String {
        switch kind {
        case .sensor: "a sensor"
        case .alarm: "an alarm"
        }
    }

    /// The condition that shows that the unit waits for Wi-Fi setup.
    private var setupModeCondition: String {
        switch kind {
        case .sensor: "the sensor light is purple"
        case .alarm: "the alarm screen shows SETUP WIFI"
        }
    }

    /// The location of the provisioning PoP. The alarm firmware shows it on the OLED screen during setup.
    private var setupCodeLocation: String {
        switch kind {
        case .sensor: "on the sensor label"
        case .alarm: "after PIN on the alarm screen"
        }
    }

    // MARK: Connection screen

    var screenTitle: String { "\(unitName) Connection" }
    let statusHeader = "Status"
    let notConnected = "Not connected"
    var connectButton: String { "Connect \(unitName)" }
    let stopSearchButton = "Stop Searching"
    var simulationFooter: String { "Simulated \(pluralUnits). The app makes no Bluetooth connection." }
    var connectFooter: String { "Turn on \(theUnit) and keep your phone near it." }

    var devicesFoundHeader: String { "\(unitName)s Found" }
    var devicesFoundFooter: String { "Tap \(aUnit) to connect it to your Wi-Fi network." }
    var searching: String { "Searching for \(pluralUnits)…" }
    var noDevicesFound: String { "No \(pluralUnits) found. Make sure that \(setupModeCondition), then try again." }
    let openSettingsButton = "Open Settings"

    // MARK: Wi-Fi setup

    var setupCodeHeader: String { "\(unitName) Setup Code" }
    let setupCodePlaceholder = "Setup code"
    var setupCodeFooter: String {
        "Find the \(SensorProvisioningConfiguration.setupCodeLength)-character setup code \(setupCodeLocation). The app uses it to make a secure Bluetooth connection. It is not the HomeKit code."
    }
    let connectToDeviceButton = "Connect"
    var connectingToDevice: String { "Connecting to \(theUnit)…" }

    let networksHeader = "Choose a Wi-Fi Network"
    var networksFooter: String {
        "\(theUnit.capitalizedFirstLetter) can connect only to 2.4 GHz networks. This list shows the networks that \(theUnit) found."
    }
    let scanningNetworks = "Searching for Wi-Fi networks…"
    var noNetworksFound: String { "\(theUnit.capitalizedFirstLetter) found no Wi-Fi networks." }
    let refreshNetworksButton = "Search Again"
    let otherNetworkButton = "Other Network…"
    let securedNetworkLabel = "Secured"

    let otherNetworkHeader = "Other Network"
    let wiFiNamePlaceholder = "Wi-Fi name"
    let passwordPlaceholder = "Password"
    var passwordFooter: String { "\(theUnit.capitalizedFirstLetter) stores this password and uses it to connect to the network." }
    let openNetworkFooter = "This network has no password."
    let joinButton = "Join"
    var joining: String { "Sending Wi-Fi to \(theUnit)…" }

    let cancelButton = "Cancel"
    let backButton = "Back"
    let doneButton = "Done"

    // MARK: Home setup

    let wiFiConnectedTitle = "Wi-Fi Connected"
    let addToHomeButton = "Add to Home"
    var addingToHome: String { "Adding \(theUnit) to Home…" }
    var addedToHomeTitle: String { "\(unitName) Added to Home" }

    func wiFiConnectedDescription(deviceName: String, wiFiName: String) -> String {
        "\(deviceName) is connected to \(wiFiName). Add \(theUnit) to Home with the HomeKit code on the \(unitName.lowercased()) label. Keep your phone on the same Wi-Fi network."
    }

    func addedToHomeDescription(deviceName: String) -> String {
        "\(deviceName) is in the Home app."
    }

    func networkAccessibilityLabel(for network: SensorWiFiNetwork) -> String {
        network.isSecured ? "\(network.ssid), \(securedNetworkLabel)" : network.ssid
    }

    // MARK: Errors

    func message(for error: Error) -> String {
        switch error {
        case let issue as SensorWiFiCredentialsIssue:
            message(for: issue)
        case let provisioningError as SensorProvisioningError:
            message(for: provisioningError)
        case let homeSetupError as SensorHomeSetupError:
            message(for: homeSetupError)
        default:
            "The operation did not complete. Try again."
        }
    }

    private func message(for issue: SensorWiFiCredentialsIssue) -> String {
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

    private func message(for error: SensorProvisioningError) -> String {
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
            "\(theUnit.capitalizedFirstLetter) was not found. Move near \(theUnit) and make sure that \(setupModeCondition)."
        case .sensorConnectionFailed:
            "The connection to \(theUnit) stopped. Move near \(theUnit) and try again."
        case .setupCodeRejected:
            "The app could not make a secure connection to \(theUnit). Check the setup code \(setupCodeLocation)."
        case .wiFiScanUnavailable:
            "\(theUnit.capitalizedFirstLetter) could not search for Wi-Fi networks. Search again, or select Other Network and type the name."
        case .wiFiPasswordRejected:
            "The Wi-Fi password is not correct."
        case .wiFiNetworkNotFound:
            "\(theUnit.capitalizedFirstLetter) cannot find this Wi-Fi network. Check the name and use a 2.4 GHz network."
        case .sensorCouldNotJoinWiFi:
            "\(theUnit.capitalizedFirstLetter) could not connect to the Wi-Fi network. Check the Wi-Fi name and password."
        }
    }

    private func message(for error: SensorHomeSetupError) -> String {
        switch error {
        case .cancelled:
            "The Home setup closed before \(theUnit) was added. Tap Add to Home to try again."
        case .unsupported:
            "This device cannot add accessories to Home."
        case .missingEntitlement:
            "BeforeFire does not have permission to add accessories to Home."
        case .accessoryNotFound:
            "Home cannot find \(theUnit). Make sure that \(theUnit) and your phone use the same Wi-Fi network, then try again."
        case .failed:
            "\(theUnit.capitalizedFirstLetter) was not added to Home. Try again."
        }
    }
}

private extension String {
    /// Changes only the first letter, so that unit names such as "the sensor" can start a sentence.
    var capitalizedFirstLetter: String {
        prefix(1).uppercased() + dropFirst()
    }
}
