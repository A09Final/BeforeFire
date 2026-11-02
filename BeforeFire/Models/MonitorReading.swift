import Foundation

struct MonitorReading: Identifiable {
    enum Kind {
        case stoveHeat
        case airQuality
        case presence
        case roomTemperature
        case roomHumidity
        case areaPressure
    }

    let id: Kind
    let title: String
    let value: String
    let unit: String?
    let spokenValue: String
}
