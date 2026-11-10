import UserNotifications

final class NotificationService: UNNotificationServiceExtension {
    override func didReceive(_ request: UNNotificationRequest,
                             withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        // Mapping is synchronous and uses only the sensor decision in the payload.
        // No network call, sensor inference, or .p8 key is needed in this extension.
        contentHandler(KitchenNotificationContent.mapped(request.content))
    }
}
