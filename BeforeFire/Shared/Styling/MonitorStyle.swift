import SwiftUI

enum MonitorStyle {
    // DESIGN: Font judul, nilai, dan satuan. Nama ini sudah mencakup ketebalan Heavy.
    static let emphasisFontName = "AvenirNextCondensed-Heavy"

    // DESIGN: Stucco #E2E2DE is the page background. Greige #B7AC9B is the card surface.
    static let background = Color(red: 226 / 255, green: 226 / 255, blue: 222 / 255)
    static let card = Color(red: 183 / 255, green: 172 / 255, blue: 155 / 255)
    // DESIGN: Onyx #1C1C1B keeps headings, values, card labels, and icons clear on warm surfaces.
    static let primaryText = Color(red: 28 / 255, green: 28 / 255, blue: 27 / 255)
    // DESIGN: Use Walnut #6A5D52 on Stucco only. Its contrast is too low on Greige for small text.
    static let secondaryText = Color(red: 106 / 255, green: 93 / 255, blue: 82 / 255)
    static let connected = Color(red: 70 / 255, green: 181 / 255, blue: 85 / 255)

    // DESIGN: spacing dipakai bersama untuk jarak kartu, tepi halaman, dan padding horizontal isi kartu.
    static let spacing: CGFloat = 16
    // DESIGN: Reduce this inset to move the connection status and cards closer to the bottom safe area.
    static let sensorSectionBottomInset: CGFloat = 30
    // DESIGN: Ubah radius dan tinggi dasar kartu di sini. Tinggi ikut membesar dengan Dynamic Type.
    static let cardCornerRadius: CGFloat = 24
    static let cardHeight: CGFloat = 160
    // DESIGN: Batas lebar konten pada layar besar; konten tetap berada di tengah.
    static let maximumContentWidth: CGFloat = 600
}
