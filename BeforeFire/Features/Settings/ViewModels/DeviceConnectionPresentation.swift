import Foundation

/// Symbols and accessibility identifiers for the connection flow of one unit type.
/// The sensor keeps the identifiers that it used before the alarm flow existed, so the UI tests stay stable.
struct DeviceConnectionPresentation {
    let kind: ProvisioningDeviceKind

    var unitSymbolName: String {
        switch kind {
        case .sensor: "sensor.fill"
        case .alarm: "bell.fill"
        }
    }

    private var identifierPrefix: String {
        switch kind {
        case .sensor: "sensor"
        case .alarm: "alarm"
        }
    }

    /// An identifier on the connection screen, for example `alarm.status`.
    func screenIdentifier(_ element: String) -> String {
        "\(identifierPrefix).\(element)"
    }

    /// An identifier in the Wi-Fi setup sheet, for example `alarmWiFi.joinButton`.
    func setupIdentifier(_ element: String) -> String {
        "\(identifierPrefix)WiFi.\(element)"
    }
}
