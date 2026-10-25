import SwiftUI

enum MonitorStyle {
    // DESIGN: Font judul, nilai, dan satuan. Nama ini sudah mencakup ketebalan Heavy.
    static let emphasisFontName = "AvenirNextCondensed-Heavy"

    // DESIGN: Edit colors in Assets.xcassets/Colors. These aliases assign each color to its UI role.
    // Named lookups do not require the editor to resolve generated asset symbols.
    static let background = Color("BonJour")
    static let card = Color("Aluminium")
    static let primaryText = Color("Onyx")
    static let secondaryText = Color("Walnut")
    static let connected = Color("ConnectionGreen")
    static let alarmText = Color("DangerRed")
    static let warningBadge = Color("WarningYellow")
    static let alarmForeground = Color("AlarmForeground")
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
