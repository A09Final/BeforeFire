import Foundation

struct MonitorViewModel {
    let connectionTitle: String
    let statusTitle: String
    let readings: [MonitorReading]

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
