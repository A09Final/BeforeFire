import Foundation

struct MonitorViewModel {
    let connectionTitle: String
    let statusTitle: String
    let readings: [MonitorReading]

    // Developer preview state stays in memory and does not control any device.
    var isActionGuidanceVisible = false
    var previewCondition: MonitorPreviewCondition = .unsafe

    var displayedStatusTitle: String {
        isActionGuidanceVisible ? previewCondition.statusTitle : statusTitle
    }

    var actionGuidance: String? {
        isActionGuidanceVisible ? previewCondition.actionGuidance : nil
    }

    var isAlarmPreview: Bool {
        isActionGuidanceVisible && previewCondition == .dangerous
    }

    func badgeCondition(for kind: MonitorReading.Kind) -> MonitorPreviewCondition? {
        // The current mock scenario flags only stove heat. No sensor threshold is evaluated.
        guard isActionGuidanceVisible, kind == .stoveHeat else { return nil }
        return previewCondition
    }

    // Fixed values for the UI prototype. No device connection is made.
    static let mock = MonitorViewModel(
        connectionTitle: "Hub connected",
        statusTitle: "Your Kitchen Is\nSafe",
        // DESIGN: Urutan array menjadi urutan kartu, dari kiri ke kanan lalu ke baris berikutnya.
        // DESIGN: value berisi nilai, unit berisi satuan. Gunakan nil untuk status tanpa satuan.
        // Sesuaikan spokenValue agar VoiceOver tetap membaca nilai dan satuan secara lengkap.
        readings: [
            MonitorReading(id: .stoveHeat, title: "Stove Heat", value: "80", unit: "°C",
                           spokenValue: "80 degrees Celsius"),
            MonitorReading(id: .airQuality, title: "Air Quality", value: "Normal", unit: nil,
                           spokenValue: "Normal"),
            MonitorReading(id: .presence, title: "Presence", value: "Detected", unit: nil,
                           spokenValue: "Detected"),
            MonitorReading(id: .roomTemperature, title: "Room Temperature", value: "30", unit: "°C",
                           spokenValue: "30 degrees Celsius"),
            MonitorReading(id: .roomHumidity, title: "Room Humidity", value: "60", unit: "%",
                           spokenValue: "60 percent"),
            MonitorReading(id: .areaPressure, title: "Area Pressure", value: "1,013", unit: "hPa",
                           spokenValue: "1,013 hectopascals")
        ]
    )
}
