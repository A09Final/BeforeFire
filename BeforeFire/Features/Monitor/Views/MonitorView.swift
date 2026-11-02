import SwiftUI

struct MonitorView: View {
    @State private var viewModel: MonitorViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .title2) private var statusHeadingSize = MonitorStyle.statusHeadingSize
    @ScaledMetric(relativeTo: .largeTitle) private var statusValueSize = MonitorStyle.statusValueSize
    @ScaledMetric(relativeTo: .subheadline) private var connectionSize = MonitorStyle.connectionSize
    @ScaledMetric(relativeTo: .body) private var actionGuidanceTextSize = MonitorStyle.actionGuidanceTextSize
    @ScaledMetric(relativeTo: .body) private var minimumCardHeight = MonitorStyle.cardHeight

    init(viewModel: MonitorViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ViewThatFits(in: .vertical) {
            pageContent(expandsGrid: true)
            ScrollView {
                pageContent(expandsGrid: false)
            }
            .scrollBounceBehavior(.basedOnSize, axes: .vertical)
            .scrollIndicators(.hidden)
        }
        .background(MonitorStyle.background.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .toolbar(.hidden, for: .navigationBar)
    }

    private func pageContent(expandsGrid: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if let guidance = viewModel.actionGuidance {
                actionGuidance(guidance)
                    .padding(.top, MonitorStyle.actionGuidanceTopSpacing)
            }

            connectionStatus
                .padding(.top, viewModel.isActionGuidanceVisible
                         ? MonitorStyle.actionGuidanceBottomSpacing : MonitorStyle.normalStatusSensorSpacing)
                .padding(.bottom, MonitorStyle.spacing)

            if expandsGrid {
                GeometryReader { geometry in
                    let gaps = CGFloat(max(0, rowCount - 1)) * MonitorStyle.spacing
                    let rowHeight = (geometry.size.height - gaps) / CGFloat(max(1, rowCount))
                    sensorGrid(cardHeight: max(minimumCardHeight, rowHeight))
                }
                .frame(minHeight: CGFloat(rowCount) * minimumCardHeight
                       + CGFloat(max(0, rowCount - 1)) * MonitorStyle.spacing)
            } else {
                sensorGrid(cardHeight: nil)
            }
        }
        .padding(.top, MonitorStyle.pageTopInset)
        .padding(.bottom, MonitorStyle.normalGridBottomInset)
        .frame(maxWidth: MonitorStyle.maximumContentWidth)
        .padding(.horizontal, MonitorStyle.pageHorizontalInset)
        .frame(maxWidth: .infinity)
    }

    private func sensorGrid(cardHeight: CGFloat?) -> some View {
        LazyVGrid(columns: columns, spacing: MonitorStyle.spacing) {
            ForEach(viewModel.readings) { reading in
                MonitorReadingCard(reading: reading,
                                   alertCondition: viewModel.readingAlertCondition,
                                   height: cardHeight)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: MonitorStyle.statusHeadingSpacing) {
            Text(viewModel.statusHeading.uppercased())
                .font(.system(size: statusHeadingSize, weight: .semibold))
                .fontWidth(MonitorStyle.fontWidth)
                .tracking(MonitorStyle.statusHeadingTracking)
                .foregroundStyle(MonitorStyle.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(MonitorStyle.statusMinimumScaleFactor)
                .padding(.trailing, MonitorStyle.settingsButtonSize + MonitorStyle.spacing)
                .accessibilityHidden(true)

            Text(viewModel.displayedStatusValue.uppercased())
                .font(.system(size: statusValueSize, weight: MonitorStyle.valueWeight))
                .fontWidth(MonitorStyle.fontWidth)
                .tracking(MonitorStyle.statusTracking)
                .foregroundStyle(viewModel.isAlarmPreview ? MonitorStyle.alarmText : MonitorStyle.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(MonitorStyle.statusMinimumScaleFactor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel(viewModel.displayedStatusTitle.replacingOccurrences(of: "\n", with: " "))
                .accessibilityAddTraits(.isHeader)
                .padding(.bottom, MonitorStyle.statusBottomInset)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .topTrailing) {
            settingsLink
        }
    }

    private var settingsLink: some View {
        NavigationLink {
            MonitorDeveloperSettingsView(
                isActionGuidanceVisible: $viewModel.isActionGuidanceVisible,
                previewCondition: $viewModel.previewCondition
            )
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: MonitorStyle.settingsIconSize))
                .frame(width: MonitorStyle.settingsButtonSize, height: MonitorStyle.settingsButtonSize)
        }
        .foregroundStyle(MonitorStyle.primaryText)
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel("Settings")
        .accessibilityIdentifier("monitor.settings")
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
        HStack(spacing: MonitorStyle.connectionSpacing) {
            Circle()
                .fill(MonitorStyle.connected)
                .frame(width: MonitorStyle.connectionDotSize, height: MonitorStyle.connectionDotSize)
                .accessibilityHidden(true)
            Text(viewModel.connectionTitle)
                .font(.system(size: connectionSize))
                .foregroundStyle(MonitorStyle.secondaryText)
        }
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: MonitorStyle.spacing, alignment: .top),
              count: columnCount)
    }

    private var columnCount: Int { dynamicTypeSize.isAccessibilitySize ? 1 : 2 }
    private var rowCount: Int { (viewModel.readings.count + columnCount - 1) / columnCount }
}

#Preview("Monitoring") {
    NavigationStack { MonitorView(viewModel: .mock) }
        .environment(AlarmPreviewModel())
}

#Preview("Large Text") {
    NavigationStack {
        MonitorView(viewModel: .mock)
            .environment(\.dynamicTypeSize, .accessibility3)
    }
    .environment(AlarmPreviewModel())
}

#Preview("Dangerous") {
    NavigationStack {
        MonitorView(viewModel: {
            var model = MonitorViewModel.mock
            model.isActionGuidanceVisible = true
            model.previewCondition = .dangerous
            return model
        }())
    }
    .environment(AlarmPreviewModel())
}
