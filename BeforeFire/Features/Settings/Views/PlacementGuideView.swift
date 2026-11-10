import SwiftUI

struct PlacementStep: Identifiable {
    let id: Int
    let title: String
    let description: String

    // Keep the current guide content in one place for Settings and onboarding.
    static let current = [
        PlacementStep(id: 0, title: "Sensor Placement Guide",
                      description: "Follow the placement of the sensor as shown in the instruction above"),
        PlacementStep(id: 1, title: "Step 2", description: "Add the second instruction here"),
        PlacementStep(id: 2, title: "Step 3", description: "Add the third instruction here")
    ]
}

struct PlacementGuidelineView: View {
    var onContinue: (() -> Void)? = nil
    @State private var selectedStep = 0
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        TabView(selection: $selectedStep) {
            ForEach(PlacementStep.current) { step in
                PlacementPage(step: step)
                    .tag(step.id)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Placement Guide")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            if onContinue == nil {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let onContinue {
                OnboardingActionButton(title: OnboardingCopy.continueButton) {
                    if selectedStep < PlacementStep.current.count - 1 {
                        withAnimation { selectedStep += 1 }
                    } else {
                        onContinue()
                    }
                }
                .accessibilityIdentifier("placement.continue")
                .padding(24)
                .background(Color(.systemGroupedBackground))
            }
        }
    }
}

struct PlacementPage: View {
    let step: PlacementStep

    var body: some View {
        ScrollView {
            VStack(alignment: .center, spacing: 30) {
                Text(step.title)
                    .font(.title2.bold())
                    .accessibilityAddTraits(.isHeader)
                Rectangle()
                    .fill(Color.black)
                    .frame(maxWidth: 300)
                    .aspectRatio(1, contentMode: .fit)
                    .accessibilityHidden(true)
                Text(step.description)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}

#Preview {
    NavigationStack { PlacementGuidelineView() }
}
