import Foundation

nonisolated enum SensorHomeSetupError: Error, Equatable {
    /// The user closed the system Home setup.
    case cancelled
    case unsupported
    case missingEntitlement
    case accessoryNotFound
    case failed
}

protocol SensorHomeSetupPerforming {
    /// Opens the system Home setup. The user scans the HomeKit code on the sensor label there.
    func addSensorToHome() async throws
}
