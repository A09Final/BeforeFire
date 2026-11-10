import Foundation

nonisolated struct PushDeviceRegistration: Equatable, Sendable {
    let bundleIdentifier: String
    let token: String

    init?(deviceToken: Data, bundleIdentifier: String) {
        guard !deviceToken.isEmpty, !bundleIdentifier.isEmpty else { return nil }
        self.bundleIdentifier = bundleIdentifier
        token = deviceToken.map { String(format: "%02x", $0) }.joined()
    }
}
