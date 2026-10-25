import SwiftUI

enum MonitorStyle {
    // DESIGN: Font judul, nilai, dan satuan. Nama ini sudah mencakup ketebalan Heavy.
    static let emphasisFontName = "AvenirNextCondensed-Heavy"

    // DESIGN: Bon Jour #E1DFE0 is the page background. Aluminium #AAB1BB is the card surface.
    static let background = Color(red: 225 / 255, green: 223 / 255, blue: 224 / 255)
    static let card = Color(red: 170 / 255, green: 177 / 255, blue: 187 / 255)
    // DESIGN: Onyx #1C1C1B keeps headings, values, card labels, and icons clear on warm surfaces.
    static let primaryText = Color(red: 28 / 255, green: 28 / 255, blue: 27 / 255)
    // DESIGN: Walnut #6A5D52 is used for secondary text on the page background.
    static let secondaryText = Color(red: 106 / 255, green: 93 / 255, blue: 82 / 255)
    static let connected = Color(red: 70 / 255, green: 181 / 255, blue: 85 / 255)
    // DESIGN: Red #B91C1C marks Dangerous. Yellow #FACC15 marks an Unsafe warning badge.
    static let alarmText = Color(red: 185 / 255, green: 28 / 255, blue: 28 / 255)
    static let warningBadge = Color(red: 250 / 255, green: 204 / 255, blue: 21 / 255)
    // DESIGN: Base size and line spacing for the action text. The view scales the font for Dynamic Type.
    static let actionGuidanceTextSize: CGFloat = 20
    static let actionGuidanceLineSpacing: CGFloat = 4
    // DESIGN: Gap between the kitchen heading and its action text.
    static let actionGuidanceTopSpacing: CGFloat = 12

    // DESIGN: spacing dipakai bersama untuk jarak kartu, tepi halaman, dan padding horizontal isi kartu.
    static let spacing: CGFloat = 16
    // DESIGN: Reduce this inset to move the connection status and cards closer to the bottom safe area.
    static let sensorSectionBottomInset: CGFloat = 25
    // DESIGN: Ubah radius dan tinggi dasar kartu di sini. Tinggi ikut membesar dengan Dynamic Type.
    static let cardCornerRadius: CGFloat = 24
    static let cardHeight: CGFloat = 160
    // DESIGN: Batas lebar konten pada layar besar; konten tetap berada di tengah.
    static let maximumContentWidth: CGFloat = 600
}
