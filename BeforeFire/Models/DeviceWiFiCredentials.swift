import Foundation

enum DeviceWiFiCredentialsIssue: Error, Equatable {
    case invalidSetupCode
    case missingWiFiName
    case wiFiNameTooLong
    case missingPassword
    case passwordTooShort
    case passwordTooLong
}

/// The proof-of-possession (PoP) code that the unit shows on its label or screen. It protects the Bluetooth session.
/// It is not the HomeKit setup code.
struct DeviceSetupCode: Equatable, Sendable {
    let value: String

    init(_ rawValue: String) throws {
        // The firmware generates setup codes from lowercase letters and digits only.
        let normalizedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalizedValue.count == DeviceProvisioningConfiguration.setupCodeLength else {
            throw DeviceWiFiCredentialsIssue.invalidSetupCode
        }
        value = normalizedValue
    }
}

/// Validated Wi-Fi values that the app sends to the sensor or alarm unit.
struct DeviceWiFiCredentials: Equatable, Sendable {
    let wiFiName: String
    let password: String

    init(wiFiName: String, password: String, requiresPassword: Bool) throws {
        // Wi-Fi names can start or end with spaces, so the name is not trimmed.
        guard !wiFiName.isEmpty else { throw DeviceWiFiCredentialsIssue.missingWiFiName }
        guard wiFiName.utf8.count <= DeviceProvisioningConfiguration.maximumWiFiNameBytes else {
            throw DeviceWiFiCredentialsIssue.wiFiNameTooLong
        }

        if requiresPassword, password.isEmpty {
            throw DeviceWiFiCredentialsIssue.missingPassword
        }
        // An empty password is permitted for open networks and for names that the user types.
        if !password.isEmpty, password.count < DeviceProvisioningConfiguration.minimumWiFiPasswordLength {
            throw DeviceWiFiCredentialsIssue.passwordTooShort
        }
        guard password.utf8.count <= DeviceProvisioningConfiguration.maximumWiFiPasswordBytes else {
            throw DeviceWiFiCredentialsIssue.passwordTooLong
        }

        self.wiFiName = wiFiName
        self.password = password
    }
}
