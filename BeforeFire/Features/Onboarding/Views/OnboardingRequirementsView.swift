import SwiftUI

struct OnboardingRequirementsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text(OnboardingCopy.requirementsTitle)
                .font(.title2.bold())
                .accessibilityAddTraits(.isHeader)

            OnboardingInfoRow(
                symbol: DeviceConnectionPresentation(kind: .sensor).unitSymbolName,
                title: OnboardingCopy.sensorRequirementTitle,
                description: OnboardingCopy.sensorRequirementDescription
            )
            OnboardingInfoRow(
                symbol: DeviceConnectionPresentation(kind: .alarm).unitSymbolName,
                title: OnboardingCopy.alarmRequirementTitle,
                description: OnboardingCopy.alarmRequirementDescription
            )
            OnboardingInfoRow(
                symbol: "wifi",
                title: OnboardingCopy.wiFiRequirementTitle,
                description: OnboardingCopy.wiFiRequirementDescription
            )
        }
    }
}


#Preview {
    OnboardingRequirementsView()
        .tint(.blue)
        .padding(24)
}
