import Foundation

/// A sensor or alarm unit that advertises Wi-Fi provisioning over Bluetooth.
struct DiscoveredDevice: Identifiable, Hashable, Sendable {
    /// The Core Bluetooth peripheral identifier. It is stable only on this phone.
    let id: UUID
    let name: String
}
