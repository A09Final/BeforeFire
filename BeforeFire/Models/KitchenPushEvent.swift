import Foundation

nonisolated enum KitchenPushPayloadError: Error, Equatable {
    case unrelatedNotification
    case invalidPayload
    case unsupportedEvent
    case differentDevice
}

nonisolated struct KitchenPushEvent: Identifiable, Equatable, Sendable {
    let id: String
    let deviceID: String
    let assessment: KitchenAssessment

    private static let supportedVersion = 2
    private static let maximumIDBytes = 128

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
        guard payload.version == Self.supportedVersion, payload.type == "condition" else {
            throw KitchenPushPayloadError.unsupportedEvent
        }
        guard Self.isValidID(payload.eventID), Self.isValidID(payload.deviceID) else {
            throw KitchenPushPayloadError.invalidPayload
        }
        id = payload.eventID
        deviceID = payload.deviceID
        assessment = payload.assessment
    }

    private static func isValidID(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.count <= maximumIDBytes && value == value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private struct Payload: Decodable {
        let version: Int
        let type: String
        let eventID: String
        let deviceID: String
        let assessment: KitchenAssessment

        enum CodingKeys: String, CodingKey {
            case version, type, assessment
            case eventID = "event_id"
            case deviceID = "device_id"
        }
    }
}
