import Foundation

/// Keeps the name of the last unit of each type that joined Wi-Fi, so the connection screen still shows it
/// after the screen closes or the app restarts.
/// The name records a completed setup. It does not tell whether the unit is online now.
protocol ConnectedDeviceStoring {
    func connectedDeviceName(for kind: ProvisioningDeviceKind) -> String?
    func saveConnectedDeviceName(_ name: String, for kind: ProvisioningDeviceKind)
    func removeConnectedDeviceName(for kind: ProvisioningDeviceKind)
}

struct UserDefaultsConnectedDeviceStore: ConnectedDeviceStoring {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func connectedDeviceName(for kind: ProvisioningDeviceKind) -> String? {
        defaults.string(forKey: Self.key(for: kind))
    }

    func saveConnectedDeviceName(_ name: String, for kind: ProvisioningDeviceKind) {
        defaults.set(name, forKey: Self.key(for: kind))
    }

    func removeConnectedDeviceName(for kind: ProvisioningDeviceKind) {
        defaults.removeObject(forKey: Self.key(for: kind))
    }

    private static func key(for kind: ProvisioningDeviceKind) -> String {
        switch kind {
        case .sensor: "deviceConnection.sensorName"
        case .alarm: "deviceConnection.alarmName"
        }
    }
}
