import SwiftUI

enum MonitorStyle {
    // DESIGN: Use system fonts. Keep the status larger and heavier than its introductory text.
    static let statusHeadingSize: CGFloat = 30
    static let statusValueSize: CGFloat = 60
    static let statusHeadingSpacing: CGFloat = 4
    static let statusMinimumScaleFactor: CGFloat = 0.6

    // DESIGN: Labels and icons are smaller and lighter than sensor values.
    static let sensorLabelSize: CGFloat = 14
    static let sensorIconSize: CGFloat = 18
    static let sensorIconColumnWidth: CGFloat = 20
    static let sensorLabelRowHeight: CGFloat = 32
    static let readingMinimumScaleFactor: CGFloat = 0.7
    // DESIGN: Posisi nilai dan satuan dalam area di bawah label: .leading, .center, atau .trailing.
    // Gunakan .topLeading, .top, .topTrailing, .bottomLeading, .bottom, atau .bottomTrailing untuk posisi vertikal.
    static let readingValueAlignment: Alignment = .topLeading
    // DESIGN: Posisi vertikal satuan terhadap angka: .firstTextBaseline, .center, .top, atau .bottom.
    static let readingUnitAlignment: VerticalAlignment = .firstTextBaseline
    // DESIGN: Jarak angka dan satuan. Gunakan 0 agar keduanya menempel.
    static let readingUnitSpacing: CGFloat = 4
    // DESIGN: Size of the warning/alarm dot beside each sensor label.
    static let sensorStatusDotSize: CGFloat = 12

    // DESIGN: Edit colors in Assets.xcassets/Colors. These aliases assign each color to its UI role.
    // Named lookups do not require the editor to resolve generated asset symbols.
    static let background = Color("BonJour")
    // DESIGN: The card surface follows the native secondary system background.
    static let card = Color(uiColor: .secondarySystemBackground)
    static let primaryText = Color("Onyx")
    static let secondaryText = Color("Aluminium")
    static let connected = Color("ConnectionGreen")
    static let alarmText = Color("DangerRed")
    static let warningIndicator = Color("WarningYellow")
    // DESIGN: Base size and line spacing for the action text. The view scales the font for Dynamic Type.
    static let actionGuidanceTextSize: CGFloat = 20
    static let actionGuidanceLineSpacing: CGFloat = 4
    // DESIGN: Gap between the kitchen heading and its action text.
    static let actionGuidanceTopSpacing: CGFloat = 12

    // DESIGN: spacing dipakai bersama untuk jarak kartu, tepi halaman, dan padding horizontal isi kartu.
    static let spacing: CGFloat = 16
    // DESIGN: Fixed gap below the normal status; it does not grow with screen height.
    static let normalStatusSensorSpacing: CGFloat = 16
    // DESIGN: Breathing room between the expanded normal grid and the bottom safe area.
    static let normalGridBottomInset: CGFloat = 20
    // DESIGN: Reduce this inset to move the connection status and cards closer to the bottom safe area.
    static let sensorSectionBottomInset: CGFloat = 25
    // DESIGN: Ubah radius dan tinggi dasar kartu di sini. Tinggi ikut membesar dengan Dynamic Type.
    static let cardCornerRadius: CGFloat = 24
    static let cardHeight: CGFloat = 160
    // DESIGN: Batas lebar konten pada layar besar; konten tetap berada di tengah.
    static let maximumContentWidth: CGFloat = 600
}
