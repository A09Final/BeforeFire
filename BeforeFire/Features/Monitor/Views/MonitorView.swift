import SwiftUI

struct MonitorView: View {
    let viewModel: MonitorViewModel

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var isSettingsPresented = false
    // DESIGN: Ukuran dasar judul dan status koneksi. Pertahankan ScaledMetric untuk Dynamic Type.
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize = 32.0
    @ScaledMetric(relativeTo: .subheadline) private var connectionSize = 15.0

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header

                    // DESIGN: Jarak minimum antara header dan kartu; ruang layar tambahan dapat memperbesar jarak ini.
                    Spacer(minLength: 40)

                    // DESIGN: Susunan kolom diatur oleh columns; urutan kartu mengikuti readings di MonitorViewModel.
                    LazyVGrid(columns: columns, spacing: MonitorStyle.spacing) {
                        ForEach(viewModel.readings) { reading in
                            MonitorReadingCard(reading: reading)
                        }
                    }
                    // DESIGN: Ubah padding ini untuk mengatur ruang di atas dan di bawah kumpulan kartu.
                    .padding(.top, MonitorStyle.spacing)
                    .padding(.bottom, 52)
                }
                .frame(minHeight: geometry.size.height, alignment: .top)
                .frame(maxWidth: MonitorStyle.maximumContentWidth)
                .padding(.horizontal, MonitorStyle.spacing)
                .frame(maxWidth: .infinity)
            }
            // DESIGN: Halaman monitoring tetap diam saat digeser; wadah ini hanya mempertahankan layout.
            .scrollDisabled(true)
            .scrollIndicators(.hidden)
        }
        .background(MonitorStyle.background.ignoresSafeArea())
        // DESIGN: Keep the warm neutral palette in light mode. Edit its colors in MonitorStyle.
        .preferredColorScheme(.light)
        .sheet(isPresented: $isSettingsPresented) {
            MonitorSettingsPlaceholderView()
        }
    }

    private var header: some View {
        // DESIGN: spacing pada VStack mengatur jarak judul; spacing pada HStack mengatur jarak elemen koneksi.
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Circle()
                    .fill(MonitorStyle.connected)
                    .frame(width: 16, height: 16)
                    .accessibilityHidden(true)

                Text(viewModel.connectionTitle)
                    .font(.system(size: connectionSize))
                    .foregroundStyle(MonitorStyle.secondaryText)

                Spacer(minLength: 8)

                Button {
                    isSettingsPresented = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 24, weight: .regular))
                        .foregroundStyle(MonitorStyle.primaryText)
                        .frame(width: MonitorStyle.buttonSize, height: MonitorStyle.buttonSize)
                        .background(MonitorStyle.buttonBackground, in: Circle())
                        .overlay {
                            Circle().strokeBorder(MonitorStyle.buttonBorder, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Settings")
            }

            Text(viewModel.statusTitle)
                // DESIGN: Ganti font di MonitorStyle. fixedSize memakai ukuran yang sudah diskalakan oleh ScaledMetric.
                .font(.custom(MonitorStyle.emphasisFontName, fixedSize: titleSize))
                .foregroundStyle(MonitorStyle.primaryText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        }
    }

    private var columns: [GridItem] {
        // DESIGN: Ubah jumlah kolom di sini. Satu kolom menjaga keterbacaan pada ukuran teks aksesibilitas.
        Array(
            repeating: GridItem(.flexible(), spacing: MonitorStyle.spacing, alignment: .top),
            count: dynamicTypeSize.isAccessibilitySize ? 1 : 2
        )
    }
}

#Preview("Monitoring") {
    MonitorView(viewModel: .mock)
}

#Preview("Large Text") {
    MonitorView(viewModel: .mock)
        .environment(\.dynamicTypeSize, .accessibility3)
}
