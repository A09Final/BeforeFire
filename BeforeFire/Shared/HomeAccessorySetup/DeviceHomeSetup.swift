import Foundation

nonisolated enum DeviceHomeSetupError: Error, Equatable {
    /// The user closed the system Home setup.
    case cancelled
    case unsupported
    case missingEntitlement
    case accessoryNotFound
    case failed
}

protocol DeviceHomeSetupPerforming {
    /// Opens the system Home setup. The user scans the HomeKit code on the unit label there.
    func addDeviceToHome() async throws
}
