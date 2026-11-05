import CryptoKit
import Foundation

/// The key that lets the app read the sensor values from the backend.
///
/// `readKey = hex(HMAC-SHA256(key: setup code, message: "beforefire-read-v1\n" + sensor serial))`
///
/// The firmware sends only `SHA-256(readKey)` to the backend, so the backend never stores the setup code.
nonisolated enum SensorReadKey {
    static func make(setupCode: String, deviceID: String) -> String {
        let message = Data("\(SensorBackendConfiguration.readKeyVersion)\n\(deviceID)".utf8)
        let key = SymmetricKey(data: Data(setupCode.utf8))
        let code = HMAC<SHA256>.authenticationCode(for: message, using: key)
        return code.map { String(format: "%02x", $0) }.joined()
    }
}
