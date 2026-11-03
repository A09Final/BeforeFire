import Foundation

enum SensorWiFiCredentialsIssue: Error, Equatable {
    case invalidSetupCode
    case missingWiFiName
    case wiFiNameTooLong
    case missingPassword
    case passwordTooShort
    case passwordTooLong
}

/// The proof-of-possession (PoP) code from the sensor label. It protects the Bluetooth session.
/// It is not the HomeKit setup code.
struct SensorSetupCode: Equatable, Sendable {
    let value: String

    init(_ rawValue: String) throws {
        // The firmware generates setup codes from lowercase letters and digits only.
        let normalizedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalizedValue.count == SensorProvisioningConfiguration.setupCodeLength else {
            throw SensorWiFiCredentialsIssue.invalidSetupCode
        }
        value = normalizedValue
    }
}

/// Validated Wi-Fi values that the app sends to the sensor unit.
struct SensorWiFiCredentials: Equatable, Sendable {
    let wiFiName: String
    let password: String

    init(wiFiName: String, password: String, requiresPassword: Bool) throws {
        // Wi-Fi names can start or end with spaces, so the name is not trimmed.
        guard !wiFiName.isEmpty else { throw SensorWiFiCredentialsIssue.missingWiFiName }
        guard wiFiName.utf8.count <= SensorProvisioningConfiguration.maximumWiFiNameBytes else {
            throw SensorWiFiCredentialsIssue.wiFiNameTooLong
        }

        if requiresPassword, password.isEmpty {
            throw SensorWiFiCredentialsIssue.missingPassword
        }
        // An empty password is permitted for open networks and for names that the user types.
        if !password.isEmpty, password.count < SensorProvisioningConfiguration.minimumWiFiPasswordLength {
            throw SensorWiFiCredentialsIssue.passwordTooShort
        }
        guard password.utf8.count <= SensorProvisioningConfiguration.maximumWiFiPasswordBytes else {
            throw SensorWiFiCredentialsIssue.passwordTooLong
        }

        self.wiFiName = wiFiName
        self.password = password
    }
}
