import Foundation

/// The status shown in Monitor and on the Home Screen.
nonisolated enum KitchenStatus: Equatable, Sendable {
    case reported(KitchenAssessment)
    case unknown
    case offline

    init(snapshot: SensorReadingsSnapshot) {
        if snapshot.isStale || snapshot.connection == .offline {
            self = .offline
        } else if snapshot.connection == .online {
            self = .reported(snapshot.assessment)
        } else {
            self = .unknown
        }
    }

    var condition: KitchenCondition? {
        guard case .reported(let assessment) = self else { return nil }
        return assessment.validCondition
    }

    var title: String {
        switch self {
        case .offline: "Offline"
        case .unknown, .reported: condition?.displayName ?? KitchenGuidance.unknownStatus
        }
    }

    var guidance: String? {
        guard case .reported(let assessment) = self else { return nil }
        return KitchenGuidance.monitorMessage(for: assessment)
    }
}
