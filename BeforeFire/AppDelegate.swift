import UIKit
import UserNotifications

@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        PushNotificationManager.shared.didRegister(deviceToken: deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        PushNotificationManager.shared.didFailToRegister(error: error)
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        KitchenNotificationContent.foregroundOptions(for: notification.request.content.userInfo)
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping @Sendable () -> Void
    ) {
        let result: Result<KitchenPushEvent, KitchenPushPayloadError>?
        if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
            do {
                result = .success(try KitchenPushEvent(userInfo: response.notification.request.content.userInfo))
            } catch {
                result = .failure(error as? KitchenPushPayloadError ?? .invalidPayload)
            }
        } else {
            result = nil
        }

        Task { @MainActor in
            // UIKit completes the app launch on this thread after a notification tap.
            defer { completionHandler() }
            switch result {
            case .success(let event):
                PushNotificationManager.shared.receiveTappedEvent(event)
            case .failure(let error):
                PushNotificationManager.shared.reportPayloadError(error)
            case nil:
                break
            }
        }
    }
}
