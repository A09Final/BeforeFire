import UIKit
import UserNotifications

@MainActor
protocol PushNotificationClient {
    func authorizationSettings() async -> (status: UNAuthorizationStatus, criticalAlertsEnabled: Bool)
    func requestAuthorization() async throws
    func requestCriticalAlertAuthorization() async throws
    func registerForRemoteNotifications()
}

@MainActor
struct SystemPushNotificationClient: PushNotificationClient {
    func authorizationSettings() async -> (status: UNAuthorizationStatus, criticalAlertsEnabled: Bool) {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return (settings.authorizationStatus, settings.criticalAlertSetting == .enabled)
    }

    func requestAuthorization() async throws {
        _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
    }

    func requestCriticalAlertAuthorization() async throws {
        _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.criticalAlert])
    }

    func registerForRemoteNotifications() {
        UIApplication.shared.registerForRemoteNotifications()
    }
}
