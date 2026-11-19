import OSLog
import WidgetKit

struct KitchenStatusEntry: TimelineEntry {
    let date: Date
    let status: KitchenStatus
    var needsSensor = false
    #if DEBUG
    var isDeveloperPreview = false
    #endif
}

struct KitchenStatusTimelineProvider: TimelineProvider {
    private static let refreshInterval: TimeInterval = 15 * 60
    private let logger = Logger(subsystem: "BeforeFire", category: "KitchenStatusWidget")

    func placeholder(in context: Context) -> KitchenStatusEntry {
        KitchenStatusEntry(date: .now, status: .reported(KitchenAssessment(condition: .normal, isValid: true)))
    }

    func getSnapshot(in context: Context, completion: @escaping (KitchenStatusEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
        } else {
            Task { completion(await currentEntry()) }
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<KitchenStatusEntry>) -> Void) {
        Task {
            let entry = await currentEntry()
            let nextRefresh = entry.date.addingTimeInterval(Self.refreshInterval)
            #if DEBUG
            if entry.isDeveloperPreview {
                completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
                return
            }
            #endif
            let entries = if entry.status.condition != nil {
                [entry, KitchenStatusEntry(date: nextRefresh, status: .offline)]
            } else {
                [entry]
            }
            completion(Timeline(entries: entries, policy: .after(nextRefresh)))
        }
    }

    private func currentEntry() async -> KitchenStatusEntry {
        do {
            let connection = try KitchenStatusWidgetConnection()
            #if DEBUG
            if let entry = try developerPreview(using: connection) { return entry }
            #endif
            guard let access = try connection.load() else {
                return KitchenStatusEntry(date: .now, status: .unknown, needsSensor: true)
            }
            let result = await fetchReadings(using: access)
            #if DEBUG
            if let entry = try developerPreview(using: connection) { return entry }
            #endif
            // Do not show a result from a sensor disconnected while the request was active.
            guard try connection.load() == access else {
                return KitchenStatusEntry(date: .now, status: .unknown)
            }
            return KitchenStatusEntry(date: .now, status: KitchenStatus(snapshot: try result.get()))
        } catch {
            logger.debug("Cannot read the widget sensor status: \(String(describing: error), privacy: .private)")
            return KitchenStatusEntry(date: .now, status: .offline)
        }
    }

    private func fetchReadings(using access: SensorReadingsAccess) async -> Result<SensorReadingsSnapshot, Error> {
        do {
            return .success(try await URLSessionSensorReadingsClient().fetchReadings(using: access))
        } catch {
            return .failure(error)
        }
    }

    #if DEBUG
    private func developerPreview(using connection: KitchenStatusWidgetConnection) throws -> KitchenStatusEntry? {
        guard let condition = try connection.loadPreviewCondition() else { return nil }
        return KitchenStatusEntry(date: .now, status: .reported(condition.assessment), isDeveloperPreview: true)
    }
    #endif
}
