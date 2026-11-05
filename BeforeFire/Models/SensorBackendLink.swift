import Foundation

/// A problem in the values that the user types to link the sensor to the backend.
nonisolated enum SensorBackendLinkIssue: Error, Equatable {
    case invalidBackendAddress
    case invalidSensorSerial
    case invalidSetupCode
    case storageFailed
}

/// The values that the app needs to read the sensor values from the backend.
struct SensorBackendLink: Equatable, Sendable {
    let backendURL: URL
    /// The sensor serial on the label, for example `DAPUR_A1B2C3`. The backend uses it as the device ID.
    let deviceID: String
    /// The setup code (PoP) on the sensor label. The app keeps it in the Keychain.
    let setupCode: String

    /// Validates and normalizes typed values.
    /// - Parameters:
    ///   - backendAddress: For example `192.168.1.10`, `192.168.1.10:8080`, or `http://192.168.1.10:8080`.
    init(backendAddress: String, deviceID: String, setupCode: String) throws {
        backendURL = try Self.serverURL(from: backendAddress)
        self.deviceID = try Self.sensorSerial(from: deviceID)
        do {
            self.setupCode = try DeviceSetupCode(setupCode).value
        } catch {
            throw SensorBackendLinkIssue.invalidSetupCode
        }
    }

    var readKey: String {
        SensorReadKey.make(setupCode: setupCode, deviceID: deviceID)
    }

    var readingsURL: URL {
        backendURL.appending(path: SensorBackendConfiguration.readingsPath(deviceID: deviceID))
    }

    /// The address in the short form that the user typed, for example `http://192.168.1.10:8080`.
    var backendAddress: String {
        backendURL.absoluteString
    }

    /// Validates a typed server address. It adds the scheme and the default port when they are missing.
    static func serverURL(from rawAddress: String) throws -> URL {
        var address = rawAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        if !address.contains("://") {
            address = "\(SensorBackendConfiguration.defaultScheme)://\(address)"
        }
        guard var components = URLComponents(string: address),
              let scheme = components.scheme?.lowercased(),
              SensorBackendConfiguration.allowedSchemes.contains(scheme),
              let host = components.host, !host.isEmpty,
              components.path.isEmpty || components.path == "/",
              components.query == nil, components.fragment == nil,
              components.user == nil, components.password == nil
        else {
            throw SensorBackendLinkIssue.invalidBackendAddress
        }
        components.scheme = scheme
        components.path = ""
        if components.port == nil {
            components.port = SensorBackendConfiguration.defaultPort
        }
        guard let url = components.url else {
            throw SensorBackendLinkIssue.invalidBackendAddress
        }
        return url
    }

    /// Accepts only sensor serials, because only the sensor unit sends readings.
    private static func sensorSerial(from rawSerial: String) throws -> String {
        let serial = rawSerial.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let sensorKind = ProvisioningDeviceKind.sensor
        guard sensorKind.matches(advertisedName: serial) else {
            throw SensorBackendLinkIssue.invalidSensorSerial
        }
        let digits = serial.dropFirst(DeviceProvisioningConfiguration.sensorNamePrefix.count)
        guard digits.count == SensorBackendConfiguration.sensorSerialDigitCount,
              digits.allSatisfy(\.isHexDigit)
        else {
            throw SensorBackendLinkIssue.invalidSensorSerial
        }
        return serial
    }
}
