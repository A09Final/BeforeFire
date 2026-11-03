import Foundation

nonisolated enum SensorProvisioningConfiguration {
    /// Must match `PROV_PREFIX` in `bme688_ld2410b.ino`. The firmware adds 6 hexadecimal MAC digits.
    static let sensorNamePrefix = "DAPUR_"
    static let scanDuration: Duration = .seconds(10)

    // Wi-Fi limits from the 802.11 SSID size and the WPA2 passphrase rules.
    static let maximumWiFiNameBytes = 32
    static let minimumWiFiPasswordLength = 8
    static let maximumWiFiPasswordBytes = 64

    /// Must match the 8-character PoP that `muatAtauBuatPop` generates in the firmware.
    static let setupCodeLength = 8
}
