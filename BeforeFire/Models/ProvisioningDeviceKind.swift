import Foundation

/// A unit type that uses the Bluetooth Wi-Fi provisioning and Home setup flow.
/// Both firmware sketches use the same setup code in `Bersama/SetupPerangkat.h`. Only the Bluetooth name prefix is different.
nonisolated enum ProvisioningDeviceKind: Sendable, Hashable {
    /// The ESP32-S3 sensor unit.
    case sensor
    /// The ESP32-C3 alarm unit.
    case alarm

    /// Returns `true` when the advertised Bluetooth name belongs to this unit type.
    func matches(advertisedName: String) -> Bool {
        switch self {
        case .sensor:
            // The alarm prefix starts with the sensor prefix, so the sensor search must not show alarm units.
            advertisedName.hasPrefix(DeviceProvisioningConfiguration.sensorNamePrefix)
                && !advertisedName.hasPrefix(DeviceProvisioningConfiguration.alarmNamePrefix)
        case .alarm:
            advertisedName.hasPrefix(DeviceProvisioningConfiguration.alarmNamePrefix)
        }
    }
}
