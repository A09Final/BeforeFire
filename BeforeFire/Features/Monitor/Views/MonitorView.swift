import SwiftUI

struct MonitorView: View {
    @State private var viewModel: MonitorViewModel

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var isSettingsPresented = false
    // DESIGN: Ukuran dasar judul dan status koneksi. Pertahankan ScaledMetric untuk Dynamic Type.
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize = 45.0
    @ScaledMetric(relativeTo: .subheadline) private var connectionSize = 15.0
    @ScaledMetric(relativeTo: .body) private var actionGuidanceTextSize = MonitorStyle.actionGuidanceTextSize

    init(viewModel: MonitorViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header

                    if let guidance = viewModel.actionGuidance {
                        actionGuidance(guidance)
                            .padding(.top, MonitorStyle.actionGuidanceTopSpacing)
                    }

                    // DESIGN: Jarak minimum antara header dan kartu; ruang layar tambahan dapat memperbesar jarak ini.
                    Spacer(minLength: viewModel.isActionGuidanceVisible ? MonitorStyle.spacing : 40)

                    // DESIGN: Keep the connection status with the cards; spacing controls their gap.
                    VStack(alignment: .leading, spacing: MonitorStyle.spacing) {
                        connectionStatus

                        // DESIGN: Susunan kolom diatur oleh columns; urutan kartu mengikuti readings di MonitorViewModel.
                        LazyVGrid(columns: columns, spacing: MonitorStyle.spacing) {
                            ForEach(viewModel.readings) { reading in
                                MonitorReadingCard(
                                    reading: reading,
                                    alertCondition: viewModel.badgeCondition(for: reading.id)
                                )
                            }
                        }
                    }
                    .padding(.bottom, MonitorStyle.sensorSectionBottomInset)
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
            MonitorDeveloperSettingsView(
                isActionGuidanceVisible: $viewModel.isActionGuidanceVisible,
                previewCondition: $viewModel.previewCondition
            )
        }
    }

    private var header: some View {
        // DESIGN: Align the kitchen title and settings button at the top of the page.
        HStack(alignment: .top, spacing: MonitorStyle.spacing) {
            Text(viewModel.displayedStatusTitle)
                // DESIGN: Ganti font di MonitorStyle. fixedSize memakai ukuran yang sudah diskalakan oleh ScaledMetric.
                .font(.custom(MonitorStyle.emphasisFontName, fixedSize: titleSize))
                .foregroundStyle(viewModel.isAlarmPreview ? MonitorStyle.alarmText : MonitorStyle.primaryText)
                // DESIGN: Keep the explicit two-line title; reduce its size when the first line needs more space.
                .lineLimit(2)
                .minimumScaleFactor(0.5)
                .layoutPriority(1)
                .accessibilityAddTraits(.isHeader)

            Spacer(minLength: 8)

            Button("Settings", systemImage: "gearshape") {
                isSettingsPresented = true
            }
            // DESIGN: Keep the native Liquid Glass fill, border, and press effect.
            .labelStyle(.iconOnly)
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .controlSize(.large)
        }
    }

    private func actionGuidance(_ guidance: String) -> some View {
        Text(guidance)
            .font(.system(size: actionGuidanceTextSize))
            .foregroundStyle(MonitorStyle.primaryText)
            .lineSpacing(MonitorStyle.actionGuidanceLineSpacing)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("monitor.actionGuidance")
    }

    private var connectionStatus: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(MonitorStyle.connected)
                .frame(width: 16, height: 16)
                .accessibilityHidden(true)

            Text(viewModel.connectionTitle)
                .font(.system(size: connectionSize))
                .foregroundStyle(MonitorStyle.secondaryText)
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
