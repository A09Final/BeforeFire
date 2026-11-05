import UserNotifications

nonisolated enum KitchenNotificationContent {
    static func mapped(_ original: UNNotificationContent) -> UNNotificationContent {
        guard original.userInfo["beforefire"] != nil,
              let content = original.mutableCopy() as? UNMutableNotificationContent else { return original }
        guard let event = try? KitchenPushEvent(userInfo: original.userInfo),
              let condition = event.assessment.validCondition else {
            content.title = "Status unavailable"
            content.subtitle = ""
            content.body = "The sensor status could not be confirmed."
            content.sound = nil
            content.badge = nil
            content.interruptionLevel = .passive
            return content
        }
        content.title = condition.displayName
        content.subtitle = ""
        content.body = KitchenGuidance.notificationBody(for: event.assessment) ?? ""
        // Normal is informational. The provider must not send a Normal alert push.
        content.sound = condition == .normal ? nil : .default
        content.interruptionLevel = condition == .normal ? .passive : .active
        if condition == .normal { content.badge = nil }
        return content
    }

    static func foregroundOptions(for userInfo: [AnyHashable: Any]) -> UNNotificationPresentationOptions {
        guard userInfo["beforefire"] != nil else { return [.banner, .list, .sound] }
        guard let event = try? KitchenPushEvent(userInfo: userInfo),
              let condition = event.assessment.validCondition, condition != .normal else { return [] }
        return [.banner, .list, .sound]
    }
}
