import SwiftUI

struct OnboardingPage<Content: View>: View {
    let title: String
    var description: String? = nil
    var footer: String? = nil
    let buttonTitle: String
    var isBusy = false
    var buttonIdentifier = "onboarding.continue"
    let action: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                VStack(alignment: .leading, spacing: 16) {
                    Text(title)
                        .font(.largeTitle.bold())
                        .accessibilityAddTraits(.isHeader)
                    if let description {
                        Text(description)
                            .foregroundStyle(.secondary)
                    }
                }
                content()
            }
            .frame(maxWidth: 560, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(24)
        }
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 24) {
                if let footer {
                    Text(footer)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                OnboardingActionButton(title: buttonTitle, isBusy: isBusy, action: action)
                    .accessibilityIdentifier(buttonIdentifier)
            }
            .padding(24)
            .frame(maxWidth: 608)
            .frame(maxWidth: .infinity)
            .background(Color(.systemGroupedBackground))
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }
}

struct OnboardingActionButton: View {
    let title: String
    var isBusy = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                if isBusy { ProgressView().tint(.white) }
                Text(title)
            }
            .frame(maxWidth: .infinity, minHeight: 30)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .disabled(isBusy)
    }
}
