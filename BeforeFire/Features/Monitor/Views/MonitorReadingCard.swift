import SwiftUI

struct MonitorReadingCard: View {
    let reading: MonitorReading

    // DESIGN: Ubah ukuran dasar label, nilai umum, Presence, dan Area Pressure di sini.
    // ScaledMetric menjaga ukuran teks agar mengikuti pengaturan Dynamic Type pengguna.
    @ScaledMetric(relativeTo: .body) private var labelSize = 16.0
    @ScaledMetric(relativeTo: .title) private var standardValueSize = 32.0
    @ScaledMetric(relativeTo: .title2) private var presenceValueSize = 22.0
    @ScaledMetric(relativeTo: .title2) private var pressureValueSize = 26.0
    // DESIGN: Ukuran satuan terpisah dari angka. Ubah unitSize untuk °C, %, dan hPa.
    @ScaledMetric(relativeTo: .body) private var unitSize = 20.0
    @ScaledMetric(relativeTo: .body) private var cardHeight = MonitorStyle.cardHeight
    // DESIGN: Jarak antara angka dan satuan. Gunakan 0 jika ingin keduanya menempel.
    private let unitSpacing: CGFloat = 4

    var body: some View {
        // DESIGN: alignment dan spacing mengatur posisi serta jarak label terhadap area nilai.
        VStack(alignment: .leading, spacing: 12) {
            Text(reading.title)
                .font(.system(size: labelSize, weight: .medium))
                .foregroundStyle(MonitorStyle.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            readingValue
                .foregroundStyle(MonitorStyle.primaryText)
                .fixedSize(horizontal: false, vertical: true)
                // DESIGN: alignment ini menempatkan nilai di kiri dan tengah vertikal ruang yang tersisa.
                .frame(maxHeight: .infinity, alignment: .leading)
        }
        // DESIGN: Padding mengatur jarak isi ke tepi kartu; tinggi dan radius dasarnya ada di MonitorStyle.
        .padding(.horizontal, MonitorStyle.spacing)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: cardHeight)
        .background(MonitorStyle.card, in: RoundedRectangle(cornerRadius: MonitorStyle.cardCornerRadius))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(reading.title)
        .accessibilityValue(reading.spokenValue)
    }

    private var readingValue: some View {
        // DESIGN: firstTextBaseline menyelaraskan dasar teks angka dan satuan meskipun ukurannya berbeda.
        HStack(alignment: .firstTextBaseline, spacing: unitSpacing) {
            Text(reading.value)
                // DESIGN: Ganti font atau weight ini untuk angka dan status tanpa satuan.
                .font(.system(size: valueSize, weight: .bold))

            if let unit = reading.unit {
                Text(unit)
                    // DESIGN: Font dan ketebalan satuan dapat diubah tanpa mengubah angka.
                    .font(.system(size: unitSize, weight: .bold))
            }
        }
    }

    private var valueSize: CGFloat {
        // DESIGN: Tentukan jenis kartu yang memakai ukuran khusus melalui switch ini.
        switch reading.id {
        case .presence:
            presenceValueSize
        case .areaPressure:
            pressureValueSize
        default:
            standardValueSize
        }
    }
}
