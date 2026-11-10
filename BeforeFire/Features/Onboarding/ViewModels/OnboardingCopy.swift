import Foundation

enum OnboardingCopy {
    static let welcomeTitle = "Set Up BeforeFire"
    static let welcomeDescription = "Connect your sensor and alarm to monitor your kitchen."
    static let requirementsTitle = "What You Need"
    static let nearbyReminder = "Keep your iPhone near the kitchen during setup."
    static let permissionsTitle = "Allow Access"
    static let permissionsDescription = "Connect your devices and receive kitchen alerts."
    static let bluetoothDescription = "Send Wi-Fi settings to your sensor and alarm."
    static let notificationsDescription = "Get alerts when your stove needs attention."
    static let permissionsFooter = "Your iPhone will ask for Bluetooth access when you search for a device."
    static let continueButton = "Continue"
    static let completionTitle = "You're All Set"
    static let monitorButton = "Go to Monitor"

    static func deviceTitle(_ kind: ProvisioningDeviceKind) -> String {
        "Connect Your \(DeviceConnectionCopy(kind: kind).unitName)"
    }

    static func deviceInstruction(_ kind: ProvisioningDeviceKind) -> String {
        switch kind {
        case .sensor: "Plug in the sensor. Wait for a purple light."
        case .alarm: "Plug in the alarm where you can hear it from other rooms. Wait for SETUP WIFI."
        }
    }

    static func codeHint(_ kind: ProvisioningDeviceKind) -> String {
        switch kind {
        case .sensor: "Use the 8-character code on the sensor label."
        case .alarm: "Use the PIN shown on the alarm screen."
        }
    }

    static func deviceContinueButton(_ kind: ProvisioningDeviceKind) -> String {
        kind == .sensor ? "Set Up Alarm" : continueButton
    }
}
