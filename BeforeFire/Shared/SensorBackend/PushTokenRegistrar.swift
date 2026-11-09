import Foundation
import os

/// Registers the APNs device token with the linked sensor, so the sensor keeps it
/// in NVS and includes it in every alert — which is how the backend knows which
/// phone to push a notification to.
///
/// The token and the sensor link can arrive in either order: the system delivers
/// the token at launch (`AppDelegate`), and the user links a sensor on the settings
/// screen. This object holds the latest token and registers once both exist.
@MainActor
final class PushTokenRegistrar {
    static let shared = PushTokenRegistrar()

    private let store: any SensorBackendLinkStoring
    private let client: any SensorCommandSending
    private let logger = Logger(subsystem: "BeforeFire", category: "PushToken")
    private var token: String?

    init(store: any SensorBackendLinkStoring = KeychainSensorBackendLinkStore(),
         client: any SensorCommandSending = URLSessionSensorCommandClient()) {
        self.store = store
        self.client = client
    }

    /// Call from `didRegisterForRemoteNotificationsWithDeviceToken`.
    func updateToken(_ token: String) {
        self.token = token
        register()
    }

    /// Call after the user links a sensor, to register a token that arrived first.
    func register() {
        guard let token, let link = store.load() else { return }
        Task { await send(token: token, to: link) }
    }

    private func send(token: String, to link: SensorBackendLink) async {
        do {
            let ack = try await client.send(SensorCommand(action: .registerPushToken, pushToken: token, link: link), for: link)
            logger.info("register_push_token: \(ack.result, privacy: .public) \(ack.reason ?? "", privacy: .public)")
        } catch {
            // The sensor may be offline right now; it still sends tokens it already has.
            // Registration retries on the next launch (the token is redelivered) or next link.
            logger.error("register_push_token failed: \(String(describing: error), privacy: .public)")
        }
    }
}
