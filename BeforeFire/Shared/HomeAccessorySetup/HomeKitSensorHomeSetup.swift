import Foundation
import HomeKit

// The only file that uses HomeKit. Verified against the iOS 27.2 SDK headers.

/// Adds the HomeSpan sensor to a home with the system accessory setup UI.
struct HomeKitSensorHomeSetup: SensorHomeSetupPerforming {
    func addSensorToHome() async throws {
        guard HMAccessorySetupManager.isSupported else {
            throw SensorHomeSetupError.unsupported
        }

        // The request has no setup payload, because a payload needs the restricted
        // `com.apple.developer.homekit.allow-setup-payload` entitlement. The system UI scans the code.
        // With no home identifier, the system UI asks the user to choose a home.
        let request = HMAccessorySetupRequest()
        do {
            _ = try await HMAccessorySetupManager().performAccessorySetup(using: request)
        } catch {
            throw HomeKitSetupErrorMapping.error(for: error)
        }
    }
}

nonisolated enum HomeKitSetupErrorMapping {
    static func error(for error: Error) -> SensorHomeSetupError {
        let nsError = error as NSError
        guard nsError.domain == HMErrorDomain else { return .failed }

        return switch HMError.Code(rawValue: nsError.code) {
        case .operationCancelled:
            // TODO: Confirm on a device that closing the system Home setup UI returns this code.
            .cancelled
        case .missingEntitlement:
            .missingEntitlement
        case .accessoryNotReachable, .notFound:
            .accessoryNotFound
        default:
            .failed
        }
    }
}
