import SwiftUI

struct OnboardingInfoRow: View {
    let symbol: String
    let title: String
    let description: String
    @ScaledMetric(relativeTo: .title2) private var iconSize = 28
    @ScaledMetric(relativeTo: .title2) private var iconColumnWidth = 40

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: symbol)
                .font(.system(size: iconSize, weight: .regular))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(.tint)
                .frame(width: iconColumnWidth)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}
