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
        switch condition {
        case .normal:
            content.sound = nil
            content.interruptionLevel = .passive
        case .warning1, .warning2:
            content.sound = .defaultCriticalSound(withAudioVolume: 1.0)
            content.interruptionLevel = .critical
        case .alarm:
            // Keep the provider's siren and interruption level.
            content.sound = original.sound ?? .default
            content.interruptionLevel = original.interruptionLevel
        }
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
