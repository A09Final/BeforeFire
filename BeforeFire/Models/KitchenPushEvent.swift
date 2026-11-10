import Foundation

nonisolated enum KitchenPushPayloadError: Error, Equatable {
    case unrelatedNotification
    case invalidPayload
    case differentDevice
}

/// Reads the APNs payload sent by A09Final-Backend/internal/alert/notification.go.
nonisolated struct KitchenPushEvent: Identifiable, Equatable, Sendable {
    let id: String
    let deviceID: String
    let assessment: KitchenAssessment
    let score: Double?
    let issuedAt: Int64

    init(userInfo: [AnyHashable: Any]) throws {
        guard let rawPayload = userInfo["beforefire"] else {
            throw KitchenPushPayloadError.unrelatedNotification
        }
        guard let fields = rawPayload as? [String: Any], JSONSerialization.isValidJSONObject(fields) else {
            throw KitchenPushPayloadError.invalidPayload
        }
        let payload: Payload
        do {
            payload = try JSONDecoder().decode(Payload.self, from: JSONSerialization.data(withJSONObject: fields))
        } catch {
            throw KitchenPushPayloadError.invalidPayload
        }
        guard Self.matches(payload.alertId, pattern: "[A-Za-z0-9_-]{1,64}"),
              Self.matches(payload.deviceId, pattern: "DAPUR_(ALM_)?[0-9A-F]{6}") else {
            throw KitchenPushPayloadError.invalidPayload
        }
        id = payload.alertId
        deviceID = payload.deviceId
        score = payload.score
        issuedAt = payload.issuedAt
        // The backend validates condition. It does not send rule, reason, or duration metadata.
        // Preserve that condition; never classify the score again in the app.
        assessment = KitchenAssessment(condition: payload.condition, isValid: true)
    }

    private static func matches(_ value: String, pattern: String) -> Bool {
        value.range(of: "\\A(?:" + pattern + ")\\z", options: .regularExpression) != nil
    }

    private struct Payload: Decodable {
        let deviceId: String
        let alertId: String
        let condition: KitchenCondition
        let score: Double?
        let issuedAt: Int64
    }
}
