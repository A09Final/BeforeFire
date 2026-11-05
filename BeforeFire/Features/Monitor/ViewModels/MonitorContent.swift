import Foundation

/// The status and the sensor cards that the Monitor screen shows.
struct MonitorContent: Equatable {
    let connectionTitle: String
    let statusValue: String
    /// `true` when the sensor reports the alarm condition. The screen then shows the status in the alarm color.
    let isDangerous: Bool
    let readings: [MonitorReading]
}
