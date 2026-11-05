import Foundation
import HomeKit
import OSLog

// The only file that uses HomeKit. Verified against the iOS 27.2 SDK headers.

/// Adds a HomeSpan unit (sensor or alarm) to a home with the system accessory setup UI.
struct HomeKitDeviceHomeSetup: DeviceHomeSetupPerforming {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "BeforeFire", category: "HomeSetup")

    func addDeviceToHome() async throws {
        guard HMAccessorySetupManager.isSupported else {
            Self.logger.error("Home setup is not supported on this device.")
            throw DeviceHomeSetupError.unsupported
        }

        // The request has no setup payload, because a payload needs the restricted
        // `com.apple.developer.homekit.allow-setup-payload` entitlement. The system UI scans the code.
        // With no home identifier, the system UI asks the user to choose a home.
        let request = HMAccessorySetupRequest()
        Self.logger.info("Home setup started.")
        do {
            let result = try await HMAccessorySetupManager().performAccessorySetup(using: request)
            Self.logger.info("Home setup added \(result.accessoryUniqueIdentifiers.count, privacy: .public) accessories.")
        } catch {
            // The domain and code identify the HomeKit failure. They contain no Wi-Fi values or setup codes.
            let nsError = error as NSError
            Self.logger.error("Home setup failed: \(nsError.domain, privacy: .public) \(nsError.code, privacy: .public)")
            throw HomeKitSetupErrorMapping.error(for: error)
        }
    }
}

nonisolated enum HomeKitSetupErrorMapping {
    // The SDK does not declare this domain. An iOS 27.2 device returned it when the system Home setup closed.
    static let homeFoundationErrorDomain = "HMFErrorDomain"
    static let homeFoundationCancelledCode = 12

    static func error(for error: Error) -> DeviceHomeSetupError {
        let nsError = error as NSError
        if nsError.domain == homeFoundationErrorDomain, nsError.code == homeFoundationCancelledCode {
            return .cancelled
        }
        guard nsError.domain == HMErrorDomain else { return .failed }

        return switch HMError.Code(rawValue: nsError.code) {
        case .operationCancelled:
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
