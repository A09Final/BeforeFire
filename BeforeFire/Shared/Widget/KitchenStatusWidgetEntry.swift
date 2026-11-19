import Foundation
import WidgetKit

nonisolated struct KitchenStatusEntry: TimelineEntry {
    let date: Date
    let status: KitchenStatus
    var needsSensor = false
    var measuredAt: Date?
    var isOutdated = false
    #if DEBUG
    var isDeveloperPreview = false
    #endif

    func outdated(at date: Date) -> KitchenStatusEntry {
        let entry = self
        return KitchenStatusEntry(date: date, status: entry.status, needsSensor: entry.needsSensor,
                                  measuredAt: entry.measuredAt, isOutdated: true)
    }
}
