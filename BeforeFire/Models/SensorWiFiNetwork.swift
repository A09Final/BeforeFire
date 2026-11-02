import Foundation

/// A Wi-Fi network that the sensor unit found during its own scan.
nonisolated struct SensorWiFiNetwork: Identifiable, Hashable, Sendable {
    // RSSI limits for the signal icon. These are display levels only, not connection rules.
    static let strongSignalMinimum = -55
    static let mediumSignalMinimum = -67
    static let weakSignalMinimum = -80

    let ssid: String
    /// Received signal strength in dBm.
    let signalStrength: Int
    let isSecured: Bool

    var id: String { ssid }

    /// A value from 0 to 1 for the variable value of the `wifi` SF Symbol.
    var signalLevel: Double {
        switch signalStrength {
        case Self.strongSignalMinimum...: 1
        case Self.mediumSignalMinimum..<Self.strongSignalMinimum: 0.66
        case Self.weakSignalMinimum..<Self.mediumSignalMinimum: 0.33
        default: 0
        }
    }

    /// Removes hidden networks, keeps the strongest access point for each name, and puts the strongest signal first.
    static func displayList(from networks: [SensorWiFiNetwork]) -> [SensorWiFiNetwork] {
        var strongestNetworkByName: [String: SensorWiFiNetwork] = [:]
        for network in networks where !network.ssid.isEmpty {
            if let current = strongestNetworkByName[network.ssid], current.signalStrength >= network.signalStrength {
                continue
            }
            strongestNetworkByName[network.ssid] = network
        }
        return strongestNetworkByName.values.sorted {
            if $0.signalStrength != $1.signalStrength {
                return $0.signalStrength > $1.signalStrength
            }
            return $0.ssid.localizedStandardCompare($1.ssid) == .orderedAscending
        }
    }
}
