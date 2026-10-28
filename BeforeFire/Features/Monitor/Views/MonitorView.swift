import SwiftUI

struct MonitorView: View {
    @State private var viewModel: MonitorViewModel

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    // DESIGN: Ukuran dasar judul dan status koneksi. Pertahankan ScaledMetric untuk Dynamic Type.
    @ScaledMetric(relativeTo: .title2) private var statusHeadingSize = MonitorStyle.statusHeadingSize
    @ScaledMetric(relativeTo: .largeTitle) private var statusValueSize = MonitorStyle.statusValueSize
    @ScaledMetric(relativeTo: .subheadline) private var connectionSize = 15.0
    @ScaledMetric(relativeTo: .body) private var actionGuidanceTextSize = MonitorStyle.actionGuidanceTextSize
    @ScaledMetric(relativeTo: .body) private var minimumCardHeight = MonitorStyle.cardHeight

    init(viewModel: MonitorViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        GeometryReader { geometry in
            if viewModel.isActionGuidanceVisible {
                scrollingContent(minimumHeight: geometry.size.height)
            } else {
                ViewThatFits(in: .vertical) {
                    expandedNormalContent
                    scrollingContent(minimumHeight: nil)
                }
            }
        }
        .background(MonitorStyle.background.ignoresSafeArea())
        // DESIGN: Keep the warm neutral palette in light mode. Edit its colors in MonitorStyle.
        .preferredColorScheme(.light)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var expandedNormalContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            connectionStatus
                .padding(.top, MonitorStyle.normalStatusSensorSpacing)
                .padding(.bottom, MonitorStyle.spacing)

            GeometryReader { gridGeometry in
                // DESIGN: Divide the remaining height equally after subtracting the row gaps.
                let rowGaps = CGFloat(max(0, rowCount - 1)) * MonitorStyle.spacing
                let rowHeight = (gridGeometry.size.height - rowGaps) / CGFloat(max(1, rowCount))
                sensorGrid(cardHeight: max(minimumCardHeight, rowHeight))
            }
            // ViewThatFits selects the scrolling layout when these minimum sizes cannot fit.
            .frame(minHeight: CGFloat(rowCount) * minimumCardHeight
                   + CGFloat(max(0, rowCount - 1)) * MonitorStyle.spacing)
        }
        .padding(.bottom, MonitorStyle.normalGridBottomInset)
        .frame(maxWidth: MonitorStyle.maximumContentWidth)
        .padding(.horizontal, MonitorStyle.spacing)
        .frame(maxWidth: .infinity)
    }

    private func scrollingContent(minimumHeight: CGFloat?) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header

                if let guidance = viewModel.actionGuidance {
                    actionGuidance(guidance)
                        .padding(.top, MonitorStyle.actionGuidanceTopSpacing)
                }

                if viewModel.isActionGuidanceVisible {
                    Spacer(minLength: MonitorStyle.spacing)
                }

                VStack(alignment: .leading, spacing: MonitorStyle.spacing) {
                    connectionStatus
                    sensorGrid(cardHeight: nil)
                }
                .padding(.top, viewModel.isActionGuidanceVisible ? 0 : MonitorStyle.normalStatusSensorSpacing)
                .padding(.bottom, viewModel.isActionGuidanceVisible
                         ? MonitorStyle.sensorSectionBottomInset : MonitorStyle.normalGridBottomInset)
            }
            .frame(minHeight: minimumHeight, alignment: .top)
            .frame(maxWidth: MonitorStyle.maximumContentWidth)
            .padding(.horizontal, MonitorStyle.spacing)
            .frame(maxWidth: .infinity)
        }
        // Allow vertical movement only when the content is taller than the visible area.
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .scrollIndicators(.hidden)
    }

    private func sensorGrid(cardHeight: CGFloat?) -> some View {
        LazyVGrid(columns: columns, spacing: MonitorStyle.spacing) {
            ForEach(viewModel.readings) { reading in
                MonitorReadingCard(
                    reading: reading,
                    alertCondition: viewModel.readingAlertCondition,
                    height: cardHeight
                )
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: MonitorStyle.statusHeadingSpacing) {
            HStack(alignment: .center, spacing: MonitorStyle.spacing) {
                Text(viewModel.statusHeading)
                    .font(.system(size: statusHeadingSize, weight: .regular))
                    .fontWidth(.expanded)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(MonitorStyle.statusMinimumScaleFactor)
                    .accessibilityHidden(true)

                Spacer(minLength: 8)

                NavigationLink {
                    MonitorDeveloperSettingsView(
                        isActionGuidanceVisible: $viewModel.isActionGuidanceVisible,
                        previewCondition: $viewModel.previewCondition
                    )
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
                // DESIGN: Keep the native Liquid Glass fill, border, and press effect.
                .labelStyle(.iconOnly)
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .controlSize(.large)
            }

            Text(viewModel.displayedStatusValue)
                .font(.system(size: statusValueSize, weight: .heavy))
                .foregroundStyle(viewModel.isAlarmPreview ? MonitorStyle.alarmText : MonitorStyle.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(MonitorStyle.statusMinimumScaleFactor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel(viewModel.displayedStatusTitle.replacingOccurrences(of: "\n", with: " "))
                .accessibilityAddTraits(.isHeader)
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
                .foregroundStyle(.secondary)
        }
    }

    private var columns: [GridItem] {
        // DESIGN: Ubah jumlah kolom di sini. Satu kolom menjaga keterbacaan pada ukuran teks aksesibilitas.
        Array(
            repeating: GridItem(.flexible(), spacing: MonitorStyle.spacing, alignment: .top),
            count: columnCount
        )
    }

    private var columnCount: Int {
        dynamicTypeSize.isAccessibilitySize ? 1 : 2
    }

    private var rowCount: Int {
        (viewModel.readings.count + columnCount - 1) / columnCount
    }
}

#Preview("Monitoring") {
    NavigationStack {
        MonitorView(viewModel: .mock)
    }
    .environment(AlarmPreviewModel())
}

#Preview("Large Text") {
    NavigationStack {
        MonitorView(viewModel: .mock)
            .environment(\.dynamicTypeSize, .accessibility3)
    }
    .environment(AlarmPreviewModel())
}
