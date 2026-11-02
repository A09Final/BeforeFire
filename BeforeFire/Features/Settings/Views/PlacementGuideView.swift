//
//  PlacementGuideView.swift
//  BeforeFire
//
//  Created by Devon on 27/10/26.
//

import SwiftUI

struct PlacementStep: Identifiable {
    let id = UUID()
    let title: String
    let description: String
}
struct PlacementGuidelineView: View {
    @Environment(\.dismiss) private var dismiss

    private let steps = [
        PlacementStep(title: "Sensor Placement Guide",
                      description: "Follow the placement of the sensor as shown in the instruction above"),
        PlacementStep(title: "Step 2", description: "Add the second instruction here"),
        PlacementStep(title: "Step 3", description: "Add the third instruction here")
    ]

    var body: some View {
        NavigationStack {
            TabView {
                ForEach(steps) { step in
                    PlacementPage(step: step)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
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
                    .font(.headline)
                Rectangle()
                    .fill(Color.black)
                    .frame(maxWidth: 300)
                    .frame(height: 300)
                Text(step.description)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}
#Preview {
    PlacementGuidelineView()
}
